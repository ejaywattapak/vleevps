#!/usr/bin/env bash
set -euo pipefail

API_BASE="https://api.vleee.net/v1"
API_URL="${API_BASE}/responses"
MODEL="gpt-5.6-luna"
KEY_FILE="/root/.openai_key"
AGENT="/usr/local/bin/ai"

echo "============================================"
echo "       INSTALL VLEEE AI VPS AGENT"
echo "============================================"
echo "API : ${API_BASE}"
echo "MODEL: ${MODEL}"
echo

echo "[1/6] Check dependencies..."
export DEBIAN_FRONTEND=noninteractive
if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update
        apt-get install -y curl jq ca-certificates
    else
        echo "ERROR: apt-get tidak dijumpai. Install curl dan jq secara manual."
        exit 1
    fi
fi

echo "[2/6] API key"
echo "Masukkan VLEEE API key."
echo "Key akan disimpan sebagai ${KEY_FILE} dengan permission 600."
printf "VLEEE API key: "
IFS= read -r API_KEY
echo

if [[ -z "${API_KEY}" ]]; then
    echo "ERROR: API key kosong. Installation dibatalkan."
    exit 1
fi

umask 077
printf '%s\n' "${API_KEY}" > "${KEY_FILE}"
chmod 600 "${KEY_FILE}"

echo "[3/6] Backup AI lama..."
if [[ -f "${AGENT}" ]]; then
    cp -a "${AGENT}" "${AGENT}.backup.$(date +%Y%m%d-%H%M%S)"
fi

echo "[4/6] Installing agent..."
cat > "${AGENT}" <<'AI'
#!/usr/bin/env bash
set -u

API_BASE="https://api.vleee.net/v1"
API_URL="${API_BASE}/responses"
MODEL="gpt-5.6-luna"
KEY_FILE="/root/.openai_key"

if [[ ! -s "${KEY_FILE}" ]]; then
    echo "ERROR: API key tidak dijumpai: ${KEY_FILE}"
    exit 1
fi

API_KEY="$(<"${KEY_FILE}")"

echo "╔══════════════════════════════════════╗"
echo "║           VLEEE AI AGENT             ║"
printf "║          model: %-20s║\n" "${MODEL}"
echo "║          type 'exit' to quit         ║"
echo "╚══════════════════════════════════════╝"
echo

while true; do
    printf "AI > "
    IFS= read -r PROMPT || break

    [[ "${PROMPT}" == "exit" ]] && break
    [[ -z "${PROMPT}" ]] && continue

    PAYLOAD="$(jq -n \
        --arg model "${MODEL}" \
        --arg input "${PROMPT}" \
        '{
          model: $model,
          input: $input
        }')"

    RESPONSE="$(curl -sS --fail-with-body \
        --connect-timeout 15 \
        --max-time 180 \
        "${API_URL}" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${API_KEY}" \
        -d "${PAYLOAD}" 2>&1)" || {
            echo
            echo "ERROR:"
            echo "${RESPONSE}"
            echo
            continue
        }

    if ! echo "${RESPONSE}" | jq -e 'type == "object"' >/dev/null 2>&1; then
        echo
        echo "ERROR: API returned invalid JSON:"
        echo "${RESPONSE}"
        echo
        continue
    fi

    if echo "${RESPONSE}" | jq -e '.error' >/dev/null 2>&1; then
        echo
        echo "ERROR:"
        echo "${RESPONSE}" | jq -r '
          if (.error|type) == "object" then
            (.error.message // (.error|tostring))
          else
            (.error|tostring)
          end'
        echo
        continue
    fi

    TEXT="$(echo "${RESPONSE}" | jq -r '
      [
        .output[]? |
        .content[]? |
        select(.type == "output_text") |
        .text
      ] | join("\n")
    ')"

    if [[ -n "${TEXT}" ]]; then
        printf '%s\n\n' "${TEXT}"
    else
        echo "ERROR: API response tidak mengandungi output_text."
        echo "${RESPONSE}" | jq .
        echo
    fi
done
AI

chmod 700 "${AGENT}"

echo "[5/6] Syntax check..."
bash -n "${AGENT}"
echo "Syntax OK."

echo "[6/6] Test VLEEE API..."
TEST_PAYLOAD="$(jq -n \
    --arg model "${MODEL}" \
    '{model:$model,input:"Reply only: VLEEE AI OK"}')"

TEST_RESPONSE="$(curl -sS --fail-with-body \
    --connect-timeout 15 \
    --max-time 60 \
    "${API_URL}" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${API_KEY}" \
    -d "${TEST_PAYLOAD}" 2>&1)" || {
        echo "${TEST_RESPONSE}"
        echo "API TEST FAILED."
        rm -f "${KEY_FILE}"
        exit 1
    }

echo "${TEST_RESPONSE}" | jq .

if echo "${TEST_RESPONSE}" | jq -e '.error' >/dev/null 2>&1; then
    echo "API TEST FAILED: key ditolak oleh VLEEE API."
    rm -f "${KEY_FILE}"
    exit 1
fi

echo
echo "============================================"
echo " VLEEE AI VPS AGENT BERJAYA DIPASANG"
echo "============================================"
echo
echo "Jalankan:"
echo "    ai"
echo
echo "API key: ${KEY_FILE}"
echo "Permission: $(stat -c '%a' "${KEY_FILE}")"
