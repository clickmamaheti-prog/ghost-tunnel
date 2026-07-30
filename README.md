# 🚇 Ghost Tunnel

**Production-ready free VPS on Railway** — Ubuntu 24.04 + SSH via bore.pub + ntfy notifications.

Deploy container ini ke Railway gratis. Setiap kali aktif, kamu dapat notifikasi ke HP dengan port SSH terbaru lewat [ntfy.sh](https://ntfy.sh).

---

## ✨ Fitur

- 🐧 Ubuntu 24.04 LTS dengan tools lengkap (Python3, Node.js, Go, Git, Tmux, Screen, Vim, dll)
- 🔐 SSH root login via bore.pub tunnel (port otomatis, berubah tiap restart)
- 📲 Notifikasi ntfy otomatis saat tunnel aktif / reconnect / crash
- 🔄 Supervisor auto-restart semua service
- 🩺 Health check endpoint (`/health`)
- ⚡ Multi-port bore tunnel support

---

## 🚀 Deploy ke Railway

### 1. Fork / clone repo ini

```bash
git clone https://github.com/clickmamaheti-prog/ghost-tunnel.git
cd ghost-tunnel
```

### 2. Deploy ke Railway

**Via Dashboard Railway:**
1. Buka [railway.app](https://railway.app) → New Project → Deploy from GitHub repo
2. Pilih repo ini
3. Railway otomatis detect `railway.json` dan `Dockerfile`

**Via GHCR (Docker image siap pakai):**
1. New Project → Empty Project → Add Service → Docker Image
2. Masukkan: `ghcr.io/clickmamaheti-prog/ghost-tunnel:latest`

### 3. Set Environment Variables

Di Railway → Service → Variables, set:

| Variable | Wajib | Default | Keterangan |
|----------|-------|---------|------------|
| `ROOT_PASS` | ✅ | `ChangeMe123!` | Password SSH root — **WAJIB DIGANTI** |
| `NTFY_TOPIC` | ✅ | `ghost-mail` | Topic ntfy.sh untuk notifikasi |
| `PORTS` | ✅ | `22` | Port yang di-tunnel. Multi: `22,80,3000` |
| `BORE_SERVER` | ❌ | `bore.pub` | Bore server (gunakan bore.pub default) |
| `TZ` | ❌ | `Asia/Jakarta` | Timezone container |
| `LOG_LEVEL` | ❌ | `INFO` | Level log: `DEBUG`, `INFO`, `WARN`, `ERROR` |
| `WATCH_INTERVAL` | ❌ | `60` | Interval watchdog dalam detik |

### 4. Subscribe ntfy di HP

1. Install app **ntfy** di HP (Android/iOS)
2. Subscribe ke topic yang kamu set di `NTFY_TOPIC`
3. URL: `https://ntfy.sh/<NTFY_TOPIC>`

Setiap kali container restart, kamu dapat notif berisi port SSH terbaru.

---

## 📲 Format Notifikasi

### Saat Tunnel Aktif
```
🚇 Ghost Tunnel UP
Ghost Tunnel active on ghost-tunnel

Tunnels:
  SSH / local :22 → bore.pub:XXXXX

Server: bore.pub
Ports: 22
```

### Saat Reconnect (bore terputus)
```
🔄 Ghost Tunnel Reconnected
Port 22 reconnected on ghost-tunnel
New remote: bore.pub:YYYYY
```

### Watchdog Alert
```
⚠️ Ghost Tunnel: sshd down
sshd not found. Supervisor will restart.
```

---

## 🔐 SSH Login

Port bore berubah setiap Railway restart — selalu cek ntfy untuk port terbaru.

```bash
ssh root@bore.pub -p <PORT_DARI_NTFY>
```

### Tips SSH
```bash
# Tambah ke ~/.ssh/config untuk mudah akses
Host ghost
    HostName bore.pub
    Port <PORT_DARI_NTFY>
    User root
```

---

## 🔧 Multi-Port Tunnel

Set `PORTS=22,80,3000` untuk expose beberapa port sekaligus:

```
PORTS=22,80,3000,8080
```

Notifikasi akan berisi semua port yang aktif:
```
Tunnels:
  SSH / local :22  → bore.pub:AAAA
  local :80        → bore.pub:BBBB
  local :3000      → bore.pub:CCCC
```

---

## 🛠️ Struktur Repo

```
ghost-tunnel/
├── Dockerfile                    # Ubuntu 24.04 + bore + SSH + Supervisor
├── railway.json                  # Railway deploy config
├── .env.example                  # Contoh env vars
├── config/
│   ├── supervisord.conf          # Supervisor main config
│   ├── conf.d/
│   │   ├── sshd.conf             # SSH service
│   │   ├── tunnel.conf           # Bore tunnel service
│   │   ├── health.conf           # Health check service
│   │   ├── cron.conf             # Cron service
│   │   └── startup.conf          # Startup script (oneshot)
│   ├── sshd_banner.txt           # SSH login banner
│   └── logrotate/ghost-tunnel    # Log rotation config
└── scripts/
    ├── startup.sh                # Init: set root pass, SSH port, etc.
    ├── tunnel.sh                 # Bore tunnel manager + ntfy notifications
    ├── watchdog.sh               # Optional watchdog (checks sshd + bore)
    ├── notify.sh                 # ntfy helper script
    └── health.py                 # HTTP health endpoint (:8080)
```

---

## 🐛 Troubleshooting

### ntfy tidak menerima notifikasi

1. **Cek topic sudah benar** — pastikan `NTFY_TOPIC` di Railway sama dengan yang di-subscribe di app ntfy
2. **Railway IP rate-limit** — ntfy.sh mungkin rate-limit IP Railway. Script sudah pakai `--retry 5` untuk handle ini. Cek log Railway untuk status pengiriman.
3. **Test manual dari terminal:**
   ```bash
   curl -d "Test notif" "https://ntfy.sh/<NTFY_TOPIC>"
   ```
4. **Log di Railway** — cari baris `[tunnel] ntfy sent` atau `[tunnel] ntfy failed`

### SSH "Connection refused" atau "Connection closed"

1. **Cek port terbaru** — port berubah setiap restart, cek ntfy atau Railway logs
2. **Cari port di Railway logs:**
   ```
   Tunnel ready: local :22 → bore.pub:XXXXX
   ```
3. **Pastikan `ROOT_PASS` sudah di-set** di Railway variables

### Container restart terus-menerus

1. Cek Railway logs untuk error di startup
2. Pastikan semua env vars wajib sudah di-set (`ROOT_PASS`, `NTFY_TOPIC`, `PORTS`)
3. Health check timeout: container butuh ~30 detik untuk fully start

---

## 📋 Changelog

### v3.2 — ntfy Fix untuk Railway Container
- **Fix:** `ntfy_send` di semua script kini pakai `--retry 5 --retry-delay 3 --retry-all-errors`
- **Fix:** Hapus pendekatan tmpfile, ganti ke direct `-d body` (lebih reliable di container)
- **Fix:** Tambah header `Content-Type: text/plain` yang konsisten
- **Fix:** watchdog.sh ntfy_send diupdate dengan retry yang sama

### v3.1 — Real Port Parsing
- Fix: Capture bore stdout ke log file untuk parse port asli
- Notifikasi kini berisi port bore yang benar (bukan `???`)

### v3.0 — Production Release
- Supervisor sebagai PID 1 (bukan bash entrypoint)
- Multi-port bore tunnel support
- Health check endpoint
- Watchdog optional

---

## 📄 License

MIT
