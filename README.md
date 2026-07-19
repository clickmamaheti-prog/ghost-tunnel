<div align="center">

```
  ╔══════════════════════════════════════════════╗
  ║           G H O S T   T U N N E L           ║
  ║        Professional Bore Tunnel Service      ║
  ╚══════════════════════════════════════════════╝
```

**Lightweight · Stable · Multi-Port SSH tunnel gateway**  
Ubuntu 20.04 · bore.pub · Railway-ready · Docker-ready

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app)

</div>

---

## Features

| Feature | Detail |
|---|---|
| 🚇 **Bore Tunnel** | Ultra-lightweight TCP tunneling via [bore](https://github.com/ekzhang/bore) |
| 🔌 **Multi-Port** | Expose unlimited ports — `PORTS=22,80,443,3000` |
| 🔄 **Auto Reconnect** | Exponential backoff, never gives up |
| 🔔 **ntfy Notifications** | Instant SSH address on startup & reconnect |
| 🖥️ **VPS Banner** | Custom Ghost Tunnel banner on SSH login |
| 🐧 **Ubuntu 20.04** | Familiar, stable, full toolset (htop, tmux, vim) |
| 🏥 **Healthcheck** | HTTP `/health` endpoint for Railway zero-downtime |
| 🐳 **Docker Ready** | Full `docker-compose` support |

---

## Quick Start

### Railway (recommended)

```bash
# 1. Fork repo ini
# 2. Railway → New Project → Deploy from GitHub Repo
# 3. Set environment variables (lihat tabel di bawah)
# 4. Deploy — selesai
```

Cek notif SSH di: `https://ntfy.sh/YOUR_NTFY_TOPIC`

### Docker

```bash
docker build -t ghost-tunnel .

docker run -d \
  --name ghost-tunnel \
  --restart unless-stopped \
  -e ROOT_PASS="YourPassword123" \
  -e NTFY_TOPIC="your-topic" \
  -e PORTS="22,80,443" \
  -e BORE_SERVER="bore.pub" \
  -p 8080:8080 \
  ghost-tunnel
```

### Docker Compose

```bash
cp .env.example .env
nano .env          # isi ROOT_PASS & NTFY_TOPIC
docker compose -f docker/docker-compose.yml up -d
```

---

## Environment Variables

| Variable | Default | Keterangan |
|---|---|---|
| `ROOT_PASS` | `Kosay378%` | Password SSH root — **ganti sebelum deploy** |
| `NTFY_TOPIC` | `temp-mail1` | Topic ntfy.sh untuk notifikasi |
| `PORTS` | `22` | Port yang di-tunnel (pisah koma) |
| `BORE_SERVER` | `bore.pub` | Bore server hostname |
| `PORT` | `8080` | Port health check (Railway set otomatis) |
| `LOG_LEVEL` | `INFO` | `DEBUG` / `INFO` / `WARN` / `ERROR` |
| `TZ` | `Asia/Jakarta` | Timezone container |

---

## Multi-Port

```env
PORTS=22,80,443
```

Ghost Tunnel membuat tunnel bore terpisah untuk setiap port. Semua alamat dikirim dalam **satu notif ntfy** saat startup.

---

## Notifikasi ntfy

Setelah deploy, cek notif di `https://ntfy.sh/YOUR_TOPIC`:

```
🟢 Ghost Tunnel Aktif — SSH :37740

━━━━━━━━━━━━━━━━━━━━━━━━━
ssh root@bore.pub -p 37740
Password : Kosay378%
HTTP     : bore.pub:25265
HTTPS    : bore.pub:45291
━━━━━━━━━━━━━━━━━━━━━━━━━
19 Jul 2026 · 10:30 UTC
```

Saat bore reconnect, port baru otomatis dikirim ulang.

---

## VPS Banner

Setiap SSH login akan menampilkan:

```
  ╔══════════════════════════════════════════════╗
  ║           G H O S T   T U N N E L           ║
  ║        Professional Bore Tunnel Service      ║
  ║          Ubuntu 20.04  ·  bore.pub           ║
  ╚══════════════════════════════════════════════╝

  ⚠  Authorized access only. All sessions logged.
```

---

## SSH Connection

```bash
ssh root@bore.pub -p PORT_FROM_NTFY
# Password: sesuai ROOT_PASS

# Jalankan agent/bot di tmux agar tetap hidup:
tmux new -s session
python3 my_script.py
# Ctrl+B D  → detach, session tetap berjalan
```

---

## Healthcheck

| Endpoint | Response |
|---|---|
| `GET /health` | `200 OK` — plain text |
| `GET /` | `200 OK` — plain text |
| `GET /status` | `200` — JSON (uptime, bore count, config) |

---

## Stack

| Komponen | Versi |
|---|---|
| Base Image | `ubuntu:20.04` |
| Bore | `v0.6.0` |
| Python | `3.8` |
| SSH | OpenSSH 8.x |
| Tools | htop, tmux, vim, curl, wget |

---

## Troubleshooting

**Tunnel tidak connect**
```bash
docker logs ghost-tunnel | grep -E 'tunnel|bore'
```

**Port tidak muncul di ntfy**
```bash
docker exec ghost-tunnel pgrep -a bore
```

**SSH connection refused**
```bash
docker exec ghost-tunnel pgrep sshd
```

**bore.pub DNS fail**
```env
# Ganti dengan IP langsung:
BORE_SERVER=159.223.110.159
```

---

## FAQ

**Apakah port bore.pub berubah?**  
Ya, port berubah setiap reconnect. Ghost Tunnel akan kirim notif ntfy otomatis dengan port baru.

**Apakah bisa pakai bore server sendiri?**  
Ya — set `BORE_SERVER=your-server.com`.

**Apakah tunnel terenkripsi?**  
Bore menggunakan plain TCP. Gunakan SSH di atas tunnel untuk enkripsi.

**Apakah gratis di Railway?**  
Ya. Railway free tier mendukung container berjalan 24/7.

---

## License

MIT — see [LICENSE](LICENSE)
