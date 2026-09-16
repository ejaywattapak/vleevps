#!/bin/bash
set -e

# ============================================================
# VLEE AI AGENT INSTALLER
# by ejaywattapak
# ============================================================

APP="/usr/local/bin/ai"
CONFIG="/root/.vlee_ai"
KEY_FILE="$CONFIG/api_key"
MODEL_FILE="$CONFIG/model"

# ---------- Root ----------
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Please run as root."
    exit 1
fi

# ---------- OS / package manager ----------
install_pkg() {
    case "$1" in
        figlet)
            if command -v apt-get >/dev/null 2>&1; then
                export DEBIAN_FRONTEND=noninteractive
                apt-get update -qq
                apt-get install -y -qq figlet >/dev/null
            elif command -v dnf >/dev/null 2>&1; then
                dnf install -y figlet >/dev/null
            elif command -v yum >/dev/null 2>&1; then
                yum install -y figlet >/dev/null
            elif command -v apk >/dev/null 2>&1; then
                apk add figlet >/dev/null
            else
                echo "ERROR: Unsupported package manager. Install figlet manually."
                exit 1
            fi
            ;;
    esac
}

# ---------- Dependencies ----------
echo "◆ Checking dependencies..."

for cmd in curl bash python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: Missing dependency: $cmd"
        exit 1
    fi
done

if ! command -v figlet >/dev/null 2>&1; then
    echo "◆ Installing required font/banner package: figlet"
    install_pkg figlet
fi

echo "✔ Dependencies OK"
sleep 1

clear

# ---------- Banner ----------
banner() {
    clear
    if command -v figlet >/dev/null 2>&1; then
        figlet -f standard "VLEE AI"
    else
        echo "VLEE AI"
    fi
    echo "        AI AGENT  •  by ejaywattapak"
    echo
}

banner
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "        VLEE AI AGENT • INSTALLER"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

echo "◆ [1/6] Check dependencies"
echo "✔ Dependencies OK"
echo

echo "◆ [2/6] API key"
echo "Masukkan VLEEE API key."
echo "Input dibaca dari /dev/tty supaya curl ... | bash tidak skip."
echo
read -r -s -p "➜ VLEEE API key: " API_KEY </dev/tty
echo
echo

if [ -z "$API_KEY" ]; then
    echo "✘ API key kosong."
    exit 1
fi

mkdir -p "$CONFIG"
chmod 700 "$CONFIG"

printf '%s\n' "$API_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

# Default requested model. Can be changed later in /root/.vlee_ai/model
printf '%s\n' "gpt-5.6-luna" > "$MODEL_FILE"
chmod 600 "$MODEL_FILE"

echo "✔ API key saved with permission 600"
echo "✔ Model: $(cat "$MODEL_FILE")"
echo

echo "◆ [3/6] Backup existing agent"

if [ -f "$APP" ]; then
    BACKUP="${APP}.backup.$(date +%Y%m%d-%H%M%S)"
    cp -a "$APP" "$BACKUP"
    echo "✔ Existing agent backed up"
    echo "  $BACKUP"
else
    echo "✔ No existing agent found"
fi
echo

echo "◆ [4/6] Installing autonomous agent"

cat > "$APP" <<'AI_SCRIPT'
#!/bin/bash
set -u

CONFIG="/root/.vlee_ai"
KEY_FILE="$CONFIG/api_key"
MODEL_FILE="$CONFIG/model"
API_URL="https://api.vleee.net/v1/chat/completions"

show_banner() {
    clear
    if command -v figlet >/dev/null 2>&1; then
        figlet -f standard "VLEE AI"
    else
        echo "VLEE AI"
    fi
    echo "        AI AGENT  •  by ejaywattapak"
}

get_key() {
    [ -s "$KEY_FILE" ] && cat "$KEY_FILE"
}

get_model() {
    if [ -s "$MODEL_FILE" ]; then
        cat "$MODEL_FILE"
    else
        echo "gpt-5.6-luna"
    fi
}

change_key() {
    echo
    read -r -s -p "  New VLEEE API key: " NEW_KEY </dev/tty
    echo

    if [ -z "$NEW_KEY" ]; then
        echo "  ✘ API key kosong."
        return
    fi

    printf '%s\n' "$NEW_KEY" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    echo "  ✔ API key updated."
}

