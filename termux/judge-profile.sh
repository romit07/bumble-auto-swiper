#!/data/data/com.termux/files/usr/bin/bash
# On-device judge: SmolVLM-256M via llama.cpp (llama-mtmd-cli) in Termux. No internet needed.
# usage: judge-profile.sh <image>   -> line 1 LIKE-lean|LIKE-default|SKIP, line 2 reason
# ~50 s per question-set on a mid-range phone. A 256M model is rough: it follows the
# "like by default when unsure" rule, so expect more LIKE-default than a big cloud model.
set -u
IMG="${1:-}"
[ -f "$IMG" ] || { printf 'LIKE-default\nno image to judge\n'; exit 1; }
MODEL_DIR="${MODEL_DIR:-$HOME/models}"; MODEL_DIR="${MODEL_DIR/#\~/$HOME}"
MODEL="${MODEL:-$MODEL_DIR/SmolVLM-256M-Instruct-Q8_0.gguf}"
MMPROJ="${MMPROJ:-$MODEL_DIR/mmproj-SmolVLM-256M-Instruct-Q8_0.gguf}"
BIN="${LLAMA_BIN:-llama-mtmd-cli}"
command -v "$BIN" >/dev/null || { printf 'LIKE-default\nllama-mtmd-cli missing (pkg install llama-cpp)\n'; exit 1; }
[ -f "$MODEL" ] && [ -f "$MMPROJ" ] || { printf 'LIKE-default\nmodel files missing (run install.sh)\n'; exit 1; }

ask() {  # $1 prompt -> upper-case short answer
  "$BIN" -m "$MODEL" --mmproj "$MMPROJ" --image "$IMG" -p "$1" -n 8 --temp 0.05 -c 2048 \
    -t "${LLAMA_THREADS:-4}" 2>/dev/null | tr -d '\r' | sed '/^[[:space:]]*$/d' | tail -2 | tr '\n' ' ' | tr '[:lower:]' '[:upper:]'
}

A=$(ask "Does this image show real photographs of a person? Answer only YES or NO.")
echo "$A" | grep -q YES || { printf 'SKIP\nno real person in photos\n'; exit 0; }
A=$(ask "Does the person look younger than 18 years old? Answer only YES or NO.")
echo "$A" | grep -q YES && { printf 'SKIP\nmay be under 18\n'; exit 0; }
A=$(ask "Is the person's body clearly visible, and do they look slim or lean? Answer only YES, NO, or UNSURE.")
if echo "$A" | grep -q UNSURE; then printf 'LIKE-default\nbuild unclear\n'
elif echo "$A" | grep -q YES; then printf 'LIKE-lean\nlooks lean\n'
elif echo "$A" | grep -q NO; then
  B=$(ask "Does this person clearly look overweight? Answer only YES or NO.")
  if echo "$B" | grep -q YES; then printf 'SKIP\nclearly not lean\n'; else printf 'LIKE-default\nbuild unclear\n'; fi
else printf 'LIKE-default\nmodel unsure\n'; fi
