#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#  Ghost Tunnel — Bore TCP Tunnel Manager v3.1
#  Managed by Supervisor (autorestart=true, startretries=999).
#  Fix v3.1: capture bore stdout to temp log so real remote ports can be parsed
#             and included in ntfy notifications instead of showing "???".
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

log "Starting bore tunnel manager v3.1"
log "Server : ${BORE_SERVER}"
log "Ports  : ${PORTS}"

# ── Temp log dir for capturing bore output ─────────────────────────────────────
BORE_LOG_DIR=$(mktemp -d /tmp/bore_logs_XXXXXX)

# ── Start one bore process per port, capturing output to per-port log file ────
BORE_PIDS=()
BORE_LOGS=()

for raw_port in "${PORT_LIST[@]}"; do
    port="${raw_port// /}"
    [ -z "$port" ] && continue

    logfile="${BORE_LOG_DIR}/bore_${port}.log"
    log "Opening tunnel → ${BORE_SERVER}:? ← local :${port} (log: $logfile)"

    bore local "${port}" --to "${BORE_SERVER}" > "$logfile" 2>&1 &
    pid=$!
    BORE_PIDS+=($pid)
    BORE_LOGS+=("$logfile")
    log "bore PID $pid started for port ${port}"
    sleep 0.3
done

# ── Wait for bore to connect and print assigned remote port ───────────────────
# bore prints a line like: "listening at bore.pub:XXXXX" within a few seconds.
log "Waiting for bore tunnels to report assigned remote ports…"
sleep 8

# ── Parse real assigned remote ports from bore output logs ────────────────────
TUNNEL_INFO=""
declare -a ASSIGNED_REMOTE=()

for i in "${!PORT_LIST[@]}"; do
    raw_port="${PORT_LIST[$i]}"
    port="${raw_port// /}"
    [ -z "$port" ] && continue

    logfile="${BORE_LOG_DIR}/bore_${port}.log"
    remote_port=""

    if [ -f "$logfile" ]; then
        # bore output: "... listening at bore.pub:XXXXX" (case-insensitive match)
        remote_port=$(grep -oi "listening at [^:]*:\([0-9]*\)" "$logfile" 2>/dev/null \
            | grep -o '[0-9]*$' | head -1)

        # Fallback: any 4-5 digit number that looks like a high port
        if [ -z "$remote_port" ]; then
            remote_port=$(grep -o '[0-9]\{4,5\}' "$logfile" 2>/dev/null \
                | grep -v "^${port}$" | head -1)
        fi

        # Log raw bore output for debug
        if [ -s "$logfile" ]; then
            log "bore output for port ${port}: $(head -5 "$logfile" | tr '\n' ' ')"
        else
            warn "bore log for port ${port} is empty — bore may not have connected yet"
        fi
    fi

    ASSIGNED_REMOTE+=("${remote_port:-???}")

    if [ -n "$remote_port" ] && [ "$remote_port" != "???" ]; then
        ok "Tunnel ready: local :${port} → ${BORE_SERVER}:${remote_port}"
        TUNNEL_INFO="${TUNNEL_INFO}  SSH / local :${port} → ${BORE_SERVER}:${remote_port}\n"
    else
        warn "Could not parse remote port for local :${port} — check bore log"
        TUNNEL_INFO="${TUNNEL_INFO}  local :${port} → ${BORE_SERVER}:??? (check ntfy for updates)\n"
    fi
done

# ── Send startup notification with real port info ──────────────────────────────
HOSTNAME="${HOSTNAME:-ghost-tunnel}"
MSG="Ghost Tunnel active on ${HOSTNAME}\n\nTunnels:\n${TUNNEL_INFO}\nServer: ${BORE_SERVER}\nPorts: ${PORTS}"
ntfy_send "🚇 Ghost Tunnel UP" "${MSG}" "default" "white_check_mark" && \
    ok "Startup notification sent to ntfy/${NTFY_TOPIC}" || \
    warn "ntfy notification failed (non-fatal)"

# ── Monitor bore processes — restart any that exit ────────────────────────────
log "Monitoring ${#BORE_PIDS[@]} tunnel process(es)…"

while true; do
    for i in "${!BORE_PIDS[@]}"; do
        pid="${BORE_PIDS[$i]}"
        if ! kill -0 "$pid" 2>/dev/null; then
            raw_port="${PORT_LIST[$i]}"
            port="${raw_port// /}"
            warn "Tunnel for port ${port} (PID ${pid}) exited — restarting"

            sleep 2

            # Restart bore, capturing output to a fresh log
            logfile="${BORE_LOG_DIR}/bore_${port}.log"
            : > "$logfile"   # truncate log
            bore local "${port}" --to "${BORE_SERVER}" > "$logfile" 2>&1 &
            new_pid=$!
            BORE_PIDS[$i]=$new_pid
            log "Restarted bore for port ${port} — new PID ${new_pid}"

            # Wait a moment then re-parse new port
            sleep 6
            new_remote=""
            if [ -f "$logfile" ]; then
                new_remote=$(grep -oi "listening at [^:]*:\([0-9]*\)" "$logfile" 2>/dev/null \
                    | grep -o '[0-9]*$' | head -1)
                [ -z "$new_remote" ] && new_remote=$(grep -o '[0-9]\{4,5\}' "$logfile" 2>/dev/null \
                    | grep -v "^${port}$" | head -1)
            fi
            ASSIGNED_REMOTE[$i]="${new_remote:-???}"

            ntfy_send "🔄 Ghost Tunnel Reconnected" \
                "Port ${port} reconnected on ${HOSTNAME}\nNew remote: ${BORE_SERVER}:${new_remote:-???}\nServer: ${BORE_SERVER}" \
                "default" "arrows_counterclockwise" || true

            ok "Tunnel for port ${port} restarted → ${BORE_SERVER}:${new_remote:-???}"
        fi
    done
    sleep 10
done
