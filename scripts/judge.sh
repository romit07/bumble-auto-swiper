#!/usr/bin/env bash
# judge.sh <montage.jpg>  -> prints 2 lines: LIKE-lean|LIKE-default|SKIP, then a short reason.
# JUDGE=api   -> scripts/judge-api.py (OpenAI-compatible vision endpoint, uses PROMPT_FILE)
# JUDGE=local -> Termux: runs termux/judge-profile.sh directly. Laptop: copies the image to
#                the phone and runs the same script there over SSH.
# JUDGE=agent -> not automatic: the agent looks at the image itself (see SKILL.md)
. "$(dirname "$0")/_common.sh"
IMG="${1:?usage: judge.sh <image>}"
case "${JUDGE:-agent}" in
  api)
    python3 "$HERE/judge-api.py" "$IMG" ;;
  local)
    if [ "$ON_TERMUX" = 1 ]; then        # phone-only mode: run llama.cpp right here
      bash "$ROOT/termux/judge-profile.sh" "$IMG" || { printf 'LIKE-default\njudge failed\n'; exit 1; }
      exit 0
    fi
    : "${SSH_USER:?set SSH_USER}" "${SSH_KEY:?set SSH_KEY}"
    KEY="${SSH_KEY/#\~/$HOME}"
    SSHO=(-i "$KEY" -p "${SSH_PORT:-8022}" -o BatchMode=yes -o ConnectTimeout=15)
    timeout 60 scp -q -i "$KEY" -P "${SSH_PORT:-8022}" -o BatchMode=yes "$IMG" "$SSH_USER@$PHONE_HOST:judge-in.jpg" || { printf 'LIKE-default\njudge copy failed\n'; exit 1; }
    timeout 600 ssh "${SSHO[@]}" "$SSH_USER@$PHONE_HOST" 'bash ~/bumble-auto-swiper/termux/judge-profile.sh ~/judge-in.jpg; rm -f ~/judge-in.jpg' \
      || { printf 'LIKE-default\njudge failed\n'; exit 1; } ;;
  *)
    echo "JUDGE=agent: open $IMG and decide yourself, then run: scripts/swipe.sh decide <LIKE-lean|LIKE-default|SKIP> \"reason\"" >&2
    exit 4 ;;
esac
