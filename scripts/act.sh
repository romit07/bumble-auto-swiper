#!/usr/bin/env bash
# act.sh like|pass
# Taps the real Like / Pass button found in a fresh UI dump. Falls back to a slow card swipe
# only when the button can't be found. Then clears simple confirmation dialogs.
# Never call this without guard.sh passing first (swipe.sh does that for you).
. "$(dirname "$0")/_common.sh"
A="${1:-}"; case "$A" in like|pass) ;; *) echo "usage: act.sh like|pass" >&2; exit 2;; esac
screen_size
"$(dirname "$0")/ui.sh" >/dev/null 2>&1
XY=$(python3 - "$UIXML" "$A" "$LIKE_DESC" "$SCREEN_W" "$SCREEN_H" <<'P'
import re, sys, xml.etree.ElementTree as ET
path, act, like_desc, W, H = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), int(sys.argv[5])
like, cands = None, []
try:
    for n in ET.parse(path).iter('node'):
        b = list(map(int, re.findall(r'\d+', n.get('bounds') or '')))
        if len(b) != 4: continue
        if n.get('content-desc') == like_desc: like = b
        if n.get('clickable') == 'true': cands.append(b)
except Exception:
    pass
if like and like[3] > H * 0.85:      # button hidden behind nav bar / sheet: don't trust it
    like = None
if like:
    if act == 'like':
        print((like[0] + like[2]) // 2, (like[1] + like[3]) // 2)
    else:                              # Pass = clickable on the same row, left side
        for b in cands:
            if b[1] == like[1] and b[3] == like[3] and b[0] < W * 0.37:
                print((b[0] + b[2]) // 2, (b[1] + b[3]) // 2); break
P
)
if [ -n "$XY" ]; then
  echo "BUTTON $A $XY"
  # shellcheck disable=SC2086
  ash input tap $XY
else
  L=$(( SCREEN_W * 23 / 100 )); R=$(( SCREEN_W * 88 / 100 )); Y=$(( SCREEN_H * 47 / 100 )); Y2=$(( SCREEN_H * 49 / 100 ))
  echo "SWIPE $A (button not found)"
  if [ "$A" = like ]; then ash input swipe "$L" "$Y" "$R" "$Y2" "${CARD_SWIPE_MS:-600}"
  else ash input swipe "$R" "$Y" "$L" "$Y2" "${CARD_SWIPE_MS:-600}"; fi
fi
sleep 4
# Confirmation dialogs ("Interested?" etc.): tap the positive button by id, max 3 times.
for _ in 1 2 3; do
  "$(dirname "$0")/ui.sh" >/dev/null 2>&1
  B=$(python3 - "$UIXML" <<'P'
import re, sys, xml.etree.ElementTree as ET
try:
    for n in ET.parse(sys.argv[1]).iter('node'):
        if (n.get('resource-id') or '').endswith('button1') and (n.get('text') or '').upper() in ('YES', 'OK', 'NOT INTERESTED'):
            b = list(map(int, re.findall(r'\d+', n.get('bounds'))))
            print((b[0] + b[2]) // 2, (b[1] + b[3]) // 2); break
except Exception:
    pass
P
)
  [ -z "$B" ] && break
  echo "DIALOG confirmed at $B"
  # shellcheck disable=SC2086
  ash input tap $B; sleep 4
done
