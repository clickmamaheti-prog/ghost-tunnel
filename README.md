<div align="center">

```
  ╔══════════════════════════════════════════════╗
  ║           G H O S T   T U N N E L           ║
  ║     Production · Supervisor · Ubuntu 24.04   ║
  ╚══════════════════════════════════════════════╝
```

**Production-ready bore.pub TCP tunnel — Supervisor · Ubuntu 24.04 LTS**

</div>

---

## Fitur

| Fitur | Detail |
|---|---|
| 🔧 **Supervisor PID 1** | Semua service dikelola Supervisor, bukan entrypoint script |
| 🚇 **bore Tunnel** | TCP tunnel ringan via [bore](https://github.com/ekzhang/bore) |
| 🔌 **Multi-Port** | Expose banyak port: `PORTS=22,80,443,3000` |
| 🔄 **Auto-Restart** | `autorestart=true` + `startretries=999` pada tunnel |
| 🔔 **ntfy Alerts** | Notifikasi SSH address saat startup & reconnect |
| 📋 **conf.d** | Tambah service baru tanpa menyentuh config utama |
| 📜 **Log Rotation** | Logrotate harian — 14 hari, compressed |
| 🏥 **Healthcheck** | Endpoint `/health` + `supervisorctl status` |
| 🐳 **Docker Best Practices** | Layer minimal, clean apt cache, WORKDIR rapi |

---

## Struktur Folder

```
ghost-tunnel/
├── Dockerfile                   # Image definition (Supervisor sebagai PID 1)
├── .env.example                 # Template environment variables
├── .gitignore
│
├── config/
│   ├── supervisord.conf         # Konfigurasi utama Supervisor
│   ├── sshd_banner.txt          # Banner SSH login
│   ├── conf.d/                  # Service definitions — satu file per service
│   │   ├── startup.conf         # Startup script (jalankan sekali, priority=5)
│   │   ├── sshd.conf            # SSH server
│   │   ├── cron.conf            # Cron daemon
│   │   ├── health.conf          # Health check HTTP server
│   │   └── tunnel.conf          # Ghost Tunnel (bore manager)
│   └── logrotate/
│       └── ghost-tunnel         # Logrotate config untuk semua log
│
├── scripts/
│   ├── startup.sh               # Inisialisasi satu kali (set password, SSH port)
│   ├── tunnel.sh                # Bore tunnel manager
│   ├── watchdog.sh              # Watchdog opsional
│   ├── health.py                # HTTP health server (:$PORT)
│   └── notify.sh                # Helper ntfy notification
│
└── docker/
    ├── docker-compose.yml       # Production compose
    └── docker-compose.dev.yml   # Development compose
```

---

## Quick Start

### 1. Clone & konfigurasi

```bash
git clone https://github.com/clickmamaheti-prog/ghost-tunnel
cd ghost-tunnel

cp .env.example .env
nano .env          # Ganti ROOT_PASS dan NTFY_TOPIC
```

### 2. Build image

```bash
docker build -t ghost-tunnel .
```

### 3. Jalankan container (production)

```bash
docker compose -f docker/docker-compose.yml up -d
```

Atau langsung tanpa compose:

```bash
docker run -d \
  --name ghost-tunnel \
  --restart unless-stopped \
  -e ROOT_PASS="YourStrongPassword!" \
  -e NTFY_TOPIC="your-topic" \
  -e PORTS="22" \
  -e BORE_SERVER="bore.pub" \
  -p 8080:8080 \
  ghost-tunnel
```

---

## Environment Variables

| Variable | Default | Keterangan |
|---|---|---|
| `ROOT_PASS` | `ChangeMe123!` | Password SSH root — **wajib diganti** |
| `NTFY_TOPIC` | `ghost-mail` | Topic ntfy.sh untuk notifikasi |
| `PORTS` | `22` | Port yang di-tunnel (pisah koma) |
| `BORE_SERVER` | `bore.pub` | Bore server hostname |
| `PORT` | `8080` | Port health check HTTP |
| `LOG_LEVEL` | `INFO` | `DEBUG` / `INFO` / `WARN` / `ERROR` |
| `TZ` | `Asia/Jakarta` | Timezone container |

---

## Cara melihat log Supervisor

### Log supervisord utama

```bash
docker exec ghost-tunnel tail -f /var/log/supervisor/supervisord.log
```

### Log per-service

```bash
# SSH server
docker exec ghost-tunnel tail -f /var/log/supervisor/sshd.log

# Ghost Tunnel (bore)
docker exec ghost-tunnel tail -f /var/log/supervisor/tunnel.log

# Health server
docker exec ghost-tunnel tail -f /var/log/supervisor/health.log

# Startup script
docker exec ghost-tunnel cat /var/log/supervisor/startup.log

# Semua log error
docker exec ghost-tunnel tail -f /var/log/supervisor/*-error.log
```

### Status semua service

```bash
docker exec ghost-tunnel supervisorctl status
```

---

## Cara menambah service baru di conf.d

1. Buat file `config/conf.d/myservice.conf`:

```ini
[program:myservice]
command=/usr/local/bin/myservice.sh
autostart=true
autorestart=true
startsecs=3
stopwaitsecs=10
startretries=5
priority=40
stdout_logfile=/var/log/supervisor/myservice.log
stdout_logfile_maxbytes=5MB
stdout_logfile_backups=3
stderr_logfile=/var/log/supervisor/myservice-error.log
stderr_logfile_maxbytes=5MB
stderr_logfile_backups=3
```

2. Rebuild image dan restart:

```bash
docker build -t ghost-tunnel .
docker compose -f docker/docker-compose.yml up -d
```

Atau jika container sudah berjalan, salin file dan reload Supervisor:

```bash
docker cp config/conf.d/myservice.conf ghost-tunnel:/etc/supervisor/conf.d/
docker exec ghost-tunnel supervisorctl reread
docker exec ghost-tunnel supervisorctl update
```

---

## Cara restart service melalui Supervisor

```bash
# Restart satu service
docker exec ghost-tunnel supervisorctl restart tunnel
docker exec ghost-tunnel supervisorctl restart sshd
docker exec ghost-tunnel supervisorctl restart health

# Stop / start service
docker exec ghost-tunnel supervisorctl stop tunnel
docker exec ghost-tunnel supervisorctl start tunnel

# Restart semua service
docker exec ghost-tunnel supervisorctl restart all

# Reload konfigurasi (setelah edit conf.d)
docker exec ghost-tunnel supervisorctl reread
docker exec ghost-tunnel supervisorctl update
```

---

## Cara masuk ke dalam container

```bash
# Shell interaktif
docker exec -it ghost-tunnel bash

# Langsung jalankan perintah
docker exec ghost-tunnel supervisorctl status
docker exec ghost-tunnel pgrep -a bore
```

---

## Cara debugging jika service gagal dijalankan

### 1. Cek status Supervisor

```bash
docker exec ghost-tunnel supervisorctl status
```

Output contoh:
```
cron          RUNNING   pid 42, uptime 0:05:10
health        RUNNING   pid 45, uptime 0:05:09
sshd          RUNNING   pid 38, uptime 0:05:11
startup       EXITED    May 01 12:00 AM
tunnel        RUNNING   pid 55, uptime 0:04:58
```

`startup` selalu `EXITED` karena memang didesain jalan sekali lalu selesai.

### 2. Baca log error service

```bash
docker exec ghost-tunnel cat /var/log/supervisor/<nama-service>-error.log
```

### 3. Cek log supervisord utama

```bash
docker exec ghost-tunnel tail -50 /var/log/supervisor/supervisord.log
```

### 4. Cek proses yang berjalan

```bash
docker exec ghost-tunnel ps aux
docker exec ghost-tunnel pgrep -a sshd
docker exec ghost-tunnel pgrep -a bore
```

### 5. Test health endpoint

```bash
curl http://localhost:8080/health
curl http://localhost:8080/status   # Detail lengkap + supervisor status
```

### 6. Tunnel tidak connect

```bash
# Cek bore processes
docker exec ghost-tunnel pgrep -a bore

# Lihat log tunnel
docker exec ghost-tunnel tail -f /var/log/supervisor/tunnel.log

# Ganti bore server jika DNS gagal
# Di .env: BORE_SERVER=159.223.110.159
```

### 7. SSH connection refused

```bash
docker exec ghost-tunnel pgrep -a sshd
docker exec ghost-tunnel cat /var/log/supervisor/sshd-error.log
docker exec ghost-tunnel supervisorctl restart sshd
```

---

## Menambah service baru di masa depan

Cukup buat file `*.conf` di `/etc/supervisor/conf.d/` mengikuti template di atas.
Tidak perlu mengubah `supervisord.conf` utama — directive `[include]` sudah mengambil semua file dari `conf.d/`.

---

## Multi-Port

```env
PORTS=22,80,443
```

Setiap port akan mendapat tunnel bore terpisah. Port pertama digunakan sebagai SSH port.

---

## Supervisor Priority Order

| Priority | Service | Keterangan |
|---|---|---|
| 5 | `startup` | Inisialisasi (jalan sekali) |
| 10 | `sshd` | SSH server |
| 20 | `cron` | Cron daemon |
| 25 | `health` | Health HTTP server |
| 30 | `tunnel` | Ghost Tunnel bore manager |

---

## Log Rotation

Semua log dirotasi otomatis oleh logrotate:
- **Frekuensi**: harian
- **Retensi**: 14 hari
- **Kompresi**: ya (gzip)
- **Lokasi**: `/var/log/supervisor/` dan `/var/log/ghost-tunnel/`

Jalankan manual (opsional):
```bash
docker exec ghost-tunnel logrotate -f /etc/logrotate.d/ghost-tunnel
```

---

## License

MIT — see [LICENSE](LICENSE)
