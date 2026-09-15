# VLEEE AI VPS Agent

VLEEE AI VPS Agent ialah AI terminal untuk membantu mendiagnosis dan membaiki script/service pada VPS menggunakan VLEEE API.

## Requirements

### Supported OS

- Ubuntu 22.04 / 24.04
- Debian 11 / 12 / 13
- Linux distributions berasaskan Debian/Ubuntu yang menyediakan `apt-get`

Installer memerlukan akses **root**.

## Installation

Jika VPS belum mempunyai `curl`, install dahulu:

```bash
apt-get update && apt-get install -y curl ca-certificates
```

Kemudian jalankan installer:

```bash
curl -fsSL https://raw.githubusercontent.com/ejaywattapak/vleevps/main/install.sh | bash
```

Installer akan:

1. Check/install `curl` dan `jq`
2. Minta **VLEEE API key**
3. Simpan key ke `/root/.openai_key`
4. Set permission key kepada `600`
5. Backup `/usr/local/bin/ai` jika sudah ada
6. Install command `ai`
7. Test API
8. Jika API key invalid, installation dihentikan dan key yang invalid dipadam

### API

```text
API: https://api.vleee.net/v1
Model: gpt-5.6-luna
```

## Usage

Selepas installation:

```bash
ai
```

Contoh:

```text
AI > tengok kenapa command menu tak function
```

Agent boleh digunakan untuk membantu menganalisis output, script, service, permission, config dan masalah VPS.

## API Key

API key diperlukan untuk menggunakan agent.

**Nak beli API key VLEEE:** Telegram `@ejaywattapak`

Jangan upload atau commit API key ke GitHub.

Key disimpan secara lokal:

```text
/root/.openai_key
```

Permission:

```text
600
```

## Security

Jangan kongsi:

- API key
- Password VPS
- Private SSH key
- Token
- Credential database

Gunakan agent hanya pada VPS yang anda miliki atau mempunyai kebenaran untuk anda urus.

## Repository

GitHub:

`https://github.com/ejaywattapak/vleevps`
