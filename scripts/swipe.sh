#!/usr/bin/env bash
# Step-by-step mode for an AI agent (or a human) that judges each montage itself.
#   swipe.sh start [--resume]           wake, stay-awake, open Bumble, guard, capture 1st profile
#   swipe.sh decide <LIKE-lean|LIKE-default|SKIP> "reason"
#                                       guard -> act -> log -> guard -> capture next profile
#   swipe.sh status                     counts so far
#   swipe.sh stop                       cleanup (delete captures, HOME, stay-awake off)
# Exit codes: 0 ok, 1 guard failed (wrong app / no card), 3 blocker screen, 5 session cap reached.
. "$(dirname "$0")/_common.sh"
S="$(dirname "$0")"
next_capture() {
  "$S/guard.sh"; rc=$?; [ $rc -ne 0 ] && { log "STOP: guard rc=$rc before capture"; exit $rc; }
  "$S/capture.sh" || exit 1
  "$S/guard.sh" focus >/dev/null || { echo "GUARD_FAIL after capture"; exit 1; }
}
case "${1:-}" in
  start)
    echo "$DISCLAIMER"
    [ "${2:-}" = --resume ] || echo 0 > "$COUNT"
    adb_connect || true
    ash input keyevent 224 >/dev/null 2>&1          # KEYCODE_WAKEUP
    ash svc power stayon true >/dev/null 2>&1       # only while working; stop/cleanup turns it off
    ash monkey -p "$BUMBLE_PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
    sleep 5
    log "=== session start (cap $MAX_PROFILES) ==="
    next_capture ;;
  decide)
    D="${2:-}"; R="${3:-no reason}"
    case "$D" in LIKE-lean|LIKE-default) A=like;; SKIP) A=pass;; *) echo "decision must be LIKE-lean|LIKE-default|SKIP" >&2; exit 2;; esac
    n=$(( $(cat "$COUNT" 2>/dev/null || echo 0) + 1 ))
    [ "$n" -gt "$MAX_PROFILES" ] && { echo "CAP_REACHED $MAX_PROFILES"; exit 5; }
    "$S/guard.sh"; rc=$?; [ $rc -ne 0 ] && { log "STOP: guard rc=$rc before action"; exit $rc; }
    rm -rf "$CAP"
    "$S/act.sh" "$A"
    echo "$n" > "$COUNT"
    log "#$n $D — $R"
    echo "#$n logged"
    [ "$n" -ge "$MAX_PROFILES" ] && { echo "CAP_REACHED $MAX_PROFILES"; exit 5; }
    next_capture ;;
  status)
    echo "decisions: $(cat "$COUNT" 2>/dev/null || echo 0) / $MAX_PROFILES"
    for k in LIKE-lean LIKE-default SKIP; do echo "$k: $(grep -c " $k " "$LOG" 2>/dev/null)"; done ;;
  stop)
    "$S/cleanup.sh"; log "=== session end: $(cat "$COUNT" 2>/dev/null || echo 0) decisions ===" ;;
  *) sed -n '2,9p' "$0"; exit 2 ;;
esac
