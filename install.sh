#!/usr/bin/env bash
set -Eeuo pipefail

API_BASE="https://api.vleee.net/v1"
API_URL="${API_BASE}/responses"
MODEL="gpt-5.6-luna"
KEY_FILE="/root/.openai_key"
AGENT="/usr/local/bin/ai"

R='\033[1;31m'; G='\033[1;32m'; Y='\033[1;33m'; C='\033[1;36m'
W='\033[1;37m'; D='\033[2m'; N='\033[0m'

clear
echo -e "${C}╔════════════════════════════════════════════════════════════╗${N}"
echo -e "${C}║${W}                 VLEEE AI VPS AGENT                       ${C}║${N}"
echo -e "${C}║${N}              Secure VPS Assistant Installer              ${C}║${N}"
echo -e "${C}╠════════════════════════════════════════════════════════════╣${N}"
echo -e "${C}║${N} API   : ${W}${API_BASE}${N}"
echo -e "${C}║${N} MODEL : ${W}${MODEL}${N}"
echo -e "${C}╚════════════════════════════════════════════════════════════╝${N}"
echo

[[ $EUID -eq 0 ]] || { echo -e "${R}✖ Run as root.${N}"; exit 1; }
command -v apt-get >/dev/null || { echo -e "${R}✖ Debian/Ubuntu apt-get diperlukan.${N}"; exit 1; }

echo -e "${C}◆ [1/6] Checking dependencies${N}"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl jq ca-certificates
echo -e "${G}✔ Dependencies ready${N}"
echo

echo -e "${C}◆ [2/6] VLEEE API key${N}"
echo -e "${D}Installer membaca input dari /dev/tty supaya curl ... | bash tidak${N}"
echo -e "${D}menelan input. Installer TIDAK akan meneruskan tanpa key.${N}"
echo

API_KEY=""
while [[ -z "$API_KEY" ]]; do
    printf "%b" "${Y}➜ Masukkan VLEEE API key: ${N}" > /dev/tty
    IFS= read -r API_KEY < /dev/tty || true
    API_KEY="${API_KEY//$'\r'/}"
    if [[ -z "$API_KEY" ]]; then
        echo -e "${R}✖ API key kosong. Sila masukkan key.${N}" > /dev/tty
    fi
done

umask 077
printf '%s\n' "$API_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"
echo -e "${G}✔ Key diterima dan disimpan: ${KEY_FILE}${N}"
echo

echo -e "${C}◆ [3/6] Backup AI lama${N}"
if [[ -f "$AGENT" ]]; then
    cp -a "$AGENT" "${AGENT}.backup.$(date +%Y%m%d-%H%M%S)"
    echo -e "${G}✔ Backup dibuat${N}"
else
    echo -e "${G}✔ Tiada agent lama${N}"
fi
echo

echo -e "${C}◆ [4/6] Installing agent${N}"
cat > "$AGENT" <<'AI'
#!/usr/bin/env bash
set -u
API_BASE="https://api.vleee.net/v1"
API_URL="${API_BASE}/responses"
MODEL="gpt-5.6-luna"
KEY_FILE="/root/.openai_key"
R='\033[1;31m'; G='\033[1;32m'; C='\033[1;36m'; W='\033[1;37m'; N='\033[0m'

[[ -s "$KEY_FILE" ]] || { echo -e "${R}ERROR: API key tidak dijumpai.${N}"; exit 1; }
API_KEY="$(<"$KEY_FILE")"

clear
echo -e "${C}╔════════════════════════════════════════════════════════════╗${N}"
echo -e "${C}║${W}                  VLEEE AI VPS AGENT                      ${C}║${N}"
echo -e "${C}║${N}             Autonomous VPS troubleshooting                ${C}║${N}"
echo -e "${C}╠════════════════════════════════════════════════════════════╣${N}"
echo -e "${C}║${N} Model : ${W}${MODEL}${N}"
echo -e "${C}║${N} Type  : ${W}exit${N} untuk keluar"
echo -e "${C}╚════════════════════════════════════════════════════════════╝${N}"
echo

