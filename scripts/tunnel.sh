#!/bin/bash
# ─────────────────────────────────────────────
#  Ghost Tunnel — Bore TCP Tunnel Manager v2.2
# ─────────────────────────────────────────────
set +e

NTFY_TOPIC="${NTFY_TOPIC:-temp-mail1}"
ROOT_PASS="${ROOT_PASS:-Kosay378%}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
PORTS="${PORTS:-22}"

TS()   { date -u '+%H:%M:%S'; }
log()  { echo "[$(TS)] [tunnel] $*"; }
ok()   { echo "[$(TS)] [OK    ] $*"; }
warn() { echo "[$(TS)] [WARN  ] $*"; }

# ── ntfy: tulis body ke file, hindari pipe issue ──
ntfy_send() {
    local title="$1"
    local body="$2"
    local priority="${3:-default}"
    local tags="${4:-white_check_mark}"
    local tmpfile="/tmp/ntfy_$$.txt"

    printf '%s' "$body" > "$tmpfile"

    local http_code
    http_code=$(curl -sS --max-time 30 --connect-timeout 10 \
        -H "Title: $title" \
        -H "Priority: $priority" \
        -H "Tags: $tags" \
        --data-binary "@$tmpfile" \
        -o /dev/null -w "%{http_code}" \
        "https://ntfy.sh/${NTFY_TOPIC}" 2>&1)
    local exit_code=$?

    rm -f "$tmpfile"

    if [ "$exit_code" -eq 0 ] && [ "${http_code:0:1}" = "2" ]; then
        log "ntfy ✓ [HTTP $http_code]"
    else
        warn "ntfy gagal — exit:$exit_code http:$http_code"
    fi
}

# ── Notif gabungan semua port aktif ──────────
notify_tunnel_up() {
    local p22=$(cat /tmp/port_22.txt 2>/dev/null)
    [ -z "$p22" ] && return

    local waktu
    waktu=$(date -u '+%d %b %Y · %H:%M UTC')
    local p80=$(cat /tmp/port_80.txt 2>/dev/null)
    local p443=$(cat /tmp/port_443.txt 2>/dev/null)

    local body
    body="━━━━━━━━━━━━━━━━━━━━━━━━━
ssh root@bore.pub -p ${p22}
Password : ${ROOT_PASS}"
    [ -n "$p80"  ] && body="${body}
HTTP     : bore.pub:${p80}"
    [ -n "$p443" ] && body="${body}
HTTPS    : bore.pub:${p443}"
    body="${body}
━━━━━━━━━━━━━━━━━━━━━━━━━
${waktu}"

    ntfy_send "Ghost Tunnel Aktif - SSH :${p22}" "$body" "high" "computer,key"
}

# ── Notif reconnect ───────────────────────────
notify_reconnect() {
    local port="$1"
    ntfy_send "Ghost Tunnel Reconnecting" \
        "Tunnel port ${port} putus, mencoba ulang... $(date -u '+%H:%M UTC')" \
        "low" "arrows_counterclockwise"
}

# ── Parse port dari log bore ──────────────────
get_bore_port() {
    local logfile="$1"
    grep -oE "${BORE_SERVER}:[0-9]+" "$logfile" 2>/dev/null | head -1 | cut -d: -f2 \
    || grep -oE "remote_port=[0-9]+" "$logfile" 2>/dev/null | head -1 | cut -d= -f2
}

# ── Jalankan satu bore tunnel ─────────────────
run_bore_tunnel() {
    local local_port="$1"
    local label="$2"
    local logfile="/tmp/bore_${local_port}.log"
    local retry=5

    while true; do
        : > "$logfile"
        log "[$label] Connecting → ${BORE_SERVER}..."

        bore local "$local_port" --to "$BORE_SERVER" >> "$logfile" 2>&1 &
        local BORE_PID=$!

        local remote_port=""
        for i in $(seq 1 30); do
            sleep 1
            remote_port=$(get_bore_port "$logfile")
            [ -n "$remote_port" ] && break
        done

        if [ -n "$remote_port" ]; then
            echo "$remote_port" > "/tmp/port_${local_port}.txt"
            ok "[$label] AKTIF → bore.pub:${remote_port}"
            notify_tunnel_up
            wait $BORE_PID 2>/dev/null || true
        else
            warn "[$label] Gagal: $(head -3 "$logfile" 2>/dev/null)"
            kill $BORE_PID 2>/dev/null || true
        fi

        rm -f "/tmp/port_${local_port}.txt"
        notify_reconnect "$local_port"
        warn "[$label] Reconnect dalam ${retry}s..."
        sleep "$retry"
        retry=$(( retry < 60 ? retry + 5 : 60 ))
    done
}

# ── Main ──────────────────────────────────────
log "BORE_SERVER : ${BORE_SERVER}"
log "PORTS       : ${PORTS}"
log "NTFY_TOPIC  : ${NTFY_TOPIC}"

IFS=',' read -ra PORT_LIST <<< "$PORTS"
for p in "${PORT_LIST[@]}"; do
    p="${p// /}"
    [ -z "$p" ] && continue
    case "$p" in
        22)  run_bore_tunnel "$p" "SSH"   & ;;
        80)  run_bore_tunnel "$p" "HTTP"  & ;;
        443) run_bore_tunnel "$p" "HTTPS" & ;;
        *)   run_bore_tunnel "$p" "PORT-${p}" & ;;
    esac
done

wait
