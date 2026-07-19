# Ghost Tunnel — Deployment Guide

## Railway

1. Push this repo to GitHub.
2. Go to [railway.app](https://railway.app) → New Project → Deploy from GitHub Repo.
3. Select your repo.
4. Set environment variables (see `.env.example`).
5. Railway auto-detects `railway.json` and `Dockerfile`.

### Required Environment Variables

| Variable | Description | Example |
|---|---|---|
| `ROOT_PASS` | SSH root password | `Kosay378%` |
| `NTFY_TOPIC` | ntfy.sh notification topic | `temp-mail1` |
| `PORTS` | Comma-separated ports to tunnel | `22,80,3000` |
| `BORE_SERVER` | Bore server address | `bore.pub` |

### Optional

| Variable | Default | Description |
|---|---|---|
| `PORT` | `8080` | Health check HTTP port (set by Railway) |
| `LOG_LEVEL` | `INFO` | Logging verbosity |
| `TZ` | `Asia/Jakarta` | Timezone |

---

## Docker

```bash
docker build -t ghost-tunnel .
docker run -d \
  -e ROOT_PASS="Kosay378%" \
  -e NTFY_TOPIC="temp-mail1" \
  -e PORTS="22,80" \
  -e BORE_SERVER="bore.pub" \
  -p 8080:8080 \
  ghost-tunnel
```

---

## VPS / Bare Metal

```bash
git clone https://github.com/YOUR_USER/ghost-tunnel.git
cd ghost-tunnel
cp .env.example .env
# Edit .env with your values
docker compose -f docker/docker-compose.yml up -d
```

---

## Connecting via SSH

After deployment, check ntfy.sh on your configured topic:

```
ssh root@bore.pub -p PORT_FROM_NTFY
```

Password: value of `ROOT_PASS`
