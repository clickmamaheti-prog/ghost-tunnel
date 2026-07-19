#!/bin/bash
# ─────────────────────────────────────────────
#  Ghost Tunnel — Multi-Port Bore Tunnel Manager
# ─────────────────────────────────────────────
set +e

GT_LOG() {
  local level="$1"; shift
  echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] [tunnel] $*"
}

INFO()    { GT_LOG "INFO   " "$*"; }
SUCCESS() { GT_LOG "SUCCESS" "$*"; }
WARN()    { GT_LOG "WARN   " "$*"; }
ERROR()   { GT_LOG "ERROR  " "$*" >&2; }

BORE_SERVER="${BORE_SERVER:-bore.pub}"
PORTS="${PORTS:-22}"
NTFY_TOPIC="${NTFY_TOPIC:-temp-mail1}"
ROOT_PASS="${ROOT_PASS:-Kosay378%}"
TUNNEL_DIR="/tmp/ghost-tunnels"
RECONNECT_DELAY=5
MAX_BACKOFF=60

mkdir -p "$TUNNEL_DIR"

# ─── Parse port list ──────────────────────────
IFS=',' read -ra PORT_LIST <<< "$PORTS"
INFO "Managing tunnels for ports: ${PORT_LIST[*]}"

declare -A TUNNEL_PIDS
declare -A TUNNEL_ADDRS
declare -A BACKOFF

# ─── Start a single bore tunnel ───────────────
start_tunnel() {
  local port="$1"
  local log_file="$TUNNEL_DIR/bore_${port}.log"
  rm -f "$log_file"

  INFO "Starting bore tunnel: localhost:$port -> $BORE_SERVER"
  bore local "$port" --to "$BORE_SERVER" > "$log_file" 2>&1 &
  TUNNEL_PIDS[$port]=$!
  BACKOFF[$port]="${BACKOFF[$port]:-$RECONNECT_DELAY}"
  INFO "bore PID ${TUNNEL_PIDS[$port]} for port $port"
}

# ─── Wait for tunnel address ──────────────────
wait_for_addr() {
  local port="$1"
  local log_file="$TUNNEL_DIR/bore_${port}.log"
  local addr=""
  for i in $(seq 1 30); do
    sleep 2
    addr=$(grep -oP "listening at \K\S+:\d+" "$log_file" 2>/dev/null | head -1)
    if [ -n "$addr" ]; then
      echo "$addr"
      return 0
    fi
    # Check if process died
    if ! kill -0 "${TUNNEL_PIDS[$port]:-0}" 2>/dev/null; then
      WARN "bore for port $port died during startup"
      return 1
    fi
  done
  return 1
}

# ─── Send startup notification ────────────────
send_startup_notif() {
  local msg="Ghost Tunnel AKTIF!\n\n"
  local has_tunnel=0

  for port in "${PORT_LIST[@]}"; do
    if [ -n "${TUNNEL_ADDRS[$port]:-}" ]; then
      local addr="${TUNNEL_ADDRS[$port]}"
      local host="${addr%:*}"
      local rport="${addr##*:}"
      msg+="Port $port → ssh root@${host} -p ${rport}\n"
      has_tunnel=1
    fi
  done

  msg+="Password: ${ROOT_PASS}\nWaktu: $(date -u '+%H:%M UTC')"

  if [ "$has_tunnel" = "1" ]; then
    curl -s -X POST "https://ntfy.sh/${NTFY_TOPIC}" \
      -H "Title: Ghost Tunnel Aktif" \
      -H "Priority: high" \
      -H "Tags: ghost,computer" \
      -d "$(echo -e "$msg")" > /dev/null 2>&1
    SUCCESS "Notification sent to ntfy.sh/$NTFY_TOPIC"
  fi
}

# ─── Initial startup: start all tunnels ───────
SUCCESS "Initializing tunnels..."
for port in "${PORT_LIST[@]}"; do
  port=$(echo "$port" | tr -d ' ')
  [ -z "$port" ] && continue
  start_tunnel "$port"
  sleep 1
done

# Wait for all tunnels to get addresses
INFO "Waiting for tunnel addresses..."
sleep 5
for port in "${PORT_LIST[@]}"; do
  port=$(echo "$port" | tr -d ' ')
  [ -z "$port" ] && continue
  addr=$(wait_for_addr "$port")
  if [ -n "$addr" ]; then
    TUNNEL_ADDRS[$port]="$addr"
    SUCCESS "Port $port → bore.pub:${addr##*:}"
    BACKOFF[$port]=$RECONNECT_DELAY
  else
    ERROR "Port $port → tunnel failed to start"
    WARN "log: $(cat "$TUNNEL_DIR/bore_${port}.log" 2>/dev/null | tail -3 | tr '\n' ' ')"
  fi
done

send_startup_notif

# ─── Main watchdog loop ───────────────────────
INFO "Entering watchdog loop (checking every 15s)..."
while true; do
  sleep 15
  changed=0

  for port in "${PORT_LIST[@]}"; do
    port=$(echo "$port" | tr -d ' ')
    [ -z "$port" ] && continue

    pid="${TUNNEL_PIDS[$port]:-0}"

    if ! kill -0 "$pid" 2>/dev/null; then
      backoff="${BACKOFF[$port]:-$RECONNECT_DELAY}"
      WARN "Port $port tunnel died (PID=$pid). Reconnecting in ${backoff}s..."
      sleep "$backoff"

      # Exponential backoff (cap at MAX_BACKOFF)
      next=$((backoff * 2))
      [ "$next" -gt "$MAX_BACKOFF" ] && next=$MAX_BACKOFF
      BACKOFF[$port]=$next

      start_tunnel "$port"
      sleep 3

      addr=$(wait_for_addr "$port")
      if [ -n "$addr" ]; then
        old="${TUNNEL_ADDRS[$port]:-}"
        TUNNEL_ADDRS[$port]="$addr"
        SUCCESS "Port $port reconnected → bore.pub:${addr##*:}"
        BACKOFF[$port]=$RECONNECT_DELAY
        changed=1
      else
        ERROR "Port $port reconnect failed"
        TUNNEL_ADDRS[$port]=""
      fi
    fi
  done

  # If any tunnel changed, resend notification
  if [ "$changed" = "1" ]; then
    INFO "Tunnels changed — sending update notification..."
    send_startup_notif
  fi
done
