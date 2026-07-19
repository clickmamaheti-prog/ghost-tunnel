#!/bin/bash
# ─────────────────────────────────────────────
#  Ghost Tunnel — Bore Tunnel Manager
# ─────────────────────────────────────────────
set +e

BORE_SERVER="${BORE_SERVER:-bore.pub}"
PORTS="${PORTS:-22}"
NTFY_TOPIC="${NTFY_TOPIC:-temp-mail1}"
ROOT_PASS="${ROOT_PASS:-Kosay378%}"

# First port = SSH port
SSH_PORT="${PORTS%%,*}"
SSH_PORT="${SSH_PORT// /}"
[ -z "$SSH_PORT" ] && SSH_PORT="22"

TS()   { date -u '+%H:%M:%S'; }
log()  { echo "[$(TS)] [tunnel] $*"; }
ok()   { echo "[$(TS)] [OK    ] $*"; }
warn() { echo "[$(TS)] [WARN  ] $*"; }

ntfy_send() {
    local msg="$1"
    curl -fsS --max-time 15 "https://ntfy.sh/${NTFY_TOPIC}" \
        -H "Title: Ghost Tunnel Aktif" \
        -H "Priority: high" \
        -H "Tags: ghost,computer" \
        -d "${msg}" >/dev/null 2>&1 || warn "ntfy failed (will retry next connect)"
}

log "SSH Port   : ${SSH_PORT}"
log "Bore Server: ${BORE_SERVER}"
log "NTFY Topic : ${NTFY_TOPIC}"

BORE_LOG="/tmp/bore_${SSH_PORT}.log"
RETRY=5
MAX_RETRY=60

while true; do
    # Kill old bore if any
    pkill -f "bore local ${SSH_PORT}" 2>/dev/null || true
    sleep 1

    # Start fresh bore, log output to file
    rm -f "$BORE_LOG"
    log "Connecting: bore local ${SSH_PORT} --to ${BORE_SERVER}"
    bore local "${SSH_PORT}" --to "${BORE_SERVER}" > "$BORE_LOG" 2>&1 &
    BORE_PID=$!
    log "bore PID=${BORE_PID}"

    # Wait for "listening at" line — up to 30 seconds
    RPORT=""
    for i in $(seq 1 15); do
        sleep 2
        # Match both "listening at bore.pub:PORT" and "Listening at bore.pub:PORT"
        RPORT=$(grep -iE "listening at [^:]+:([0-9]+)" "$BORE_LOG" 2>/dev/null \
                | grep -oE "[0-9]+$" | head -1)
        if [ -n "$RPORT" ]; then
            break
        fi
        # Bore died early?
        if ! kill -0 "$BORE_PID" 2>/dev/null; then
            warn "bore exited early. Log: $(cat "$BORE_LOG" 2>/dev/null | tail -3)"
            break
        fi
    done

    if [ -n "$RPORT" ]; then
        ok "Tunnel UP → ssh root@${BORE_SERVER} -p ${RPORT}"
        RETRY=5   # reset backoff

        ntfy_send "Ghost Tunnel AKTIF!

ssh root@${BORE_SERVER} -p ${RPORT}
Password: ${ROOT_PASS}
Waktu: $(date -u '+%H:%M UTC')"

        # Wait for bore to die while echoing its output
        while kill -0 "$BORE_PID" 2>/dev/null; do
            tail -n +1 -f "$BORE_LOG" 2>/dev/null | head -1 || true
            sleep 5
        done
        warn "bore connection dropped (was port ${RPORT})"
    else
        warn "Bore failed to connect. Log: $(cat "$BORE_LOG" 2>/dev/null | tail -5 | tr '\n' ' ')"
    fi

    warn "Retrying in ${RETRY}s..."
    sleep "${RETRY}"
    RETRY=$(( RETRY * 2 ))
    [ "${RETRY}" -gt "${MAX_RETRY}" ] && RETRY="${MAX_RETRY}"
done
