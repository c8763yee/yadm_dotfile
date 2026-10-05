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
    ├── 30-user       # shell, tmux, Claude, crontab
    └── 40-system     # binaries and systemd integration
```

Shared package-manager primitives live in `.config/yadm/lib/`. Do not add config-copy or symlink deployment code back into bootstrap; if a file belongs in `$HOME`, track it at that path with yadm.

## Migrating from the legacy layout

The legacy layout kept most configuration under `~/Config` and `~/Scripts`, then deployed it with symlinks or copies. The current layout tracks the final `$HOME` paths directly with yadm; `Scripts/install.sh` is intentionally gone.

For an existing checkout, do not force the update over local files. First inspect local changes, fetch `main`, and remove only legacy symlinks that still point into `~/Config`:

```bash
yadm status --short
yadm fetch origin

for path in \
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
  [ -L "$path" ] || continue
  case "$(readlink -f -- "$path")" in
    "$HOME/Config"/*) rm -- "$path" ;;
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

## Testing

- [QEMU full test matrix](docs/QEMU_TESTING.md) — OS group × desktop profile, ownership, idempotency, reboot, GUI, and negative-contract tests.
- `.github/workflows/hydevm-preflight.yml` — fast Arch + Hyprland / HyDE ownership preflight.

## References

- [Martin3/My-Linux-Config](https://github.com/Martins3/My-Linux-Config)
- [x56Jason/nvim](https://github.com/x56Jason/nvim)
