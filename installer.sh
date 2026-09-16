#!/usr/bin/env bash
set -Eeuo pipefail

API_URL="https://api.vleee.net/v1/chat/completions"
MODEL="cx/gpt-5.6-luna"
KEY_DIR="/root/.vlee_ai"
KEY_FILE="$KEY_DIR/api_key"
AI="/usr/local/bin/ai"
MENU="/usr/local/bin/ai-menu"

YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
RESET='\033[0m'

banner() {
  clear || true
  printf '%b\n' "${CYAN}"
  if command -v figlet >/dev/null 2>&1; then
    figlet -f standard "VLEE AI"
  else
    printf '%s\n' \
      '██╗   ██╗██╗     ███████╗███████╗' \
      '██║   ██║██║     ██╔════╝██╔════╝' \
      '██║   ██║██║     █████╗  █████╗  ' \
      '╚██╗ ██╔╝██║     ██╔══╝  ██╔══╝  ' \
      ' ╚████╔╝ ███████╗███████╗███████╗' \
      '  ╚═══╝  ╚══════╝╚══════╝╚══════╝'
  fi
  printf '%bVLEE AI AGENT BY EJAYWATTAPAK%b\n\n' "$YELLOW" "$RESET"
}

step(){ printf '%b◆ [%s/6] %s%b\n' "$CYAN" "$1" "$2" "$RESET"; }
ok(){ printf '%b✔ %s%b\n' "$GREEN" "$1" "$RESET"; }
fail(){ printf '%b✖ %s%b\n' "$RED" "$1" "$RESET"; }

banner

step 1 "Check dependencies"
if ! command -v python3 >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  fail "python3 and curl are required."
  exit 1
fi
if ! command -v figlet >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq figlet >/dev/null
fi
ok "Dependencies OK"

step 2 "API key"
mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"

printf 'Masukkan VLEEE API key.\n'
printf '%b➜ VLEEE API key: %b' "$YELLOW" "$RESET"
IFS= read -r API_KEY </dev/tty

if [[ -z "$API_KEY" ]]; then
  fail "API key kosong."
  exit 1
fi

# Do NOT save the key until the real VLEE API has accepted the request.
TMP_KEY="$(mktemp)"
trap 'rm -f "$TMP_KEY"' EXIT
printf '%s\n' "$API_KEY" > "$TMP_KEY"
chmod 600 "$TMP_KEY"

printf '%bVerifying API key with VLEEE...%b\n' "$YELLOW" "$RESET"

VERIFY="$(python3 - "$TMP_KEY" <<'PY'
import json, sys, urllib.error, urllib.request

key = open(sys.argv[1], encoding="utf-8").read().strip()
body = json.dumps({
    "model": "cx/gpt-5.6-luna",
    "messages": [{"role": "user", "content": "Reply with exactly: OK"}],
    "max_tokens": 8,
    "temperature": 0
}).encode()

req = urllib.request.Request(
    "https://api.vleee.net/v1/chat/completions",
    data=body,
    method="POST",
    headers={
        "Authorization": "Bearer " + key,
        "Content-Type": "application/json",
        "Accept": "application/json",
        "User-Agent": "VLEE-AI-Agent/1.0"
    }
)

try:
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.loads(r.read().decode())
    text = data.get("choices", [{}])[0].get("message", {}).get("content", "")
    if text:
        print("VALID")
    else:
        print("INVALID_RESPONSE")
except urllib.error.HTTPError as e:
    body = e.read().decode(errors="replace")
    print("HTTP " + str(e.code))
    print(body)
except Exception as e:
    print("ERROR " + str(e))
PY
)"

if [[ "$VERIFY" == "VALID" ]]; then
  printf '%s\n' "$API_KEY" > "$KEY_FILE"
  chmod 600 "$KEY_FILE"
  ok "API key verified and saved"
elif [[ "$VERIFY" == HTTP\ 402* || "$VERIFY" == HTTP\ 503* ]]; then
  # VLEE has authenticated the request but currently cannot route the model.
  # This is NOT treated as a fake successful chat test.
  printf '%s\n' "$API_KEY" > "$KEY_FILE"
  chmod 600 "$KEY_FILE"
  printf '%b⚠ API key was accepted by VLEEE, but GPT-5.6 Luna is currently unavailable.%b\n' "$YELLOW" "$RESET"
  printf '%s\n' "$VERIFY"
  printf '%bKey saved. The final real AI test below will show the actual service error.%b\n' "$YELLOW" "$RESET"
else
  fail "API key verification failed. Key was NOT saved."
  printf '%s\n' "$VERIFY"
  exit 1
fi

step 3 "Backup existing agent"
BACKUP="$KEY_DIR/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"
for f in "$AI" "$MENU"; do
  [[ -f "$f" ]] && cp -a "$f" "$BACKUP/"
done
ok "Existing files backed up"

step 4 "Installing autonomous agent"
cat > "$AI" <<'PY'
#!/usr/bin/env python3
import json, subprocess, urllib.error, urllib.request

