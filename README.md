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

## References

- [Martin3/My-Linux-Config](https://github.com/Martins3/My-Linux-Config)
- [x56Jason/nvim](https://github.com/x56Jason/nvim)
