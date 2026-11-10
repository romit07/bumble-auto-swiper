#!/usr/bin/env bash
# guard.sh [focus]
# Exit 0 only if Bumble is the foreground app AND (unless "focus") a profile card is showing.
# Exit 1 = wrong app / no card, exit 3 = blocker screen (limit, paywall, verification, ban...).
# Run this before EVERY tap or swipe. Blind taps are how the first runner ended up in Camera.
. "$(dirname "$0")/_common.sh"
adb_connect
F=$(ash dumpsys window 2>/dev/null | tr -d '\r' | grep -m1 mCurrentFocus)
if ! echo "$F" | grep -q "$BUMBLE_PKG/$BUMBLE_ACTIVITY"; then
  echo "GUARD_FAIL wrong foreground: ${F:-unknown}"; exit 1
fi
[ "${1:-}" = focus ] && { echo FOCUS_OK; exit 0; }
"$(dirname "$0")/ui.sh" > "$STATE_DIR/guard.txt" 2>/dev/null
if grep -q "$CARD_MARKER" "$STATE_DIR/guard.txt"; then echo CARD_OK; exit 0; fi
if grep -qiE "$BLOCKER_REGEX" "$STATE_DIR/guard.txt"; then
  echo "BLOCKER:"; grep -iE "$BLOCKER_REGEX" "$STATE_DIR/guard.txt" | head -5; exit 3
fi
echo "GUARD_FAIL no profile card on screen"; exit 1
