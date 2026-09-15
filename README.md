# VLEEE AI VPS Agent

VLEEE AI VPS Agent is a root-level terminal AI agent for Linux VPS administration.

It uses the VLEEE API with **GPT-5.6 Luna** and can inspect, diagnose, modify, test and repair VPS scripts directly through the terminal.

## Features

- Root VPS auto-repair
- Execute Linux commands through AI tool calls
- Read and inspect VPS files
- Create and modify scripts
- Automatic syntax checking with `bash -n`
- Automatic command/service testing
- Timestamped backups before important script changes
- Command execution timeout to prevent accidental hangs
- Local execution log
- VLEEE API endpoint:
  `https://api.vleee.net/v1`
- Model:
  `gpt-5.6-luna`

## Installation

Run as root:

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install.sh | bash
```

The installer will ask:

```text
VLEEE API Key:
```

The key is stored locally at:

```text
/root/.openai_key
```

with permission `600`.

The installer then:

1. Installs required dependencies.
2. Saves the API key securely.
3. Backs up an existing `/usr/local/bin/ai`.
4. Installs the VLEEE AI Agent.
5. Runs a shell syntax check.
6. Tests the VLEEE API.

## Start

After installation:

```bash
ai
```

Example:

```text
AI > aku tak boleh pakai command "menu". tolong fix
```

The agent is designed to inspect the VPS itself instead of simply telling the user which commands to run.

For example, it can inspect:

```text
/usr/local/bin/menu
/usr/bin/menu
/usr/local/xraayvpn/bin/menu
/opt/ejvpn
```

It can then backup, repair, syntax-check and test the affected script.

## Example workflow

```text
AI > menu tak function. fix sampai boleh buka menu asal dan submenu.

[EXECUTE] type -a menu
[EXECUTE] readlink -f /usr/local/bin/menu
[EXECUTE] ls -lah /usr/local/xraayvpn/bin/menu
[EXECUTE] file /usr/local/xraayvpn/bin/menu
[EXECUTE] find ... backup ...
[EXECUTE] cp ... backup ...
[EXECUTE] chmod ...
[EXECUTE] bash -n ...
[EXECUTE] menu
```

If the first repair fails, the agent can continue the diagnosis using the command result.

## API Key

The key is never hard-coded into the repository.

During installation it is requested interactively and stored at:

```text
/root/.openai_key
```

The file is created with restrictive permissions:

```text
600
```

Do **not** put your API key inside `install.sh`, `README.md`, GitHub commits, issues or screenshots.

## Logs

Execution logs are stored at:

```text
/var/log/vleee-ai-agent.log
```

The log contains executed commands and their exit codes.

Secrets should not be intentionally printed or stored.

## Configuration

The agent uses:

```text
API:   https://api.vleee.net/v1/responses
Model: gpt-5.6-luna
```

The installed agent is:

```text
/usr/local/bin/ai
```

API key:

```text
/root/.openai_key
```

## Safety

This agent has **root access** and can modify the VPS.

Use it only on VPS systems you own or are authorized to administer.

The agent is instructed to:

- inspect before changing important files
- create backups before overwriting non-empty scripts
- syntax-check shell scripts
- test repairs
- avoid destructive disk operations
- avoid reboot/shutdown unless explicitly requested
- avoid exposing credentials and secrets

Root-level AI automation can still make mistakes. Review important changes before deploying to production.

## Uninstall

Remove the agent:

```bash
rm -f /usr/local/bin/ai
```

The API key can be removed with:

```bash
rm -f /root/.openai_key
```

Remove the log if desired:

```bash
rm -f /var/log/vleee-ai-agent.log
```

## License

Use and modify this project at your own risk.
