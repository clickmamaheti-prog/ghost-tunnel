#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#  Ghost Tunnel — Bore TCP Tunnel Manager v3.3
#  Managed by Supervisor (autorestart=true, startretries=999).
#  Fix v3.1: capture bore stdout to temp log so real remote ports can be parsed
#             and included in ntfy notifications instead of showing "???".
#  Fix v3.2: ntfy_send uses curl --retry 5 with backoff + direct -d body
#             (no tmpfile) to fix Railway container notification failures.
#  Fix v3.3: updated ntfy notification format to structured status card.
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

# ── ntfy notification via curl (v3.2: retry + direct body, no tmpfile) ─────────
# Retries up to 5 times with 3-second delay between attempts.
# Uses direct -d string to avoid tmpfile permission/mktemp issues in containers.
ntfy_send() {
    local title="$1" body="$2" priority="${3:-default}" tags="${4:-white_check_mark}"
    local code
    code=$(curl -sS \
        --retry 5 \
        --retry-delay 3 \
        --retry-all-errors \
        --connect-timeout 15 \
        --max-time 60 \
        -H "Content-Type: text/plain" \
        -H "Title: ${title}" \
        -H "Priority: ${priority}" \
        -H "Tags: ${tags}" \
        -d "${body}" \
        -o /dev/null \
        -w "%{http_code}" \
        "https://ntfy.sh/${NTFY_TOPIC}" 2>/dev/null)
    if [ "$code" = "200" ]; then
        ok "ntfy sent → ntfy.sh/${NTFY_TOPIC} (HTTP ${code})"
        return 0
    else
        warn "ntfy failed → ntfy.sh/${NTFY_TOPIC} (HTTP ${code})"
        return 1
    fi
}

# ── Parse ports list into array ────────────────────────────────────────────────
IFS=',' read -ra PORT_LIST <<< "$PORTS"

log "Starting bore tunnel manager v3.3"
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
        TUNNEL_INFO="${TUNNEL_INFO}  local :${port} → ${BORE_SERVER}:${remote_port}\n"
    else
        warn "Could not parse remote port for local :${port} — check bore log"
        TUNNEL_INFO="${TUNNEL_INFO}  local :${port} → ${BORE_SERVER}:??? (check logs)\n"
    fi
done

# ── SSH remote port (first port in PORTS list = SSH) ──────────────────────────
SSH_REMOTE_PORT="${ASSIGNED_REMOTE[0]:-???}"

# ── Uptime string ──────────────────────────────────────────────────────────────
UPTIME_STR=$(uptime | sed 's/.*up /up /' | sed 's/, [0-9]* user.*//' | sed 's/,$//')

# ── Send startup notification with structured status card ─────────────────────
MSG="🖥️ c2026 Gost tunnel linux

━━━━━━━━━━━━━━━━━━━━━━
🟢 VPS Status : ONLINE
⏱️ Uptime     : ${UPTIME_STR}

🌐 Host       : ${BORE_SERVER}
🔐 SSH        : ssh root@${BORE_SERVER} -p ${SSH_REMOTE_PORT}
👤 User       : root
🔑 Password   : ${ROOT_PASS}

━━━━━━━━━━━━━━━━━━━━━━"

ntfy_send "🖥️ c2026 Gost tunnel linux" "${MSG}" "high" "white_check_mark" && \
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

            # Update SSH_REMOTE_PORT if this is the first port (SSH port)
            [ "$i" -eq 0 ] && SSH_REMOTE_PORT="${new_remote:-???}"

            UPTIME_STR=$(uptime | sed 's/.*up /up /' | sed 's/, [0-9]* user.*//' | sed 's/,$//')

            RECONNECT_MSG="🖥️ c2026 Gost tunnel linux

━━━━━━━━━━━━━━━━━━━━━━
🔄 VPS Status : RECONNECTED
⏱️ Uptime     : ${UPTIME_STR}

🌐 Host       : ${BORE_SERVER}
🔐 SSH        : ssh root@${BORE_SERVER} -p ${new_remote:-???}
👤 User       : root
🔑 Password   : ${ROOT_PASS}

━━━━━━━━━━━━━━━━━━━━━━"

            ntfy_send "🖥️ c2026 Gost tunnel linux" \
                "${RECONNECT_MSG}" \
                "default" "arrows_counterclockwise" || true

            ok "Tunnel for port ${port} restarted → ${BORE_SERVER}:${new_remote:-???}"
        fi
    done
    sleep 10
done
