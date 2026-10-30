# yadm dotfiles

The repository is laid out as the target `$HOME` tree. yadm owns configuration files directly; bootstrap only provisions packages, external projects, services, and privileged system integration.

## Profiles

`.config/yadm/bootstrap` selects one yadm `local.class`:

- `Base`
- `Kde`
- `Niri`
- `Hyprland`

Profile-specific files use yadm alternates (for example `##class.Niri`). After selecting the class, bootstrap runs `yadm alt` before provisioning.

## HyDE ownership

HyDE and yadm must never write the same path.

- HyDE owns files declared as `sync` by HyDE, including its runtime data under `~/.local/share/hypr`.
- yadm owns HyDE user extension points declared as `preserve`, plus user Waybar modules under `~/.config/waybar/modules`.
- The two HyDE-synchronized Zsh entry files (`~/.zshenv` and `~/.config/zsh/.zshenv`) are intentionally absent from the `Hyprland` class.
- Niri's standalone Waybar configuration exists only as `##class.Niri` alternates, so it cannot shadow HyDE's preserved Waybar configuration.

## Bootstrap

Bootstrap stages are independent and ordered:

```text
.config/yadm/bootstrap
└── bootstrap.d/
    ├── 10-packages   # base packages
    ├── 20-desktop    # KDE / Niri / HyDE profile
    ├── 30-user       # shell, tmux, Claude, shared skills, crontab
    ├── 34-antigravity # Antigravity CLI installation and settings
    ├── 35-mcp        # MCP registration
    └── 40-system     # binaries and systemd integration
```

Shared package-manager primitives live in `.config/yadm/lib/`. Do not add config-copy or symlink deployment code back into bootstrap; if a file belongs in `$HOME`, track it at that path with yadm.

## Migrating from the legacy layout

The legacy layout kept most configuration under `~/Config` and `~/Scripts`, then deployed it with symlinks or copies. The current layout tracks the final `$HOME` paths directly with yadm; `Scripts/install.sh` is intentionally gone.

For an existing checkout, do not force the update over local files. First inspect local changes, fetch `main`, and remove only legacy symlinks that still point into `~/Config`:

```bash
yadm status --short
yadm fetch origin

for link in \
  "$HOME/.config/nvim" \
  "$HOME/.config/zsh" \
  "$HOME/.config/niri" \
  "$HOME/.config/waybar" \
  "$HOME/.config/swaylock" \
  "$HOME/.config/fastfetch" \
  "$HOME/.gdbinit" \
  "$HOME/.gitconfig" \
  "$HOME/.tmux.conf" \
  "$HOME/.tmux.conf.local"
do
  [ -L "$link" ] || continue
  target=$(readlink -- "$link") || continue

  case "$target" in
    "$HOME/Config"/*) rm -- "$link" ;;
  esac
done

yadm pull --ff-only
```

If Git reports an untracked path that would be overwritten, move that path to a backup first and retry; do not use a forced checkout as a migration shortcut.

Then select the target profile and run the new staged bootstrap:

```bash
YADM_CLASS=Base yadm bootstrap
# or: Kde / Niri / Hyprland
```

After the first successful run, verify `yadm status --short`. Bootstrap must not mutate tracked files.

## AI skills and Pensieve

Bootstrap installs one user-level Pensieve source at
`~/.claude/skills/pensieve/`. Codex and Antigravity CLI use symlinks at
`~/.agents/skills/pensieve` and
`~/.gemini/antigravity-cli/skills/pensieve`, respectively. Existing
unrelated skills are never overwritten.

The user-scope `.config/agents/AGENTS.md` instructs the **main agent** to
check `<repo>/.pensieve/state.md` on its first substantive task in each
writable Git project. When no `.pensieve/` exists, the agent is authorized
to initialize that specific project using:

```bash
pensieve-init --project "$HOME/src/my-project"
```

Neither Bootstrap, startup hooks, nor subagents initialize projects.
Existing incomplete `.pensieve/` data must not be overwritten.
Non-Git directories, nested directory paths and `$HOME` are rejected.
The live yadm working tree is deliberately excluded because it is rooted
at `$HOME`.

The obsolete Pensieve Claude marketplace plugin is no longer installed
by Bootstrap; users with an older installation may remove it using
`claude plugin uninstall pensieve@kingkongshot-marketplace`.

## Antigravity CLI

The `34-antigravity` stage installs Google's official `agy` CLI on
supported Linux/macOS hosts if it is missing. An existing installation
is preserved. App-owned `~/.gemini/antigravity-cli/settings.json`
is seeded once from a version-controlled template, using the
`request-review` permission policy; later user changes are preserved.

The CLI reads the already managed global `~/.gemini/AGENTS.md`,
`logic-adversary` agent and shared Pensieve skill. The `35-mcp` stage
adds available MCP definitions from `.config/agents/mcp.json` into
Antigravity's global configuration, without overwriting existing entries.
Runtime settings, MCP credentials and authentication remain app-owned.
Run `agy` interactively to authenticate on first launch.

For regression checks, run `bash tests/test-pensieve-scope.sh` and
`bash tests/test-antigravity-scope.sh`.

## Lightweight engineering Harness

User-scope `AGENTS.md` routes engineering tasks into FAST / STANDARD /
CRITICAL paths. It reuses the existing `logic-adversary` for bounded
pre-implementation review, and installs `harness-verify` plus
`failure-to-eval` as on-demand Skills for Claude Code, Codex and
Antigravity CLI. Each client gets a link to one yadm-owned source under
`~/.config/agents/skills/`; generated links are ignored by yadm. No separate
reviewer Agent is added.

For this dotfile repository, `~/.config/yadm/agent/contract.md` defines
ownership and verification requirements. The read-only verification entry is:

```bash
bash ~/.config/yadm/verify/run.sh --level quick
bash ~/.config/yadm/verify/run.sh --level standard
bash ~/.config/yadm/verify/run.sh --level critical
```

Quick checks syntax, JSON and diff hygiene. Standard also runs isolated
scope tests; critical reports QEMU integration NOT RUN (exit 2) until a
specific guest-side validation is executed. No Git Hook, full QEMU run,
automatic Skill generation or background Agent is installed.

The first known integration gaps are recorded under
`~/.config/yadm/agent/evals/`; an observation is not called a passing
regression test until an executable check demonstrates it.

## Testing

- [QEMU full test matrix](docs/QEMU_TESTING.md) — OS group × desktop profile, ownership, idempotency, reboot, GUI, and negative-contract tests.
- `.github/workflows/hydevm-preflight.yml` — fast Arch + Hyprland / HyDE ownership preflight.

## References

- [Martin3/My-Linux-Config](https://github.com/Martins3/My-Linux-Config)
- [x56Jason/nvim](https://github.com/x56Jason/nvim)
