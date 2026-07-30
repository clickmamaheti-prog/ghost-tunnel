#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#  Ghost Tunnel — Watchdog v3.2
#  Optional additional watchdog; Supervisor already handles auto-restart.
#  Can be enabled by adding watchdog.conf to /etc/supervisor/conf.d/.
#
#  v3.2 fix: ntfy_send uses --retry 5 --retry-delay 3 --retry-all-errors
#            + direct -d body (no tmpfile) to fix Railway container failures.
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
    local code
    code=$(curl -sS \
        --retry 5 \
        --retry-delay 3 \
        --retry-all-errors \
        --connect-timeout 15 \
        --max-time 60 \
        -H "Content-Type: text/plain" \
        -H "Title: ${title}" \
        -d "${body}" \
        -o /dev/null \
        -w "%{http_code}" \
        "https://ntfy.sh/${NTFY_TOPIC}" 2>/dev/null)
    [ "$code" = "200" ] && return 0 || return 1
}

log "Watchdog started (interval: ${WATCH_INTERVAL}s)"

while true; do
    sleep "${WATCH_INTERVAL}"

    # ── Check SSH ──────────────────────────────────────────────────────────────
    if ! pgrep -x sshd > /dev/null 2>&1; then
        warn "sshd not running — Supervisor should restart it"
        ntfy_send "⚠️ Ghost Tunnel: sshd down" "sshd not found. Supervisor will restart." || true
    fi

    # ── Check bore processes ───────────────────────────────────────────────────
    bore_count=$(pgrep -c bore 2>/dev/null || echo 0)
    if [ "$bore_count" -eq 0 ]; then
        warn "No bore processes found — tunnel service may be recovering"
        ntfy_send "⚠️ Ghost Tunnel: no bore processes" "No bore tunnels detected. Supervisor will restart." || true
    else
        ok "Health OK — sshd: $(pgrep -c sshd 2>/dev/null || echo 0), bore: ${bore_count}"
    fi

    # ── Check health endpoint ──────────────────────────────────────────────────
    PORT="${PORT:-8080}"
    if ! curl -sf "http://localhost:${PORT}/health" > /dev/null 2>&1; then
        warn "Health endpoint not responding on :${PORT}"
    fi
done
