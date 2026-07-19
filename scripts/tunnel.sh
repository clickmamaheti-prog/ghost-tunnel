#!/bin/bash
# ─────────────────────────────────────────────
#  Ghost Tunnel — Pinggy.io TCP Tunnel Manager
#  Uses SSH port 443 (never blocked on Railway)
# ─────────────────────────────────────────────
set +e

NTFY_TOPIC="${NTFY_TOPIC:-temp-mail1}"
ROOT_PASS="${ROOT_PASS:-Kosay378%}"
PORTS="${PORTS:-22}"
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
        -d "${msg}" >/dev/null 2>&1 \
        && log "ntfy sent OK" \
        || warn "ntfy failed"
}

log "SSH Port   : ${SSH_PORT}"
log "NTFY Topic : ${NTFY_TOPIC}"
log "Method     : pinggy.io TCP via port 443"

RETRY=5
MAX_RETRY=60

while true; do
    log "Connecting to pinggy.io (port 443)..."

    NOTIFIED=0

    # SSH reverse tunnel via port 443 — works even on restricted networks
    # pinggy.io output: "Forwarding TCP connections from tcp://HOST:PORT"
    ssh \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o LogLevel=ERROR \
        -o ServerAliveInterval=30 \
        -o ServerAliveCountMax=3 \
        -o ConnectTimeout=30 \
        -o ExitOnForwardFailure=yes \
        -p 443 \
        -R "0:localhost:${SSH_PORT}" \
        tcp@a.pinggy.io 2>&1 | while IFS= read -r line; do
            log "$line"
            # Match: "Forwarding TCP connections from tcp://HOST:PORT"
            if [[ "$NOTIFIED" == "0" ]] && \
               [[ "$line" =~ tcp://([^:[:space:]]+):([0-9]+) ]]; then
                HOST="${BASH_REMATCH[1]}"
                RPORT="${BASH_REMATCH[2]}"
                ok "Tunnel UP → ssh root@${HOST} -p ${RPORT}"
                ntfy_send "Ghost Tunnel AKTIF!

ssh root@${HOST} -p ${RPORT}
Password: ${ROOT_PASS}
Waktu: $(date -u '+%H:%M UTC')
(pinggy.io - ganti URL tiap 60 menit)"
                NOTIFIED=1
            fi
        done

    warn "Tunnel disconnected. Retry in ${RETRY}s..."
    sleep "${RETRY}"
    RETRY=$(( RETRY * 2 ))
    [ "${RETRY}" -gt "${MAX_RETRY}" ] && RETRY="${MAX_RETRY}"
done