change_model() {
    echo
    echo "  Current model: $(get_model)"
    read -r -p "  Model [Enter = keep current]: " NEW_MODEL </dev/tty

    if [ -n "$NEW_MODEL" ]; then
        printf '%s\n' "$NEW_MODEL" > "$MODEL_FILE"
        chmod 600 "$MODEL_FILE"
        echo "  ✔ Model updated: $NEW_MODEL"
    else
        echo "  ✔ Model unchanged."
    fi
}

api_request() {
    local prompt="$1"
    local key model payload response

    key="$(get_key)"
    model="$(get_model)"

    if [ -z "$key" ]; then
        echo "ERROR:"
        echo "API key belum diset."
        return 1
    fi

    payload="$(
        python3 - "$model" "$prompt" <<'PY'
import json
import sys

model = sys.argv[1]
prompt = sys.argv[2]

print(json.dumps({
    "model": model,
    "messages": [
        {
            "role": "system",
            "content": (
                "You are VLEE AI Agent running inside a Linux VPS. "
                "Help the user inspect, troubleshoot, and manage their VPS. "
                "When asked to check a VPS, give safe read-only diagnostic commands "
                "or analyze command output. Do not claim to have executed commands "
                "unless their output is provided."
            )
        },
        {
            "role": "user",
            "content": prompt
        }
    ]
}))
PY
    )"

    response="$(
        curl -sS \
            --max-time 120 \
            -H "Authorization: Bearer $key" \
            -H "Content-Type: application/json" \
            -d "$payload" \
            "$API_URL" 2>&1
    )"

    python3 - "$response" <<'PY'
import json
import sys

raw = sys.argv[1]

try:
    data = json.loads(raw)

    if "choices" in data and data["choices"]:
        msg = data["choices"][0].get("message", {})
        content = msg.get("content", "")

        if isinstance(content, list):
            text = []
            for item in content:
                if isinstance(item, dict) and "text" in item:
                    text.append(str(item["text"]))
            content = "".join(text)

        print(content)
    elif "error" in data:
        err = data["error"]
        print("ERROR:")
        if isinstance(err, dict):
            print(err.get("message", err))
        else:
            print(err)
    else:
        print(raw)
except Exception:
    print(raw)
PY
}

test_api() {
    echo
    echo "  Testing VLEEE API..."
    echo "  Model: $(get_model)"
    echo

    api_request "Reply with exactly: VLEE AI API OK"
}

terminal() {
    if [ ! -s "$KEY_FILE" ]; then
        echo "ERROR: API key belum diset."
        return
    fi

    show_banner
    echo
    echo "  Model : $(get_model)"
    echo "  Type  : exit untuk kembali"
    echo

    while :; do
        printf "AI > "
        IFS= read -r PROMPT </dev/tty || return

        [ "$PROMPT" = "exit" ] && return
        [ -z "$PROMPT" ] && continue

        echo
        api_request "$PROMPT"
        echo
    done
}

menu() {
    while :; do
        show_banner
        echo
        echo "  ╭──────────────────────────────────────────────╮"
        echo "  │  1) Change API key                           │"
        echo "  │  2) Test API connection                      │"
        echo "  │  3) Change model                             │"
        echo "  │  4) Start AI terminal                        │"
        echo "  │  5) Exit                                     │"
        echo "  ╰──────────────────────────────────────────────╯"
        echo

        read -r -p "  Select [1-5]: " C </dev/tty

        case "$C" in
            1)
                change_key
                read -r -p "  Press Enter..." _ </dev/tty
                ;;
            2)
                test_api
                read -r -p "  Press Enter..." _ </dev/tty
                ;;
            3)
                change_model
                read -r -p "  Press Enter..." _ </dev/tty
                ;;
            4)
                terminal
                ;;
            5)
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
AI_SCRIPT

chmod 700 "$APP"

echo "✔ Agent installed"
echo

echo "◆ [5/6] Syntax validation"

if bash -n "$APP"; then
    echo "✔ Bash syntax OK"
else
    echo "✘ Syntax error detected."
    echo "Agent was not started."
    exit 1
fi
echo

echo "◆ [6/6] Final verification"

if [ -x "$APP" ] && [ -s "$KEY_FILE" ] && [ -s "$MODEL_FILE" ]; then
    echo "✔ Installation complete"
else
    echo "✘ Installation verification failed."
    exit 1
fi

echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "                  VLEE AI READY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "Run:"
echo "  ai"
echo
echo "Files:"
echo "  $APP"
echo "  $CONFIG"
echo