while true; do
    printf "%b" "${C}AI ${N}> "
    IFS= read -r PROMPT || break
    [[ "$PROMPT" == "exit" ]] && break
    [[ -z "$PROMPT" ]] && continue

    PAYLOAD="$(jq -n --arg model "$MODEL" --arg input "$PROMPT" '{model:$model,input:$input}')"
    RESPONSE="$(curl -sS --connect-timeout 20 --max-time 600 "$API_URL"         -H "Content-Type: application/json"         -H "Authorization: Bearer $API_KEY"         -d "$PAYLOAD" 2>&1)"
    RC=$?

    if [[ $RC -ne 0 ]]; then
        echo -e "${R}ERROR: API request gagal${N}"
        echo "$RESPONSE"
        echo
        continue
    fi

    if echo "$RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
        echo -e "${R}ERROR:${N}"
        echo "$RESPONSE" | jq -r 'if (.error|type)=="object" then (.error.message // (.error|tostring)) else (.error|tostring) end'
        echo
        continue
    fi

    TEXT="$(echo "$RESPONSE" | jq -r '[.output[]?.content[]? | select(.type=="output_text") | .text] | join("\n")')"
    if [[ -n "$TEXT" ]]; then
        printf '%s\n\n' "$TEXT"
    else
        echo -e "${R}ERROR: response API tiada output_text.${N}"
        echo "$RESPONSE" | jq .
        echo
    fi
done
AI
chmod 700 "$AGENT"
echo -e "${G}✔ Agent installed${N}"
echo

echo -e "${C}◆ [5/6] Syntax & security check${N}"
bash -n "$AGENT"
[[ "$(stat -c '%a' "$KEY_FILE")" == "600" ]]
echo -e "${G}✔ Syntax OK${N}"
echo -e "${G}✔ Key permission 600${N}"
echo

echo -e "${C}◆ [6/6] Testing VLEEE API${N}"
TEST_PAYLOAD="$(jq -n --arg model "$MODEL" '{model:$model,input:"Reply only: VLEEE AI OK"}')"
TEST_RESPONSE="$(curl -sS --connect-timeout 20 --max-time 120 "$API_URL"     -H "Content-Type: application/json"     -H "Authorization: Bearer $API_KEY"     -d "$TEST_PAYLOAD" 2>&1)"
RC=$?

if [[ $RC -ne 0 ]]; then
    echo "$TEST_RESPONSE"
    echo -e "${R}✖ API TEST FAILED${N}"
    rm -f "$KEY_FILE"
    exit 1
fi

if echo "$TEST_RESPONSE" | jq -e '.error' >/dev/null 2>&1; then
    echo "$TEST_RESPONSE" | jq .
    echo -e "${R}✖ API TEST FAILED: key invalid/ditolak${N}"
    rm -f "$KEY_FILE"
    exit 1
fi

TEXT="$(echo "$TEST_RESPONSE" | jq -r '[.output[]?.content[]? | select(.type=="output_text") | .text] | join("\n")')"
[[ -n "$TEXT" ]] || { echo "$TEST_RESPONSE" | jq .; rm -f "$KEY_FILE"; exit 1; }

echo -e "${G}✔ API connection OK${N}"
echo -e "${G}✔ Response: ${TEXT}${N}"
echo
echo -e "${G}╔════════════════════════════════════════════════════════════╗${N}"
echo -e "${G}║${W}                 INSTALLATION COMPLETE                    ${G}║${N}"
echo -e "${G}╠════════════════════════════════════════════════════════════╣${N}"
echo -e "${G}║${N} Command : ${W}ai${N}"
echo -e "${G}║${N} API     : ${W}${API_BASE}${N}"
echo -e "${G}║${N} Model   : ${W}${MODEL}${N}"
echo -e "${G}╚════════════════════════════════════════════════════════════╝${N}"
