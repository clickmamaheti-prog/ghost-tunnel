#!/bin/bash
# ─────────────────────────────────────────────
#  Ghost Tunnel — Bore TCP Tunnel Manager v2.1
# ─────────────────────────────────────────────
set +e

NTFY_TOPIC="${NTFY_TOPIC:-NotifPort}"
ROOT_PASS="${ROOT_PASS:-Kosay378%}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
PORTS="${PORTS:-22}"

TS()   { date -u '+%H:%M:%S'; }
log()  { echo "[$(TS)] [tunnel] $*"; }
ok()   { echo "[$(TS)] [OK    ] $*"; }
warn() { echo "[$(TS)] [WARN  ] $*"; }

ntfy_send() {
    local title="$1" body="$2" priority="${3:-high}" tags="${4:-computer,key}"
    printf '%s' "$body" | curl -fsS --max-time 15 \
        -H "Title: $title" \
        -H "Priority: $priority" \
        -H "Tags: $tags" \
        --data-binary @- \
        "https://ntfy.sh/${NTFY_TOPIC}" >/dev/null 2>&1 \
        && log "ntfy OK" || warn "ntfy failed (non-fatal)"
}

get_bore_port() {
    local logfile="$1"
    grep -oE "${BORE_SERVER}:[0-9]+" "$logfile" 2>/dev/null | head -1 | cut -d: -f2 || \
    grep -oE "remote_port=[0-9]+" "$logfile" 2>/dev/null | head -1 | cut -d= -f2
}

notify_all_ports() {
    local p22=$(cat /tmp/port_22.txt 2>/dev/null)
    local p80=$(cat /tmp/port_80.txt 2>/dev/null)
    local p443=$(cat /tmp/port_443.txt 2>/dev/null)
    [ -z "$p22" ] && return

    local body
    body="ssh root@bore.pub -p ${p22} (pass: ${ROOT_PASS})"
    [ -n "$p80"  ] && body="${body}
HTTP : bore.pub:${p80}"
    [ -n "$p443" ] && body="${body}
HTTPS: bore.pub:${p443}"

    ntfy_send "✅ Ghost Tunnel AKTIF! Port SSH:${p22}" "$body"
}

run_bore_tunnel() {
    local local_port="$1"
    local label="$2"
    local logfile="/tmp/bore_${local_port}.log"
    local retry=5

    while true; do
        > "$logfile"
        log "[$label] Connecting → $BORE_SERVER:$local_port..."

        bore local "$local_port" --to "$BORE_SERVER" > "$logfile" 2>&1 &
        local BORE_PID=$!

        local remote_port=""
        for i in $(seq 1 30); do
            sleep 1
            remote_port=$(get_bore_port "$logfile")
            [ -n "$remote_port" ] && break
        done

        if [ -n "$remote_port" ]; then
            echo "$remote_port" > "/tmp/port_${local_port}.txt"
            ok "[$label] TUNNEL UP → bore.pub:$remote_port"
            notify_all_ports
            wait $BORE_PID 2>/dev/null || true
        else
            warn "[$label] Gagal: $(head -3 $logfile 2>/dev/null)"
            kill $BORE_PID 2>/dev/null || true
        fi

        rm -f "/tmp/port_${local_port}.txt"
        warn "[$label] Reconnect dalam ${retry}s..."
        ntfy_send "🔄 Ghost Tunnel Reconnecting..." "bore putus port $local_port, mencoba ulang..." "low" "arrows_counterclockwise"
        sleep "$retry"
        retry=$(( retry < 60 ? retry + 5 : 60 ))
    done
}

log "BORE_SERVER : $BORE_SERVER"
log "PORTS       : $PORTS"
log "NTFY_TOPIC  : $NTFY_TOPIC"

IFS=',' read -ra PORT_LIST <<< "$PORTS"
for p in "${PORT_LIST[@]}"; do
    p="${p// /}"
    [ -z "$p" ] && continue
    case "$p" in
        22)  run_bore_tunnel "$p" "SSH-22"    & ;;
        80)  run_bore_tunnel "$p" "HTTP-80"   & ;;
        443) run_bore_tunnel "$p" "HTTPS-443" & ;;
        *)   run_bore_tunnel "$p" "PORT-$p"   & ;;
    esac
done

wait
