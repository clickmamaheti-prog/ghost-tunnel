#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#  Ghost Tunnel — Watchdog v3.0
#  Optional additional watchdog; Supervisor already handles auto-restart.
#  Can be enabled by adding watchdog.conf to /etc/supervisor/conf.d/.
# ══════════════════════════════════════════════════════════════════════════════
set +e

NTFY_TOPIC="${NTFY_TOPIC:-ghost-mail}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
PORTS="${PORTS:-22}"
WATCH_INTERVAL="${WATCH_INTERVAL:-60}"

TS()   { date -u '+%Y-%m-%d %H:%M:%S'; }
log()  { echo "[$(TS)] [watchdog] [INFO ] $*"; }
warn() { echo "[$(TS)] [watchdog] [WARN ] $*"; }
ok()   { echo "[$(TS)] [watchdog] [OK   ] $*"; }

ntfy_send() {
    local title="$1" body="$2"
    curl -sS --connect-timeout 15 --max-time 30 \
        -H "Title: $title" \
        -d "$body" \
        "https://ntfy.sh/${NTFY_TOPIC}" > /dev/null 2>&1 || true
}

log "Watchdog started (interval: ${WATCH_INTERVAL}s)"

while true; do
    sleep "${WATCH_INTERVAL}"

    # ── Check SSH ──────────────────────────────────────────────────────────────
    if ! pgrep -x sshd > /dev/null 2>&1; then
        warn "sshd not running — Supervisor should restart it"
        ntfy_send "⚠️ Ghost Tunnel: sshd down" "sshd not found. Supervisor will restart."
    fi

    # ── Check bore processes ───────────────────────────────────────────────────
    bore_count=$(pgrep -c bore 2>/dev/null || echo 0)
    if [ "$bore_count" -eq 0 ]; then
        warn "No bore processes found — tunnel service may be recovering"
        ntfy_send "⚠️ Ghost Tunnel: no bore processes" "No bore tunnels detected. Supervisor will restart."
    else
        ok "Health OK — sshd: $(pgrep -c sshd 2>/dev/null || echo 0), bore: ${bore_count}"
    fi

    # ── Check health endpoint ──────────────────────────────────────────────────
    PORT="${PORT:-8080}"
    if ! curl -sf "http://localhost:${PORT}/health" > /dev/null 2>&1; then
        warn "Health endpoint not responding on :${PORT}"
    fi
done
