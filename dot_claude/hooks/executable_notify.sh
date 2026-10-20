#!/usr/bin/env bash
# Claude Code Notification hook: desktop popup plus sound naming the
# session (its topic and tmux pane). Clicking the popup switches tmux to
# the pane that raised it.
set -u
command -v notify-send >/dev/null || exit 0

input=$(cat)
msg=$(jq -r '.message // "Needs your attention"' <<<"$input")
proj=$(basename "$(jq -r '.cwd // empty' <<<"$input")")
topic=""
where=$proj
pane=${TMUX_PANE:-}

# Stay quiet when the user is already looking at this pane: it is the
# active pane of its session's current window and a client showing that
# session has terminal focus. Client focus is only tracked with tmux
# focus-events on; otherwise the flag is stale and cannot be trusted.
if [ -n "$pane" ] && [ "$(tmux show -gv focus-events 2>/dev/null)" = on ]; then
  read -r sid visible < <(tmux display -p -t "$pane" \
    '#{session_id} #{pane_active}#{window_active}' 2>/dev/null)
  if [ "$visible" = 11 ] &&
    tmux list-clients -t "$sid" -F '#{client_flags}' 2>/dev/null |
    grep -q focused; then
    exit 0
  fi
fi

if [ -n "$pane" ]; then
  # Claude Code sets the terminal title to the session topic behind a
  # status glyph (e.g. "✳ Fix login bug"); tmux keeps it as pane_title.
  topic=$(tmux display -p -t "$pane" '#{pane_title}' 2>/dev/null |
    sed -E 's/^[^[:alnum:]]+ //')
  where="$(tmux display -p -t "$pane" '#S:#I.#P' 2>/dev/null) · $proj"
fi
title="Claude: ${topic:-${proj:-session}}"
msg+=$'\n'"$where"

sound=/usr/share/sounds/freedesktop/stereo/window-attention.oga
if command -v pw-play >/dev/null && [ -f "$sound" ]; then
  # Idle outputs (HDMI/DP especially) are suspended and drop the start of a
  # stream while waking, which can swallow a short sound entirely. One second
  # of raw silence (s16, 48 kHz, stereo) wakes the sink first.
  (
    head -c 192000 /dev/zero | pw-play --raw - &
    sleep 0.8
    pw-play --volume 1.5 "$sound"
    wait
  ) </dev/null >/dev/null 2>&1 &
fi

# The click-to-pane action only works while the popup is visible, so it
# stays up longer than the desktop default (CLAUDE_NOTIFY_TIMEOUT_MS).
# notify-send --wait blocks until the popup closes, so it runs detached
# with all fds redirected or Claude Code would wait on the hook.
(
  action=$(notify-send -a "Claude Code" -i utilities-terminal \
    -t "${CLAUDE_NOTIFY_TIMEOUT_MS:-30000}" \
    ${pane:+--action=default=Open} --wait "$title" "$msg")
  if [ "$action" = default ] && [ -n "$pane" ]; then
    tmux switch-client -t "$pane" \; select-window -t "$pane" \; \
      select-pane -t "$pane"
  fi
) </dev/null >/dev/null 2>&1 &
disown
exit 0
