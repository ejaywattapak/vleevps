#!/usr/bin/env bash
set -Eeuo pipefail

API_BASE="https://api.vleee.net/v1"
API_URL="${API_BASE}/responses"
MODEL="gpt-5.6-luna"
KEY_FILE="/root/.openai_key"
AGENT="/usr/local/bin/ai"
BACKUP_DIR="/root/.vleevps/backups"

C='\033[1;36m'; G='\033[1;32m'; Y='\033[1;33m'; R='\033[1;31m'
W='\033[1;37m'; D='\033[2m'; N='\033[0m'

die(){ echo -e "${R}✖ $*${N}"; exit 1; }
[[ $EUID -eq 0 ]] || die "Jalankan installer sebagai root."
command -v apt-get >/dev/null || die "OS ini tidak menggunakan apt-get. Gunakan Debian/Ubuntu."

clear
echo -e "${C}╔════════════════════════════════════════════════════════════╗${N}"
echo -e "${C}║${W}                 VLEEE AI VPS AGENT                       ${C}║${N}"
echo -e "${C}║${N}              Autonomous VPS Troubleshooter               ${C}║${N}"
echo -e "${C}╠════════════════════════════════════════════════════════════╣${N}"
echo -e "${C}║${N} API   : ${W}${API_BASE}${N}"
echo -e "${C}║${N} MODEL : ${W}${MODEL}${N}"
echo -e "${C}╚════════════════════════════════════════════════════════════╝${N}"
echo

export DEBIAN_FRONTEND=noninteractive
echo -e "${C}◆ [1/6] Installing dependencies${N}"
apt-get update
apt-get install -y curl jq ca-certificates
echo -e "${G}✔ Dependencies ready${N}\n"

echo -e "${C}◆ [2/6] API key${N}"
echo -e "${D}Prompt menggunakan /dev/tty supaya curl ... | bash tidak skip input.${N}"
API_KEY=""
while [[ -z "$API_KEY" ]]; do
    printf "%b" "${Y}➜ Masukkan VLEEE API key: ${N}" > /dev/tty
    IFS= read -r API_KEY < /dev/tty || true
    API_KEY="${API_KEY//$'\r'/}"
    [[ -n "$API_KEY" ]] || echo -e "${R}✖ API key kosong. Cuba lagi.${N}" > /dev/tty
done
umask 077
printf '%s\n' "$API_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"
echo -e "${G}✔ API key saved with permission 600${N}\n"

echo -e "${C}◆ [3/6] Backup existing agent${N}"
mkdir -p "$BACKUP_DIR"
if [[ -f "$AGENT" ]]; then
    cp -a "$AGENT" "$BACKUP_DIR/ai.$(date +%Y%m%d-%H%M%S)"
    echo -e "${G}✔ Existing agent backed up${N}"
else
    echo -e "${G}✔ No existing agent${N}"
fi
echo

echo -e "${C}◆ [4/6] Installing autonomous agent${N}"
cat > "$AGENT" <<'AI'
#!/usr/bin/env bash
set -u
API_BASE="https://api.vleee.net/v1"
API_URL="${API_BASE}/responses"
MODEL="gpt-5.6-luna"
KEY_FILE="/root/.openai_key"
MAX_STEPS=30
TIMEOUT=600
C='\033[1;36m'; G='\033[1;32m'; Y='\033[1;33m'; R='\033[1;31m'; W='\033[1;37m'; D='\033[2m'; N='\033[0m'

die(){ echo -e "${R}ERROR: $*${N}"; }
[[ -s "$KEY_FILE" ]] || { die "API key tidak dijumpai: $KEY_FILE"; exit 1; }
API_KEY="$(<"$KEY_FILE")"

