#!/usr/bin/env bash
# Fully automatic guarded loop:  scripts/run.sh [N]   (N defaults to MAX_PROFILES, never above it)
# For each profile: guard -> capture -> judge -> guard -> act -> log. Stops on any blocker.
# In Termux, Termux keeps running in the background while Bumble is in the foreground.
# If another app comes to the front (you opened Termux, a call, a notification...), the run
# PAUSES for up to PAUSE_WAIT seconds waiting for Bumble to come back, then stops. It never
# taps anything outside Bumble.
. "$(dirname "$0")/_common.sh"
S="$(dirname "$0")"
echo "$DISCLAIMER"
[ "${JUDGE:-local}" = agent ] && { echo "JUDGE=agent is step mode: use scripts/swipe.sh (see SKILL.md)" >&2; exit 2; }
N="${1:-$MAX_PROFILES}"; [ "$N" -gt "$MAX_PROFILES" ] && N=$MAX_PROFILES
[ "$ON_TERMUX" = 1 ] && command -v termux-wake-lock >/dev/null && termux-wake-lock
trap '"$S/cleanup.sh"; log "=== session end: $done_n decisions, $likes likes, $skips skips ($why) ==="; [ "$ON_TERMUX" = 1 ] && command -v termux-wake-unlock >/dev/null && termux-wake-unlock' EXIT
done_n=0; likes=0; skips=0; why="finished"
adb_connect || { why="adb not connected"; echo "adb can't reach $SERIAL - run scripts/adb-reconnect.sh"; exit 1; }
ash input keyevent 224 >/dev/null 2>&1
ash svc power stayon true >/dev/null 2>&1
ash monkey -p "$BUMBLE_PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
sleep 6
log "=== auto session start: target $N, judge ${JUDGE:-local} ==="

wait_guard() {   # $1 = full|focus ; returns guard rc after optional pause
  local waited=0 rc
  while :; do
    if [ "$1" = focus ]; then "$S/guard.sh" focus >/dev/null; rc=$?; else "$S/guard.sh" >/dev/null; rc=$?; fi
    [ $rc -ne 1 ] && return $rc
    [ $waited -ge "${PAUSE_WAIT:-60}" ] && return 1
    [ $waited -eq 0 ] && echo "paused: Bumble not in front / no card; waiting up to ${PAUSE_WAIT:-60}s"
    sleep 10; waited=$((waited + 10))
  done
}

while [ $done_n -lt "$N" ]; do
  wait_guard full; rc=$?
  [ $rc -eq 3 ] && { why="blocker screen (limit/paywall/verification/ban)"; "$S/guard.sh"; break; }
  [ $rc -ne 0 ] && { why="Bumble profile card not on screen"; break; }
  IMG=$("$S/capture.sh" | tail -1) || { why="capture failed"; break; }
  [ -s "$IMG" ] || { why="capture failed"; break; }
  OUT=$("$S/judge.sh" "$IMG"); D=$(echo "$OUT" | head -1 | tr -d '\r'); R=$(echo "$OUT" | sed -n 2p | tr -d '\r')
  case "$D" in LIKE-lean|LIKE-default) A=like;; SKIP) A=pass;; *) D=LIKE-default; A=like; R="judge gave no answer";; esac
  rm -rf "$CAP"
  wait_guard full; rc=$?                 # re-check right before acting: never tap blind
  [ $rc -eq 3 ] && { why="blocker screen"; break; }
  [ $rc -ne 0 ] && { why="Bumble profile card not on screen before action"; break; }
  "$S/act.sh" "$A" >/dev/null
  done_n=$((done_n + 1)); if [ "$A" = like ]; then likes=$((likes + 1)); else skips=$((skips + 1)); fi
  echo "$done_n" > "$COUNT"
  log "#$done_n $D — ${R:-no reason}"
  echo "#$done_n/$N $D — ${R:-no reason}"
done
echo "done: $done_n decisions ($likes likes, $skips skips) - $why"
[ "$ON_TERMUX" = 1 ] && command -v termux-notification >/dev/null && \
  termux-notification --title "Bumble run finished" --content "$done_n decisions: $likes likes, $skips skips ($why)" >/dev/null 2>&1
exit 0
