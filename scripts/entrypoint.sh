#!/bin/bash
# ─────────────────────────────────────────────
#  Ghost Tunnel — Entrypoint v2.1
#  Ubuntu 20.04 | bore.pub
# ─────────────────────────────────────────────
set -e

# ── Banner startup ────────────────────────────
cat << 'BANNER'

  ╔══════════════════════════════════════════════╗
  ║           G H O S T   T U N N E L           ║
  ║        Professional Bore Tunnel Service      ║
  ║          Ubuntu 20.04  ·  v2.1.0            ║
  ╚══════════════════════════════════════════════╝

BANNER

ROOT_PASS="${ROOT_PASS:-Kosay378%}"
NTFY_TOPIC="${NTFY_TOPIC:-temp-mail1}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
PORT="${PORT:-8080}"
PORTS="${PORTS:-22}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

SSH_PORT="${PORTS%%,*}"
SSH_PORT="${SSH_PORT// /}"
[ -z "$SSH_PORT" ] && SSH_PORT="22"

TS() { date -u '+%H:%M:%S'; }
info() { echo "[$(TS)] [INFO ] $*"; }
ok()   { echo "[$(TS)] [OK   ] $*"; }

info "OS         : Ubuntu 20.04 LTS"
info "Root Pass  : (set)"
info "HTTP Port  : ${PORT}"
info "Ports      : ${PORTS}"
info "Bore Server: ${BORE_SERVER}"
info "NTFY Topic : ${NTFY_TOPIC}"
echo ""

# ── Set root password ─────────────────────────
echo "root:${ROOT_PASS}" | chpasswd
ok "Root password set"

# ── Configure SSH ─────────────────────────────
sed -i \
    -e 's/#PermitRootLogin.*/PermitRootLogin yes/' \
    -e 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' \
    -e 's/#PasswordAuthentication.*/PasswordAuthentication yes/' \
    -e 's/PasswordAuthentication no/PasswordAuthentication yes/' \
    -e "/^Port /d" \
    /etc/ssh/sshd_config
echo "Port ${SSH_PORT}" >> /etc/ssh/sshd_config
mkdir -p /run/sshd
ssh-keygen -A 2>/dev/null || true
ok "SSH configured on port ${SSH_PORT} (banner: /etc/ssh/ghost_banner)"

# ── Start sshd ───────────────────────────────
/usr/sbin/sshd
ok "sshd started"

# ── HTTP listener untuk port 80 & 443 ────────
if echo "$PORTS" | grep -qE "(^|,)\s*(80|443)\s*(,|$)"; then
    python3 - << 'PY' &
import http.server, socketserver, threading, os, time

class SimpleHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'Ghost Tunnel VPS')

for p in [80, 443]:
    try:
        s = socketserver.TCPServer(('', p), SimpleHandler)
        s.allow_reuse_address = True
        t = threading.Thread(target=s.serve_forever, daemon=True)
        t.start()
        print(f'[Ghost Tunnel] Listener :{p} ready', flush=True)
    except OSError as e:
        print(f'[Ghost Tunnel] Listener :{p} skip ({e})', flush=True)

time.sleep(86400 * 30)
PY
    sleep 1
fi

# ── Start health server ───────────────────────
PORT="${PORT}" python3 /usr/local/bin/health.py &
ok "Health server → http://0.0.0.0:${PORT}/health"

# ── Export env untuk tunnel ───────────────────
export ROOT_PASS NTFY_TOPIC BORE_SERVER PORTS SSH_PORT

echo ""
info "Starting bore tunnel manager…"
echo "  ──────────────────────────────────────────"
exec /usr/local/bin/tunnel.sh
