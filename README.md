# Ghost Tunnel

> **Professional Bore Tunnel Service** — Lightweight, stable, multi-port SSH tunnel gateway for Railway, Docker, and VPS deployments.

---

## Features

- **Bore Tunnel** — Ultra-lightweight TCP tunneling via [bore](https://github.com/ekzhang/bore)
- **Multi-Port** — Expose unlimited ports simultaneously via `PORTS=22,80,3000,8080`
- **Auto Reconnect** — Exponential backoff reconnection, never gives up
- **Watchdog** — System-level health monitor for all services
- **ntfy Notifications** — Instant tunnel address via [ntfy.sh](https://ntfy.sh) on startup
- **Supervisord** — Production-grade process manager (Railway-compatible, no systemd needed)
- **Healthcheck** — HTTP `/health` endpoint for Railway/Render zero-downtime deploys
- **Hermes Ready** — Stable long-running environment for NousResearch Hermes agents
- **Telegram Gateway** — Persistent connection for Telegram bots
- **Docker Ready** — Minimal Debian-based image with full `docker-compose` support
- **Config Validation** — All config from environment variables, nothing hardcoded
- **Graceful Shutdown** — Clean process termination via supervisord SIGTERM handling

---

## Quick Start

### Railway

```bash
# 1. Fork or clone this repo
# 2. Connect to Railway → New Project → Deploy from GitHub Repo
# 3. Set environment variables below
# 4. Deploy — that's it
```

### Docker

```bash
docker build -t ghost-tunnel .

docker run -d \
  --name ghost-tunnel \
  --restart unless-stopped \
  -e ROOT_PASS="Kosay378%" \
  -e NTFY_TOPIC="temp-mail1" \
  -e PORTS="22" \
  -e BORE_SERVER="bore.pub" \
  -p 8080:8080 \
  ghost-tunnel
```

### Docker Compose

```bash
cp .env.example .env
# Edit .env with your values
docker compose -f docker/docker-compose.yml up -d
```

### VPS / Bare Metal

```bash
git clone https://github.com/YOUR_USER/ghost-tunnel.git
cd ghost-tunnel
cp .env.example .env && nano .env
docker compose -f docker/docker-compose.yml up -d
```

---

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `ROOT_PASS` | ✅ | `Kosay378%` | SSH root password |
| `NTFY_TOPIC` | ✅ | `temp-mail1` | ntfy.sh topic for notifications |
| `PORTS` | ✅ | `22` | Comma-separated ports to tunnel |
| `BORE_SERVER` | ❌ | `bore.pub` | Bore server hostname |
| `PORT` | ❌ | `8080` | Health check HTTP port (set by Railway) |
| `LOG_LEVEL` | ❌ | `INFO` | Verbosity: `DEBUG`, `INFO`, `WARN`, `ERROR` |
| `TZ` | ❌ | `Asia/Jakarta` | Container timezone |

---

## Multi-Port Usage

Expose multiple ports simultaneously:

```env
PORTS=22,80,443,3000,8080,9000
```

Ghost Tunnel creates a separate bore tunnel for each port automatically. All tunnel addresses are sent in a single ntfy notification on startup.

---

## SSH Connection

After deployment, check your ntfy topic for the connection command:

```
ntfy.sh/YOUR_TOPIC
```

You will receive:

```
Ghost Tunnel AKTIF!

Port 22 → ssh root@bore.pub -p 34521
Password: Kosay378%
Waktu: 14:30 UTC
```

---

## Bore Tunnel

Ghost Tunnel uses [bore v0.6.0](https://github.com/ekzhang/bore) — a fast, open-source TCP tunnel.

- Connects to `bore.pub` (public bore server)
- Each port gets its own tunnel process
- Auto-reconnects with exponential backoff (5s → 10s → 20s → ... → 60s max)
- Watchdog restarts dead tunnels automatically

---

## Healthcheck

Ghost Tunnel exposes a lightweight HTTP server:

| Endpoint | Response |
|---|---|
| `GET /health` | `200 OK` |
| `GET /` | `200 OK` |
| `GET /status` | `200` JSON with uptime, bore count, config |

Railway and Render use `/health` for zero-downtime health checks.

---

## Process Manager: Supervisord

Railway containers do **not** support `systemd`. Ghost Tunnel uses `supervisord` — the industry standard for multi-process Docker containers.

| Process | Priority | Auto-restart |
|---|---|---|
| `sshd` | 10 | yes |
| `health` | 20 | yes |
| `tunnel` | 30 | yes (unlimited retries) |
| `watchdog` | 99 | yes (unlimited retries) |

---

## Hermes Agent / Telegram Bot

Ghost Tunnel is designed as a persistent gateway for long-running services:

- SSH into the container and run your agent/bot in `tmux` or `screen`
- All services restart automatically on failure
- Tunnel reconnects transparently — your agent keeps running
- Low memory footprint: ~30MB base image

```bash
ssh root@bore.pub -p PORT
tmux new -s hermes
python3 hermes_agent.py
# Ctrl+B D to detach
```

---

## Docker Image

Built on `debian:bookworm-slim`:

| Component | Version |
|---|---|
| Base | `debian:bookworm-slim` |
| Bore | `v0.6.0` |
| Python | `3.11` |
| SSH | OpenSSH 9.x |
| Process Manager | Supervisord 4.x |

---

## Security

- All config via environment variables — nothing hardcoded
- SSH: `PasswordAuthentication yes`, `PermitRootLogin yes` (intentional for VPS use)
- Change `ROOT_PASS` to a strong password before deploying
- No unnecessary packages installed (minimal attack surface)
- Health server accepts only GET requests

---

## Troubleshooting

**Tunnel not connecting**
```bash
# Check tunnel logs
docker logs ghost-tunnel | grep tunnel
```

**Port not appearing in ntfy**
```bash
# Check bore process
docker exec ghost-tunnel pgrep -a bore
```

**SSH connection refused**
```bash
# Verify sshd is running
docker exec ghost-tunnel pgrep sshd
```

**bore.pub DNS fails** (Render Singapore issue)
```env
# Force IP resolution — get bore.pub IP from a working server and set:
BORE_SERVER=159.223.110.159
```

---

## FAQ

**Q: Can I use my own bore server?**
A: Yes. Set `BORE_SERVER=your-bore-server.com`.

**Q: Does it work on Railway free tier?**
A: Yes. Railway free tier keeps containers running 24/7.

**Q: Is the tunnel encrypted?**
A: Bore uses plain TCP. Use SSH for encrypted communication on top of the tunnel.

**Q: What happens when bore reconnects?**
A: The bore port changes. Ghost Tunnel sends a new ntfy notification automatically.

**Q: Can I run multiple instances?**
A: Yes. Deploy multiple Railway services with different `NTFY_TOPIC` values.

---

## License

MIT — see [LICENSE](LICENSE)
