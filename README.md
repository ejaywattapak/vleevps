# VLEEE AI VPS Agent

VLEEE AI VPS Agent is a root-level terminal AI agent for Linux VPS administration.

It uses the VLEEE API and **GPT-5.6 Luna** to inspect, diagnose, modify, test and repair VPS scripts directly from the terminal.

The goal is simple:

> Tell the AI what is broken, and let the agent inspect and fix the VPS itself.

---

## Features

- AI-powered VPS troubleshooting and repair
- Runs with root privileges
- Executes Linux commands directly
- Inspects files, symlinks, services, logs and configurations
- Creates and modifies VPS scripts
- Creates backups before important changes
- Bash syntax checking
- Tests repaired commands and services
- Continues troubleshooting when the first fix fails
- Local execution logging
- API key stored locally with permission `600`
- VLEEE API: `https://api.vleee.net/v1`
- Model: `gpt-5.6-luna`

---

## Supported Operating Systems

The current installer uses `apt-get`, so the supported operating systems are Debian/Ubuntu based Linux distributions.

| Operating System | Status |
|---|---|
| Debian 12 (Bookworm) | ✅ Supported |
| Debian 13 (Trixie) | ✅ Supported |
| Ubuntu 22.04 LTS | ✅ Supported |
| Ubuntu 24.04 LTS | ✅ Supported |
| Ubuntu 26.04 LTS | ✅ Supported |
| Debian 11 | ⚠️ Not recommended |
| Ubuntu 20.04 | ⚠️ EOL / not recommended |
| Rocky Linux | ❌ Not supported by current installer |
| AlmaLinux | ❌ Not supported by current installer |
| CentOS Stream | ❌ Not supported by current installer |
| Fedora | ❌ Not supported by current installer |
| Alpine Linux | ❌ Not supported by current installer |

### Requirements

- 64-bit Linux VPS
- Root access
- `apt-get`
- Internet connection
- `bash`
- `curl`
- `jq`
- Outbound HTTPS access to `api.vleee.net`

The installer installs the required dependencies on supported Debian/Ubuntu systems.

---

## Installation

Run the installer as root:

```bash
curl -fsSL https://raw.githubusercontent.com/ejaywattapak/vleevps/main/install.sh | bash
```

During installation you will be asked to enter your VLEEE API key:

```text
VLEEE API Key:
```

The key is stored locally at:

```text
/root/.openai_key
```

with permission:

```text
600
```

The installer then:

1. Checks the operating system.
2. Installs required dependencies.
3. Requests the VLEEE API key.
4. Saves the API key securely.
5. Backs up an existing AI agent.
6. Installs the VLEEE AI Agent.
7. Checks the script syntax.
8. Tests the VLEEE API connection.

---

## Start the Agent

After installation:

```bash
ai
```

Example:

```text
AI > aku tak boleh pakai command "menu". tolong fix sampai boleh.
```

The agent is designed to inspect the VPS itself and perform the repair.

It should not simply ask the user to manually run diagnostic commands when it has the ability to execute those commands itself.

---

## Example: Fixing a Broken VPS Menu

For example, if:

```bash
menu
```

returns:

```text
/usr/local/bin/menu: line 2: /usr/local/xraayvpn/bin/menu: Success
```

you can tell the agent:

```text
AI > aku tak boleh pakai command "menu". tolong fix sampai boleh.
```

The agent can inspect:

```text
/usr/local/bin/menu
/usr/bin/menu
/usr/local/xraayvpn/bin/menu
/opt
/root
```

and search for valid backups or copies of the original menu.

A typical repair workflow:

```text
[EXECUTE] type -a menu
[EXECUTE] command -v menu
[EXECUTE] readlink -f /usr/local/bin/menu
[EXECUTE] ls -lah /usr/local/bin/menu /usr/bin/menu
[EXECUTE] ls -lah /usr/local/xraayvpn/bin/menu
[EXECUTE] file /usr/local/xraayvpn/bin/menu
[EXECUTE] find backup copies
[EXECUTE] backup current files
[EXECUTE] restore valid menu
[EXECUTE] chmod 755
[EXECUTE] bash -n
[EXECUTE] test menu
```

If the first repair fails, the agent should continue diagnosing instead of stopping immediately.

When a valid original menu or backup exists, the agent should prefer restoring it rather than replacing the original VPS menu with an unrelated minimal menu.

---

## Agent Workflow

The agent is instructed to follow this workflow:

```text
1. Understand the request
2. Inspect the VPS
3. Identify the root cause
4. Create a backup
5. Apply the smallest correct fix
6. Syntax-check the change
7. Test the result
8. Continue fixing if the test fails
9. Verify the final result
10. Report completion
```

This is especially useful for VPS scripts where the problem may involve several files, symlinks, permissions, services or dependencies.

---

## API Configuration

The agent uses:

```text
API Base:
https://api.vleee.net/v1

Responses API:
https://api.vleee.net/v1/responses

Model:
gpt-5.6-luna
```

The API key is not hard-coded into the repository.

During installation it is requested interactively and saved to:

```text
/root/.openai_key
```

Do not commit your API key to GitHub.

Never put API keys in:

- `install.sh`
- `README.md`
- Git commits
- GitHub Issues
- screenshots
- public configuration files

---

## Installed Files

Main agent:

```text
/usr/local/bin/ai
```

API key:

```text
/root/.openai_key
```

Execution log:

```text
/var/log/vleee-ai-agent.log
```

Existing AI installations are backed up with a timestamp before replacement.

Example:

```text
/usr/local/bin/ai.backup.20260915-123456
```

---

## Logs

Execution information is written to:

```text
/var/log/vleee-ai-agent.log
```

The log can be used to review commands executed by the agent and their exit codes.

The agent is instructed not to intentionally expose:

- API keys
- passwords
- private keys
- cookies
- tokens
- other credentials

---

## Change API Key

To replace the API key without reinstalling:

```bash
read -r -s -p "VLEEE API Key: " KEY
echo
printf '%s\n' "$KEY" > /root/.openai_key
chmod 600 /root/.openai_key
unset KEY
```

Then:

```bash
ai
```

---

## Manual API Test

You can test the VLEEE API directly:

```bash
curl -sS https://api.vleee.net/v1/responses \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(cat /root/.openai_key)" \
  -d '{"model":"gpt-5.6-luna","input":"Reply exactly: VLEEE AI OK"}' | jq .
```

A successful response should contain a response object and the configured model.

---

## Security

This is a **root-level autonomous VPS agent**.

The agent can modify:

- system files
- VPS scripts
- services
- configurations
- permissions

Only use it on VPS systems that you own or are authorized to administer.

The agent is instructed to:

- inspect before changing important files
- create backups before overwriting non-empty scripts
- syntax-check shell scripts
- test changes after repairing them
- avoid destructive disk operations
- avoid unrelated data deletion
- avoid rebooting or shutting down unless explicitly requested
- avoid exposing credentials
- prefer targeted repairs instead of blindly reinstalling components

Root-level automation can still make mistakes. Review important production changes when appropriate.

---

## Uninstall

Remove the agent:

```bash
rm -f /usr/local/bin/ai
```

Remove the API key:

```bash
rm -f /root/.openai_key
```

Remove the log:

```bash
rm -f /var/log/vleee-ai-agent.log
```

---

## Repository

GitHub:

https://github.com/ejaywattapak/vleevps

Installer:

https://raw.githubusercontent.com/ejaywattapak/vleevps/main/install.sh

---

## License

Use and modify this project at your own risk.
