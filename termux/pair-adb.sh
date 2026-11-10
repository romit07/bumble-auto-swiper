#!/data/data/com.termux/files/usr/bin/bash
# One-time: pair Termux's adb with this same phone, then switch to the fixed port 5555.
# Open Settings > Developer options > Wireless debugging in SPLIT SCREEN (or pop-up view)
# with Termux, tap "Pair device with pairing code", and keep that dialog open.
set -u
echo "Wireless debugging > Pair device with pairing code (keep the dialog open in split screen)."
read -rp "Pairing port shown under 'IP address & Port' in the pairing dialog: " PP
read -rp "6-digit pairing code: " CODE
timeout 30 adb pair "localhost:$PP" "$CODE" || { echo "pairing failed - code expires quickly, try again"; exit 1; }
echo "Paired. Now the main Wireless debugging screen shows 'IP address & Port' (a different port)."
read -rp "Debug port from the main Wireless debugging screen: " DP
timeout 15 adb connect "localhost:$DP" || exit 1
timeout 20 adb -s "localhost:$DP" tcpip 5555
sleep 4
timeout 15 adb connect 127.0.0.1:5555
timeout 10 adb devices
echo "If you see '127.0.0.1:5555  device' you're done. (Accept any 'Allow USB debugging?' prompt.)"
