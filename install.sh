#!/bin/bash
set -Eeuo pipefail
API_BASE='https://api.vleee.net/v1'; MODEL='gpt-5.6-luna'; KEY_FILE='/root/.openai_key'; AGENT='/usr/local/bin/ai'; BACKUP='/root/.vleevps/backups'
R='\033[0m'; C='\033[1;36m'; G='\033[1;32m'; Y='\033[1;33m'; X='\033[1;31m'; B='\033[1m'
die(){ echo -e "${X}✖ $*${R}"; exit 1; }
[ "$EUID" -eq 0 ] || die 'Run as root.'
clear; echo -e "${C}${B}╭──────────────────────────────────────────────────────╮\n│              VLEEE AI VPS AGENT                     │\n│          Autonomous VPS Repair & Tools              │\n╰──────────────────────────────────────────────────────╯${R}"
echo "  API   : $API_BASE"; echo "  MODEL : $MODEL"; echo

echo -e "${C}◆ [1/6] Check dependencies${R}"
if ! command -v curl >/dev/null || ! command -v jq >/dev/null; then apt-get update && apt-get install -y curl jq ca-certificates; fi
command -v curl >/dev/null || die 'curl installation failed.'; command -v jq >/dev/null || die 'jq installation failed.'
echo -e "${G}✔ Dependencies OK${R}"

echo; echo -e "${C}◆ [2/6] API key${R}"
echo 'Masukkan VLEEE API key.'; echo 'Input dibaca dari /dev/tty supaya curl ... | bash tidak skip.'
while :; do IFS= read -r -s -p '➜ VLEEE API key: ' API_KEY </dev/tty; echo; API_KEY="${API_KEY//$'\r'/}"; [ -n "$API_KEY" ] && break; echo -e "${Y}⚠ API key kosong. Sila masukkan key.${R}"; done
umask 077; printf '%s\n' "$API_KEY" > "$KEY_FILE"; chmod 600 "$KEY_FILE"

echo; echo -e "${C}◆ [3/6] Backup existing agent${R}"; mkdir -p "$BACKUP"; chmod 700 "$BACKUP"
if [ -f "$AGENT" ]; then cp -a "$AGENT" "$BACKUP/ai.$(date +%Y%m%d-%H%M%S)"; echo -e "${G}✔ Existing agent backed up${R}"; else echo '• No existing agent.'; fi

