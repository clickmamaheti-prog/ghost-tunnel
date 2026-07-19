#!/bin/bash
# ─────────────────────────────────────────────
#  Ghost Tunnel — Entrypoint (no supervisord)
# ─────────────────────────────────────────────
set -e

echo ""
echo "  ╔══════════════════════════════════════╗"
echo "  ║      Ghost Tunnel  v1.0.0            ║"
echo "  ║   Pinggy.io TCP Tunnel Service       ║"
echo "  ╚══════════════════════════════════════╝"
echo ""

ROOT_PASS="${ROOT_PASS:-Kosay378%}"
NTFY_TOPIC="${NTFY_TOPIC:-temp-mail1}"
PORT="${PORT:-8080}"
PORTS="${PORTS:-22}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

SSH_PORT="${PORTS%%,*}"
SSH_PORT="${SSH_PORT// /}"
[ -z "$SSH_PORT" ] && SSH_PORT="22"

echo "[$(date -u '+%H:%M:%S')] [INFO] Root Pass  : (set)"
echo "[$(date -u '+%H:%M:%S')] [INFO] HTTP Port  : $PORT"
echo "[$(date -u '+%H:%M:%S')] [INFO] SSH Port   : $SSH_PORT"
echo "[$(date -u '+%H:%M:%S')] [INFO] NTFY Topic : $NTFY_TOPIC"

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

# ── Start sshd as daemon ──────────────────────
/usr/sbin/sshd
echo "[$(date -u '+%H:%M:%S')] [OK] sshd started"

# ── Start health server in background ─────────
PORT="${PORT}" python3 /usr/local/bin/health.py &
HEALTH_PID=$!
echo "[$(date -u '+%H:%M:%S')] [OK] Health server started (PID $HEALTH_PID) on port $PORT"

# ── Export for tunnel script ──────────────────
export ROOT_PASS NTFY_TOPIC PORTS SSH_PORT

# ── Run tunnel as main process (visible in Railway logs) ──
echo "[$(date -u '+%H:%M:%S')] [INFO] Starting tunnel manager..."
exec /usr/local/bin/tunnel.sh
