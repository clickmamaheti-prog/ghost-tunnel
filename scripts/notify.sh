#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#  Ghost Tunnel — ntfy Notification Helper v3.0
#  Usage: notify.sh "Title" "Body" [priority] [tags]
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

tmpfile=$(mktemp /tmp/ntfy_XXXXXX.txt)
printf '%s' "$BODY" > "$tmpfile"

code=$(curl -sS \
    --connect-timeout 20 \
    --max-time 60 \
    -H "Title: ${TITLE}" \
    -H "Priority: ${PRIORITY}" \
    -H "Tags: ${TAGS}" \
    --data-binary "@${tmpfile}" \
    -o /dev/null \
    -w "%{http_code}" \
    "https://ntfy.sh/${NTFY_TOPIC}" 2>/dev/null)

rm -f "$tmpfile"

if [ "$code" = "200" ]; then
    echo "[notify] Sent → ntfy.sh/${NTFY_TOPIC} (HTTP ${code})"
else
    echo "[notify] Failed → ntfy.sh/${NTFY_TOPIC} (HTTP ${code})" >&2
    exit 1
fi
