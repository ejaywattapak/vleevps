#!/usr/bin/env bash
set -Eeuo pipefail

INSTALL_DIR="/usr/local/bin"
DATA_DIR="/root/.vlee_ai"
KEY_FILE="$DATA_DIR/api_key"
API_URL="https://api.vleee.net/v1/chat/completions"
MODEL="cx/gpt-5.6-luna"

YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
RESET='\033[0m'

if [[ $EUID -ne 0 ]]; then
  echo "Run as root."
  exit 1
fi

backup_dir="$(mktemp -d)"
rollback() {
  echo
  echo -e "${RED}✖ Installation failed. Rolling back changes...${RESET}"
  rm -f "$INSTALL_DIR/ai" "$INSTALL_DIR/ai-menu" "$INSTALL_DIR/ai.old" "$INSTALL_DIR/ai-menu.old"
  if [[ -f "$backup_dir/ai" ]]; then cp -a "$backup_dir/ai" "$INSTALL_DIR/ai"; fi
  if [[ -f "$backup_dir/ai-menu" ]]; then cp -a "$backup_dir/ai-menu" "$INSTALL_DIR/ai-menu"; fi
  if [[ -f "$backup_dir/api_key" ]]; then mkdir -p "$DATA_DIR"; cp -a "$backup_dir/api_key" "$KEY_FILE"; fi
  rm -rf "$backup_dir"
  echo -e "${RED}Rollback complete. No partial installation left behind.${RESET}"
}
trap 'rollback' ERR

echo -e "${YELLOW}__     ___     _____ _____      _    ___${RESET}"
echo -e "${YELLOW}\\ \\   / / |   | ____| ____|    / \\  |_ _|${RESET}"
echo -e "${YELLOW} \\ \\ / /| |   |  _| |  _|     / _ \\  | |${RESET}"
echo -e "${YELLOW}  \\ V / | |___| |___| |___   / ___ \\ | |${RESET}"
echo -e "${YELLOW}   \\_/  |_____|_____|_____| /_/   \\_\\___|${RESET}"
echo -e "${YELLOW}VLEE AI AGENT BY EJAYWATTAPAK${RESET}"
echo

echo "◆ [1/6] Check dependencies"
command -v python3 >/dev/null
command -v curl >/dev/null
echo -e "${GREEN}✔ Dependencies OK${RESET}"

echo "◆ [2/6] API key"
mkdir -p "$DATA_DIR"
chmod 700 "$DATA_DIR"

[[ -f "$INSTALL_DIR/ai" ]] && cp -a "$INSTALL_DIR/ai" "$backup_dir/ai"
[[ -f "$INSTALL_DIR/ai-menu" ]] && cp -a "$INSTALL_DIR/ai-menu" "$backup_dir/ai-menu"
[[ -f "$KEY_FILE" ]] && cp -a "$KEY_FILE" "$backup_dir/api_key"

valid=0
for attempt in 1 2 3; do
  printf "➜ VLEEE API key (attempt %s/3): " "$attempt" > /dev/tty
  IFS= read -r API_KEY < /dev/tty

  if [[ -z "$API_KEY" ]]; then
    echo -e "${RED}✖ Empty API key${RESET}"
    continue
  fi

  code="$(
    curl -sS -o /tmp/vlee_key_check.json -w '%{http_code}' \
      --connect-timeout 10 --max-time 20 \
      -X POST "$API_URL" \
      -H "Authorization: Bearer $API_KEY" \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -H "User-Agent: VLEE-AI-Agent/1.0" \
      --data '{"model":"cx/gpt-5.6-luna","messages":[{"role":"user","content":"ping"}],"max_tokens":1}' \
      || true
  )"

  if [[ "$code" != "401" && "$code" != "403" ]]; then
    printf '%s\n' "$API_KEY" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    valid=1
    echo -e "${GREEN}✔ API key accepted${RESET}"
    break
  fi

  echo -e "${RED}✖ Invalid API key${RESET}"
done

if [[ "$valid" -ne 1 ]]; then
  echo -e "${RED}✖ 3 invalid attempts. Rolling back.${RESET}"
  rollback
  trap - ERR
  exit 1
