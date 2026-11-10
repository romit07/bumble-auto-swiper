#!/usr/bin/env bash
# Fix 'device offline' / hanging adb: restart the adb server and reconnect.
. "$(dirname "$0")/_common.sh"
for i in 1 2 3; do
  timeout 10 adb disconnect "$SERIAL" >/dev/null 2>&1
  timeout 10 adb kill-server >/dev/null 2>&1
  timeout 15 adb start-server >/dev/null 2>&1
  adb_connect
  if [ "$(ash echo ok 2>/dev/null | tr -d '\r')" = "ok" ]; then echo "connected: $SERIAL"; exit 0; fi
  echo "attempt $i failed; retrying in 10s"; sleep 10
done
echo "Could not reach $SERIAL. Check Tailscale on the phone (tailscale ping $PHONE_HOST)" >&2
echo "and that Wireless debugging is on after the last reboot (termux/start-adb.sh reopens 5555)." >&2
exit 1
