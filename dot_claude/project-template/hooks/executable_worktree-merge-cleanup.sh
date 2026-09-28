#!/usr/bin/env bash
# .claude/hooks/worktree-merge-cleanup.sh
#
# PostToolUse hook: runs after Bash tool calls. When a `git merge worktree-*`
# command is detected, cleans up ghost files left in the working directory.
#
# Problem: When a worktree branch moves/deletes files (git mv, git rm) and is
# merged back, the parent working directory may retain the old files as
# untracked copies. This hook removes them automatically.

INPUT=$(cat)

# Only act on Bash tool uses
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')
[ "$TOOL" = "Bash" ] || exit 0

# Only act on successful commands
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_result.exit_code // "1"')
[ "$EXIT_CODE" = "0" ] || exit 0

# Only act on git merge of worktree branches
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
if ! echo "$COMMAND" | grep -qE 'git merge worktree-'; then
    exit 0
fi

# Extract the repo directory from the command (handles cd prefix or cwd)
REPO_DIR=$(echo "$INPUT" | jq -r '.cwd // empty')
if echo "$COMMAND" | grep -qE '^cd\s+'; then
    REPO_DIR=$(echo "$COMMAND" | sed -E 's/^cd\s+([^ ;&&]+).*/\1/')
fi
[ -d "$REPO_DIR" ] || exit 0

# Clean untracked files that are likely ghost copies from worktree file moves
cd "$REPO_DIR" || exit 0

# Get list of untracked files (excluding .claude/ and other dotfiles)
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null)
[ -n "$UNTRACKED" ] || exit 0

# Only remove files that exist in the committed tree under a different path
# (i.e., they were moved, not newly created)
CLEANED=()
while IFS= read -r file; do
    [ -f "$file" ] || continue
    basename=$(basename "$file")
    # Check if the same filename exists elsewhere in the committed tree
    if git ls-files --error-unmatch "**/$basename" >/dev/null 2>&1; then
        # File exists in the index under a different path — this is a ghost copy
        if ! git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
            rm -f "$file"
            CLEANED+=("$file")
        fi
    fi
done <<< "$UNTRACKED"

if [ ${#CLEANED[@]} -gt 0 ]; then
    echo "Worktree cleanup: removed ${#CLEANED[@]} ghost file(s)" >&2
    printf '  %s\n' "${CLEANED[@]}" >&2
fi

exit 0
