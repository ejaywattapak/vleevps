#!/bin/bash
set -euo pipefail

# ============================================================
# VLEE AI AGENT
# Autonomous VPS troubleshooting / repair agent
# by ejaywattapak
# ============================================================

APP="/usr/local/bin/ai"
CONF="/root/.vlee_ai"
KEY_FILE="$CONF/api_key"
MODEL_FILE="$CONF/model"
LOG_FILE="$CONF/agent.log"
API_URL="https://api.vleee.net/v1/chat/completions"
MODEL="cb/gpt-5.6-luna"

# -------------------- helpers --------------------
die() {
    echo "✘ $*"
    exit 1
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

install_packages() {
    local packages=("$@")

    if command_exists apt-get; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -y -qq "${packages[@]}"
    elif command_exists dnf; then
        dnf install -y "${packages[@]}"
    elif command_exists yum; then
        yum install -y "${packages[@]}"
    elif command_exists apk; then
        apk add "${packages[@]}"
    else
        die "Unsupported package manager."
    fi
}

# -------------------- root --------------------
[ "$(id -u)" -eq 0 ] || die "Run this installer as root."

clear

# -------------------- dependency check --------------------
echo "╭──────────────────────────────────────────────────────────╮"
echo "│                  VLEE AI AGENT                           │"
echo "│              by ejaywattapak                             │"
echo "╰──────────────────────────────────────────────────────────╯"
echo

echo "◆ [1/6] Checking dependencies"

MISSING=()
for cmd in bash curl python3 figlet; do
    command_exists "$cmd" || MISSING+=("$cmd")
done

if [ "${#MISSING[@]}" -gt 0 ]; then
    echo "  Missing: ${MISSING[*]}"
    echo "  Installing required packages..."

    PKGS=()
    for x in "${MISSING[@]}"; do
        case "$x" in
            bash) PKGS+=("bash") ;;
            curl) PKGS+=("curl") ;;
            python3) PKGS+=("python3") ;;
            figlet) PKGS+=("figlet") ;;
        esac
    done

    install_packages "${PKGS[@]}"
fi

for cmd in bash curl python3 figlet; do
    command_exists "$cmd" || die "Dependency unavailable: $cmd"
done

echo "✔ Dependencies OK"
echo

# -------------------- big banner --------------------
clear
figlet -f standard "VLEE AI"
echo "              AGENT BY EJAYWATAPAK"
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "              AUTONOMOUS VPS AGENT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# -------------------- API key --------------------
echo "◆ [2/6] API key"
echo
echo "Masukkan VLEEE API key."
echo "Input dibaca dari /dev/tty."
echo

read -r -s -p "➜ VLEEE API key: " API_KEY </dev/tty
echo

[ -n "$API_KEY" ] || die "API key kosong."

mkdir -p "$CONF"
chmod 700 "$CONF"

printf '%s\n' "$API_KEY" > "$KEY_FILE"
printf '%s\n' "$MODEL" > "$MODEL_FILE"

chmod 600 "$KEY_FILE" "$MODEL_FILE"

echo "✔ API key saved"
echo "✔ Model: $MODEL"
echo

# -------------------- backup --------------------
echo "◆ [3/6] Backup existing agent"

if [ -f "$APP" ]; then
    BACKUP="${APP}.backup.$(date +%Y%m%d-%H%M%S)"
    cp -a "$APP" "$BACKUP"
    echo "✔ Existing agent backed up:"
    echo "  $BACKUP"
else
    echo "✔ No existing agent"
fi
echo

# -------------------- install agent --------------------
echo "◆ [4/6] Installing autonomous agent"

cat > "$APP" <<'AI'
#!/bin/bash
set -u

CONF="/root/.vlee_ai"
KEY_FILE="$CONF/api_key"
MODEL_FILE="$CONF/model"
LOG_FILE="$CONF/agent.log"
API_URL="https://api.vleee.net/v1/chat/completions"

mkdir -p "$CONF"
chmod 700 "$CONF"

log() {
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE"
}

model() {
    if [ -s "$MODEL_FILE" ]; then
        cat "$MODEL_FILE"
    else
        echo "cb/gpt-5.6-luna"
    fi
}

key() {
    [ -s "$KEY_FILE" ] && cat "$KEY_FILE"
}

banner() {
    clear
    if command -v figlet >/dev/null 2>&1; then
        figlet -f standard "VLEE AI"
    else
        echo "VLEE AI"
    fi
    echo "              AGENT BY EJAYWATAPAK"
    echo
}

# Return a compact, useful snapshot of this VPS.
vps_snapshot() {
    {
        echo "=== DATE ==="
        date
        echo
        echo "=== HOST ==="
        hostnamectl 2>/dev/null || hostname
        echo
        echo "=== OS ==="
        cat /etc/os-release 2>/dev/null || true
        echo
        echo "=== KERNEL ==="
        uname -a
        echo
        echo "=== UPTIME ==="
        uptime
        echo
        echo "=== MEMORY ==="
        free -h
        echo
        echo "=== DISK ==="
        df -hT
        echo
        echo "=== FAILED SERVICES ==="
        systemctl --failed --no-legend 2>/dev/null || true
        echo
        echo "=== LISTENING PORTS ==="
        ss -lntup 2>/dev/null | head -100 || true
    } 2>&1
}

