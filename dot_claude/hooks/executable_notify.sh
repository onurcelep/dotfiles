#!/usr/bin/env bash
# Claude Code Notification hook: desktop popup plus sound naming the
# session (project and tmux window). Clicking the popup switches tmux to
# the pane that raised it.
set -u
command -v notify-send >/dev/null || exit 0

input=$(cat)
msg=$(jq -r '.message // "Needs your attention"' <<<"$input")
proj=$(basename "$(jq -r '.cwd // empty' <<<"$input")")
title="Claude: ${proj:-session}"
pane=${TMUX_PANE:-}
if [ -n "$pane" ]; then
  title+=" [$(tmux display -p -t "$pane" '#S:#I #W' 2>/dev/null)]"
fi

sound=/usr/share/sounds/freedesktop/stereo/message-new-instant.oga
if command -v pw-play >/dev/null && [ -f "$sound" ]; then
  pw-play "$sound" </dev/null >/dev/null 2>&1 &
fi

# notify-send --wait blocks until the popup is closed, so it must run
# detached with all fds redirected or Claude Code waits on the hook.
(
  action=$(notify-send -a "Claude Code" -i utilities-terminal \
    ${pane:+--action=default=Open} --wait "$title" "$msg")
  if [ "$action" = default ] && [ -n "$pane" ]; then
    tmux switch-client -t "$pane" \; select-window -t "$pane" \; \
      select-pane -t "$pane"
  fi
) </dev/null >/dev/null 2>&1 &
disown
exit 0