API_URL = "https://api.vleee.net/v1/chat/completions"
MODEL = "cx/gpt-5.6-luna"
KEY_FILE = "/root/.vlee_ai/api_key"

Y = "\033[1;33m"
DIM = "\033[90m"
RESET = "\033[0m"

SYSTEM = """You are VLEE AI Agent running directly on a Linux VPS.
You have real shell access. Do the work yourself; do not merely tell the user commands to run.

For VPS requests:
- inspect the system yourself with shell commands
- diagnose from real command output
- make required repairs/configuration yourself
- verify important changes yourself
- continue until the user's task is actually completed
- never claim a command ran unless it actually ran
- keep explanations short and practical
- prefer fast, read-only inspection first
- avoid destructive actions; ask before irreversible operations

To execute a shell command, output exactly one command inside:
<CMD>...</CMD>
Do not put explanatory text inside CMD tags.
After command output is returned, analyze it and continue if needed.
"""

def get_key():
    try:
        with open(KEY_FILE, "r", encoding="utf-8") as f:
            return f.read().strip()
    except Exception:
        return ""

def request(messages, max_tokens=1200):
    key = get_key()
    if not key:
        print("ERROR: VLEEE API key not found.")
        return None

    body = json.dumps({
        "model": MODEL,
        "messages": messages,
        "max_tokens": max_tokens,
        "temperature": 0.1
    }).encode()

    req = urllib.request.Request(
        API_URL, data=body, method="POST",
        headers={
            "Authorization": "Bearer " + key,
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "VLEE-AI-Agent/1.0"
        })

    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            data = json.loads(r.read().decode())
        return data["choices"][0]["message"]["content"]
    except urllib.error.HTTPError as e:
        b = e.read().decode(errors="replace")
        print(f"ERROR: HTTP {e.code}\n{b}")
        return None
    except Exception as e:
        print("ERROR:", str(e))
        return None

def run(cmd):
    try:
        p = subprocess.run(
            cmd, shell=True, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
            timeout=60, executable="/bin/bash")
        return p.stdout[-12000:]
    except subprocess.TimeoutExpired:
        return "COMMAND TIMEOUT after 60 seconds"
    except Exception as e:
        return "COMMAND ERROR: " + str(e)

def agent(prompt):
    messages = [
        {"role": "system", "content": SYSTEM},
        {"role": "user", "content": prompt}
    ]

    for _ in range(8):
        answer = request(messages)
        if answer is None:
            return

        if "<CMD>" not in answer:
            print(answer)
            return

        pre = answer.split("<CMD>", 1)[0].strip()
        if pre:
            print(pre)

        if "</CMD>" not in answer:
            print("ERROR: AI returned an incomplete command block.")
            return

        cmd = answer.split("<CMD>", 1)[1].split("</CMD>", 1)[0].strip()
        if not cmd:
            print("ERROR: AI returned an empty command.")
            return

        print(f"{DIM}$ {cmd}{RESET}")
        out = run(cmd)
        messages.append({"role": "assistant", "content": answer})
        messages.append({
            "role": "user",
            "content": "REAL SHELL OUTPUT:\n" + out +
                       "\nContinue the task. Execute another command if required. "
                       "When completely finished, give a concise final result."
        })

    print("AI stopped after the execution limit.")

def main():
    print(f"{Y}VLEE AI — GPT-5.6 Luna{RESET}")
    print("Type 'exit' to quit.\n")

    while True:
        try:
            prompt = input(f"{Y}AI > {RESET}").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return

        if not prompt:
            continue
        if prompt.lower() in ("exit", "quit"):
            return

        print(f"\n{Y}Thinking...{RESET}")
        agent(prompt)
        print()

if __name__ == "__main__":
    main()
PY
chmod 755 "$AI"
ok "Autonomous agent installed"

step 5 "Installing minimal menu"
cat > "$MENU" <<'BASH'
#!/usr/bin/env bash
set -u

KEY_FILE="/root/.vlee_ai/api_key"
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'
RESET='\033[0m'