# Run a command and return output.
run_cmd() {
    local cmd="$1"
    local output rc

    log "EXEC: $cmd"

    output="$(bash -lc "$cmd" 2>&1)"
    rc=$?

    printf '%s\n' "$output"
    printf '\n[exit_code=%s]\n' "$rc"

    log "EXIT: $rc"
    return 0
}

# JSON request. The model is fixed intentionally.
ask_model() {
    local system_prompt="$1"
    local user_prompt="$2"
    local k m payload response

    k="$(key)"
    m="$(model)"

    [ -n "$k" ] || {
        echo "ERROR:"
        echo "API key belum diset."
        return 1
    }

    payload="$(
        python3 - "$m" "$system_prompt" "$user_prompt" <<'PY'
import json
import sys

model, system_prompt, user_prompt = sys.argv[1:4]

print(json.dumps({
    "model": model,
    "messages": [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt}
    ],
    "temperature": 0.1
}))
PY
    )"

    response="$(
        curl -sS \
            --connect-timeout 15 \
            --max-time 180 \
            -H "Authorization: Bearer $k" \
            -H "Content-Type: application/json" \
            -d "$payload" \
            "$API_URL" 2>&1
    )"

    log "API response received"

    python3 - "$response" <<'PY'
import json
import sys

raw = sys.argv[1]

try:
    data = json.loads(raw)
except Exception:
    print("ERROR:")
    print(raw)
    raise SystemExit(0)

if "error" in data:
    err = data["error"]
    print("ERROR:")
    if isinstance(err, dict):
        print(err.get("message", err))
    else:
        print(err)
    raise SystemExit(0)

choices = data.get("choices") or []
if not choices:
    print("ERROR:")
    print(raw)
    raise SystemExit(0)

msg = choices[0].get("message", {})
content = msg.get("content", "")

if isinstance(content, list):
    parts = []
    for item in content:
        if isinstance(item, dict):
            if "text" in item:
                parts.append(str(item["text"]))
    content = "".join(parts)

print(content)
PY
}

test_api() {
    echo
    echo "◆ API test"
    echo "  Endpoint : $API_URL"
    echo "  Model    : $(model)"
    echo

    local result
    result="$(
        ask_model \
            "You are a VPS AI agent. Reply with exactly VLEE AI OK and nothing else." \
            "Test the connection."
    )"

    printf '%s\n' "$result"

    if printf '%s' "$result" | grep -q "ERROR:"; then
        echo
        echo "✘ API test failed."
        echo "If VLEEE reports provider exhaustion/cooldown, the VPS agent cannot use"
        echo "the model until the provider becomes available again."
    else
        echo
        echo "✔ API connection works."
    fi
}

change_key() {
    echo
    read -r -s -p "  New VLEEE API key: " NEW_KEY </dev/tty
    echo

    if [ -z "$NEW_KEY" ]; then
        echo "  ✘ Empty key."
        return
    fi

    printf '%s\n' "$NEW_KEY" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    echo "  ✔ API key updated."
}

show_status() {
    echo
    echo "  Model : $(model)"
    echo "  Agent : $0"
    echo "  Key   : $([ -s "$KEY_FILE" ] && echo configured || echo missing)"
    echo "  Log   : $LOG_FILE"
    echo
}

# Extract shell blocks from the model response.
extract_commands() {
    python3 - <<'PY'
import re
import sys

text = sys.stdin.read()

blocks = re.findall(r"```(?:bash|sh|shell|console)?\s*\n(.*?)```", text, re.S | re.I)

for block in blocks:
    for line in block.splitlines():
        line=line.rstrip()
        if line.strip():
            print(line)
PY
}

# Commands that should never be silently executed by an autonomous repair loop.
dangerous_command() {
    local c="$1"

    case "$c" in
        *"rm -rf /"*|*"mkfs "*|*"mkfs."*|*"dd if="*|*"shutdown"*|*"reboot"*|*"poweroff"*|*"init 0"*|*"iptables -F"*|*"nft flush ruleset"*|*"userdel "*|*"passwd "*)
            return 0
            ;;
    esac

    return 1
}

