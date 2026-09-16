#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# VLEE AI AGENT - Installer
# Model: gpt-5.6-luna
# Commands: ai / ai-menu
# ============================================================

API_BASE="https://api.vleee.net/v1"
MODEL="gpt-5.6-luna"
CONF_DIR="/root/.vlee_ai"
KEY_FILE="$CONF_DIR/api_key"
AI_BIN="/usr/local/bin/ai"
MENU_BIN="/usr/local/bin/ai-menu"
BACKUP_DIR="$CONF_DIR/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"

printf '\033c'
if ! command -v figlet >/dev/null 2>&1; then
    echo "◆ Installing required font/banner tool: figlet"
    if command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -y -qq figlet >/dev/null
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y figlet >/dev/null
    elif command -v yum >/dev/null 2>&1; then
        yum install -y figlet >/dev/null
    else
        echo "ERROR: Cannot install figlet automatically."
        exit 1
    fi
fi

figlet -f standard "VLEE AI" 2>/dev/null || echo "VLEE AI"
echo "        AGENT BY EJAYWATTAPAK"
echo
echo "◆ [1/6] Check dependencies"

for cmd in curl bash awk sed grep date; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "ERROR: Missing dependency: $cmd"
        exit 1
    }
done
echo "✔ Dependencies OK"

mkdir -p "$CONF_DIR" "$BACKUP_DIR"
chmod 700 "$CONF_DIR" "$BACKUP_DIR"

echo "◆ [2/6] API key"
if [[ -s "$KEY_FILE" ]]; then
    echo "✔ Existing API key found"
else
    printf "➜ Masukkan VLEEE API key: "
    IFS= read -r API_KEY </dev/tty
    [[ -n "$API_KEY" ]] || { echo "ERROR: API key kosong."; exit 1; }
    printf '%s\n' "$API_KEY" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    unset API_KEY
    echo "✔ API key saved"
fi

echo "◆ [3/6] Backup existing agent"
for f in "$AI_BIN" "$MENU_BIN"; do
    if [[ -f "$f" ]]; then
        cp -a "$f" "$BACKUP_DIR/$(basename "$f").$STAMP.bak"
        echo "✔ Backed up $(basename "$f")"
    fi
done

echo "◆ [4/6] Installing autonomous agent"

cat > "$AI_BIN" <<'AI_EOF'
#!/usr/bin/env bash
set -u

API_BASE="https://api.vleee.net/v1"
MODEL="gpt-5.6-luna"
CONF_DIR="/root/.vlee_ai"
KEY_FILE="$CONF_DIR/api_key"

die() {
    echo "ERROR: $*"
    return 1
}

get_key() {
    [[ -s "$KEY_FILE" ]] || { echo "ERROR: API key belum diset. Guna: ai-menu"; return 1; }
    cat "$KEY_FILE"
}

json_escape() {
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
}

api_call() {
    local prompt="$1"
    local key
    key="$(get_key)" || return 1

    # No max-per-mtok bid / discount parameters are sent.
    # VLEEE can therefore route to any currently available provider.
    local payload
    payload="$(python3 - "$MODEL" "$prompt" <<'PY'
import json,sys
model=sys.argv[1]
prompt=sys.argv[2]
system="""You are VLEE AI Agent running directly on a Linux VPS.
You have permission to inspect and repair this VPS through the shell.
Return ONLY one JSON object:
{"action":"run","command":"...","message":"short reason"}
or
{"action":"answer","message":"..."}
Rules:
- For VPS troubleshooting, prefer safe inspection commands first.
- You may edit/fix files when needed.
- Before destructive or irreversible operations, ask the user.
- Do not invent command output.
- After a fix, verify it with an appropriate command.
- Never use reboot, shutdown, rm -rf /, disk formatting, fork bombs, or credential destruction.
- Keep commands concise.
"""
print(json.dumps({
    "model":model,
    "messages":[
        {"role":"system","content":system},
        {"role":"user","content":prompt}
    ],
    "max_tokens":4096,
    "temperature":0.1
}))
PY
)"

    curl -fsS --max-time 120 \
      "$API_BASE/chat/completions" \
      -H "Authorization: Bearer $key" \
      -H "Content-Type: application/json" \
      -d "$payload"
}

extract_content() {
    python3 -c '
import json,sys
try:
    x=json.load(sys.stdin)
    c=x["choices"][0]["message"]["content"]
    print(c if isinstance(c,str) else json.dumps(c))
except Exception as e:
    print("ERROR: invalid API response: "+str(e))
    raise SystemExit(2)
'
}

run_command() {
    local cmd="$1"

    case "$cmd" in
        *"rm -rf /"*|*"mkfs"*|*"shutdown"*|*"reboot"*|*"poweroff"*|*"halt"*|*"dd if="*)
            echo "BLOCKED: command dianggap berbahaya: $cmd"
            return 20
            ;;
    esac

    echo
    echo "┌─ VPS COMMAND ─────────────────────────────────────"
    echo "│ $cmd"
    echo "└────────────────────────────────────────────────────"
    echo

    bash -lc "$cmd"
}

