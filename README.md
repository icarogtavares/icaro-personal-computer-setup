# Icaro's PC Setup

Main goals:
1. Everything needed to rebuild my macOS machine.
2. Configuration files live in this repo
3. An interactive installer symlinks them into place and installs the tools they depend on.

Configs are grouped in topic modules and placed as **symlinks**, so this repo stays the single source of truth: edit any config where it lives, see the change with `git diff`, commit, push.

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

Running it without arguments opens a checkbox menu — toggle modules with the number keys, then press enter:

```
icaro-personal-computer-setup

  [x] 1. claude     Claude Code config (CLAUDE.md, settings, statusline, hoo
  [ ] 2. wezterm    WezTerm config + app and Nerd Fonts
  [x] 3. zsh        Oh My Zsh, powerlevel10k, plugins, fzf/eza/bat/zoxide +

  1-3 toggle · a all · n none · enter install · q quit
```

Non-interactive:

```bash
./install.sh --all               # everything
./install.sh zsh wezterm         # specific modules
./install.sh --all --dry-run     # preview without changing anything
./install.sh --all --yes         # unattended: never prompt
./install.sh --all --skip-deps   # only link configs, install nothing
./install.sh --list              # module names
./install.sh --help              # all options
```

`SETUP_SKIP_DEPS=1` is equivalent to `--skip-deps`, and `NO_COLOR` disables colored output.

The installer is idempotent — run it as many times as you want; anything already installed or already linked is skipped.

Because configs are symlinks into this repo, keep the clone in a permanent location.

## Modules

| Module | Links into `$HOME` | Installs when missing |
| --- | --- | --- |
| `claude` | `~/.claude/CLAUDE.md`, `~/.claude/RTK.md`, `~/.claude/settings.json`, `~/.claude/statusline.sh`, `~/.claude/hooks/notify.sh` | [rtk](https://www.rtk-ai.app/), `jq`, [Claude Code](https://claude.ai/code) |
| `wezterm` | `~/.wezterm.lua` | [WezTerm](https://wezterm.org), MesloLGS / Hack / Symbols Nerd Fonts |
| `zsh` | `~/.zshrc`, `~/.zprofile`, `~/.p10k.zsh` | [Oh My Zsh](https://ohmyz.sh), [powerlevel10k](https://github.com/romkatv/powerlevel10k), [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions), [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting), [fzf](https://junegunn.github.io/fzf/), [eza](https://github.com/eza-community/eza), [bat](https://github.com/sharkdp/bat), [zoxide](https://github.com/ajeetdsouza/zoxide) |

Only individual files are linked into `~/.claude/` — the rest of that directory is machine state (projects, history, caches) and stays out of git.

## Backup Strategy: NOTHING IN YOUR MACHINE IS EVER DELETED

When a real file already exists where a symlink should go, it's renamed in place:

```
~/.zshrc  →  ~/.zshrc-backup
~/.zshrc  →  ~/.zshrc-backup-20260712153000   (when a backup already exists)
```

To restore an original: delete the symlink, rename the backup back.

## Machine-local overrides

`~/.zshrc` sources `~/.zshrc.local` when it exists. Put machine-specific exports and secrets there — that file is never tracked by this repo.

## Updating configs

The live files are symlinks, so edit them wherever is convenient (`code ~/.zshrc` or in the repo) — either way the repo sees the change:

```bash
git diff
git add -p && git commit
```

One exception: Claude Code sometimes rewrites `settings.json` (e.g. through `/config`), which can replace the symlink with a regular file. Re-run `./install.sh claude` — the rewritten file is kept as `settings.json-backup`, the link is restored, and you can diff the backup against the repo copy to decide what to keep.

## Adding a new module

1. Create a directory with the config files (non-hidden names).
2. Add a `name|description` line to `MODULE_TABLE` in `install.sh`.
3. Write an `install_<name>` function: dependency checks first, then `link_file "$REPO_DIR/<module>/<file>" "$HOME/<dotfile>"` calls.

Run `shellcheck install.sh` before committing.

## After installing

- Open a new terminal (or WezTerm) so zsh loads the linked configs.
- Run `claude` and log in on first use.
- If prompt glyphs look wrong, run `p10k configure` once.
