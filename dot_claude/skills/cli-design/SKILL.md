---
name: cli-design
description: >
  CLI/TUI application design guidelines. Use when implementing command-line
  interfaces, adding commands/flags/subcommands, designing output formatting,
  error messages, help text, configuration, or any user-facing terminal behavior.
  Triggers on: new CLI commands, argument parsing, output design, error handling
  in CLI context, interactive prompts, progress indicators, signal handling.
---

# CLI Application Design Guidelines

Based on [Command Line Interface Guidelines](https://clig.dev/) and
[The Art of Command Line](https://github.com/jlevy/the-art-of-command-line).

Apply these principles when building or modifying CLI/TUI applications.
When a guideline conflicts with project-specific conventions, project conventions win.

---

## Philosophy

- **Human-first**: design for humans, not machines. Machines get `--json`/`--plain`.
- **Composable**: stdin/stdout/stderr, exit codes, signals. Your program is a building block.
- **Consistent**: follow existing terminal conventions. Only break them intentionally.
- **Say just enough**: no output looks broken; too much output is noise.
- **Discoverable**: help text, examples, suggested next commands.
- **Empathetic**: guide users through errors, confirm dangerous operations.
- **Robust**: handle unexpected input, crash-only design, idempotent operations.

---

## Arguments & Flags

- **Prefer flags over positional args** — clearer, more extensible, order-independent.
- **Always provide long-form flags** (`-h` AND `--help`, `-v` AND `--verbose`).
- **One-letter flags only for common operations** — don't pollute the namespace.
- Use standard names when they exist:

  | Flag | Meaning |
  |------|---------|
  | `-h, --help` | Help |
  | `-V, --version` | Version |
  | `-v, --verbose` | Verbose output |
  | `-q, --quiet` | Suppress non-essential output |
  | `-f, --force` | Skip confirmations |
  | `-n, --dry-run` | Preview without executing |
  | `-o, --output` | Output file/path |
  | `--json` | JSON output |
  | `--plain` | Machine-parseable plain text |
  | `--no-color` | Disable color |
  | `--no-input` | Disable prompts |

- **Make argument/flag/subcommand order independent** where parser allows.
- **Never accept secrets via flags** — they leak to `ps` and shell history.
  Use `--password-file`, stdin, or secret management services.
- Support `-` for stdin/stdout (e.g., `tool - < input.txt`).

> Ref: <https://clig.dev/#arguments-and-flags>

---

## Subcommands

- Use when tool is complex enough to benefit from logical grouping.
- **Be consistent**: same flag names, same output format, same verb/noun ordering.
- Pick `noun verb` or `verb noun` and stick with it (noun-verb is more common).
- **No catch-all default subcommand** — breaks future additions.
- **No arbitrary abbreviations** — creates permanent compatibility debt.
- Avoid ambiguous names (don't offer both `update` and `upgrade`).

> Ref: <https://clig.dev/#subcommands>

---

## Output

- **stdout** = primary data (pipeable). **stderr** = messages, logs, errors.
- Detect TTY with `isatty()` — adapt output for humans vs. machines.
- On success: brief confirmation of what changed + new state.
- **Show current state** when it's not obvious (like `git status`).
- **Suggest next commands** — aids discovery and learning.
- Provide `--json` for structured data, `--plain` for grep/awk-friendly tables.
- Provide `-q`/`--quiet` to suppress non-essential output for scripts.
- Use a **pager** (`less -FIRX`) for large output when stdout is a TTY.
- Actions that cross boundaries (network, filesystem) should be explicit.

> Ref: <https://clig.dev/#output>

---

## Color & Formatting

- Use color **intentionally** — highlight important info, indicate errors (red).
- Disable color when ANY of:
  - stdout/stderr is not a TTY
  - `NO_COLOR` env var is set (respect <https://no-color.org/>)
  - `TERM=dumb`
  - `--no-color` flag passed
- Support `FORCE_COLOR` to override TTY detection.
- Disable animations in non-interactive contexts (CI logs).
- Symbols/emoji are fine when they add clarity, not decoration.

> Ref: <https://clig.dev/#output>

---

## Errors

- **Rewrite expected errors for humans** — include what went wrong and how to fix it.
- Put the most important info **last** (where the eye lands).
- Use red sparingly — draws attention to what matters.
- Group similar errors under a header instead of repeating.
- For unexpected errors: include debug info + bug report instructions.
- Write verbose debug info to a **file**, not the terminal.

> Ref: <https://clig.dev/#errors>

---

## Help Text

- Show help on: `tool`, `tool -h`, `tool --help`, `tool help [subcommand]`.
- When args required but missing: show **concise** help (description + 1-2 examples + pointer to `--help`).
- In full `--help`:
  - **Lead with examples** — users prefer examples over prose.
  - Show common flags/commands first.
  - Use formatting (bold, sections) for scannability.
  - Link to web docs (specific anchors).
- **Suggest corrections** on invalid input (don't auto-correct silently).
- If expecting piped stdin but terminal is interactive: show help and quit.

> Ref: <https://clig.dev/#help>

---

## Interactivity

- **Only prompt when stdin is a TTY** — detect with `isatty()`.
- `--no-input` disables all prompts (fail with message about required flags).
- Never echo passwords.
- **Make Ctrl-C always work** — exit promptly, say something before cleanup.
- Make it clear how to exit (don't be vim).
- Prompt for missing arguments, but **never require** a prompt (always offer flag alternative).

### Dangerous Operations

| Risk Level | Action |
|------------|--------|
| Mild (small local change) | Optional `-y` confirmation |
| Moderate (larger/remote change) | Prompt for `y/n` |
| Severe (delete complex resources) | Hard confirm: type resource name |

Always offer `--dry-run` and `--force` to skip confirmation.

> Ref: <https://clig.dev/#interactivity>

---

## Progress & Performance

- **Print something within 100ms** — silence feels broken.
- Print a message **before** network/slow operations.
- Use spinners or progress bars for long operations (include ETA when possible).
- Make operations **recoverable** — rerun should pick up where it left off.
- **Timeouts**: never hang forever. Make network timeouts configurable.
- Libraries: `tqdm` (Python), `rich.progress` (Python), `indicatif` (Rust).

> Ref: <https://clig.dev/#robustness>

---

## Exit Codes & Signals

- **0** = success, **non-zero** = failure.
- Map distinct non-zero codes to meaningful failure modes.
- On **Ctrl-C** (SIGINT): exit immediately, print brief message, timeout cleanup.
- On second Ctrl-C during cleanup: skip remaining cleanup.
- **Crash-only design**: avoid cleanup requirements, defer to next run.

> Ref: <https://clig.dev/#signals-and-control-characters>

---

## Configuration

**Precedence** (highest to lowest):
1. Flags
2. Environment variables (current shell)
3. Project-level config (`.env`, project config file)
4. User-level config (`~/.config/tool/`)
5. System-wide config

### When to use what

| Type | Mechanism |
|------|-----------|
| Per-invocation (debug, dry-run) | Flags, env vars |
| Per-project (paths, preferences) | Flags, env vars, config file |
| Shared across users in project | Version-controlled config file |

- Follow **XDG Base Directory Specification** (`~/.config/`, `~/.local/share/`).
- If modifying config you don't own: **ask consent**, explain what you're doing.
- Read `.env` for project-local env vars (but don't use it as a config substitute).

> Ref: <https://clig.dev/#configuration>

---

## Environment Variables

- **Uppercase letters, numbers, underscores only** (no leading digit).
- Keep values single-line.
- Don't commandeer widely-used names (check POSIX list).
- **Never store secrets in env vars** — they leak to child processes, logs, `docker inspect`.
- Respect these standard variables:
  - `NO_COLOR`, `FORCE_COLOR` — color control
  - `DEBUG` — verbose output
  - `EDITOR` — preferred editor
  - `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY` — network
  - `PAGER` — output paging
  - `TMPDIR`, `HOME`, `SHELL`, `TERM`, `COLUMNS`, `LINES`

> Ref: <https://clig.dev/#environment-variables>

---

## Naming

- Simple, memorable, lowercase word.
- Dashes OK if needed (`my-tool`), no CamelCase.
- Short but not too short (reserve 2-3 letter names for core utils).
- Easy to type (consider keyboard ergonomics).
- Don't collide with existing common commands.

> Ref: <https://clig.dev/#naming>

---

## Composability (Unix)

- **Expect your output to become input for unknown programs** (Doug McIlroy).
- Text line-by-line is the universal interface.
- Support null-delimited output (`-0`, `-print0`) for safe filename handling.
- Work cleanly with `xargs`, `find`, pipes, and redirection.
- Minimize external dependencies; prefer POSIX-compatible behavior.

> Ref: <https://github.com/jlevy/the-art-of-command-line>

---

## Future-Proofing

- Subcommands, flags, config keys, env vars are **interfaces** — breaking them requires deprecation.
- **Keep changes additive** — new flag rather than modifying old one.
- **Warn on deprecated usage** — show migration path, stop warning once migrated.
- Human-readable output can change freely; machine output (`--json`, `--plain`) is a contract.
- Don't create time bombs (external service dependencies that will disappear).

> Ref: <https://clig.dev/#future-proofing>

---

## Distribution

- Single binary if possible (or language-native installer).
- Make uninstall easy — document it next to install instructions.

---

## Checklist

When implementing CLI features, verify:

- [ ] Flags have both short and long forms where appropriate
- [ ] `--help` is comprehensive with examples
- [ ] Errors include what went wrong + how to fix
- [ ] Output goes to correct stream (stdout vs stderr)
- [ ] Color/formatting respects `NO_COLOR` and TTY detection
- [ ] Dangerous operations have confirmation (with `--force` escape hatch)
- [ ] Long operations show progress
- [ ] Exit codes are meaningful
- [ ] Ctrl-C exits promptly
- [ ] Secrets never appear in flags or env vars
- [ ] Config follows XDG and precedence rules
- [ ] Machine-readable output available (`--json` or `--plain`)
- [ ] No breaking changes to existing interface without deprecation

---

*Full references:*
- *CLI Guidelines: <https://clig.dev/>*
- *The Art of Command Line: <https://github.com/jlevy/the-art-of-command-line>*
