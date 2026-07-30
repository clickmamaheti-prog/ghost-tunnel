#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#  Ghost Tunnel — Bore TCP Tunnel Manager v3.0
#  Managed by Supervisor (autorestart=true, startretries=999).
# ══════════════════════════════════════════════════════════════════════════════
set +e

NTFY_TOPIC="${NTFY_TOPIC:-ghost-mail}"
ROOT_PASS="${ROOT_PASS:-ChangeMe123!}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
PORTS="${PORTS:-22}"

TS()   { date -u '+%Y-%m-%d %H:%M:%S'; }
log()  { echo "[$(TS)] [tunnel] [INFO ] $*"; }
ok()   { echo "[$(TS)] [tunnel] [OK   ] $*"; }
warn() { echo "[$(TS)] [tunnel] [WARN ] $*"; }

# ── ntfy notification via curl ─────────────────────────────────────────────────
ntfy_send() {
    local title="$1" body="$2" priority="${3:-default}" tags="${4:-white_check_mark}"
    local tmpfile; tmpfile=$(mktemp /tmp/ntfy_XXXXXX.txt)
    printf '%s' "$body" > "$tmpfile"
    local code
    code=$(curl -sS \
        --connect-timeout 20 \
        --max-time 60 \
        -H "Title: $title" \
        -H "Priority: $priority" \
        -H "Tags: $tags" \
        --data-binary "@$tmpfile" \
        -o /dev/null \
        -w "%{http_code}" \
        "https://ntfy.sh/${NTFY_TOPIC}" 2>/dev/null)
    rm -f "$tmpfile"
    [ "$code" = "200" ] && return 0 || return 1
}

# ── Parse ports list into array ────────────────────────────────────────────────
IFS=',' read -ra PORT_LIST <<< "$PORTS"

log "Starting bore tunnel manager"
log "Server : ${BORE_SERVER}"
log "Ports  : ${PORTS}"

# ── Start one bore process per port ───────────────────────────────────────────
BORE_PIDS=()

for raw_port in "${PORT_LIST[@]}"; do
    port="${raw_port// /}"
    [ -z "$port" ] && continue

    log "Opening tunnel → ${BORE_SERVER}:??? ← local :${port}"
    bore local "${port}" --to "${BORE_SERVER}" 2>&1 &
    BORE_PIDS+=($!)
    log "bore PID $! started for port ${port}"
    sleep 0.5
done

# ── Wait for bore output to capture assigned remote ports ─────────────────────
sleep 5

# ── Collect remote port assignments ────────────────────────────────────────────
ASSIGNED_PORTS=()
for pid in "${BORE_PIDS[@]}"; do
    assigned=$(grep -r "remote_port" /proc/${pid}/fd/ 2>/dev/null | head -1 || true)
    ASSIGNED_PORTS+=("${assigned:-unknown}")
done

# ── Discover assigned remote ports from process output ────────────────────────
TUNNEL_INFO=""
for raw_port in "${PORT_LIST[@]}"; do
    port="${raw_port// /}"
    [ -z "$port" ] && continue
    TUNNEL_INFO="${TUNNEL_INFO}  Local :${port} → ${BORE_SERVER}:???\n"
done

# ── Send startup notification ──────────────────────────────────────────────────
HOSTNAME="${HOSTNAME:-ghost-tunnel}"
MSG="Ghost Tunnel active on ${HOSTNAME}\n\nTunnels:\n${TUNNEL_INFO}\nServer: ${BORE_SERVER}\nPorts: ${PORTS}"
ntfy_send "🚇 Ghost Tunnel UP" "${MSG}" "default" "white_check_mark" && \
    ok "Startup notification sent to ntfy/${NTFY_TOPIC}" || \
    warn "ntfy notification failed (non-fatal)"

# ── Monitor bore processes — restart if any exits ─────────────────────────────
log "Monitoring ${#BORE_PIDS[@]} tunnel process(es)…"

while true; do
    for i in "${!BORE_PIDS[@]}"; do
        pid="${BORE_PIDS[$i]}"
        if ! kill -0 "$pid" 2>/dev/null; then
            raw_port="${PORT_LIST[$i]}"
            port="${raw_port// /}"
            warn "Tunnel for port ${port} (PID ${pid}) exited — restarting"

            sleep 2
            bore local "${port}" --to "${BORE_SERVER}" 2>&1 &
            new_pid=$!
            BORE_PIDS[$i]=$new_pid
            log "Restarted bore for port ${port} — new PID ${new_pid}"

            ntfy_send "🔄 Ghost Tunnel Reconnected" \
                "Port ${port} tunnel reconnected on ${HOSTNAME}\nServer: ${BORE_SERVER}" \
                "default" "arrows_counterclockwise" || true
        fi
    done
    sleep 10
done
