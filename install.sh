#!/bin/bash
set -euo pipefail

APP_NAME="VLEEE AI VPS Agent"
INSTALL_PATH="/usr/local/bin/ai"
KEY_FILE="/root/.openai_key"
LOG_FILE="/var/log/vleee-ai-agent.log"
API_BASE="https://api.vleee.net/v1"
API_URL="${API_BASE}/responses"
MODEL="gpt-5.6-luna"

if [ "${EUID}" -ne 0 ]; then
    echo "ERROR: Jalankan installer sebagai root."
    exit 1
fi

clear
echo "============================================"
echo "       INSTALL VLEEE AI VPS AGENT"
echo "============================================"
echo
echo "API : ${API_BASE}"
echo "MODEL: ${MODEL}"
echo

echo "[1/6] Check dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y curl jq bash coreutils >/dev/null

echo
echo "[2/6] API key"
echo "Masukkan VLEEE API key."
echo "Key akan disimpan sebagai ${KEY_FILE} dengan permission 600."
echo
read -r -s -p "VLEEE API Key: " API_KEY
echo

if [ -z "${API_KEY}" ]; then
    echo "ERROR: API key kosong."
    exit 1
fi

umask 077
printf '%s\n' "${API_KEY}" > "${KEY_FILE}"
chmod 600 "${KEY_FILE}"
unset API_KEY

echo "[3/6] Backup AI lama..."
if [ -e "${INSTALL_PATH}" ] || [ -L "${INSTALL_PATH}" ]; then
    cp -a "${INSTALL_PATH}" "${INSTALL_PATH}.backup.$(date +%Y%m%d-%H%M%S)"
fi

echo "[4/6] Installing agent..."
cat > "${INSTALL_PATH}" <<'AGENT'
#!/bin/bash
set -u

KEY_FILE="/root/.openai_key"
API_URL="https://api.vleee.net/v1/responses"
MODEL="gpt-5.6-luna"
LOG="/var/log/vleee-ai-agent.log"
MAX_OUTPUT=30000

if [ ! -s "$KEY_FILE" ]; then
    echo "ERROR: API key tidak dijumpai: $KEY_FILE"
    exit 1
fi

API_KEY="$(cat "$KEY_FILE")"

mkdir -p "$(dirname "$LOG")"
touch "$LOG"
chmod 600 "$LOG"

SYSTEM_PROMPT='
You are VLEEE AI VPS Agent running directly on the users own VPS.

You have ROOT access.

Your job is to diagnose and FIX the VPS, not merely explain commands to the user.

IMPORTANT:
- When the user asks to fix something, inspect the VPS yourself using run_command.
- Do not tell the user to run diagnostic commands that you can run yourself.
- Do not ask the user to paste command output if you can obtain it yourself.
- You may read, create, modify, move, rename and backup files required to repair the VPS scripts.
- You may use normal Linux administration commands.
- Always inspect before changing important files.
- Before overwriting a non-empty script, make a timestamped backup.
- After changing a shell script, run bash -n on it.
- After fixing a command, actually test it.
- If a service is involved, check its status/logs after the repair.
- Do not blindly reinstall the whole VPS when a targeted repair is possible.
- Do not delete unrelated data.
- Avoid destructive disk commands and reboot/shutdown unless explicitly requested.
- Never expose or print API keys, passwords, private keys, cookies or other secrets.
- If command output contains secrets, redact them.

MENU REPAIR RULES:
- The command "menu" is important.
- Inspect /usr/local/bin/menu, /usr/bin/menu and /usr/local/xraayvpn/bin/menu before changing them.
- Resolve symlinks and wrappers.
- If the target menu is empty/broken, search for valid existing copies or backups.
- Check locations such as /opt/ejvpn, /root, /usr/local and related installation directories.
- Prefer restoring the original menu and submenu structure instead of replacing it with a fake minimal menu.
- Verify the restored command with bash -n and an actual test.
- If the first repair fails, continue diagnosing and repairing.

WORKFLOW:
1. Understand the request.
2. Inspect relevant files/commands.
3. Identify the root cause.
4. Make a backup.
5. Apply the smallest correct fix.
6. Syntax-check.
7. Test.
8. If the test fails, continue fixing.
9. Only report completion after verification.

Do not stop after giving a suggested command. Execute it yourself with run_command.
'

call_api() {
    local payload="$1"
    curl -sS --connect-timeout 15 --max-time 90 \
        "$API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        -d "$payload"
}

run_command() {
    local cmd="$1"
    local output rc

    printf '\n[EXECUTE] %s\n' "$cmd"
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$cmd" >> "$LOG"

    output="$(timeout 45s bash -lc "$cmd" 2>&1)"
    rc=$?

    if [ "${#output}" -gt "$MAX_OUTPUT" ]; then
        output="${output:0:$MAX_OUTPUT}
...[output truncated]..."
    fi

    printf '%s\n' "$output" >> "$LOG"
    printf '[EXIT CODE] %s\n' "$rc" >> "$LOG"

    printf '%s\n' "$output"
    printf '[exit code: %s]\n' "$rc"
}

