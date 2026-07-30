# 🖥️ Ghost Tunnel

**Free VPS di Railway** — Ubuntu 24.04 + SSH via bore.pub + notifikasi ntfy ke HP.

Deploy container ini ke Railway (akun siapapun). Setiap kali aktif atau reconnect, kamu dapat notifikasi ke HP dengan port SSH terbaru.

---

## ✨ Fitur

- 🐧 Ubuntu 24.04 LTS — Python3, Node.js, Go, Git, Tmux, Screen, Vim, dan lainnya
- 🔐 SSH root login via bore.pub tunnel (port otomatis, bisa berubah tiap restart)
- 📲 Notifikasi ntfy otomatis saat tunnel aktif / reconnect / down
- 🔄 Supervisor manage semua service — auto-restart kalau crash
- 🩺 Health check endpoint (`/health`) untuk Railway
- ⚡ Multi-port bore tunnel support

---

## 🚀 Setup dari Nol (akun Railway baru)

### Langkah 1 — Fork repo ini

Klik tombol **Fork** di GitHub. Repo akan muncul di akun kamu sendiri, misalnya:
`https://github.com/<username-kamu>/ghost-tunnel`

### Langkah 2 — Buat Railway project

1. Buka [railway.app](https://railway.app) → login / daftar
2. Klik **New Project** → **Deploy from GitHub repo**
3. Authorize Railway ke GitHub, pilih repo fork kamu
4. Railway otomatis detect `Dockerfile` dan `railway.json`, lalu mulai build

> **Alternatif — pakai Docker image langsung (tanpa fork):**
> New Project → Empty Project → Add Service → Docker Image
> Masukkan: `ghcr.io/clickmamaheti-prog/ghost-tunnel:latest`
> *(Pilihan ini tidak dapat notifikasi otomatis dari GitHub Actions)*

### Langkah 3 — Set Environment Variables di Railway

Buka Railway → project kamu → service → tab **Variables**, lalu tambahkan:

| Variable | Wajib | Contoh nilai | Keterangan |
|----------|:-----:|-------------|------------|
| `ROOT_PASS` | ✅ | `RahasiaKuat99!` | Password SSH root — **wajib diganti** |
| `NTFY_TOPIC` | ✅ | `nama-topic-unik-kamu` | Topic ntfy.sh untuk notifikasi |
| `PORTS` | ✅ | `22` | Port yang di-tunnel. Multi: `22,3000,8080` |
| `BORE_SERVER` | ❌ | `bore.pub` | Bore server (default sudah OK) |
| `TZ` | ❌ | `Asia/Jakarta` | Timezone container |
| `LOG_LEVEL` | ❌ | `INFO` | `DEBUG` / `INFO` / `WARN` / `ERROR` |
| `WATCH_INTERVAL` | ❌ | `60` | Interval watchdog (detik) |

Setelah simpan variables, Railway akan redeploy otomatis.

### Langkah 4 — Install ntfy di HP

1. Install app **ntfy** — [Android](https://play.google.com/store/apps/details?id=io.heckel.ntfy) / [iOS](https://apps.apple.com/app/ntfy/id1625396347)
2. Buka app → **+** → masukkan topic yang kamu set di `NTFY_TOPIC`
3. Atau subscribe lewat browser: `https://ntfy.sh/<NTFY_TOPIC>`

Setiap Railway restart atau bore reconnect, notifikasi masuk otomatis.

---

## 📲 Format Notifikasi

### Tunnel aktif / reconnect

```
Title: 🖥️ c2026 Gost tunnel linux

🖥️ c2026 Gost tunnel linux

━━━━━━━━━━━━━━━━━━━━━━
🟢 VPS Status : ONLINE
⏱️ Uptime     : up 2 days, 4 hours

🌐 Host       : bore.pub
🔐 SSH        : ssh root@bore.pub -p 52341
👤 User       : root
🔑 Password   : RahasiaKuat99!

━━━━━━━━━━━━━━━━━━━━━━
```

### Reconnect setelah terputus

```
🔄 VPS Status : RECONNECTED  (port baru tercantum)
```

### Watchdog alert (sshd/bore down)

```
⚠️ VPS Status : sshd DOWN  (Supervisor akan restart)
⚠️ VPS Status : TUNNEL DOWN
```

---

## 🔐 Cara SSH

Port berubah tiap Railway restart — selalu cek ntfy untuk port terbaru.

```bash
ssh root@bore.pub -p <PORT_DARI_NTFY>
```

### Shortcut SSH (opsional)

Tambah ke `~/.ssh/config`:

```
Host ghost
    HostName bore.pub
    Port 52341
    User root
```

Lalu cukup ketik `ssh ghost` (update `Port` setiap dapat notif port baru).

---

## ⚙️ Setup GitHub Actions (opsional — untuk auto-deploy + notifikasi deploy)

Kalau kamu fork repo ini dan mau GitHub Actions jalan otomatis (build Docker image + notif ntfy setelah deploy):

### 1. Dapat Railway tokens

Buka Railway → **Account Settings** → **Tokens** → buat token baru.

Lalu cari ID-ID berikut:
- **Project ID**: Railway → project kamu → Settings → lihat URL atau field Project ID
- **Service ID**: Railway → project → service → Settings → Service ID
- **Environment ID**: Railway → project → Environments → klik environment → lihat URL

### 2. Set GitHub Secrets di repo fork

Buka GitHub repo fork kamu → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**:

| Secret | Nilai |
|--------|-------|
| `RAILWAY_TOKEN` | Token Railway yang kamu buat |
| `RAILWAY_PROJECT_ID` | Project ID dari Railway |
| `RAILWAY_SERVICE_ID` | Service ID dari Railway |
| `RAILWAY_ENVIRONMENT_ID` | Environment ID dari Railway |
| `NTFY_TOPIC` | Topic ntfy yang sama dengan env Railway |
| `ROOT_PASS` | Password SSH yang sama dengan env Railway |

### 3. Aktifkan GitHub Actions

Push apapun ke branch `main`, atau buka tab **Actions** → klik workflow → **Run workflow**.

GitHub Actions akan:
1. Build Docker image baru dari Dockerfile
2. Push ke GHCR (`ghcr.io/<username>/ghost-tunnel:latest`)
3. Trigger Railway redeploy
4. Kirim notifikasi ntfy setelah deploy berhasil

> **Tanpa GitHub Secrets:** Railway tetap jalan normal, hanya saja tidak ada notifikasi dari GitHub Actions. Notifikasi dari dalam container (tunnel.sh) tetap berfungsi.

---

## 🔧 Multi-Port Tunnel

Set `PORTS` dengan beberapa port dipisah koma:

```
PORTS=22,3000,8080
```

Semua port akan di-tunnel. Port pertama (22) = port SSH.

---

## 🏗️ Struktur Repo

```
ghost-tunnel/
├── Dockerfile                      # Ubuntu 24.04 + bore + SSH + Supervisor
├── railway.json                    # Railway deploy config
├── .env.example                    # Contoh semua env variables
├── config/
│   ├── supervisord.conf            # Supervisor main config (PID 1)
│   ├── conf.d/
│   │   ├── startup.conf            # Jalankan startup.sh sekali saat boot
│   │   ├── sshd.conf               # SSH daemon
│   │   ├── tunnel.conf             # Bore tunnel manager
│   │   ├── health.conf             # HTTP health check server
│   │   └── cron.conf               # Cron daemon
│   ├── sshd_banner.txt             # Banner saat SSH login
│   └── logrotate/ghost-tunnel      # Konfigurasi log rotation
└── scripts/
    ├── startup.sh                  # Init: set password, SSH port, buat env file
    ├── tunnel.sh                   # Bore tunnel manager + ntfy notification
    ├── watchdog.sh                 # Opsional: monitor tambahan + alert ntfy
    ├── health.py                   # HTTP server /health dan /status
    └── notify.sh                   # Helper: kirim notifikasi ntfy manual
```

---

## 🩺 Health Check

Railway memakai endpoint `/health` untuk mengecek container sehat:

```bash
curl https://<railway-domain>/health
```

Response:
```json
{
  "status": "ok",
  "uptime_seconds": 3600,
  "services": {
    "sshd": "RUNNING",
    "tunnel": "RUNNING"
  }
}
```

---

## 🔍 Troubleshooting

### Tidak ada notifikasi ntfy

1. Pastikan `NTFY_TOPIC` di Railway Variables sama persis dengan yang di-subscribe di app ntfy
2. Test manual via SSH:
   ```bash
   curl -d "Test" "https://ntfy.sh/<NTFY_TOPIC>"
   ```
3. Cek Railway logs — cari baris `[tunnel] ntfy sent` atau `[tunnel] ntfy failed`

### SSH "Connection refused"

1. Port bore **berubah setiap restart** — cek ntfy atau Railway logs untuk port terbaru
2. Cari di Railway logs:
   ```
   Tunnel ready: local :22 → bore.pub:XXXXX
   ```

### Container restart terus

1. Cek Railway logs untuk error saat startup
2. Pastikan `ROOT_PASS`, `NTFY_TOPIC`, dan `PORTS` sudah di-set di Variables
3. Health check butuh ~30 detik saat container baru start — tunggu sebentar

### GitHub Actions gagal di step "Trigger Railway"

Pastikan semua 4 secrets Railway sudah di-set dengan benar (`RAILWAY_TOKEN`, `RAILWAY_PROJECT_ID`, `RAILWAY_SERVICE_ID`, `RAILWAY_ENVIRONMENT_ID`). Kalau hanya satu yang salah, step akan dilanjutkan (`continue-on-error: true`) dan tidak crash.

---

## 📋 Changelog

### v3.3 — Format Notifikasi Baru
- **Update:** Format notifikasi ntfy diubah ke status card terstruktur dengan separator dan emoji
- **Fix:** GitHub Actions `deploy-and-notify` job tidak lagi crash jika Railway API gagal (`continue-on-error: true`)
- **Fix:** Notifikasi GitHub Actions ikut format baru

### v3.2 — Fix ntfy di Railway Container
- **Fix:** `ntfy_send` di semua script kini pakai `--retry 5 --retry-delay 3 --retry-all-errors`
- **Fix:** Ganti tmpfile ke direct `-d body` (lebih reliable di container)
- **Fix:** Tambah header `Content-Type: text/plain` yang konsisten

### v3.1 — Real Port Parsing
- Fix: Capture bore stdout ke log file untuk parse port asli
- Notifikasi kini berisi port bore yang benar (bukan `???`)

### v3.0 — Production Release
- Supervisor sebagai PID 1 (bukan bash entrypoint)
- Multi-port bore tunnel support
- Health check endpoint

---

## 📄 License

MIT
