#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#  Ghost Tunnel — Startup Script v3.0
#  Runs ONCE at container start (managed by Supervisor, priority=5).
#  All long-running services are managed by Supervisor, not this script.
# ══════════════════════════════════════════════════════════════════════════════
set -e

TS()   { date -u '+%Y-%m-%d %H:%M:%S'; }
info() { echo "[$(TS)] [startup] [INFO ] $*"; }
ok()   { echo "[$(TS)] [startup] [OK   ] $*"; }
warn() { echo "[$(TS)] [startup] [WARN ] $*"; }
err()  { echo "[$(TS)] [startup] [ERROR] $*" >&2; }

# ── Banner ─────────────────────────────────────────────────────────────────────
cat << 'BANNER'

  ╔══════════════════════════════════════════════╗
  ║           G H O S T   T U N N E L           ║
  ║     Production · Supervisor · Ubuntu 24.04   ║
  ║              v3.0.0 — Startup                ║
  ╚══════════════════════════════════════════════╝

BANNER

ROOT_PASS="${ROOT_PASS:-ChangeMe123!}"
NTFY_TOPIC="${NTFY_TOPIC:-ghost-mail}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
PORT="${PORT:-8080}"
PORTS="${PORTS:-22}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

info "OS         : Ubuntu 24.04 LTS"
info "HTTP Port  : ${PORT}"
info "Tunnels    : ${PORTS}"
info "Bore Server: ${BORE_SERVER}"
info "NTFY Topic : ${NTFY_TOPIC}"
info "Log Level  : ${LOG_LEVEL}"
echo ""

# ── Set root password ──────────────────────────────────────────────────────────
echo "root:${ROOT_PASS}" | chpasswd
ok "Root password updated"

# ── Determine SSH port from $PORTS (first port in list) ───────────────────────
SSH_PORT="${PORTS%%,*}"
SSH_PORT="${SSH_PORT// /}"
[ -z "$SSH_PORT" ] && SSH_PORT="22"
info "SSH port   : ${SSH_PORT}"

# ── Apply SSH port dynamically ─────────────────────────────────────────────────
sed -i "/^Port /d" /etc/ssh/sshd_config
echo "Port ${SSH_PORT}" >> /etc/ssh/sshd_config

# ── Regenerate host keys if missing ───────────────────────────────────────────
mkdir -p /run/sshd
ssh-keygen -A 2>/dev/null || true
ok "SSH host keys ready"

# ── Ensure log directories exist ──────────────────────────────────────────────
mkdir -p /var/log/supervisor /var/log/ghost-tunnel
ok "Log directories ready"

# ── Export runtime env for child processes ────────────────────────────────────
# Supervisor inherits env from its own invocation, but we write a sourced file
# so scripts can re-source it if needed.
cat > /etc/ghost-tunnel.env << EOF
export ROOT_PASS="${ROOT_PASS}"
export NTFY_TOPIC="${NTFY_TOPIC}"
export BORE_SERVER="${BORE_SERVER}"
export PORT="${PORT}"
export PORTS="${PORTS}"
export SSH_PORT="${SSH_PORT}"
export LOG_LEVEL="${LOG_LEVEL}"
EOF
chmod 600 /etc/ghost-tunnel.env
ok "Runtime env written to /etc/ghost-tunnel.env"

echo ""
ok "Startup complete — Supervisor will manage all services."