extract_text() {
    echo "$1" | jq -r '
        [.output[]?.content[]?
         | select(.type=="output_text")
         | .text] | join("\n")
    ' 2>/dev/null
}

echo "╔══════════════════════════════════════╗"
echo "║           VLEEE AI AGENT             ║"
echo "║          model: gpt-5.6-luna         ║"
echo "║       ROOT VPS AUTO-REPAIR           ║"
echo "║          type '\''exit'\'' to quit        ║"
echo "╚══════════════════════════════════════╝"
echo

INPUT='[]'

while true; do
    printf "AI > "
    IFS= read -r PROMPT || break

    [ "$PROMPT" = "exit" ] && break
    [ -z "$PROMPT" ] && continue

    INPUT="$(
        jq -c --arg text "$PROMPT" \
        '. + [{"role":"user","content":[{"type":"input_text","text":$text}]}]' \
        <<< "$INPUT"
    )"

    while true; do
        PAYLOAD="$(
            jq -n \
            --arg model "$MODEL" \
            --arg system "$SYSTEM_PROMPT" \
            --argjson input "$INPUT" \
            '{
                model:$model,
                instructions:$system,
                input:$input,
                tools:[{
                    type:"function",
                    name:"run_command",
                    description:"Execute a Linux shell command on the VPS as root to inspect, diagnose, modify and test the VPS.",
                    parameters:{
                        type:"object",
                        properties:{
                            command:{
                                type:"string",
                                description:"Bash command to execute on the VPS."
                            }
                        },
                        required:["command"],
                        additionalProperties:false
                    },
                    strict:true
                }],
                tool_choice:"auto"
            }'
        )"

        RESPONSE="$(call_api "$PAYLOAD")"

        if [ -z "$RESPONSE" ]; then
            echo
            echo "ERROR: API tidak memberikan response."
            break
        fi

        if echo "$RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
            echo
            echo "ERROR:"
            echo "$RESPONSE" | jq -r '
                if (.error | type) == "object"
                then (.error.message // (.error | tostring))
                else (.error | tostring)
                end
            ' 2>/dev/null
            echo
            break
        fi

        OUTPUT_ITEMS="$(echo "$RESPONSE" | jq -c '.output // []')"
        INPUT="$(jq -c --argjson items "$OUTPUT_ITEMS" '. + $items' <<< "$INPUT")"

        CALL_COUNT="$(
            echo "$RESPONSE" |
            jq '[.output[]? | select(.type=="function_call" and .name=="run_command")] | length'
        )"

        if [ "$CALL_COUNT" -gt 0 ]; then
            for ((i=0; i<CALL_COUNT; i++)); do
                CALL_ID="$(
                    echo "$RESPONSE" | jq -r --argjson i "$i" '
                    [.output[]? | select(.type=="function_call" and .name=="run_command")][$i].call_id'
                )"

                ARGS="$(
                    echo "$RESPONSE" | jq -r --argjson i "$i" '
                    [.output[]? | select(.type=="function_call" and .name=="run_command")][$i].arguments'
                )"

                CMD="$(echo "$ARGS" | jq -r '.command // empty')"

                if [ -z "$CMD" ]; then
                    RESULT="ERROR: AI produced an empty command."
                else
                    RESULT="$(run_command "$CMD")"
                fi

                INPUT="$(
                    jq -c \
                    --arg call_id "$CALL_ID" \
                    --arg result "$RESULT" \
                    '. + [{"type":"function_call_output","call_id":$call_id,"output":$result}]' \
                    <<< "$INPUT"
                )"
            done
            continue
        fi

        TEXT="$(extract_text "$RESPONSE")"
        [ -n "$TEXT" ] && printf '\n%s\n\n' "$TEXT"
        break
    done
done
AGENT

chmod 700 "${INSTALL_PATH}"
touch "${LOG_FILE}"
chmod 600 "${LOG_FILE}"

echo "[5/6] Syntax check..."
bash -n "${INSTALL_PATH}"

echo "[6/6] Test VLEEE API..."
TEST_PAYLOAD="$(
    jq -n --arg model "gpt-5.6-luna" \
    '{model:$model,input:"Reply exactly: VLEEE AI OK"}'
)"

TEST="$(
    curl -sS --connect-timeout 15 --max-time 60 \
    "${API_URL}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $(cat "${KEY_FILE}")" \
    -d "${TEST_PAYLOAD}"
)"

if echo "${TEST}" | jq -e '.error' >/dev/null 2>&1; then
    echo "${TEST}" | jq .
    echo
    echo "API TEST FAILED."
    exit 1
fi

RESULT="$(
    echo "${TEST}" | jq -r '
    [.output[]?.content[]?
     | select(.type=="output_text")
     | .text] | join("\n")'
)"

echo "API: ${RESULT:-OK}"
echo
echo "============================================"
echo " VLEEE AI VPS AGENT INSTALLED"
echo "============================================"
echo
echo "Run: ai"
echo "Key: ${KEY_FILE}"
echo "Log: ${LOG_FILE}"
echo