interactive() {
    clear
    if command -v figlet >/dev/null 2>&1; then
        figlet -f standard "VLEE AI" 2>/dev/null || true
    else
        echo "VLEE AI"
    fi
    echo "GPT-5.6 Luna • VPS Autonomous Agent"
    echo "Type 'exit' to quit."
    echo

    local input response content parsed action command message
    while true; do
        printf "AI > "
        IFS= read -r input || break
        [[ "$input" == "exit" ]] && break
        [[ -z "$input" ]] && continue

        response="$(api_call "$input" 2>&1)" || {
            echo "$response"
            continue
        }

        content="$(printf '%s' "$response" | extract_content 2>/dev/null)" || {
            echo "$content"
            continue
        }

        parsed="$(python3 - "$content" <<'PY'
import json,sys
s=sys.argv[1].strip()
if s.startswith("```"):
    s=s.strip("`")
    if s.startswith("json"):
        s=s[4:].strip()
try:
    x=json.loads(s)
    print(json.dumps(x,separators=(",",":")))
except Exception:
    print(json.dumps({"action":"answer","message":s}))
PY
)"

        action="$(python3 - "$parsed" <<'PY'
import json,sys
print(json.loads(sys.argv[1]).get("action","answer"))
PY
)"
        message="$(python3 - "$parsed" <<'PY'
import json,sys
print(json.loads(sys.argv[1]).get("message",""))
PY
)"

        if [[ "$action" == "run" ]]; then
            command="$(python3 - "$parsed" <<'PY'
import json,sys
print(json.loads(sys.argv[1]).get("command",""))
PY
)"
            [[ -n "$command" ]] || { echo "ERROR: AI returned empty command."; continue; }

            echo "$message"
            run_command "$command"
            rc=$?

            # Give command result back to the model for diagnosis/repair/verification.
            result="$(bash -lc "$command" 2>&1 || true)"
            followup="Command executed:
$command
Exit code: $rc
Output:
$result

Analyse the result. If the original task is not complete, return a JSON run command for the next safe step. If complete, return a JSON answer."

            response="$(api_call "$followup" 2>&1)" || {
                echo "$response"
                continue
            }
            content="$(printf '%s' "$response" | extract_content 2>/dev/null)" || {
                echo "$content"
                continue
            }
            printf '%s\n' "$content"
        else
            echo "$message"
        fi
    done
}

interactive
AI_EOF

chmod 755 "$AI_BIN"

cat > "$MENU_BIN" <<'MENU_EOF'
#!/usr/bin/env bash
set -u

CONF_DIR="/root/.vlee_ai"
KEY_FILE="$CONF_DIR/api_key"
API_BASE="https://api.vleee.net/v1"
MODEL="gpt-5.6-luna"

while :; do
    clear
    if command -v figlet >/dev/null 2>&1; then
        figlet -f standard "VLEE AI" 2>/dev/null || true
    else
        echo "VLEE AI"
    fi
    echo "        AGENT BY EJAYWATTAPAK"
    echo
    echo "  1) Change API key"
    echo "  2) Check status"
    echo "  3) Exit"
    echo
    read -r -p "  Select [1-3]: " c </dev/tty

    case "$c" in
        1)
            printf "\n  VLEEE API key: "
            IFS= read -r key </dev/tty
            if [[ -n "$key" ]]; then
                mkdir -p "$CONF_DIR"
                printf '%s\n' "$key" > "$KEY_FILE"
                chmod 600 "$KEY_FILE"
                echo "  ✔ API key saved."
            else
                echo "  ERROR: Empty API key."
            fi
            read -r -p "  Press Enter..." _ </dev/tty
            ;;
        2)
            echo
            echo "  Model : $MODEL"
            echo "  API   : $API_BASE"
            if [[ ! -s "$KEY_FILE" ]]; then
                echo "  Key   : MISSING"
                read -r -p "  Press Enter..." _ </dev/tty
                continue
            fi

            echo "  Key   : PRESENT"
            echo
            echo "  Testing API/model..."
            code="$(curl -sS -o /tmp/vlee_status.json -w '%{http_code}' \
                --max-time 30 "$API_BASE/models" \
                -H "Authorization: Bearer $(cat "$KEY_FILE")" || true)"

            if [[ "$code" == "200" ]] && grep -q '"id":"gpt-5.6-luna"' /tmp/vlee_status.json; then
                echo "  ✔ API OK"
                echo "  ✔ Model gpt-5.6-luna available"
            else
                echo "  ✖ API/model check FAILED"
                echo "  HTTP: ${code:-unknown}"
                [[ -s /tmp/vlee_status.json ]] && cat /tmp/vlee_status.json
            fi
            rm -f /tmp/vlee_status.json
            read -r -p "  Press Enter..." _ </dev/tty
            ;;
        3) exit 0 ;;
        *) ;;
    esac
done
MENU_EOF

chmod 755 "$MENU_BIN"

echo "◆ [5/6] Installing commands"
echo "✔ ai      -> autonomous AI terminal"
echo "✔ ai-menu -> API key / status menu"

echo "◆ [6/6] Final function test"
TEST_CODE="$(curl -sS -o /tmp/vlee_test.json -w '%{http_code}' \
    --max-time 30 "$API_BASE/models" \
    -H "Authorization: Bearer $(cat "$KEY_FILE")" || true)"

if [[ "$TEST_CODE" == "200" ]] && grep -q '"id":"gpt-5.6-luna"' /tmp/vlee_test.json; then
    echo
    echo "===================================================="
    echo "✔ INSTALLATION OK"
    echo "✔ VLEEE API OK"
    echo "✔ GPT-5.6 Luna AVAILABLE"
    echo "✔ ai / ai-menu READY"
    echo "===================================================="
else
    echo
    echo "===================================================="
    echo "✖ INSTALLATION COMPLETED WITH ERROR"
    echo "HTTP: ${TEST_CODE:-unknown}"
    echo "Response:"
    cat /tmp/vlee_test.json 2>/dev/null || true
    echo "===================================================="
    rm -f /tmp/vlee_test.json
    exit 1
fi

rm -f /tmp/vlee_test.json

echo
echo "Run:"
echo "  ai"
echo "  ai-menu"
