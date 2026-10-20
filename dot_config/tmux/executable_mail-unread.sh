#!/usr/bin/env bash
# Print the unread count of one IMAP folder for the tmux status bar.
# Prints nothing when unconfigured or unreachable. The server is
# queried at most once per MAIL_UNREAD_INTERVAL seconds; tmux redraws the
# status far more often.
#
# Settings live in ~/.config/mail-unread.conf (kept out of dotfiles):
#   MAIL_UNREAD_URL=imaps://mail.example.org/
#   MAIL_UNREAD_USER=me
#   MAIL_UNREAD_CRED_CMD="secret-tool lookup service imap user me"
set -u
conf=${XDG_CONFIG_HOME:-$HOME/.config}/mail-unread.conf
[ -r "$conf" ] || exit 0
. "$conf"
interval=${MAIL_UNREAD_INTERVAL:-60}
cache=${XDG_RUNTIME_DIR:-/tmp}/mail-unread.$(id -u)

if [ -f "$cache" ] &&
  [ $(($(date +%s) - $(stat -c %Y "$cache"))) -lt "$interval" ]; then
  count=$(cat "$cache")
else
  pw=$(eval "$MAIL_UNREAD_CRED_CMD" 2>/dev/null) || exit 0
  pw=${pw//\\/\\\\}
  pw=${pw//\"/\\\"}
  # Credentials reach curl through its stdin config, never its arguments,
  # so they do not show up in the process list.
  reply=$(printf 'user = "%s:%s"\n' "$MAIL_UNREAD_USER" "$pw" |
    curl -s --max-time 10 --config - --url "$MAIL_UNREAD_URL" \
      -X "STATUS ${MAIL_UNREAD_FOLDER:-INBOX} (UNSEEN)")
  count=$(sed -n 's/.*UNSEEN \([0-9][0-9]*\).*/\1/p' <<<"$reply")
  printf '%s' "$count" >"$cache"
fi
[ -n "$count" ] && printf '%s' "$count"
exit 0
