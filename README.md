<div align="center">

# 🤖 VLEEE AI VPS Agent

### Autonomous AI-powered VPS troubleshooting & repair

<img src="assets/banner.svg" alt="VLEEE AI VPS Agent" width="900">

<p>
  <a href="https://t.me/ejaywattapak">💬 Get API Key / Telegram</a>
  ·
  <a href="https://github.com/ejaywattapak/vleevps">⭐ GitHub Repository</a>
</p>

</div>

---

## 🚀 What is VLEEE AI VPS Agent?

**VLEEE AI VPS Agent** is not just a chatbot.

It is an **autonomous VPS troubleshooting agent** that can inspect the VPS, execute commands, read scripts/configurations, diagnose errors, make repairs, and verify the result.

You tell it what is wrong. The agent investigates the VPS itself instead of asking you to copy/paste every file.

Example:

```text
AI > aku tak boleh pakai command menu. tolong fix.

[exec] command -v menu
[exec] readlink -f /usr/local/bin/menu
[exec] wc -c /usr/local/xraayvpn/bin/menu
[exec] find /usr/local /root /opt -type f ...
[backup] /root/.vleevps/backups/...
[write] /usr/local/xraayvpn/bin/menu
[exec] bash -n /usr/local/xraayvpn/bin/menu
[exec] menu

AI:
Menu sudah dipulihkan dan verification berjaya.
```

---

## ✨ Features

- 🤖 Autonomous troubleshooting loop
- 🖥️ Real VPS command execution
- 🔎 Inspect files, scripts, services and configuration
- 🛠️ Repair scripts automatically
- 💾 Automatic backup before file modifications
- 🧪 Syntax/configuration verification
- 🔄 Service restart/reload when required
- 📦 Install normal packages required for troubleshooting
- 🔐 API key stored with permission `600`
- 🎨 Modern terminal interface
- ⚡ GPT-5.6 Luna
- 🧠 Multi-step inspect → diagnose → repair → verify workflow

---

## 💻 Supported OS

Officially supported:

| OS | Status |
|---|---|
| Ubuntu 22.04 LTS | ✅ |
| Ubuntu 24.04 LTS | ✅ |
| Debian 11 | ✅ |
| Debian 12 | ✅ |
| Debian 13 | ✅ |

### Requirements

- Root access
- `apt-get`
- Internet connection
- `curl`, `jq`, `ca-certificates` and `python3` are installed automatically by the installer

> Other Debian-based distributions may work, but the versions above are the tested target.

---

## 📥 Installation

If `curl` is missing:

```bash
apt-get update && apt-get install -y curl ca-certificates
```

Then run:

```bash
curl -fsSL https://raw.githubusercontent.com/ejaywattapak/vleevps/main/install.sh | bash
```

The installer will **wait for your API key before continuing**.

```text
╭──────────────────────────────────────────────╮
│             VLEEE AI VPS AGENT               │
╰──────────────────────────────────────────────╯

◆ API KEY
➜ Masukkan VLEEE API key:
```

The key is read from the terminal directly, so piping the installer through `bash` does not make the installer accidentally continue with an empty key.

The installer should only save the key after it has passed the API test.

---

## 🔑 Need an API Key?

For an API key, contact:

### 👉 [@ejaywattapak on Telegram](https://t.me/ejaywattapak)

Please use Telegram for API key purchase/support.

---

## 🧠 How the Agent Works

```text
┌──────────────────────────┐
│       USER REQUEST       │
└────────────┬─────────────┘
             ↓
┌──────────────────────────┐
│    VLEEE AI / LUNA       │
└────────────┬─────────────┘
             ↓
┌──────────────────────────┐
│       INSPECT VPS        │
└────────────┬─────────────┘
             ↓
┌──────────────────────────┐
│   DIAGNOSE THE PROBLEM   │
└────────────┬─────────────┘
             ↓
       ┌─────┴─────┐
       ↓           ↓
   EXECUTE      WRITE/FIX
       │           │
       └─────┬─────┘
             ↓
┌──────────────────────────┐
│      VERIFY RESULT       │
└────────────┬─────────────┘
             ↓
        ┌────┴────┐
        │  FIXED  │
        └─────────┘
```

The agent can perform multiple diagnostic and repair steps in a single user request.

---

## 🖥️ Commands

### Start AI

```bash
ai
```

Example:

```text
AI > check kenapa command menu tak function dan fix sendiri
```

The agent should inspect the VPS directly.

### Open Agent Menu

```bash
ai menu
```

The menu provides VPS information and management options such as:

```text
╔════════════════════════════════════════════════════╗
║                VLEEE AI VPS AGENT                 ║
╠════════════════════════════════════════════════════╣
║ OS      : Ubuntu / Debian                          ║
║ CPU     : ...                                      ║
║ RAM     : ...                                      ║
║ DISK    : ...                                     ║
║ VPS IP  : ...                                     ║
║ MODEL   : GPT-5.6 Luna                             ║
╠════════════════════════════════════════════════════╣
║ 1) Change API Key                                  ║
║ 2) Test API Connection                             ║
║ 3) Start AI Terminal                               ║
║ 0) Exit                                            ║
╚════════════════════════════════════════════════════╝
```

---

## 🛠️ Example Tasks

```text
AI > check kenapa command menu tak function dan fix sendiri

AI > tengok script menu aku kosong atau tidak. cari backup kalau kosong.

AI > check kenapa xray service failed dan fix kalau config rosak

AI > check nginx error dan repair configuration yang rosak

AI > cari autoscript yang ada dalam VPS ini

AI > check semua error installation aku dan repair satu per satu

AI > check script ini betul-betul kosong atau masih ada isi
```

The important part is that the agent is designed to **inspect first**, not immediately guess.

---

## 💾 Automatic Backups

Before modifying an existing file, the agent creates a backup when practical:

```text
/root/.vleevps/backups/
```

This makes it possible to restore a previous version if a repair needs to be reversed.

---

## 🔐 Security

The agent runs with **root privileges** because VPS administration requires access to system files and services.

The API key is stored locally:

```text
/root/.openai_key
```

with:

```text
chmod 600
```

Do not share your API key with anyone.

Only install this software on a VPS you own or are authorized to administer.

The agent is instructed to avoid destructive operations such as:

```text
rm -rf /
disk formatting
unrelated data deletion
disabling security controls
```

---

## 📂 Important Files

```text
/usr/local/bin/ai
/root/.openai_key
/root/.vleevps/backups/
```

---

## 🔄 Reinstall / Update

Run the installer again:

```bash
curl -fsSL https://raw.githubusercontent.com/ejaywattapak/vleevps/main/install.sh | bash
```

The existing agent should be backed up before replacement.

---

## 💬 Support

Need an API key or support?

### 👉 [Contact @ejaywattapak on Telegram](https://t.me/ejaywattapak)

---

<div align="center">

**VLEEE AI VPS Agent**

Made for fast VPS troubleshooting, automation and repair.

⭐ Star the repository if you find it useful.

</div>
