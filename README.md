<div align="center">

# 🤖 VLEEE AI VPS Agent

### Autonomous AI-powered VPS troubleshooting & repair

<img src="https://raw.githubusercontent.com/ejaywattapak/vleevps/main/assets/banner.svg" alt="VLEEE AI VPS Agent" width="900">

<p>
  <a href="https://t.me/ejaywattapak">💬 Get API Key / Telegram</a>
  ·
  <a href="https://github.com/ejaywattapak/vleevps">⭐ GitHub Repository</a>
</p>

</div>

---

## 🚀 What is VLEEE AI VPS Agent?

**VLEEE AI VPS Agent** is not just a chatbot.

It is an **autonomous VPS troubleshooting agent** that can inspect the VPS, run commands, read scripts/configurations, diagnose errors, make repairs, and verify the result.

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

You do **not** need to copy/paste every command output back to the AI.

---

## ✨ Features

- 🤖 Autonomous troubleshooting loop
- 🖥️ Real VPS command execution
- 🔎 Inspect files, scripts, services and configuration
- 🛠️ Repair scripts automatically
- 💾 Automatic backup before file modifications
- 🧪 Syntax/configuration verification
- 🔄 Service restart/reload when required
- 📦 Install required Debian/Ubuntu packages
- 🔐 API key stored with permission `600`
- 🎨 Modern terminal UI
- ⚡ Powered by **GPT-5.6 Luna**
- 🌐 VLEEE API

---

## 💻 Supported OS

Officially supported:

| OS | Status |
|---|---|
| Ubuntu 22.04 | ✅ |
| Ubuntu 24.04 | ✅ |
| Debian 11 | ✅ |
| Debian 12 | ✅ |
| Debian 13 | ✅ |

The installer requires `apt-get` and should be run as `root`.

---

## 📥 Installation

If `curl` is not installed:

```bash
apt-get update && apt-get install -y curl ca-certificates
```

Then install:

```bash
curl -fsSL https://raw.githubusercontent.com/ejaywattapak/vleevps/main/install.sh | bash
```

The installer will stop and wait for your API key:

```text
◆ [2/6] API key

➜ Masukkan VLEEE API key:
```

The installer reads the key directly from `/dev/tty`, so it works correctly even when using:

```bash
curl ... | bash
```

It will **not continue with an empty key**.

---

## 🔑 API Key

API:

```text
https://api.vleee.net/v1
```

Model:

```text
gpt-5.6-luna
```

The key is stored locally at:

```text
/root/.openai_key
```

with:

```text
chmod 600
```

### 🛒 Need an API key?

Contact directly on Telegram:

👉 **[@ejaywattapak](https://t.me/ejaywattapak)**

---

## 🧠 How the Agent Works

```text
┌──────────────────────┐
│      USER REQUEST    │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│    VLEEE AI / Luna   │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│   CHOOSE NEXT ACTION │
└──────────┬───────────┘
           ↓
     ┌─────┴─────┐
     ↓           ↓
  execute    write_file
     │           │
     └─────┬─────┘
           ↓
┌──────────────────────┐
│   VPS RETURNS OUTPUT │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│ AI ANALYSES & REPEATS│
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│  VERIFY → FINISH     │
└──────────────────────┘
```

The agent can perform multiple diagnostic/repair steps in one request.

---

## 🛠️ Usage

Start the agent:

```bash
ai
```

Example:

```text
AI > check kenapa command menu tak function dan fix sendiri
```

Other examples:

```text
AI > check kenapa xray service failed dan fix kalau config yang rosak

AI > tengok script menu aku kosong atau tidak. cari backup kalau kosong.

AI > check nginx error dan fix configuration yang menyebabkan service gagal start

AI > check semua error installation aku dan repair satu per satu
```

The agent will inspect the VPS itself instead of asking you to paste files.

---

## 🛡️ Safety

The agent runs with **root privileges** because VPS administration requires access to system files and services.

Before modifying an existing file, the agent creates a backup under:

```text
/root/.vleevps/backups/
```

The agent is instructed to avoid destructive operations such as:

```text
rm -rf /
disk formatting
unrelated data deletion
disabling security controls
```

Only run this software on VPS infrastructure you own or are authorized to administer.

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

The existing agent is backed up before replacement.

---

## 💬 Support / API Key

Need a VLEEE API key?

### 👉 [Contact @ejaywattapak on Telegram](https://t.me/ejaywattapak)

---

<div align="center">

**VLEEE AI VPS Agent**

Made for fast VPS troubleshooting, automation and repair.

⭐ Star the repository if you find it useful.

</div>