fi

echo "◆ [3/6] Backup existing agent"
echo -e "${GREEN}✔ Existing files backed up${RESET}"

echo "◆ [4/6] Installing autonomous agent"
cat > "$INSTALL_DIR/ai" <<'PY'
#!/usr/bin/env python3
import json, os, subprocess, sys, urllib.error, urllib.request

API_URL="https://api.vleee.net/v1/chat/completions"
MODEL="cx/gpt-5.6-luna"
KEY_FILE="/root/.vlee_ai/api_key"

SYSTEM = """You are VLEE AI Agent running directly on a Linux VPS.
You have real shell access. Do the work yourself; do not merely tell the user commands to run.
For VPS requests:
- inspect the system yourself with shell commands
- diagnose from real command output
- make the required repair/configuration yourself
- verify every important change yourself
- continue until the user's task is completed
- never claim a command ran unless it actually ran
- keep explanations short and practical
- prefer fast, read-only inspection first
- avoid destructive actions; ask before irreversible operations
To execute a shell command, output exactly one command inside:
<CMD>...</CMD>
Do not put explanatory text inside CMD tags.
After command output is returned, analyze it and continue if needed.
"""

def key():
    try:
        return open(KEY_FILE).read().strip()
    except Exception:
        return ""

def request(messages, max_tokens=1200):
    k=key()
    if not k:
        print("ERROR: VLEEE API key not found.")
        return None
    body=json.dumps({
        "model":MODEL,
        "messages":messages,
        "max_tokens":max_tokens,
        "temperature":0.1
    }).encode()
    req=urllib.request.Request(
        API_URL, data=body, method="POST",
        headers={
            "Authorization":"Bearer "+k,
            "Content-Type":"application/json",
            "Accept":"application/json",
            "User-Agent":"VLEE-AI-Agent/1.0"
        })
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            data=json.loads(r.read().decode())
        return data["choices"][0]["message"]["content"]
    except urllib.error.HTTPError as e:
        b=e.read().decode(errors="replace")
        print(f"ERROR: HTTP {e.code}\n{b}")
        return None
    except Exception as e:
        print("ERROR:", str(e))
        return None

def run(cmd):
    try:
        p=subprocess.run(cmd, shell=True, text=True,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                         timeout=60, executable="/bin/bash")
        return p.stdout[-12000:]
    except subprocess.TimeoutExpired:
        return "COMMAND TIMEOUT after 60 seconds"
    except Exception as e:
        return "COMMAND ERROR: "+str(e)

def agent(prompt):
    messages=[
        {"role":"system","content":SYSTEM},
        {"role":"user","content":prompt}
    ]
    for _ in range(8):
        answer=request(messages)
        if answer is None:
            return
        if "<CMD>" not in answer:
            print(answer)
            return
        pre=answer.split("<CMD>",1)[0].strip()
        if pre:
            print(pre)
        cmd=answer.split("<CMD>",1)[1].split("</CMD>",1)[0].strip()
        if not cmd:
            print("AI returned an empty command.")
            return
        print(f"\033[90m$ {cmd}\033[0m")
        out=run(cmd)
        messages.append({"role":"assistant","content":answer})
        messages.append({"role":"user","content":"REAL SHELL OUTPUT:\n"+out+
                         "\nContinue the task. Execute another command if required. "
                         "When completely finished, give a concise final result."})
    print("AI stopped after the safety execution limit.")

def main():
    print("\033[1;33mVLEE AI — GPT-5.6 Luna\033[0m")
    print("Type 'exit' to quit.\n")
    while True:
        try:
            prompt=input("\033[1;33mAI > \033[0m").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return
        if not prompt:
            continue
        if prompt.lower() in ("exit","quit"):
            return
        print("\n\033[1;33mThinking...\033[0m")
        agent(prompt)
        print()

if __name__=="__main__":
    main()
PY
chmod 755 "$INSTALL_DIR/ai"
echo -e "${GREEN}✔ Autonomous agent installed${RESET}"

