# 🖥️ Ghost Tunnel

**Free VPS di Railway** — Ubuntu 24.04 + SSH via bore.pub + notifikasi ntfy ke HP.

Setiap kali aktif atau reconnect, kamu dapat notifikasi ke HP dengan port SSH terbaru.

---

## ⚡ Quick Deploy — Tanpa Fork, Tanpa Clone

> Cara paling cepat — langsung deploy image siap pakai, tidak perlu menyentuh kode sama sekali.

### 1. Buka Railway

Buka [railway.app](https://railway.app) → login → **New Project** → **Empty Project** → **Add Service** → **Docker Image**

Masukkan image:
```
ghcr.io/clickmamaheti-prog/ghost-tunnel:latest
```

### 2. Set Variables

Railway → service kamu → tab **Variables**, tambahkan:

| Variable | Wajib | Contoh | Keterangan |
|----------|:-----:|--------|------------|
| `ROOT_PASS` | ✅ | `RahasiaKuat99!` | Password SSH root — **wajib diganti** |
| `NTFY_TOPIC` | ✅ | `nama-topic-unik-ku` | Topic ntfy.sh untuk notifikasi |
| `PORTS` | ✅ | `22` | Port yang di-tunnel (default SSH) |
| `BORE_SERVER` | ❌ | `bore.pub` | Bore server (default sudah OK) |
| `TZ` | ❌ | `Asia/Jakarta` | Timezone container |

### 3. Install ntfy di HP

1. Install app **ntfy** — [Android](https://play.google.com/store/apps/details?id=io.heckel.ntfy) / [iOS](https://apps.apple.com/app/ntfy/id1625396347)
2. Subscribe ke topic yang kamu set di `NTFY_TOPIC`

### 4. SSH

Setelah Railway selesai deploy, notifikasi masuk ke HP:

```
🖥️ c2026 Gost tunnel linux

━━━━━━━━━━━━━━━━━━━━━━
🟢 VPS Status : ONLINE
⏱️ Uptime     : up X minutes

🌐 Host       : bore.pub
🔐 SSH        : ssh root@bore.pub -p 52341
👤 User       : root
🔑 Password   : RahasiaKuat99!

━━━━━━━━━━━━━━━━━━━━━━
```

```bash
ssh root@bore.pub -p <PORT_DARI_NOTIF>
```

**Selesai.** Tidak perlu fork, tidak perlu setup GitHub Actions.

---

## 🍴 Deploy dengan Fork (opsional — untuk kustomisasi + auto-deploy)

Fork repo ini kalau kamu ingin:
- Mengubah kode / konfigurasi
- GitHub Actions otomatis build image baru setiap push ke `main`
- Notifikasi ntfy dikirim dari GitHub Actions setelah deploy

### Langkah 1 — Fork repo

Klik tombol **Fork** di GitHub. Repo muncul di akun kamu:
`https://github.com/<username-kamu>/ghost-tunnel`

### Langkah 2 — Deploy ke Railway dari GitHub

Railway → New Project → **Deploy from GitHub repo** → pilih fork kamu.

Railway otomatis detect `Dockerfile` dan `railway.json`.

### Langkah 3 — Set Variables Railway

Sama seperti tabel di bagian Quick Deploy di atas.

### Langkah 4 — Set GitHub Secrets (untuk GitHub Actions)

Buka repo fork → **Settings** → **Secrets and variables** → **Actions**:

| Secret | Cara dapat | Keterangan |
|--------|-----------|------------|
| `RAILWAY_TOKEN` | Railway → Account Settings → Tokens → New token | Token API Railway |
| `RAILWAY_PROJECT_ID` | Railway → project → Settings → Project ID | ID project |
| `RAILWAY_SERVICE_ID` | Railway → project → service → Settings → Service ID | ID service |
| `RAILWAY_ENVIRONMENT_ID` | Railway → project → Environments → klik env → lihat URL | ID environment |
| `NTFY_TOPIC` | Sama dengan env Railway | Topic ntfy |
| `ROOT_PASS` | Sama dengan env Railway | Password SSH |

Setelah secrets di-set, setiap push ke `main` akan otomatis:
1. Build Docker image baru
2. Push ke GHCR (`ghcr.io/<username>/ghost-tunnel:latest`)
3. Trigger Railway redeploy
4. Kirim notifikasi ntfy

> **Tanpa GitHub Secrets:** Railway tetap berjalan normal. Notifikasi dari dalam container (tunnel.sh) tetap jalan. Hanya notifikasi dari GitHub Actions yang tidak aktif.

---

## 📲 Semua Format Notifikasi

### Tunnel aktif (startup)
```
🟢 VPS Status : ONLINE
🔐 SSH        : ssh root@bore.pub -p <PORT>
🔑 Password   : <ROOT_PASS>
```

### Reconnect (bore terputus lalu konek kembali)
```
🔄 VPS Status : RECONNECTED
🔐 SSH        : ssh root@bore.pub -p <PORT_BARU>
```

### Watchdog alert
```
⚠️ VPS Status : sshd DOWN       ← sshd crash (Supervisor restart otomatis)
⚠️ VPS Status : TUNNEL DOWN     ← bore crash (Supervisor restart otomatis)
```

---

## 🔧 Multi-Port Tunnel

Set `PORTS` dengan beberapa port dipisah koma:

```
PORTS=22,3000,8080
```

Port pertama (22) selalu jadi port SSH.

---

## 🏗️ Struktur Repo

```
ghost-tunnel/
├── Dockerfile                      # Ubuntu 24.04 + bore + SSH + Supervisor
├── railway.json                    # Railway deploy config + health check
├── .env.example                    # Contoh semua env variables
├── config/
│   ├── supervisord.conf            # Supervisor (PID 1) — manage semua service
│   ├── conf.d/
│   │   ├── startup.conf            # Jalankan startup.sh sekali saat boot
│   │   ├── sshd.conf               # SSH daemon
│   │   ├── tunnel.conf             # Bore tunnel manager
│   │   ├── health.conf             # HTTP health check (/health)
│   │   └── cron.conf               # Cron daemon
│   └── sshd_banner.txt             # Banner saat SSH login
└── scripts/
    ├── startup.sh                  # Init: set password, SSH port, buat env file
    ├── tunnel.sh                   # Bore tunnel manager + ntfy notification
    ├── watchdog.sh                 # Monitor tambahan + alert ntfy (opsional)
    ├── health.py                   # HTTP server /health dan /status
    └── notify.sh                   # Helper: kirim notifikasi ntfy manual
```

---

## 🩺 Health Check

Railway memakai endpoint `/health` untuk cek container sehat:

```bash
curl https://<railway-domain>/health
```

---

## 🔍 Troubleshooting

### Tidak ada notifikasi ntfy

1. Pastikan `NTFY_TOPIC` di Railway **sama persis** dengan topic di app ntfy
2. Test manual setelah SSH masuk:
   ```bash
   curl -d "Test" "https://ntfy.sh/<NTFY_TOPIC>"
   ```
3. Cek Railway logs — cari `[tunnel] ntfy sent` atau `[tunnel] ntfy failed`

### SSH "Connection refused"

- Port bore **berubah setiap Railway restart** — cek ntfy atau Railway logs
- Cari di Railway logs: `Tunnel ready: local :22 → bore.pub:XXXXX`

### Container restart terus-menerus

1. Pastikan `ROOT_PASS`, `NTFY_TOPIC`, dan `PORTS` sudah di-set
2. Health check butuh ~30 detik saat container baru start

### GitHub Actions gagal

Pastikan semua 4 secrets Railway sudah benar. Step Railway di workflow sudah `continue-on-error: true` — tidak akan crash build kalau satu secrets salah.

---

## 📋 Changelog

### v3.3
- Format notifikasi ntfy diubah ke status card terstruktur
- GitHub Actions tidak lagi crash jika Railway API gagal (`continue-on-error`)

### v3.2
- Fix: ntfy di Railway container pakai `--retry 5 --retry-delay 3`
- Fix: Ganti tmpfile ke direct `-d body`

### v3.1
- Fix: Capture bore stdout untuk parse port asli (bukan `???`)

### v3.0
- Supervisor sebagai PID 1
- Multi-port bore tunnel support
- Health check endpoint

---

## 📄 License

MIT
