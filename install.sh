#!/usr/bin/env bash
# One-command setup.
#   Termux (phone-only, recommended):  bash install.sh
#   Laptop / server (optional remote): bash install.sh
# Safe to re-run. Asks before downloading the ~280 MB on-device model.
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"; cd "$ROOT" || exit 1
[ -f config.env ] || cp config.example.env config.env
chmod +x scripts/*.sh scripts/*.py termux/*.sh 2>/dev/null
if [ -n "${TERMUX_VERSION:-}" ] || [ "${PREFIX:-}" = /data/data/com.termux/files/usr ]; then
  echo "== Termux detected: phone-only mode =="
  pkg update -y && pkg install -y android-tools ffmpeg python termux-api curl util-linux
  pkg install -y llama-cpp || echo "!! llama-cpp package unavailable on this arch; JUDGE=api still works"
  command -v llama-mtmd-cli >/dev/null || echo "!! llama-mtmd-cli not found; update Termux packages or use JUDGE=api"
  M="$HOME/models"; mkdir -p "$M"
  HF=https://huggingface.co/ggml-org/SmolVLM-256M-Instruct-GGUF/resolve/main
  if [ ! -f "$M/SmolVLM-256M-Instruct-Q8_0.gguf" ] || [ ! -f "$M/mmproj-SmolVLM-256M-Instruct-Q8_0.gguf" ]; then
    read -rp "Download SmolVLM-256M (~280 MB) for the on-device judge? [Y/n] " yn
    if [ "${yn:-Y}" != n ] && [ "${yn:-Y}" != N ]; then
      curl -L --fail -o "$M/SmolVLM-256M-Instruct-Q8_0.gguf" "$HF/SmolVLM-256M-Instruct-Q8_0.gguf"
      curl -L --fail -o "$M/mmproj-SmolVLM-256M-Instruct-Q8_0.gguf" "$HF/mmproj-SmolVLM-256M-Instruct-Q8_0.gguf"
    fi
  fi
  mkdir -p "$HOME/.termux/boot"
  cp termux/start-adb.sh "$HOME/.termux/boot/start-adb.sh"; chmod +x "$HOME/.termux/boot/start-adb.sh"
  BIN="$PREFIX/bin"
  ln -sf "$ROOT/scripts/run.sh" "$BIN/bumble-swipe"
  ln -sf "$ROOT/scripts/swipe.sh" "$BIN/bumble-step"
  ln -sf "$ROOT/scripts/cleanup.sh" "$BIN/bumble-stop"
  termux-wake-lock 2>/dev/null
  echo
  echo "Next:"
  echo " 1. Settings > Apps > Termux (and Termux:Boot) > Battery > Unrestricted. Open Termux:Boot once."
  echo " 2. Pair adb once:  bash termux/pair-adb.sh   (Wireless debugging in split screen)"
  echo " 3. Check:          adb -s 127.0.0.1:5555 shell echo ok"
  echo " 4. Run:            bumble-swipe 20      (then switch to nothing - leave Bumble in front)"
else
  echo "== Laptop/server detected: remote controller mode =="
  for t in adb ffmpeg python3; do command -v $t >/dev/null || echo "!! missing: $t  (apt install adb ffmpeg python3 | brew install android-platform-tools ffmpeg)"; done
  echo "Edit config.env: set PHONE_HOST to the phone's Tailscale IP / MagicDNS name, then:"
  echo "  ./scripts/adb-reconnect.sh && ./scripts/run.sh 20     (or step mode: ./scripts/swipe.sh start)"
fi
