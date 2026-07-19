#!/bin/bash
# ─────────────────────────────────────────────
#  Ghost Tunnel — System Watchdog
# ─────────────────────────────────────────────
set +e

INFO()  { echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO   ] [watchdog] $*"; }
WARN()  { echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN   ] [watchdog] $*"; }
ERROR() { echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR  ] [watchdog] $*" >&2; }

INFO "Watchdog started — monitoring system health..."
CHECK_INTERVAL="${WATCHDOG_INTERVAL:-30}"

while true; do
  sleep "$CHECK_INTERVAL"

  # ── Check sshd ──────────────────────────────
  if ! pgrep -x sshd > /dev/null 2>&1; then
    WARN "sshd is down — restarting via supervisorctl..."
    supervisorctl restart sshd 2>/dev/null || /usr/sbin/sshd 2>/dev/null || true
  fi

  # ── Check tunnel manager ─────────────────────
  if ! pgrep -f "tunnel.sh" > /dev/null 2>&1; then
    WARN "tunnel manager is down — supervisord should restart it"
  fi

  # ── Check health server ─────────────────────
  if ! pgrep -f "health.py" > /dev/null 2>&1; then
    WARN "health server is down — supervisord should restart it"
  fi

  # ── System stats (debug) ────────────────────
  if [ "${LOG_LEVEL:-INFO}" = "DEBUG" ]; then
    MEM=$(free -m | awk '/^Mem:/{printf "%.0f%%", $3/$2*100}')
    INFO "System: mem=${MEM} | bore_procs=$(pgrep -c bore 2>/dev/null || echo 0)"
  fi
done
