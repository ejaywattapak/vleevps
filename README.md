# VLEE AI Agent

**VLEE AI Agent by EJAYWATTAPAK** — autonomous Linux VPS AI agent powered by **GPT-5.6 Luna** through VLEEE API.

It can inspect your VPS, read files/scripts, diagnose errors, run shell commands, repair configurations, install/configure software, and verify changes. The agent is designed to **do the work on the VPS**, not just tell you what commands to run.

## Update

### Ubuntu

```bash
curl -fsSL https://raw.githubusercontent.com/ejaywattapak/vleevps/main/installer.sh | bash
```

### Debian

```bash
curl -fsSL https://raw.githubusercontent.com/ejaywattapak/vleevps/main/installer.sh | bash
```

## Installation

One latest installer for supported Ubuntu/Debian systems:

```bash
curl -fsSL https://raw.githubusercontent.com/ejaywattapak/vleevps/main/installer.sh | bash
```

The installer asks for your VLEEE API key and performs a real GPT-5.6 Luna function test before finishing.

## Commands

### Start AI

```bash
ai
```

Example:

```text
AI > check spec vps aku

Thinking...
```

### Menu

```bash
ai-menu
```

Menu:

```text
1) Change API key
2) Check status
3) Exit
```

`Check status` performs a **real GPT-5.6 Luna chat request**. It does not report fake/assumed status.

## Requirements

- Ubuntu or Debian
- `root` access
- Internet connection
- VLEEE API key

The installer handles required dependencies and creates:

```text
/usr/local/bin/ai
/usr/local/bin/ai-menu
/root/.vlee_ai/api_key
```

## API Key

If you need a VLEEE API key, contact:

**Telegram:** [@ejaywattapak](https://t.me/ejaywattapak)

Please keep your API key private and do not publish it in GitHub repositories, screenshots, or public logs.

## Notes

GPT-5.6 Luna availability depends on VLEEE provider capacity. If VLEEE returns `402`, `503`, rate-limit, or provider-capacity errors, the agent will show the actual API error instead of claiming that the AI is working.

---

**VLEE AI AGENT BY EJAYWATTAPAK**