echo; echo -e "${C}◆ [4/6] Installing autonomous agent${R}"
cat > "$AGENT" <<'AI'
#!/bin/bash
set -Eeuo pipefail
API_BASE='https://api.vleee.net/v1'; MODEL='gpt-5.6-luna'; KEY_FILE='/root/.openai_key'; BACKUP='/root/.vleevps/backups'; TIMEOUT=180
R='\033[0m'; C='\033[1;36m'; G='\033[1;32m'; Y='\033[1;33m'; X='\033[1;31m'; B='\033[1m'; D='\033[2m'
key(){ [ -s "$KEY_FILE" ] && tr -d '\r\n' < "$KEY_FILE"; }
backup(){ [ -f "$1" ] || return 0; mkdir -p "$BACKUP"; cp -a "$1" "$BACKUP/$(printf '%s' "$1"|sed 's#/#_#g').$(date +%Y%m%d-%H%M%S)"; echo -e "${D}[backup] $1${R}"; }
run(){ local c="$1"; case "$c" in 'rm -rf /'|'rm -rf /*'|'mkfs'|'mkfs '*|'shutdown '*|'reboot '*) echo -e "${X}[blocked] dangerous command${R}"; return 125;; esac; echo -e "${Y}[exec]${R} $c"; bash -lc "$c"; }
write_file(){ local p="$1"; local v="$2"; case "$p" in /*) ;; *) return 2;; esac; [ -f "$p" ] && backup "$p"; mkdir -p "$(dirname "$p")"; printf '%s\n' "$v" > "$p"; echo -e "${G}[write]${R} $p"; }
text(){ jq -r '[.output[]?.content[]?|select(.type=="output_text")|.text]|join("\n")'; }
agent(){ local req="$1" n=1 max=12 resp txt clean act cmd path content msg input k; local sys='You are VLEEE AI VPS Agent running as root on the user'7s own VPS. Inspect the VPS yourself, diagnose, repair and verify. Do not ask the user to paste files you can inspect. Do not merely give commands when you can execute them. Before changing an existing file, inspect it and make a backup. Never claim success without verification. Every response must be exactly one JSON object. Allowed actions: {"action":"execute","command":"...","reason":"..."} OR {"action":"write_file","path":"/absolute/path","content":"...","reason":"..."} OR {"action":"final","message":"..."}. Do not expose secrets. Do not use destructive system-wide commands. Use absolute paths. Continue through multiple steps until complete.'
while [ $n -le $max ]; do echo -e "${C}[AI step $n/$max]${R} inspecting / repairing..."; k="$(key)"; input="$(jq -n --arg s "$sys" --arg r "$req" --arg n "$n" '$s+"\n\nUser request:\n"+$r+"\n\nRepair step "+$n+". Act now."')"; resp="$(curl -sS --connect-timeout 20 --max-time "$TIMEOUT" "$API_BASE/responses" -H 'Content-Type: application/json' -H "Authorization: Bearer $k" -d "$(jq -n --arg m "$MODEL" --arg i "$input" '{model:$m,input:$i}')")" || { echo -e "${X}✖ VLEEE connection failed${R}"; return 1; }; if jq -e '.error' >/dev/null 2>&1 <<<"$resp"; then jq -r '.error.message // "API error"' <<<"$resp"; return 1; fi; txt="$(printf '%s' "$resp"|text)"; clean="$(printf '%s' "$txt"|sed -e 's/^```json[[:space:]]*$//' -e 's/^```[[:space:]]*$//')"; act="$(jq -r '.action // empty' <<<"$clean" 2>/dev/null || true)"; [ -n "$act" ] || { echo -e "${X}ERROR: AI returned invalid JSON action:${R}"; printf '%s\n' "$txt"; return 1; }; case "$act" in execute) cmd="$(jq -r '.command // empty' <<<"$clean")"; [ -n "$cmd" ] || return 1; run "$cmd" || true;; write_file) path="$(jq -r '.path // empty' <<<"$clean")"; content="$(jq -r '.content // empty' <<<"$clean")"; write_file "$path" "$content" || { echo -e "${X}Invalid write_file action${R}"; return 1; };; final) msg="$(jq -r '.message // "Done."' <<<"$clean")"; echo; echo -e "${G}${B}AI:${R} $msg"; return 0;; *) echo -e "${X}Unknown action: $act${R}"; return 1;; esac; n=$((n+1)); done; echo -e "${Y}AI reached the maximum repair steps ($max).${R}"; }
show(){ local os cpu ram disk ip; . /etc/os-release 2>/dev/null || true; os="${PRETTY_NAME:-Linux}"; cpu="$(nproc 2>/dev/null||echo '?')"; ram="$(free -h 2>/dev/null|awk '/^Mem:/{print $2}'||echo '?')"; disk="$(df -h /|awk 'NR==2{print $2" total / "$4" free"}')"; ip="$(curl -4 -sS --max-time 5 https://ipv4.icanhazip.com 2>/dev/null|tr -d '\r\n'||echo unknown)"; echo -e "${C}${B}╭──────────────────────────────────────────────────────╮\n│                 VLEEE AI VPS AGENT                  │\n╰──────────────────────────────────────────────────────╯${R}"; printf '  OS     : %s\n  CPU    : %s cores\n  RAM    : %s\n  DISK   : %s\n  VPS IP : %s\n  MODEL  : %s\n' "$os" "$cpu" "$ram" "$disk" "$ip" "$MODEL"; }
change_key(){ local nk old test typ; while :; do IFS= read -r -s -p '➜ New VLEEE API key: ' nk </dev/tty; echo; [ -n "$nk" ]&&break; done; old="$(key||true)"; printf '%s\n' "$nk">"$KEY_FILE"; chmod 600 "$KEY_FILE"; test="$(curl -sS --connect-timeout 20 --max-time 60 "$API_BASE/responses" -H 'Content-Type: application/json' -H "Authorization: Bearer $nk" -d "$(jq -n --arg m "$MODEL" '{model:$m,input:"Reply only: VLEEE AI OK"}')"||true)"; typ="$(jq -r '.error.type//empty'<<<"$test")"; if [ "$typ" = invalid_key ]||[ "$typ" = authentication_error ]; then [ -n "$old" ]&&printf '%s\n' "$old">"$KEY_FILE"; chmod 600 "$KEY_FILE"; echo -e "${X}✖ Invalid key. Previous key restored.${R}"; return 1; fi; echo -e "${G}✔ New key saved.${R}"; }
test_api(){ local r; r="$(curl -sS --connect-timeout 20 --max-time 60 "$API_BASE/responses" -H 'Content-Type: application/json' -H "Authorization: Bearer $(key)" -d "$(jq -n --arg m "$MODEL" '{model:$m,input:"Reply only: VLEEE AI OK"}')"||true)"; if jq -e '.error' >/dev/null 2>&1<<<"$r"; then jq .<<<"$r"; return 1; fi; echo -e "${G}✔ VLEEE AI connection OK${R}"; text<<<"$r"; }
terminal(){ echo -e "${C}${B}╔════════════════════════════════════════════════════╗\n║           VLEEE AI TERMINAL                       ║\n║           model: gpt-5.6-luna                      ║\n║           type 'exit' to quit                      ║\n╚════════════════════════════════════════════════════╝${R}"; while :; do printf 'AI > '; IFS= read -r p </dev/tty||break; [ "$p" = exit ]&&break; [ -z "$p" ]&&continue; agent "$p"; echo; done; }
menu(){ while :; do clear; show; echo; echo '  ╭──────────────────────────────────────────────╮'; echo '  │  1) Change API key                           │'; echo '  │  2) Test API connection                      │'; echo '  │  3) Start AI terminal                        │'; echo '  │  4) Exit                                     │'; echo '  ╰──────────────────────────────────────────────╯'; read -r -p '  Select [1-4]: ' c </dev/tty; case "$c" in 1)change_key;read -r -p '  Press Enter...' _ </dev/tty;;2)test_api;read -r -p '  Press Enter...' _ </dev/tty;;3)terminal;return;;4)return;;*)sleep 1;;esac;done; }
[ "${1:-}" = menu ]&&menu||{ [ $# -eq 0 ]&&terminal||agent "$*"; }
AI
chmod 700 "$AGENT"; bash -n "$AGENT"; echo -e "${G}✔ Agent installed and syntax OK${R}"

echo; echo -e "${C}◆ [5/6] Permissions${R}"; chmod 700 "$AGENT"; chmod 600 "$KEY_FILE"; echo -e "${G}✔ /usr/local/bin/ai = 700${R}"; echo -e "${G}✔ /root/.openai_key = 600${R}"

echo; echo -e "${C}◆ [6/6] Testing VLEEE API${R}"
TEST="$(curl -sS --connect-timeout 20 --max-time 60 "$API_BASE/responses" -H 'Content-Type: application/json' -H "Authorization: Bearer $API_KEY" -d "$(jq -n --arg m "$MODEL" '{model:$m,input:"Reply only: VLEEE AI OK"}')"||true)"
printf '%s\n' "$TEST"|jq . 2>/dev/null || printf '%s\n' "$TEST"
TYPE="$(printf '%s' "$TEST"|jq -r '.error.type//empty' 2>/dev/null||true)"; MSG="$(printf '%s' "$TEST"|jq -r '.error.message//empty' 2>/dev/null||true)"
case "$TYPE" in invalid_key|authentication_error) rm -f "$KEY_FILE"; die 'API key invalid. Key removed.';; no_provider) echo -e "${Y}⚠ Key diterima, tetapi provider untuk $MODEL tidak tersedia. Key dikekalkan.${R}";; '') echo -e "${G}✔ VLEEE AI API connection OK${R}";; *) echo -e "${Y}⚠ API error: ${MSG:-unknown}. Key dikekalkan kerana bukan authentication error.${R}";; esac
unset API_KEY TEST
echo; echo -e "${G}${B}╭──────────────────────────────────────────────────────╮\n│              INSTALLATION COMPLETE                  │\n╰──────────────────────────────────────────────────────╯${R}"; echo '  Start AI : ai'; echo '  AI menu  : ai menu'; echo '  Key file : /root/.openai_key'; echo
