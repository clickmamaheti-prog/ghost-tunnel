#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#  Ghost Tunnel — ntfy Notification Helper v3.2
#  Usage: notify.sh "Title" "Body" [priority] [tags]
#
#  v3.2 fix: --retry 5 --retry-delay 3 --retry-all-errors + direct -d body
#            (no tmpfile) to fix Railway container notification failures.
# ══════════════════════════════════════════════════════════════════════════════
set -e

NTFY_TOPIC="${NTFY_TOPIC:-ghost-mail}"
TITLE="${1:-Ghost Tunnel}"
BODY="${2:-Notification}"
PRIORITY="${3:-default}"
TAGS="${4:-white_check_mark}"

if [ -z "$NTFY_TOPIC" ]; then
    echo "[notify] ERROR: NTFY_TOPIC is not set" >&2
    exit 1
fi

code=$(curl -sS \
    --retry 5 \
    --retry-delay 3 \
    --retry-all-errors \
    --connect-timeout 15 \
    --max-time 60 \
    -H "Content-Type: text/plain" \
    -H "Title: ${TITLE}" \
    -H "Priority: ${PRIORITY}" \
    -H "Tags: ${TAGS}" \
    -d "${BODY}" \
    -o /dev/null \
    -w "%{http_code}" \
    "https://ntfy.sh/${NTFY_TOPIC}" 2>/dev/null)

if [ "$code" = "200" ]; then
    echo "[notify] Sent → ntfy.sh/${NTFY_TOPIC} (HTTP ${code})"
else
    echo "[notify] Failed → ntfy.sh/${NTFY_TOPIC} (HTTP ${code})" >&2
    exit 1
fi
