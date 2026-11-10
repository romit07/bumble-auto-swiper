#!/data/data/com.termux/files/usr/bin/bash
# Termux:Boot script (installed to ~/.termux/boot/ by install.sh).
# Android turns Wireless debugging OFF at every reboot and a non-rooted app cannot turn it
# back on (`settings put global adb_wifi_enabled 1` needs INTERACT_ACROSS_USERS).
# So: YOU toggle Wireless debugging on once after a reboot (Quick Settings tile helps), and
# this script notices within ~30 s, finds the random debug port with Termux's already-paired
# adb, and switches adbd to the fixed port 5555 (127.0.0.1:5555 for Termux, Tailscale IP:5555
# for an optional laptop).
exec 8>"$HOME/.start-adb.lock"; flock -n 8 || exit 0
LOG="$HOME/boot-adb.log"; MAXWAIT=${MAXWAIT:-5400}
log() { echo "$(date '+%F %T %Z') $*" >> "$LOG"; }
termux-wake-lock 2>/dev/null
log "start-adb: started"
settings put global adb_wifi_enabled 1 >/dev/null 2>&1 && log "adb_wifi_enabled set (unexpected: you have the permission)"
adb start-server >/dev/null 2>&1
tcp_open() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }
is_dev() { timeout 10 adb -s "127.0.0.1:$1" get-state 2>/dev/null | grep -q device; }
try_port() {
  if ! { timeout 10 adb connect "127.0.0.1:$1" 2>&1 | grep -q "connected to" && is_dev "$1"; }; then
    adb disconnect "127.0.0.1:$1" >/dev/null 2>&1; return 1
  fi
  log "wireless debugging on port $1 -> adb tcpip 5555"
  timeout 20 adb -s "127.0.0.1:$1" tcpip 5555 >> "$LOG" 2>&1
  adb disconnect "127.0.0.1:$1" >/dev/null 2>&1; sleep 4
  timeout 10 adb connect 127.0.0.1:5555 >/dev/null 2>&1
  if tcp_open 5555; then log "SUCCESS: 5555 open"; else log "tcpip sent, 5555 not open yet"; fi
  return 0
}
start=$(date +%s); n=0
while [ $(( $(date +%s) - start )) -lt "$MAXWAIT" ]; do
  if tcp_open 5555 && timeout 10 adb connect 127.0.0.1:5555 2>&1 | grep -q connected && is_dev 5555; then
    log "5555 already serving adb"; exit 0; fi
  # fast path: mDNS advertises the TLS debug port
  for p in $(timeout 10 adb mdns services 2>/dev/null | grep -i '_adb-tls-connect' | grep -oE ':[0-9]+' | tr -d ':'); do
    try_port "$p" && exit 0
  done
  # slow path: scan the range Android picks the random port from
  for p in $(seq 30000 49999); do tcp_open "$p" || continue; try_port "$p" && exit 0; done
  n=$((n + 1)); [ $((n % 5)) -eq 1 ] && log "waiting: turn on Wireless debugging (Developer options / Quick Settings tile)"
  sleep 30
done
log "gave up after ${MAXWAIT}s"
