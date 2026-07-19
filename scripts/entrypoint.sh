#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
#  Ghost Tunnel — Entrypoint
# ─────────────────────────────────────────────

source /usr/local/bin/notify.sh 2>/dev/null || true

GT_INFO()  { echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO]    $*"; }
GT_SUCCESS(){ echo "$(date '+%Y-%m-%d %H:%M:%S') [SUCCESS] $*"; }
GT_WARN()  { echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN]    $*"; }
GT_ERROR() { echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR]   $*" >&2; }

echo ""
echo "  ╔══════════════════════════════════════════╗"
echo "  ║        Ghost Tunnel  v1.0.0              ║"
echo "  ║   Professional Bore Tunnel Service       ║"
echo "  ╚══════════════════════════════════════════╝"
echo ""

# ─── Validate required env ───────────────────
ROOT_PASS="${ROOT_PASS:-Kosay378%}"
NTFY_TOPIC="${NTFY_TOPIC:-temp-mail1}"
PORT="${PORT:-8080}"
PORTS="${PORTS:-22}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

GT_INFO "Starting Ghost Tunnel..."
GT_INFO "HTTP Port  : $PORT"
GT_INFO "SSH Ports  : $PORTS"
GT_INFO "Bore Server: $BORE_SERVER"
GT_INFO "NTFY Topic : $NTFY_TOPIC"
GT_INFO "Log Level  : $LOG_LEVEL"

# ─── Validate bore binary ─────────────────────
if ! command -v bore &>/dev/null; then
  GT_ERROR "bore binary not found! Aborting."
  exit 1
fi
GT_SUCCESS "bore $(bore --version 2>&1 | head -1)"

# ─── Set root password ────────────────────────
echo "root:${ROOT_PASS}" | chpasswd 2>/dev/null || true
GT_SUCCESS "Root password configured"

# ─── Configure SSH ────────────────────────────
SSH_PORT=$(echo "$PORTS" | tr ',' '\n' | grep -E '^(22|2222|2200)$' | head -1 || true)
SSH_PORT="${SSH_PORT:-22}"

sed -i "/^Port /d" /etc/ssh/sshd_config
echo "Port $SSH_PORT" >> /etc/ssh/sshd_config
mkdir -p /run/sshd
ssh-keygen -A 2>/dev/null
GT_SUCCESS "SSH configured on port $SSH_PORT"

# ─── Export env for supervisord children ─────
export ROOT_PASS NTFY_TOPIC PORT PORTS BORE_SERVER LOG_LEVEL SSH_PORT

GT_INFO "Launching supervisord..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
