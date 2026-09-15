# VLEEE AI VPS Agent

AI terminal assistant untuk membantu diagnose dan troubleshoot script, service dan configuration VPS menggunakan VLEEE API.

## Supported OS

- Ubuntu 22.04
- Ubuntu 24.04
- Debian 11
- Debian 12
- Debian 13

OS Debian/Ubuntu-based dengan `apt-get` juga mungkin berfungsi.

**Installer mesti dijalankan sebagai root.**

## Installation

Jika `curl` belum ada:

```bash
apt-get update && apt-get install -y curl ca-certificates
```

Kemudian:

```bash
curl -fsSL https://raw.githubusercontent.com/ejaywattapak/vleevps/main/install.sh | bash
```

### API key

Installer akan **berhenti di prompt API key dan menunggu input**.

Installer membaca input daripada `/dev/tty`, jadi walaupun command menggunakan:

```bash
curl ... | bash
```

input API key tidak akan hilang ke dalam pipe.

Contoh:

```text
◆ [2/6] VLEEE API key

➜ Masukkan VLEEE API key: YOUR_KEY_HERE
```

**Jika belum masukkan key, installer tidak akan meneruskan installation atau API test.**

## API

```text
API   : https://api.vleee.net/v1
MODEL : gpt-5.6-luna
```

Endpoint yang digunakan:

```text
https://api.vleee.net/v1/responses
```

## API Key

Key disimpan secara local:

```text
/root/.openai_key
```

Permission:

```text
600
```

Jangan upload API key ke GitHub.

### Nak beli API key

Telegram:

**@ejaywattapak**

## Usage

Selepas installation:

```bash
ai
```

Contoh:

```text
AI > aku tak boleh pakai command menu, tolong diagnose dan fix
```

## Installer Features

- Modern terminal installer UI
- Automatic dependency installation
- Safe interactive API-key input
- Works with `curl ... | bash`
- API key validation
- API key permission `600`
- Backup agent lama
- Syntax check
- VLEEE API connectivity test
- GPT-5.6 Luna
- Automatic cleanup jika API key invalid

## Security

Jangan masukkan ke repository:

- API key
- VPS password
- SSH private key
- Database credentials
- Secret tokens

Gunakan agent hanya pada VPS yang anda miliki atau mempunyai kebenaran untuk urus.

## Repository

https://github.com/ejaywattapak/vleevps
