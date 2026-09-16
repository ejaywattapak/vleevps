#!/usr/bin/env bash
set -euo pipefail

API_BASE="https://api.vleee.net/v1"
MODEL="gpt-5.6-luna"
KEY_DIR="/root/.vlee_ai"
KEY_FILE="$KEY_DIR/api_key"
AI="/usr/local/bin/ai"
MENU="/usr/local/bin/ai-menu"

if [ "$(id -u)" != "0" ]; then
  echo "Run as root."
  exit 1
fi

clear
if command -v figlet >/dev/null 2>&1; then
  figlet "VLEE AI"
else
  printf '\nVLEE AI\n'
fi
printf 'VLEE AI AGENT BY EJAYWATTAPAK\n\n'

echo "◆ [1/6] Check dependencies"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl ca-certificates python3 figlet >/dev/null
echo "✔ Dependencies OK"

echo "◆ [2/6] API key"
mkdir -p "$KEY_DIR"
chmod 700 "$KEY_DIR"
printf 'Masukkan VLEEE API key.\n'
printf '➜ VLEEE API key: '
IFS= read -r API_KEY </dev/tty
if [ -z "$API_KEY" ]; then
  echo "✖ API key kosong"
  exit 1
fi
printf '%s' "$API_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"
echo "✔ API key saved"

echo "◆ [3/6] Backup existing agent"
TS="$(date +%Y%m%d-%H%M%S)"
for f in "$AI" "$MENU" /usr/bin/ai /usr/bin/ai-menu /bin/ai /bin/ai-menu; do
  if [ -e "$f" ] || [ -L "$f" ]; then
    cp -a "$f" "$f.bak.$TS" 2>/dev/null || true
  fi
done
echo "✔ Existing files backed up"

echo "◆ [4/6] Installing autonomous agent"
cat > "$AI" <<'PY'
#!/usr/bin/env python3
import json, os, subprocess, sys, urllib.error, urllib.request

API_URL="https://api.vleee.net/v1/chat/completions"
MODEL="gpt-5.6-luna"
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
        # Show only natural answer; command execution is internal.
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
    print("VLEE AI — GPT-5.6 Luna")
    print("Type exit to quit.\n")
    while True:
        try:
            prompt=input("AI > ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return
        if not prompt:
            continue
        if prompt.lower() in ("exit","quit"):
            return
        print("\nThinking...")
        agent(prompt)
        print()

if __name__=="__main__":
    main()
PY
chmod 755 "$AI"

echo "◆ [5/6] Installing minimal menu"
cat > "$MENU" <<'BASH'
#!/usr/bin/env bash
set -u
KEY_FILE="/root/.vlee_ai/api_key"
API="https://api.vleee.net/v1/chat/completions"
MODEL="gpt-5.6-luna"

banner() {
  clear
  if command -v figlet >/dev/null 2>&1; then figlet "VLEE AI"; else echo "VLEE AI"; fi
  echo "VLEE AI AGENT BY EJAYWATTAPAK"
  echo
}
change_key() {
  printf "➜ VLEEE API key: "
  IFS= read -r k </dev/tty
  [ -n "$k" ] || { echo "✖ Empty key"; read -r _ </dev/tty; return; }
  printf '%s' "$k" > "$KEY_FILE"
  chmod 600 "$KEY_FILE"
  echo "✔ API key saved"
  read -r _ </dev/tty
}
status() {
  echo "Checking actual AI function..."
  k="$(cat "$KEY_FILE" 2>/dev/null || true)"
  if [ -z "$k" ]; then echo "✖ API key not found"; read -r _ </dev/tty; return; fi
  body="$(python3 - "$k" "$API" "$MODEL" <<'PY'
import json,sys,urllib.request,urllib.error
k,api,model=sys.argv[1:]
d=json.dumps({"model":model,"messages":[{"role":"user","content":"Reply exactly: VLEE OK"}],"max_tokens":8,"temperature":0}).encode()
r=urllib.request.Request(api,data=d,method="POST",headers={"Authorization":"Bearer "+k,"Content-Type":"application/json","Accept":"application/json","User-Agent":"VLEE-AI-Agent/1.0"})
try:
  with urllib.request.urlopen(r,timeout=60) as x:
    print("HTTP:",x.status); print(x.read().decode())
except urllib.error.HTTPError as e:
  print("HTTP:",e.code); print(e.read().decode(errors="replace"))
except Exception as e:
  print("ERROR:",e)
PY
)"
  echo "$body"
  echo
  if echo "$body" | grep -q '^HTTP: 200$'; then
    echo "✔ AI function OK"
  else
    echo "✖ AI function FAILED"
  fi
  read -r _ </dev/tty
}
while true; do
  banner
  echo "  1) Change API key"
  echo "  2) Check status"
  echo "  3) Exit"
  echo
  read -r -p "  Select [1-3]: " c </dev/tty
  case "$c" in
    1) change_key ;;
    2) status ;;
    3) exit 0 ;;
  esac
done
BASH
chmod 755 "$MENU"

ln -sf "$AI" /usr/bin/ai
ln -sf "$AI" /bin/ai
ln -sf "$MENU" /usr/bin/ai-menu
ln -sf "$MENU" /bin/ai-menu
echo "✔ Commands installed: ai, ai-menu"

echo "◆ [6/6] Real AI function test"
echo "Testing actual $MODEL chat completion..."
set +e
TEST_OUT="$(python3 - "$KEY_FILE" "$API_BASE/chat/completions" "$MODEL" <<'PY'
import json,sys,urllib.request,urllib.error
kf,api,model=sys.argv[1:]
k=open(kf).read().strip()
d=json.dumps({"model":model,"messages":[{"role":"user","content":"Reply exactly: VLEE OK"}],"max_tokens":8,"temperature":0}).encode()
r=urllib.request.Request(api,data=d,method="POST",headers={"Authorization":"Bearer "+k,"Content-Type":"application/json","Accept":"application/json","User-Agent":"VLEE-AI-Agent/1.0"})
try:
  with urllib.request.urlopen(r,timeout=60) as x:
    print("HTTP:",x.status)
    print(x.read().decode())
except urllib.error.HTTPError as e:
  print("HTTP:",e.code)
  print(e.read().decode(errors="replace"))
except Exception as e:
  print("ERROR:",e)
PY
)"
set -e
echo "$TEST_OUT"
if echo "$TEST_OUT" | grep -q '^HTTP: 200$'; then
  echo "✔ AI FUNCTION OK"
else
  echo "✖ AI FUNCTION TEST FAILED"
  echo "Files were installed, but the actual GPT-5.6 Luna chat test failed."
  echo "Run: ai-menu → 2) Check status"
fi

echo
echo "Installation complete."
echo "Use: ai"
echo "Menu: ai-menu"