echo "◆ [5/6] Installing minimal menu"
cat > "$INSTALL_DIR/ai-menu" <<'EOF'
#!/usr/bin/env bash
API_KEY_FILE="/root/.vlee_ai/api_key"
API_URL="https://api.vleee.net/v1/chat/completions"
YELLOW='\033[1;33m'; GREEN='\033[1;32m'; RED='\033[1;31m'; RESET='\033[0m'

while true; do
  clear
  echo -e "${YELLOW}VLEE AI AGENT BY EJAYWATTAPAK${RESET}"
  echo "  1) Change API key"
  echo "  2) Check status"
  echo "  3) Exit"
  printf "  Select [1-3]: "
  read -r choice

  case "$choice" in
    1)
      printf "➜ VLEEE API key: "
      read -r key
      [[ -z "$key" ]] && { echo -e "${RED}Invalid/empty key${RESET}"; read -r; continue; }
      code="$(curl -sS -o /tmp/vlee_key_check.json -w '%{http_code}' \
        --connect-timeout 10 --max-time 20 \
        -X POST "$API_URL" \
        -H "Authorization: Bearer $key" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -H "User-Agent: VLEE-AI-Agent/1.0" \
        --data '{"model":"cx/gpt-5.6-luna","messages":[{"role":"user","content":"ping"}],"max_tokens":1}' || true)"
      if [[ "$code" != "401" && "$code" != "403" ]]; then
        printf '%s\n' "$key" > "$API_KEY_FILE"
        chmod 600 "$API_KEY_FILE"
        echo -e "${GREEN}✔ API key accepted${RESET}"
      else
        echo -e "${RED}✖ Invalid API key${RESET}"
      fi
      read -r -p "Press Enter to continue..."
      ;;
    2)
      echo "Checking VLEEE API..."
      if [[ ! -s "$API_KEY_FILE" ]]; then
        echo -e "${RED}✖ API key not found${RESET}"
      else
        key="$(cat "$API_KEY_FILE")"
        curl -sS --connect-timeout 10 --max-time 20 \
          -X POST "$API_URL" \
          -H "Authorization: Bearer $key" \
          -H "Content-Type: application/json" \
          -H "Accept: application/json" \
          -H "User-Agent: VLEE-AI-Agent/1.0" \
          --data '{"model":"cx/gpt-5.6-luna","messages":[{"role":"user","content":"ping"}],"max_tokens":1}' \
          > /tmp/vlee_status.json 2>&1 || true
        if grep -q '"choices"' /tmp/vlee_status.json; then
          echo -e "${GREEN}✔ AI function OK${RESET}"
        else
          echo -e "${RED}✖ AI function FAILED${RESET}"
          cat /tmp/vlee_status.json
        fi
      fi
      read -r -p "Press Enter to continue..."
      ;;
    3) exit 0 ;;
    *) echo "Invalid option"; sleep 1 ;;
  esac
done
EOF
chmod 755 "$INSTALL_DIR/ai-menu"
echo -e "${GREEN}✔ Commands installed: ai, ai-menu${RESET}"

# Avoid the /usr/local/bin/ai -> same-file ln error.
rm -f /usr/bin/ai /bin/ai /usr/bin/ai-menu /bin/ai-menu
ln -s "$INSTALL_DIR/ai" /usr/bin/ai
ln -s "$INSTALL_DIR/ai-menu" /usr/bin/ai-menu

echo "◆ [6/6] Real AI function test"
echo "Testing actual gpt-5.6-luna chat completion..."
set +e
TEST_OUTPUT="$(printf 'Reply with exactly: OK\n' | "$INSTALL_DIR/ai" 2>&1)"
TEST_RC=$?
set -e

if [[ "$TEST_OUTPUT" == *"OK"* && "$TEST_RC" -eq 0 ]]; then
  echo -e "${GREEN}✔ AI FUNCTION TEST OK${RESET}"
else
  echo -e "${RED}✖ AI FUNCTION TEST FAILED${RESET}"
  echo "$TEST_OUTPUT"
  echo "Files were installed, but the actual GPT-5.6 Luna chat test failed."
fi

rm -rf "$backup_dir"
trap - ERR

echo
echo -e "${GREEN}Installation complete.${RESET}"
echo "Use: ai"
echo "Menu: ai-menu"
