#!/bin/bash
# ─────────────────────────────────────────────
#  Ghost Tunnel — ntfy.sh Notification Helper
# ─────────────────────────────────────────────

NTFY_BASE="https://ntfy.sh"

ntfy_send() {
  local topic="${1:-temp-mail1}"
  local title="${2:-Ghost Tunnel}"
  local message="${3:-}"
  local priority="${4:-default}"
  local tags="${5:-ghost}"

  curl -s -X POST "${NTFY_BASE}/${topic}" \
    -H "Title: ${title}" \
    -H "Priority: ${priority}" \
    -H "Tags: ${tags}" \
    -d "${message}" \
    > /dev/null 2>&1 && return 0 || return 1
}

ntfy_info() {
  ntfy_send "$NTFY_TOPIC" "$1" "$2" "default" "information"
}

ntfy_success() {
  ntfy_send "$NTFY_TOPIC" "$1" "$2" "high" "white_check_mark"
}

ntfy_error() {
  ntfy_send "$NTFY_TOPIC" "$1" "$2" "urgent" "warning"
}
