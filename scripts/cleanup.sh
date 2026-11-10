#!/usr/bin/env bash
# Always run at the end (run.sh / swipe.sh stop call it): delete captures and UI dumps on the
# phone and locally, go HOME, and let the screen sleep again. Keeps state/session.log.
. "$(dirname "$0")/_common.sh"
adb_connect
ash 'rm -f /sdcard/ui.xml /sdcard/bas.mp4' >/dev/null 2>&1
rm -rf "$CAP" "$UIXML" "$STATE_DIR/guard.txt"
ash input keyevent KEYCODE_HOME >/dev/null 2>&1
ash svc power stayon false >/dev/null 2>&1
echo "cleanup done (captures deleted, HOME, stay-awake off)"
