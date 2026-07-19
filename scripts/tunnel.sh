#!/bin/bash
# ─────────────────────────────────────────────
#  Ghost Tunnel — Bore Tunnel Manager (Railway)
# ─────────────────────────────────────────────
set +e

BORE_SERVER="${BORE_SERVER:-bore.pub}"
PORTS="${PORTS:-22}"
NTFY_TOPIC="${NTFY_TOPIC:-temp-mail1}"
ROOT_PASS="${ROOT_PASS:-Kosay378%}"

# Use only the first port (SSH port)
SSH_PORT="${PORTS%%,*}"
SSH_PORT="${SSH_PORT// /}"
SSH_PORT="${SSH_PORT:-22}"

TS() { date -u '+%H:%M:%S'; }

log()  { echo "[$(TS)] [tunnel] $*"; }
info() { echo "[$(TS)] [INFO  ] $*"; }
ok()   { echo "[$(TS)] [OK    ] $*"; }
warn() { echo "[$(TS)] [WARN  ] $*"; }
err()  { echo "[$(TS)] [ERROR ] $*" >&2; }

ntfy_send() {
    local msg="$1"
    curl -fsS --max-time 10 "https://ntfy.sh/${NTFY_TOPIC}" \
        -H "Title: Ghost Tunnel Aktif" \
        -H "Priority: high" \
        -H "Tags: ghost,computer" \
        -d "${msg}" >/dev/null 2>&1 || warn "ntfy send failed"
}

info "SSH Port   : ${SSH_PORT}"
info "Bore Server: ${BORE_SERVER}"
info "NTFY Topic : ${NTFY_TOPIC}"

RETRY=5
MAX_RETRY=60

while true; do
    info "Connecting bore: localhost:${SSH_PORT} -> ${BORE_SERVER} ..."

    NOTIFIED=0

    # Process substitution keeps vars in current shell (unlike pipe subshell)
    while IFS= read -r line; do
        log "$line"

        # Match bore output: "listening at bore.pub:PORT"
        # bore v0.5+ / v0.6.0 output format (case-insensitive match)
        if [[ "$NOTIFIED" == "0" ]] && \
           [[ "$line" =~ [Ll]istening[[:space:]]at[[:space:]].*:([0-9]+) ]]; then

            RPORT="${BASH_REMATCH[1]}"
            ok "Tunnel UP: ssh root@${BORE_SERVER} -p ${RPORT}"

            ntfy_send "Ghost Tunnel AKTIF!

ssh root@${BORE_SERVER} -p ${RPORT}
Password: ${ROOT_PASS}
Waktu: $(date -u '+%H:%M UTC')"

            NOTIFIED=1
            RETRY=5   # reset backoff setelah berhasil konek
        fi

    done < <(bore local "${SSH_PORT}" --to "${BORE_SERVER}" 2>&1)

    warn "bore exited (port ${SSH_PORT}). Retry in ${RETRY}s..."
    sleep "${RETRY}"

    # Exponential backoff, cap at MAX_RETRY
    RETRY=$(( RETRY * 2 ))
    [ "${RETRY}" -gt "${MAX_RETRY}" ] && RETRY="${MAX_RETRY}"
done