# Autonomous diagnosis + repair loop.
agent() {
    local request="$1"
    local context=""
    local answer=""
    local commands=""
    local cmd=""
    local i=1
    local max_rounds=6

    banner

    echo "AI > $request"
    echo
    echo "◆ Autonomous VPS agent started"
    echo "  Model: $(model)"
    echo "  Max repair rounds: $max_rounds"
    echo

    context="$(vps_snapshot)"

    while [ "$i" -le "$max_rounds" ]; do
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  ROUND $i/$max_rounds"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        answer="$(
            ask_model \
                'You are an autonomous Linux VPS troubleshooting and repair agent.

You have shell access through a wrapper that executes commands you provide.

Your job:
1. Diagnose the user request using the VPS information and command output.
2. Inspect files/scripts when necessary.
3. Fix problems automatically when a safe fix is possible.
4. Prefer backups before modifying important files.
5. Verify every change after making it.
6. Do not claim a command was executed unless its output is supplied.
7. Do not invent files, services, paths, APIs, or command output.

When you need the wrapper to execute a command, put ONLY executable shell commands inside a fenced bash block.

Rules for commands:
- Use read-only commands for diagnosis first.
- Before editing an existing important file, create a timestamped backup.
- Use bash -n for shell scripts after editing.
- Verify services/configuration after changes.
- Do not use destructive commands such as rm -rf /, disk formatting, reboot/shutdown, firewall flush, or password/user deletion automatically.
- If a dangerous action is required, explain it and stop.

Your response may contain normal explanation plus fenced bash command blocks.' \
                "USER REQUEST:
$request

CURRENT VPS SNAPSHOT:
$context"
        )"

        if printf '%s\n' "$answer" | grep -q '^ERROR:'; then
            printf '%s\n' "$answer"
            return
        fi

        printf '%s\n' "$answer"

        commands="$(
            printf '%s\n' "$answer" | extract_commands
        )"

        if [ -z "$commands" ]; then
            echo
            echo "◆ No command requested by agent."
            echo "◆ Diagnosis/fix cycle finished."
            return
        fi

        echo
        echo "◆ Commands proposed by AI"

        while IFS= read -r cmd; do
            [ -n "$cmd" ] || continue

            echo
            printf '  $ %s\n' "$cmd"

            if dangerous_command "$cmd"; then
                echo "  ⚠ Blocked dangerous command."
                echo "  AI must explain this action instead of executing it."
                context="${context}

BLOCKED COMMAND:
$cmd
Reason: dangerous command requires manual approval."
                continue
            fi

            echo "  ▶ Executing..."
            result="$(run_cmd "$cmd")"

            echo "$result"

            context="${context}

COMMAND:
$cmd

OUTPUT:
$result"
        done <<< "$commands"

        echo
        echo "◆ Sending command results back to AI..."
        i=$((i + 1))
    done

    echo
    echo "◆ Maximum repair rounds reached."
    echo "  Review the output above and the log:"
    echo "  $LOG_FILE"
}

terminal() {
    while :; do
        echo
        printf "AI > "
        IFS= read -r prompt </dev/tty || return

        [ "$prompt" = "exit" ] && return
        [ -z "$prompt" ] && continue

        agent "$prompt"
    done
}

menu() {
    while :; do
        banner
        echo "  ╭────────────────────────────────────────────────────╮"
        echo "  │  1) Start autonomous AI terminal                 │"
        echo "  │  2) Check VPS status                              │"
        echo "  │  3) Test API connection                           │"
        echo "  │  4) Change API key                                │"
        echo "  │  5) Show agent info                               │"
        echo "  │  6) Exit                                          │"
        echo "  ╰────────────────────────────────────────────────────╯"
        echo

        read -r -p "  Select [1-6]: " choice </dev/tty

        case "$choice" in
            1)
                terminal
                ;;
            2)
                banner
                echo "◆ VPS STATUS"
                echo
                vps_snapshot
                read -r -p $'\nPress Enter...' _ </dev/tty
                ;;
            3)
                banner
                test_api
                read -r -p $'\nPress Enter...' _ </dev/tty
                ;;
            4)
                banner
                change_key
                read -r -p $'\nPress Enter...' _ </dev/tty
                ;;
            5)
                banner
                show_status
                read -r -p $'\nPress Enter...' _ </dev/tty
                ;;
            6)
                clear
                exit 0
                ;;
            *)
                echo "  Invalid option."
                sleep 1
                ;;
        esac
    done
}

menu
AI

chmod 700 "$APP"

echo "✔ Autonomous agent installed"
echo

# -------------------- syntax --------------------
echo "◆ [5/6] Syntax validation"

bash -n "$APP" || {
    echo "✘ Agent syntax validation failed."
    exit 1
}

echo "✔ Bash syntax OK"
echo

# -------------------- final --------------------
echo "◆ [6/6] Final verification"

[ -x "$APP" ] || die "Agent is not executable."
[ -s "$KEY_FILE" ] || die "API key was not saved."
[ "$(cat "$MODEL_FILE")" = "$MODEL" ] || die "Model configuration mismatch."

echo "✔ Agent verified"
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                     VLEE AI READY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "Model: $MODEL"
echo
echo "Run:"
echo "  ai"
echo
echo "API config:"
echo "  $CONF"
echo
echo "Agent:"
echo "  $APP"
echo
