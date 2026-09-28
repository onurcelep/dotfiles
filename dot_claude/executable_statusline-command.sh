#!/usr/bin/env bash
# Claude Code status line - agnoster-inspired
# Reads JSON from stdin and outputs a formatted status line

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
session=$(echo "$input" | jq -r '.session_name // empty')

user_host="$(whoami)@$(hostname -s)"
dir="${cwd/#$HOME/\~}"

# Build context percentage display
ctx_part=""
if [ -n "$used" ]; then
    used_int=${used%.*}
    if [ "${used_int:-0}" -ge 80 ]; then
        ctx_part=" \033[0;31mctx:${used_int}%\033[0m"
    elif [ "${used_int:-0}" -ge 50 ]; then
        ctx_part=" \033[0;33mctx:${used_int}%\033[0m"
    else
        ctx_part=" ctx:${used_int}%"
    fi
fi

# Build session display
session_part=""
if [ -n "$session" ]; then
    session_part=" [$session]"
fi

printf "\033[0;32m%s\033[0m \033[0;34m%s\033[0m |%s%s%s" \
    "$user_host" \
    "$dir" \
    " $model" \
    "$ctx_part" \
    "$session_part"
