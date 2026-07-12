# icaro-personal-computer-setup

Everything needed to rebuild my macOS machine. Configuration files live in this repo, and an interactive installer symlinks them into place and installs the tools they depend on.

Configs are grouped in topic modules — the layout used by most dotfiles repos — and placed as **symlinks**, so this repo stays the single source of truth: edit any config where it lives, see the change with `git diff`, commit, push. A plain bash script does the work because it needs no extra tooling (unlike [Stow](https://www.gnu.org/software/stow/) or [chezmoi](https://www.chezmoi.io)) and gives exact control over backups.

## Layout

```
├── install.sh           interactive installer
├── claude/              Claude Code → ~/.claude/*
│   ├── CLAUDE.md
│   ├── RTK.md
│   ├── settings.json
│   ├── statusline.sh
│   └── hooks/notify.sh
├── wezterm/
│   └── wezterm.lua      → ~/.wezterm.lua
└── zsh/
    ├── zshrc            → ~/.zshrc
    ├── zprofile         → ~/.zprofile
    └── p10k.zsh         → ~/.p10k.zsh
```

## Requirements

- macOS
- git (`xcode-select --install`)

Everything else — including Homebrew — is detected and offered by the installer when missing.

## Install

```bash
git clone git@github.com:icarogtavares/icaro-personal-computer-setup.git
cd icaro-personal-computer-setup
./install.sh
```

Running it without arguments opens the menu:

```
icaro-personal-computer-setup

  1) claude    Claude Code config (CLAUDE.md, settings, statusline, hooks) + rtk, jq
  2) wezterm   WezTerm config + app and Nerd Fonts
  3) zsh       Oh My Zsh, powerlevel10k, plugins, fzf/eza/bat/zoxide + zsh dotfiles
  a) all
  q) quit

Select modules to install (e.g. "1 3", "zsh", "a"):
```

Non-interactive:

```bash
./install.sh --all                     # everything
./install.sh zsh wezterm               # specific modules
./install.sh --list                    # module names
SETUP_SKIP_DEPS=1 ./install.sh --all   # only link configs, install nothing
```

The installer is idempotent — run it as many times as you want; anything already installed or already linked is skipped.

Because configs are symlinks into this repo, keep the clone in a permanent location.

## Modules

| Module | Links into `$HOME` | Installs when missing |
| --- | --- | --- |
| `claude` | `~/.claude/CLAUDE.md`, `~/.claude/RTK.md`, `~/.claude/settings.json`, `~/.claude/statusline.sh`, `~/.claude/hooks/notify.sh` | [rtk](https://www.rtk-ai.app/), `jq`, [Claude Code](https://claude.ai/code) |
| `wezterm` | `~/.wezterm.lua` | [WezTerm](https://wezterm.org), MesloLGS / Hack / Symbols Nerd Fonts |
| `zsh` | `~/.zshrc`, `~/.zprofile`, `~/.p10k.zsh` | [Oh My Zsh](https://ohmyz.sh), [powerlevel10k](https://github.com/romkatv/powerlevel10k), [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions), [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting), `fzf`, `eza`, `bat`, `zoxide` |

Only individual files are linked into `~/.claude/` — the rest of that directory is machine state (projects, history, caches) and stays out of git.

## Backups: nothing is ever deleted

When a real file already exists where a symlink should go, it is renamed in place:

```
~/.zshrc  →  ~/.zshrc-backup
~/.zshrc  →  ~/.zshrc-backup-20260712153000   (when a backup already exists)
```

To restore an original: delete the symlink, rename the backup back.

## Machine-local overrides

`~/.zshrc` sources `~/.zshrc.local` when it exists. Put machine-specific exports and secrets there — that file is never tracked by this repo.

## Updating configs

The live files are symlinks, so edit them wherever is convenient (`vim ~/.zshrc` or in the repo) — either way the repo sees the change:

```bash
git diff
git add -p && git commit
```

One exception: Claude Code sometimes rewrites `settings.json` (e.g. through `/config`), which can replace the symlink with a regular file. Re-run `./install.sh claude` — the rewritten file is kept as `settings.json-backup`, the link is restored, and you can diff the backup against the repo copy to decide what to keep.

## Adding a new module

1. Create a directory with the config files (non-hidden names).
2. Add the name to `MODULES` and a line to `describe_module` in `install.sh`.
3. Write an `install_<name>` function: dependency checks first, then `link_file "$REPO_DIR/<module>/<file>" "$HOME/<dotfile>"` calls.

## After installing

- Open a new terminal (or WezTerm) so zsh loads the linked configs.
- Run `claude` and log in on first use.
- If prompt glyphs look wrong, run `p10k configure` once.
