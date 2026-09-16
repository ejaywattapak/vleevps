#!/usr/bin/env bash
set -Eeuo pipefail
REPO_RAW="https://raw.githubusercontent.com/ejaywattapak/vleekey/main/key.conf"
KEY_FILE=/root/.vlee_ai/api_key
INSTALL_DIR=/usr/local/bin
TMP=$(mktemp -d /tmp/vlee-installer.XXXXXX)
BACKUP="$TMP/backup"; mkdir -p "$BACKUP"
Y='\033[1;33m'; G='\033[1;32m'; R='\033[1;31m'; Z='\033[0m'
rollback(){ echo -e "${R}Rolling back changes...${Z}"; rm -f "$INSTALL_DIR/ai" "$INSTALL_DIR/ai-menu"; [[ -f "$BACKUP/ai" ]] && install -m755 "$BACKUP/ai" "$INSTALL_DIR/ai"; [[ -f "$BACKUP/ai-menu" ]] && install -m755 "$BACKUP/ai-menu" "$INSTALL_DIR/ai-menu"; rm -rf /root/.vlee_ai.new; echo -e "${R}✖ Installation aborted. Changes rolled back.${Z}"; }
fail(){ echo -e "${R}✖ $*${Z}"; rollback; exit 1; }
trap 'rm -rf "$TMP"' EXIT
[[ $EUID -eq 0 ]] || fail "Run as root."
command -v curl >/dev/null || fail "curl is required."
command -v python3 >/dev/null || fail "python3 is required."
echo -e "${Y}Downloading authorization list...${Z}"
curl -fsSL --retry 3 --connect-timeout 10 "$REPO_RAW" -o "$TMP/key.conf" || fail "Unable to download authorization list."
VPS_IP=$(curl -4fsSL --connect-timeout 10 https://api.ipify.org 2>/dev/null || true)
[[ -n "$VPS_IP" ]] || fail "Unable to determine VPS public IPv4."
[[ -f "$INSTALL_DIR/ai" ]] && cp -a "$INSTALL_DIR/ai" "$BACKUP/ai"
[[ -f "$INSTALL_DIR/ai-menu" ]] && cp -a "$INSTALL_DIR/ai-menu" "$BACKUP/ai-menu"
ip_registered=0; registered_key=""
while IFS='|' read -r ip key; do
  [[ -z "${ip// }" || "${ip:0:1}" == "#" ]] && continue
  ip="${ip//[[:space:]]/}"; key="${key//$'\r'/}"; key="${key## }"; key="${key%% }"
  if [[ "$ip" == "$VPS_IP" ]]; then ip_registered=1; registered_key="$key"; fi
done < "$TMP/key.conf"
for attempt in 1 2 3; do
  printf '➜ VLEEE API key (attempt %d/3): ' "$attempt"; IFS= read -r API_KEY < /dev/tty || fail "Unable to read API key."
  key_registered=0; grep -Fq "|$API_KEY" "$TMP/key.conf" && key_registered=1 || true
  if [[ $ip_registered -eq 1 && $key_registered -eq 1 && "$registered_key" == "$API_KEY" ]]; then echo -e "${G}✔ IP and API key registered${Z}"; break; fi
  if [[ $ip_registered -eq 0 && $key_registered -eq 0 ]]; then echo -e "${R}✖ IP AND KEY NOT REGISTERED — PLEASE CONTACT ADMIN${Z}"; elif [[ $ip_registered -eq 0 ]]; then echo -e "${R}✖ IP NOT REGISTERED — PLEASE CONTACT ADMIN${Z}"; else echo -e "${R}✖ KEY NOT REGISTERED — PLEASE CONTACT ADMIN${Z}"; fi
  [[ $attempt -eq 3 ]] && { rollback; exit 1; }
done
mkdir -p /root/.vlee_ai.new; printf '%s\n' "$API_KEY" > /root/.vlee_ai.new/api_key; chmod 700 /root/.vlee_ai.new; chmod 600 /root/.vlee_ai.new/api_key
cat > "$INSTALL_DIR/ai" <<'PY'
#!/usr/bin/env python3
import json,subprocess,urllib.request,urllib.error
API_URL="https://api.vleee.net/v1/chat/completions"
MODELS=["cx/gpt-5.6-luna","cb/gpt-5.6-luna","deepseek-v4.1-flash","glm-5.3-flash","minimax-m3"]
KEY_FILE="/root/.vlee_ai/api_key"
SYSTEM="""You are VLEE AI Agent running directly on a Linux VPS. You have real shell access. Do the work yourself; do not merely tell the user commands to run. Inspect, diagnose, repair/configure, and verify yourself. Never claim a command ran unless it actually ran. Prefer fast read-only inspection. Avoid destructive actions; ask before irreversible operations. To execute a shell command, output exactly one command inside <CMD>...</CMD>."""
def key():
 try:return open(KEY_FILE).read().strip()
 except:return ""
def request(messages,max_tokens=1200):
 k=key()
 if not k: print("ERROR: VLEEE API key not found."); return None
 for model in MODELS:
  body=json.dumps({"model":model,"messages":messages,"max_tokens":max_tokens,"temperature":0.1}).encode()
  req=urllib.request.Request(API_URL,data=body,method="POST",headers={"Authorization":"Bearer "+k,"Content-Type":"application/json","Accept":"application/json","User-Agent":"VLEE-AI-Agent/1.0","x-max-input-price":"0.10","x-max-output-price":"0.60"})
  try:
   with urllib.request.urlopen(req,timeout=30) as r:data=json.loads(r.read().decode())
   return data["choices"][0]["message"]["content"]
  except urllib.error.HTTPError as e:
   b=e.read().decode(errors="replace")
   if e.code in (402,429,500,502,503,504): print(f"\033[1;33mProvider unavailable: {model} — trying fallback...\033[0m"); continue
   print(f"ERROR: HTTP {e.code}\n{b}"); return None
  except Exception as e: print(f"\033[1;33mProvider error: {model} — trying fallback...\033[0m"); continue
 print("ERROR: All VLEEE providers/models are unavailable."); return None
def run(c):
 try:return subprocess.run(c,shell=True,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60,executable="/bin/bash").stdout[-12000:]
 except subprocess.TimeoutExpired:return "COMMAND TIMEOUT after 60 seconds"
def agent(p):
 m=[{"role":"system","content":SYSTEM},{"role":"user","content":p}]
 for _ in range(8):
  a=request(m)
  if a is None:return
  if "<CMD>" not in a:print(a);return
  pre=a.split("<CMD>",1)[0].strip()
  if pre:print(pre)
  c=a.split("<CMD>",1)[1].split("</CMD>",1)[0].strip()
  print(f"\033[90m$ {c}\033[0m"); out=run(c)
  m += [{"role":"assistant","content":a},{"role":"user","content":"REAL SHELL OUTPUT:\n"+out+"\nContinue until complete."}]
def main():
 print("\033[1;33mVLEE AI — GPT-5.6 Luna\033[0m\nType exit to quit.\n")
 while True:
  try:p=input("\033[1;33mAI > \033[0m").strip()
  except (EOFError,KeyboardInterrupt):print();return
  if p.lower() in ("exit","quit"):return
  if not p:continue
  print("\n\033[1;33mThinking...\033[0m");agent(p);print()
if __name__=="__main__":main()
PY
chmod 755 "$INSTALL_DIR/ai"
cat > "$INSTALL_DIR/ai-menu" <<'SH'
#!/usr/bin/env bash
set -u
KEY_FILE=/root/.vlee_ai/api_key; API=https://api.vleee.net/v1/chat/completions; MODEL=cx/gpt-5.6-luna; Y='\033[1;33m';G='\033[1;32m';R='\033[1;31m';Z='\033[0m'
while true; do clear; echo -e "${Y}VLEE AI AGENT BY EJAYWATTAPAK${Z}"; echo '  1) Change API key'; echo '  2) Check status'; echo '  3) Exit'; printf '  Select [1-3]: '; read -r c; case $c in
1) printf 'New VLEEE API key: '; read -r k < /dev/tty; if [[ -n $k ]]; then mkdir -p /root/.vlee_ai; printf '%s\n' "$k">"$KEY_FILE"; chmod 600 "$KEY_FILE"; echo -e "${G}✔ API key saved${Z}"; else echo -e "${R}✖ Empty key${Z}"; fi; read -r -p 'Press Enter to continue...' ;;
2) echo 'Checking VLEEE API...'; curl -sS -X POST "$API" -H "Authorization: Bearer $(cat "$KEY_FILE" 2>/dev/null)" -H 'Content-Type: application/json' -H 'User-Agent: VLEE-AI-Agent/1.0' -d '{"model":"cx/gpt-5.6-luna","messages":[{"role":"user","content":"Reply only OK"}],"max_tokens":5}'; echo; read -r -p 'Press Enter to continue...' ;;
3) exit 0;; *) echo 'Invalid choice'; sleep 1;; esac; done
SH
chmod 755 "$INSTALL_DIR/ai-menu"
rm -rf /root/.vlee_ai; mv /root/.vlee_ai.new /root/.vlee_ai
for c in ai ai-menu; do [[ -e /usr/bin/$c ]] || ln -s "$INSTALL_DIR/$c" /usr/bin/$c; [[ -e /bin/$c ]] || ln -s "$INSTALL_DIR/$c" /bin/$c; done
python3 -m py_compile "$INSTALL_DIR/ai" || fail 'AI script syntax test failed.'
echo -e "${Y}◆ Installation complete${Z}"; echo 'Use: ai'; echo 'Menu: ai-menu'