SYSTEM_PROMPT=$(cat <<'SYS'
You are VLEEE AI VPS Agent, a root-level Linux troubleshooting and repair agent.
You have REAL command execution access through the local executor. Do not ask the user to paste files or command output when you can inspect the VPS yourself.

Your job:
1. Inspect first.
2. Diagnose from real command output.
3. Before changing a file, create a timestamped backup when practical.
4. Make the smallest correct repair.
5. Run syntax/config checks after changes.
6. Restart/reload services only when needed.
7. Verify the original problem is actually fixed.
8. Continue autonomously until fixed or until a safe blocker is reached.

IMPORTANT:
- The VPS belongs to the operator who launched you. You may inspect and modify its scripts/services/configuration to fulfill the user's request.
- Never expose API keys, passwords, private keys, cookies, or other secrets in your final answer. Avoid printing them in commands/output.
- Do not blindly overwrite a working script with a guessed replacement.
- Prefer existing backups, repositories, installed copies, and package files when restoring missing scripts.
- Avoid destructive commands such as `rm -rf /`, disk formatting, deleting unrelated user data, or disabling security controls. If such an action would be required, stop and explain.
- For service changes, verify with systemctl status/logs or an equivalent check.
- You may install normal packages required for diagnosis/repair.

OUTPUT FORMAT:
Return EXACTLY one JSON object and nothing else.

For a command:
{"action":"execute","command":"...","reason":"short reason"}

For writing a file:
{"action":"write_file","path":"/absolute/path","content":"FULL FILE CONTENT","reason":"short reason"}

For a safe final response:
{"action":"finish","message":"what was checked, what was changed, and verification result"}

For a safe pause when human approval is genuinely required:
{"action":"ask","message":"what approval is needed"}

Rules:
- One action per response.
- Commands must be non-interactive.
- Use absolute paths.
- Never use sudo; you already have root.
- When checking a suspected empty file, use stat/wc/file/head and then search backups/copies before recreating anything.
SYS
)

