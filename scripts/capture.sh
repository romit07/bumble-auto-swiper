#!/usr/bin/env bash
# capture.sh -> $STATE_DIR/capture/montage.jpg
# Records the screen at low resolution while slowly scrolling through the current profile,
# then tiles ~12 frames into one image for the judge. The raw video is deleted at once
# (on the phone and on the controller); only the montage is kept until the next profile.
. "$(dirname "$0")/_common.sh"
command -v ffmpeg >/dev/null || { echo "ffmpeg not installed on the controller" >&2; exit 2; }
screen_size
W=${REC_WIDTH:-288}; H=$(( W * SCREEN_H / SCREEN_W / 2 * 2 ))
N=${SCROLLS:-6}; SECS=${REC_SECONDS:-13}
X=$(( SCREEN_W / 2 )); Y1=$(( SCREEN_H * 75 / 100 )); Y2=$(( SCREEN_H * 41 / 100 ))
rm -rf "$CAP"; mkdir -p "$CAP"
ash rm -f /sdcard/bas.mp4 >/dev/null 2>&1
( timeout $(( SECS + 15 )) adb -s "$SERIAL" shell \
    "screenrecord --size ${W}x${H} --bit-rate 150000 --time-limit $SECS /sdcard/bas.mp4" >/dev/null 2>&1 ) &
RP=$!
sleep 1.5
for _ in $(seq 1 "$N"); do ash input swipe "$X" "$Y1" "$X" "$Y2" "${SWIPE_MS:-1200}" >/dev/null 2>&1; sleep 0.6; done
wait "$RP"
timeout 90 adb -s "$SERIAL" pull /sdcard/bas.mp4 "$CAP/v.mp4" >/dev/null 2>&1
ash rm -f /sdcard/bas.mp4 >/dev/null 2>&1
[ -s "$CAP/v.mp4" ] || { echo "CAPTURE_FAILED (no video)"; exit 1; }
# crop away status bar / bottom buttons, ~0.85 fps, 6x2 grid
ffmpeg -loglevel error -y -i "$CAP/v.mp4" \
  -vf "fps=0.85,crop=iw:trunc(ih*0.75/2)*2:0:trunc(ih*0.105),tile=6x2" -frames:v 1 "$CAP/montage.jpg"
rm -f "$CAP/v.mp4"
[ -s "$CAP/montage.jpg" ] || { echo "CAPTURE_FAILED (no montage)"; exit 1; }
echo "$CAP/montage.jpg"
