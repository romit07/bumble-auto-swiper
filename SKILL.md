---
name: bumble-auto-swiper-android
description: Set up and run a guarded Bumble auto-swiper on a non-rooted Android phone, phone-only from Termux (adb to itself over Wireless debugging, on-device SmolVLM judge) or optionally from a laptop/agent over Tailscale. Captures each profile with a slow screenrecord + ffmpeg montage, judges it against a configurable preference prompt, taps Like/Pass only after verifying Bumble and a profile card are on screen, logs every decision and cleans up. Use when asked to set up, run, fix or explain Bumble auto-swiping on Android.
---

# Bumble Auto-Swiper (Android) skill

> ⚠️ **Disclaimer: educational purposes only.** Bumble's Terms of Service prohibit automation. Using this, especially frequently, **can get the Bumble account banned**. Use it at your own risk. Tell the user this once before the first run and get their OK.

You are an agent with a shell. There are two modes; the scripts detect which one they run in:

| Mode | Where the scripts run | adb target | Judge |
|---|---|---|---|
| **Phone-only (primary)** | Termux on the phone itself | `127.0.0.1:5555` (the phone's own adbd) | `JUDGE=local` SmolVLM-256M (~50 s/profile) or `JUDGE=api` |
| Remote (optional) | Laptop / server / agent box | `$PHONE_HOST:5555` over Tailscale | `JUDGE=agent` (you look at the montage), `api`, or `local` over SSH |

Repo layout: `install.sh`, `config.example.env`, `prompt.example.txt`, `scripts/` (guarded runner + helpers), `termux/` (boot script, pairing, on-device judge).

## Ground rules (non-negotiable)
- **Never tap blind.** Before every tap or swipe, `scripts/guard.sh` must pass: Bumble is the foreground activity (`dumpsys window`) and a profile card is on screen (fresh `uiautomator dump`, old `/sdcard/ui.xml` deleted first). If it fails, stop or pause; never "try a tap anyway".
- **Stop immediately** on a like limit, paywall/premium, verification, warning or ban screen (`guard.sh` exit 3). Report it; don't work around it.
- **Never** use SuperSwipe, Boost, Spotlight, compliments or any paid feature. **Never** send messages, open chats, or edit the profile, photos or filters. Never buy anything.
- Respect the session cap (`MAX_PROFILES`, default 50). Don't raise it without the user asking.
- Skip anyone who appears under 18, always.
- Don't send screenshots/montages to the user unless asked; captures are deleted after each profile. Logs contain decision + short reason only, never names.
- Wrap every `adb` call in `timeout` (the scripts do). Don't install apps or change phone settings beyond these steps without asking. Never confirm a system software-update dialog; back out of it.
- Keep the screen awake only while working: `svc power stayon true` at start, `false` at the end (`scripts/cleanup.sh` always runs).

## Setup: phone-only (Termux) — do in order, verify each step
1. **Human:** install **Termux** and **Termux:Boot** from F-Droid (not Play Store). Open Termux:Boot once. Settings → Apps → Termux and Termux:Boot → Battery → **Unrestricted**. Install and log in to Bumble; set filters in the app by hand.
2. **Human:** Settings → About phone → Software information → tap **Build number** 7×. Developer options → **Wireless debugging ON** (requires Wi-Fi). Optional: add the Wireless debugging Quick Settings tile (Developer options → Quick settings developer tiles) for fast re-enabling after reboots.
3. In Termux:
   ```bash
   pkg install -y git && git clone https://github.com/romit07/bumble-auto-swiper ~/bumble-auto-swiper && cd ~/bumble-auto-swiper
   bash install.sh      # android-tools ffmpeg python termux-api llama-cpp, SmolVLM model, boot script, commands
   ```
   **Verify:** `command -v adb ffmpeg llama-mtmd-cli` all print paths; `ls ~/models` shows both `.gguf` files; `ls ~/.termux/boot/start-adb.sh` exists.
4. **Pair Termux's adb with its own phone** (one time). Human opens Settings → Wireless debugging in **split screen** with Termux → "Pair device with pairing code". Then run `bash termux/pair-adb.sh` and enter the pairing port, code, and the debug port (or by hand: `adb pair localhost:<pair-port> <code>`, `adb connect localhost:<debug-port>`, `adb -s localhost:<debug-port> tcpip 5555`, `adb connect 127.0.0.1:5555`). Never paste the pairing code into a public chat or log.
   **Verify:** `timeout 10 adb -s 127.0.0.1:5555 shell echo ok` prints `ok`.
5. `termux-wake-lock` (install.sh does it; the runner does it too). Edit `prompt.example.txt` (or point `PROMPT_FILE` at your own) with the user's preference rule.
   **Verify:** `bash scripts/guard.sh focus` with Bumble open prints `FOCUS_OK`.

## Setup: remote controller (optional)
1. Controller: `apt install adb ffmpeg python3` (or `brew install android-platform-tools ffmpeg`), clone the repo, `bash install.sh`.
2. Tailscale on phone and controller, same account. Put the phone's Tailscale IP/MagicDNS name in `PHONE_HOST` in `config.env`. Never expose 5555 to the internet.
3. Phone side still needs steps 1–4 above (the Termux boot script is what reopens 5555 after reboots).
   **Verify:** `./scripts/adb-reconnect.sh` prints `connected: …`.

## Running
**Automatic (Termux or remote with JUDGE=local/api):**
```bash
bumble-swipe 20          # Termux shortcut for scripts/run.sh 20 (capped at MAX_PROFILES)
```
In Termux, start it, then leave the phone alone: the script launches Bumble to the foreground and Termux keeps running in the background (wake lock + notification). If anything else comes to the front (you open Termux, a call, a dialog), the run **pauses** up to `PAUSE_WAIT` s and then stops, without tapping. Check progress afterwards with `tail state/session.log` or `bumble-step status`.

**Step mode (you, the agent, are the judge — what worked best):**
```bash
scripts/swipe.sh start                  # wake, stay-awake on, open Bumble, guard, capture -> prints montage path
# look at the montage image yourself, apply the preference rule, then:
scripts/swipe.sh decide LIKE-lean "slim in full-body shot"     # or LIKE-default / SKIP
# ...it guards, acts, logs, guards, captures the next profile and prints the new montage path
scripts/swipe.sh stop                   # ALWAYS at the end: delete captures, HOME, stay-awake off
```
Exit codes: `0` ok, `1` guard failed (wrong app / no card: stop and inspect with `scripts/ui.sh`), `3` blocker (stop and report), `5` session cap reached.

## Judging rule (example; the user's own rule goes in PROMPT_FILE)
- `LIKE-lean`: appears lean / low body fat.
- `LIKE-default`: build can't be judged (face-only, heavy/loose clothes, group shots, unclear).
- `SKIP`: clearly not lean.
- `SKIP` always: appears under 18; photos clearly fake or not matching the profile.
Reasons ≤ 12 words, no names, no descriptions of faces.

## The guarded loop (what each step does)
1. Wake `input keyevent 224`; `svc power stayon true`.
2. Guard: `dumpsys window` focus == Bumble main activity; fresh `uiautomator dump` contains `CARD_MARKER`.
3. Blocker check (`BLOCKER_REGEX`) when no card → stop.
4. Capture: low-res `screenrecord` while scrolling slowly through the profile; `ffmpeg` → 6×2 montage; video deleted.
5. Judge the montage (agent / API / on-device SmolVLM).
6. Guard again, then act: tap the real **Like** button (content-desc `Like`) or the **Pass** button on the same row, from bounds in the fresh `ui.xml`; fall back to a slow card swipe only if the button isn't found. Confirm simple "Interested?" dialogs.
7. Log `#n DECISION — reason` to `state/session.log`.
8. Cleanup at the end: delete captures and `/sdcard/ui.xml`, HOME, `svc power stayon false`.

## Lesson: why the first runner broke
An earlier runner tapped and swiped **fixed screen coordinates** without checking which app was in front. When Bumble lost focus and the phone fell back to the home screen, those coordinates landed on the launcher's **Camera** icon (and other apps), and the runner kept "deciding" on profiles it never saw, logging them as "no photo" skips. Fixes, now built in: verify foreground activity + profile card before every action, find buttons from the live UI dump instead of hard-coded positions, stop instead of guessing, and treat a missing photo as a failure, not a decision.

## Recovery playbook
1. `adb` hangs / `offline` → `scripts/adb-reconnect.sh`.
2. Phone rebooted → ask the human to turn **Wireless debugging** on (tile). `~/.termux/boot/start-adb.sh` reopens 5555 within ~30–60 s (log: `~/boot-adb.log`). Fully automatic re-enable is impossible without root.
3. `GUARD_FAIL wrong foreground` → something else is in front. Run `scripts/ui.sh`, back out (KEYCODE_BACK) of dialogs like system updates, reopen Bumble, then resume with `swipe.sh start --resume`.
4. `GUARD_FAIL no profile card` → Bumble may be on another tab, out of profiles, or the UI changed. Inspect with `scripts/ui.sh`; if the card marker text changed, update `CARD_MARKER` / `LIKE_DESC` in `config.env`.
5. Blocker (exit 3) → stop, report what the screen says. Don't retry today if it's a like limit.
6. Judge too slow/wrong on device → lower `SCROLLS`, or use `JUDGE=api`, or step mode with an agent.