change_key() {
  printf "${YELLOW}New VLEEE API key: ${RESET}"
  IFS= read -r k </dev/tty
  [[ -z "$k" ]] && { printf "${RED}✖ Key kosong.${RESET}\n"; return; }

  printf '%bVerifying new API key...%b\n' "$YELLOW" "$RESET"
  tmp="$(mktemp)"
  printf '%s\n' "$k" > "$tmp"
  chmod 600 "$tmp"

  result="$(python3 - "$tmp" <<'PY'
import json,sys,urllib.error,urllib.request
key=open(sys.argv[1]).read().strip()
body=json.dumps({
 "model":"cx/gpt-5.6-luna",
 "messages":[{"role":"user","content":"Reply with exactly: OK"}],
 "max_tokens":8,"temperature":0
}).encode()
req=urllib.request.Request(
 "https://api.vleee.net/v1/chat/completions",
 data=body, method="POST",
 headers={"Authorization":"Bearer "+key,"Content-Type":"application/json",
          "Accept":"application/json","User-Agent":"VLEE-AI-Agent/1.0"})
try:
 with urllib.request.urlopen(req,timeout=30) as r:
  d=json.loads(r.read().decode())
 print("VALID" if d.get("choices") else "INVALID_RESPONSE")
except urllib.error.HTTPError as e:
 print("HTTP "+str(e.code))
 print(e.read().decode(errors="replace"))
except Exception as e:
 print("ERROR "+str(e))
PY
)"
  rm -f "$tmp"

  if [[ "$result" == "VALID" || "$result" == HTTP\ 402* || "$result" == HTTP\ 503* ]]; then
    printf '%s\n' "$k" > "$KEY_FILE"
    chmod 600 "$KEY_FILE"
    printf "${GREEN}✔ API key accepted and saved${RESET}\n"
    [[ "$result" != "VALID" ]] && printf "${YELLOW}⚠ GPT-5.6 Luna is currently unavailable; actual error shown below.${RESET}\n%s\n" "$result"
  else
    printf "${RED}✖ API key rejected. It was NOT saved.${RESET}\n%s\n" "$result"
  fi
}

status() {
  python3 - <<'PY'
import json,urllib.error,urllib.request
p="/root/.vlee_ai/api_key"
try:
    key=open(p).read().strip()
except Exception:
    print("\033[1;31m✖ API key not found\033[0m")
    raise SystemExit

body=json.dumps({
 "model":"cx/gpt-5.6-luna",
 "messages":[{"role":"user","content":"Reply with exactly: OK"}],
 "max_tokens":8,"temperature":0
}).encode()
req=urllib.request.Request(
 "https://api.vleee.net/v1/chat/completions",
 data=body,method="POST",
 headers={"Authorization":"Bearer "+key,"Content-Type":"application/json",
          "Accept":"application/json","User-Agent":"VLEE-AI-Agent/1.0"})
try:
    with urllib.request.urlopen(req,timeout=30) as r:
        d=json.loads(r.read().decode())
    text=d.get("choices",[{}])[0].get("message",{}).get("content","").strip()
    if text:
        print("\033[1;32m✔ GPT-5.6 Luna actual chat test OK\033[0m")
    else:
        print("\033[1;31m✖ Chat returned empty response\033[0m")
except urllib.error.HTTPError as e:
    print(f"\033[1;31m✖ AI function FAILED — HTTP {e.code}\033[0m")
    print(e.read().decode(errors="replace"))
except Exception as e:
    print(f"\033[1;31m✖ AI function FAILED: {e}\033[0m")
PY
}

while :; do
  clear
  printf "${CYAN}VLEE AI AGENT BY EJAYWATTAPAK${RESET}\n\n"
  echo "  1) Change API key"
  echo "  2) Check status"
  echo "  3) Exit"
  printf "\n  Select [1-3]: "
  IFS= read -r c </dev/tty
  case "$c" in
    1) change_key; read -r -p "  Press Enter..." _ </dev/tty ;;
    2) status; read -r -p "  Press Enter..." _ </dev/tty ;;
    3) exit 0 ;;
  esac
done
BASH
chmod 755 "$MENU"

ln -sf "$AI" /usr/local/bin/ai
ln -sf "$MENU" /usr/local/bin/ai-menu
ok "Commands installed: ai, ai-menu"

step 6 "Real AI function test"
printf '%bTesting actual %s chat completion...%b\n' "$YELLOW" "$RESET"

TEST="$(python3 - <<'PY'
import json,urllib.error,urllib.request
key=open("/root/.vlee_ai/api_key").read().strip()
body=json.dumps({
 "model":"cx/gpt-5.6-luna",
 "messages":[{"role":"user","content":"Reply with exactly: OK"}],
 "max_tokens":8,"temperature":0
}).encode()
req=urllib.request.Request(
 "https://api.vleee.net/v1/chat/completions",
 data=body,method="POST",
 headers={"Authorization":"Bearer "+key,"Content-Type":"application/json",
          "Accept":"application/json","User-Agent":"VLEE-AI-Agent/1.0"})
try:
    with urllib.request.urlopen(req,timeout=30) as r:
        d=json.loads(r.read().decode())
    print("OK:"+d["choices"][0]["message"]["content"].strip())
except urllib.error.HTTPError as e:
    print("HTTP:"+str(e.code))
    print(e.read().decode(errors="replace"))
except Exception as e:
    print("ERROR:"+str(e))
PY
)"

if [[ "$TEST" == OK:* ]]; then
  ok "AI FUNCTION TEST PASSED — GPT-5.6 Luna is responding"
else
  fail "AI FUNCTION TEST FAILED"
  printf '%s\n' "$TEST"
  printf '%bFiles were installed, but the actual AI chat test failed.%b\n' "$YELLOW" "$RESET"
  echo "Run: ai-menu → 2) Check status"
fi

echo
printf '%bInstallation complete.%b\n' "$GREEN" "$RESET"
echo "Use: ai"
echo "Menu: ai-menu"