run_action() {
    local json="$1"
    ACTION="$(jq -r '.action // empty' <<<"$json")"
    case "$ACTION" in
        execute)
            CMD="$(jq -r '.command // empty' <<<"$json")"
            [[ -n "$CMD" ]] || return 2
            echo -e "${C}[exec]${N} $CMD"
            EXEC_OUT="$(timeout "$TIMEOUT" bash -lc "$CMD" 2>&1)"
            EXEC_RC=$?
            printf '%s\n' "$EXEC_OUT"
            return 0
            ;;
        write_file)
            PATH_TO_WRITE="$(jq -r '.path // empty' <<<"$json")"
            CONTENT="$(jq -r '.content // empty' <<<"$json")"
            [[ "$PATH_TO_WRITE" == /* && -n "$PATH_TO_WRITE" ]] || return 2
            mkdir -p "$(dirname "$PATH_TO_WRITE")"
            if [[ -e "$PATH_TO_WRITE" ]]; then
                BACKUP="/root/.vleevps/backups/$(echo "$PATH_TO_WRITE" | sed 's#/#_#g').$(date +%Y%m%d-%H%M%S)"
                mkdir -p /root/.vleevps/backups
                cp -a "$PATH_TO_WRITE" "$BACKUP"
                echo -e "${C}[backup]${N} $BACKUP"
            fi
            printf '%s' "$CONTENT" > "$PATH_TO_WRITE"
            echo -e "${G}[write]${N} $PATH_TO_WRITE"
            return 0
            ;;
        finish)
            jq -r '.message // "Selesai."' <<<"$json"
            return 10
            ;;
        ask)
            echo
            echo -e "${Y}AI memerlukan pengesahan:${N}"
            jq -r '.message // empty' <<<"$json"
            return 11
            ;;
        *)
            echo -e "${R}AI returned invalid action.${N}"
            return 2
            ;;
    esac
}

clear
echo -e "${C}╔════════════════════════════════════════════════════════════╗${N}"
echo -e "${C}║${W}                  VLEEE AI VPS AGENT                      ${C}║${N}"
echo -e "${C}║${N}              REAL VPS COMMAND EXECUTION                  ${C}║${N}"
echo -e "${C}╠════════════════════════════════════════════════════════════╣${N}"
echo -e "${C}║${N} Model : ${W}${MODEL}${N}"
echo -e "${C}║${N} Mode  : ${G}AUTONOMOUS${N}"
echo -e "${C}║${N} Type  : ${W}exit${N} untuk keluar"
echo -e "${C}╚════════════════════════════════════════════════════════════╝${N}"
echo

while true; do
    printf "%b" "${C}AI ${N}> "
    IFS= read -r USER_PROMPT || break
    [[ "$USER_PROMPT" == "exit" ]] && break
    [[ -z "$USER_PROMPT" ]] && continue

    HISTORY=""
    STEP=0
    while (( STEP < MAX_STEPS )); do
        ((STEP+=1))
        INPUT=$(cat <<EOF
${SYSTEM_PROMPT}

TASK FROM USER:
${USER_PROMPT}

EXECUTION HISTORY:
${HISTORY:-No commands have been executed yet.}

You are on step ${STEP}/${MAX_STEPS}. Choose exactly one action.
EOF
)
        PAYLOAD="$(jq -n --arg model "$MODEL" --arg input "$INPUT" '{model:$model,input:$input}')"
        RESPONSE="$(curl -sS --connect-timeout 20 --max-time "$TIMEOUT" "$API_URL" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $API_KEY" \
            -d "$PAYLOAD" 2>&1)"
        RC=$?
        if ((RC != 0)); then
            die "API request failed."
            echo "$RESPONSE"
            break
        fi
        if echo "$RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
            echo -e "${R}ERROR:${N}"
            echo "$RESPONSE" | jq -r 'if (.error|type)=="object" then (.error.message // (.error|tostring)) else (.error|tostring) end'
            break
        fi

        DECISION="$(echo "$RESPONSE" | jq -r '[.output[]?.content[]? | select(.type=="output_text") | .text] | join("\n")' 2>/dev/null)"
        [[ -n "$DECISION" ]] || { die "API returned no output_text."; break; }

        if ! echo "$DECISION" | jq -e 'type=="object" and (.action|type)=="string"' >/dev/null 2>&1; then
            echo -e "${R}ERROR: AI returned invalid JSON action:${N}"
            echo "$DECISION"
            break
        fi

        ACTION="$(echo "$DECISION" | jq -r '.action')"
        if [[ "$ACTION" == "finish" ]]; then
            echo
            echo "$DECISION" | jq -r '.message'
            echo
            break
        fi
        if [[ "$ACTION" == "ask" ]]; then
            echo
            echo "$DECISION" | jq -r '.message'
            echo
            break
        fi

        OUTPUT_FILE="$(mktemp)"
        run_action "$DECISION" > "$OUTPUT_FILE"
        EXEC_STATUS=$?
        OUTPUT="$(cat "$OUTPUT_FILE")"
        rm -f "$OUTPUT_FILE"

        HISTORY="${HISTORY}

STEP ${STEP}
ACTION:
${DECISION}
RESULT:
${OUTPUT}
"
        if ((EXEC_STATUS == 2)); then
            HISTORY="${HISTORY}
Executor rejected the action. Choose a safer/correct action.
"
        fi
        if ((EXEC_STATUS == 10 || EXEC_STATUS == 11)); then break; fi
    done
done
AI
chmod 700 "$AGENT"
mkdir -p /root/.vleevps/backups
echo -e "${G}✔ Agent installed${N}\n"

echo -e "${C}◆ [5/6] Syntax & permissions${N}"
bash -n "$AGENT"
chmod 700 "$AGENT"
chmod 600 "$KEY_FILE"
echo -e "${G}✔ Syntax OK${N}"
echo -e "${G}✔ /usr/local/bin/ai = 700${N}"
echo -e "${G}✔ /root/.openai_key = 600${N}\n"

echo -e "${C}◆ [6/6] Testing VLEEE API${N}"
TEST_PAYLOAD="$(jq -n --arg model "$MODEL" '{model:$model,input:"Return exactly: VLEEE AI OK"}')"
TEST_RESPONSE="$(curl -sS --connect-timeout 20 --max-time 120 "$API_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_KEY" \
    -d "$TEST_PAYLOAD" 2>&1)"
RC=$?
if ((RC != 0)); then
    echo "$TEST_RESPONSE"
    rm -f "$KEY_FILE"
    die "API test failed."
    exit 1
fi
if echo "$TEST_RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
    echo "$TEST_RESPONSE" | jq .
    rm -f "$KEY_FILE"
    die "API key ditolak. Key tidak disimpan."
    exit 1
fi
TEST_TEXT="$(echo "$TEST_RESPONSE" | jq -r '[.output[]?.content[]? | select(.type=="output_text") | .text] | join("\n")')"
[[ -n "$TEST_TEXT" ]] || { echo "$TEST_RESPONSE" | jq .; rm -f "$KEY_FILE"; die "API test returned no text."; exit 1; }

echo -e "${G}✔ API connection OK${N}"
echo -e "${G}✔ Response: ${TEST_TEXT}${N}\n"
echo -e "${G}╔════════════════════════════════════════════════════════════╗${N}"
echo -e "${G}║${W}                 INSTALLATION COMPLETE                    ${G}║${N}"
echo -e "${G}╠════════════════════════════════════════════════════════════╣${N}"
echo -e "${G}║${N} Command : ${W}ai${N}"
echo -e "${G}║${N} Mode    : ${W}AUTONOMOUS VPS AGENT${N}"
echo -e "${G}║${N} API     : ${W}${API_BASE}${N}"
echo -e "${G}║${N} Model   : ${W}${MODEL}${N}"
echo -e "${G}╚════════════════════════════════════════════════════════════╝${N}"
