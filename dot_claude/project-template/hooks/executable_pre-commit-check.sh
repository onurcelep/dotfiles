#!/usr/bin/env bash
# Stop hook: blocks session completion if pre-commit fails in any repo under the
# project directory that has uncommitted changes.
#
# Wired via .claude/settings.json hooks.Stop.

INPUT=$(cat)

# Required: prevent infinite loops when the hook itself triggers a response.
if [ "$(echo "$INPUT" | jq -r '.stop_hook_active // false')" = "true" ]; then
    exit 0
fi

WORKSPACE="${CLAUDE_PROJECT_DIR:-$(echo "$INPUT" | jq -r '.cwd // empty')}"
[ -d "$WORKSPACE" ] || exit 0

# pre-commit runner: prefer the repo's uv environment, fall back to PATH.
run_pre_commit() {
    if { [ -f "uv.lock" ] || [ -f "pyproject.toml" ]; } && command -v uv >/dev/null 2>&1; then
        uv run pre-commit run --all-files
    elif [ -x ".venv/bin/pre-commit" ]; then
        .venv/bin/pre-commit run --all-files
    elif command -v pre-commit >/dev/null 2>&1; then
        pre-commit run --all-files
    else
        return 0
    fi
}

mapfile -t REPOS < <(
    find "$WORKSPACE" -maxdepth 2 -name ".pre-commit-config.yaml" -type f \
        -exec dirname {} \; | sort
)

OUT=$(mktemp)
trap 'rm -f "$OUT"' EXIT
FAILED=()

for REPO in "${REPOS[@]}"; do
    # Skip repos with no uncommitted changes: pre-commit would be a no-op.
    if git -C "$REPO" diff --quiet HEAD 2>/dev/null && \
       git -C "$REPO" diff --cached --quiet 2>/dev/null; then
        continue
    fi

    cd "$REPO" || continue

    # First pass: some hooks (ruff, trailing-whitespace) auto-fix in place.
    run_pre_commit > "$OUT" 2>&1
    STATUS=$?

    if [ $STATUS -ne 0 ]; then
        # Second pass: verify the auto-fixes resolved everything.
        run_pre_commit >> "$OUT" 2>&1
        STATUS=$?
    fi

    if [ $STATUS -ne 0 ]; then
        FAILED+=("$(basename "$REPO")")
        echo "=== pre-commit failures in $(basename "$REPO") ===" >&2
        cat "$OUT" >&2
    fi
done

if [ ${#FAILED[@]} -gt 0 ]; then
    REPOS_STR=$(IFS=', '; echo "${FAILED[*]}")
    printf '{"decision":"block","reason":"Pre-commit checks failed in: %s. Review the output above and fix all issues before completing."}\n' \
        "$REPOS_STR"
fi

exit 0
