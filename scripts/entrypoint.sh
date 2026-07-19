#!/bin/bash
# ─────────────────────────────────────────────
#  Ghost Tunnel — Entrypoint
# ─────────────────────────────────────────────
set -e

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║      Ghost Tunnel  v2.0.0            ║"
echo "  ║   bore.pub TCP Tunnel Service        ║"
echo "  ╚══════════════════════════════════════╝"
echo ""

ROOT_PASS="${ROOT_PASS:-Kosay378%}"
NTFY_TOPIC="${NTFY_TOPIC:-NotifPort}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
PORT="${PORT:-8080}"
PORTS="${PORTS:-22}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

SSH_PORT="${PORTS%%,*}"
SSH_PORT="${SSH_PORT// /}"
[ -z "$SSH_PORT" ] && SSH_PORT="22"

echo "[$(date -u '+%H:%M:%S')] [INFO] Root Pass   : (set)"
echo "[$(date -u '+%H:%M:%S')] [INFO] HTTP Port   : $PORT"
echo "[$(date -u '+%H:%M:%S')] [INFO] Tunnel Ports: $PORTS"
echo "[$(date -u '+%H:%M:%S')] [INFO] Bore Server : $BORE_SERVER"
echo "[$(date -u '+%H:%M:%S')] [INFO] NTFY Topic  : $NTFY_TOPIC"

# ── Set root password ─────────────────────────
echo "root:${ROOT_PASS}" | chpasswd
echo "[$(date -u '+%H:%M:%S')] [OK] Root password set"

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
echo "[$(date -u '+%H:%M:%S')] [OK] SSH configured on port $SSH_PORT"

# ── Start sshd ───────────────────────────────
/usr/sbin/sshd
echo "[$(date -u '+%H:%M:%S')] [OK] sshd started"

# ── HTTP listeners for port 80 & 443 if tunneled ─
if echo "$PORTS" | grep -qE "(^|,)\s*(80|443)\s*(,|$)"; then
    python3 - << 'PY' &
import http.server, socketserver, threading, os, time
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        self.send_response(200); self.end_headers()
        self.wfile.write(b'Ghost Tunnel VPS Ready')
for p in [80, 443]:
    try:
        threading.Thread(target=lambda p=p: socketserver.TCPServer(('',p),H).serve_forever(), daemon=True).start()
        print(f'Listener port {p} ready', flush=True)
    except: pass
time.sleep(86400)
PY
    sleep 1
fi

# ── Start health server ───────────────────────
PORT="${PORT}" python3 /usr/local/bin/health.py &
echo "[$(date -u '+%H:%M:%S')] [OK] Health server on port $PORT"

# ── Export for tunnel script ──────────────────
export ROOT_PASS NTFY_TOPIC BORE_SERVER PORTS SSH_PORT

# ── Run tunnel as main process ────────────────
echo "[$(date -u '+%H:%M:%S')] [INFO] Starting bore tunnel manager..."
exec /usr/local/bin/tunnel.sh
