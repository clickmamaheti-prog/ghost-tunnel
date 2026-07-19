#!/bin/bash
# ─────────────────────────────────────────────
#  Ghost Tunnel — Bore TCP Tunnel Manager v2.3
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

# ── ntfy via curl: body ke tempfile, timeout 60s ─
ntfy_send() {
    local title="$1" body="$2" priority="${3:-default}" tags="${4:-white_check_mark}"
    local tmpfile="/tmp/ntfy_$$.txt"
    printf '%s' "$body" > "$tmpfile"
    local code
    code=$(curl -sS \
        --connect-timeout 20 \
        --max-time 60 \
        -H "Title: $title" \
        -H "Priority: $priority" \
        -H "Tags: $tags" \
        --data-binary "@$tmpfile" \
        -o /dev/null -w "%{http_code}" \
        "https://ntfy.sh/${NTFY_TOPIC}" 2>&1)
    rm -f "$tmpfile"
    local exit_code=$?
    if [ "$exit_code" -eq 0 ] && [[ "$code" =~ ^2 ]]; then
        log "ntfy ✓ [HTTP $code]"
    else
        warn "ntfy gagal — exit:${exit_code} http:${code}"
        # Retry sekali via HTTP (port 80) jika HTTPS gagal
        printf '%s' "$body" > "$tmpfile"
        curl -sS --connect-timeout 20 --max-time 60 \
            -H "Title: $title" -H "Priority: $priority" -H "Tags: $tags" \
            --data-binary "@$tmpfile" \
            "http://ntfy.sh/${NTFY_TOPIC}" >/dev/null 2>&1 \
            && log "ntfy ✓ [HTTP fallback OK]" \
            || warn "ntfy gagal total (non-fatal)"
        rm -f "$tmpfile"
    fi
}

# ── Notif semua port aktif (gabungan) ─────────
notify_tunnel_up() {
    local p22; p22=$(cat /tmp/port_22.txt 2>/dev/null)
    [ -z "$p22" ] && return

    local waktu; waktu=$(date -u '+%d %b %Y · %H:%M UTC')
    local p80;  p80=$(cat /tmp/port_80.txt  2>/dev/null)
    local p443; p443=$(cat /tmp/port_443.txt 2>/dev/null)

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

# ── Notif reconnect ────────────────────────────
notify_reconnect() {
    local port="$1"; local waktu; waktu=$(date -u '+%H:%M UTC')
    ntfy_send "Ghost Tunnel Reconnecting" \
        "Tunnel port ${port} putus, mencoba ulang...\n${waktu}" \
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
    local local_port="$1" label="$2"
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
