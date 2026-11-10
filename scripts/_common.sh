#!/usr/bin/env bash
# Shared helpers: load config, build adb commands, screen geometry, logging.
# shellcheck disable=SC2034  # variables are used by the scripts that source this file
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
for f in "${CONFIG:-}" "$ROOT/config.env" "$HOME/.config/bumble-auto-swiper/config.env"; do
  if [ -n "$f" ] && [ -f "$f" ]; then set -a; # shellcheck disable=SC1090
    . "$f"; set +a; break; fi
done
# Where are we running? Termux on the phone itself (primary) or a laptop/server (optional).
if [ -n "${TERMUX_VERSION:-}" ] || [ "${PREFIX:-}" = /data/data/com.termux/files/usr ]; then
  ON_TERMUX=1; : "${PHONE_HOST:=127.0.0.1}"     # Termux talks to its own phone's adbd
else
  ON_TERMUX=0
fi
: "${PHONE_HOST:?Set PHONE_HOST in config.env (see config.example.env)}"
case "$PHONE_HOST" in "<"*">") echo "PHONE_HOST is still a placeholder in config.env" >&2; exit 2;; esac
ADB_PORT="${ADB_PORT:-5555}"
SERIAL="$PHONE_HOST:$ADB_PORT"
T="${ADB_TIMEOUT:-25}"
BUMBLE_PKG="${BUMBLE_PKG:-com.bumble.app}"
BUMBLE_ACTIVITY="${BUMBLE_ACTIVITY:-com.bumble.app.ui.main.AppMainActivity}"
CARD_MARKER="${CARD_MARKER:-main photo}"
LIKE_DESC="${LIKE_DESC:-Like}"
BLOCKER_REGEX="${BLOCKER_REGEX:-limit|out of likes|come back|premium|subscribe|upgrade|verif|banned|suspend|blocked|warning|log in|sign in}"
MAX_PROFILES="${MAX_PROFILES:-50}"
SWIPE_MS="${SWIPE_MS:-1200}"
STATE_DIR="${STATE_DIR:-$ROOT/state}"
case "$STATE_DIR" in /*) ;; *) STATE_DIR="$ROOT/${STATE_DIR#./}";; esac
mkdir -p "$STATE_DIR"
LOG="$STATE_DIR/session.log"
COUNT="$STATE_DIR/count.txt"
CAP="$STATE_DIR/capture"
UIXML="$STATE_DIR/ui.xml"

adb_connect() { timeout 15 adb connect "$SERIAL" >/dev/null 2>&1; }
# Always wrap adb in timeout: a half-dead connection can hang forever.
ash() { timeout "$T" adb -s "$SERIAL" shell "$@"; }
aexec() { timeout "$T" adb -s "$SERIAL" exec-out "$@"; }

# Screen size, e.g. "1080 2340" (override with SCREEN_W / SCREEN_H in config.env)
screen_size() {
  if [ -z "${SCREEN_W:-}" ] || [ -z "${SCREEN_H:-}" ]; then
    local s
    s=$(ash wm size 2>/dev/null | tr -d '\r' | grep -oE '[0-9]+x[0-9]+' | tail -1)
    SCREEN_W=${s%x*}; SCREEN_H=${s#*x}
    : "${SCREEN_W:=1080}" "${SCREEN_H:=2340}"
  fi
}

DISCLAIMER="NOTICE: educational use only. Bumble's terms prohibit automation; frequent use may get your account banned. Use at your own risk."

ts() { date '+%Y-%m-%d %H:%M:%S %Z'; }
log() { echo "[$(ts)] $*" >> "$LOG"; }
