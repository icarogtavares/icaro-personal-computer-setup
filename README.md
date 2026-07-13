# Icaro's PC Setup

[![CI](https://img.shields.io/github/actions/workflow/status/icarogtavares/icaro-personal-computer-setup/ci.yml?branch=main&label=ci)](https://github.com/icarogtavares/icaro-personal-computer-setup/actions/workflows/ci.yml)
![Platform](https://img.shields.io/badge/platform-macOS-blue)
[![License](https://img.shields.io/github/license/icarogtavares/icaro-personal-computer-setup)](LICENSE)

Everything needed to rebuild my macOS machine. Configuration files live in this repo, grouped in topic modules under `modules/`; an interactive installer symlinks them into place and installs the tools they depend on. Because the live configs are symlinks, the repo stays the single source of truth — edit any config where it lives, see the change with `git diff`, commit, push.

## Quick start

```bash
git clone https://github.com/icarogtavares/icaro-personal-computer-setup.git
cd icaro-personal-computer-setup
./install.sh
```

Requirements: macOS and git (`xcode-select --install`). Everything else — including Homebrew — is detected and offered by the installer when missing.

Running without arguments opens a checkbox menu — move with ↑/↓, toggle with space (or the number keys), then press enter:

```
icaro-personal-computer-setup

> [x] 1. claude     Claude Code config (CLAUDE.md, settings, statusline, hoo
  [ ] 2. wezterm    WezTerm config + app and Nerd Fonts
  [x] 3. zsh        Oh My Zsh, powerlevel10k, plugins, fzf/eza/bat/zoxide +

  ↑↓ move · space/1-3 toggle · a all · n none · enter install · q quit
```

Keep the clone in a permanent location — the live configs are symlinks into it.

## Safe to run

- **Nothing on the machine is ever deleted.** A real file in a symlink's place is renamed next to it: `~/.zshrc` → `~/.zshrc-backup` (timestamped when a backup already exists). To restore an original: delete the symlink, rename the backup back.
- **Idempotent** — run it as many times as you want; anything already installed or already linked is skipped.
- **`--dry-run`** previews every action without changing anything.
- **60+ tests** run the installer against a throwaway `$HOME` with a stripped `PATH` and stub `brew`/`curl`/`git` — nothing on the machine is touched and no network is used; the menu is driven through a real pty. CI runs the suite on macOS (stock bash 3.2) and Ubuntu for every push and pull request.

## Usage

```bash
./install.sh --all               # everything
./install.sh zsh wezterm         # specific modules
./install.sh --all --dry-run     # preview without changing anything
./install.sh --all --yes         # unattended: never prompt
./install.sh --all --skip-deps   # only link configs, install nothing
./install.sh --list              # module names
./install.sh --help              # all options
```

Environment variables:

- `SETUP_SKIP_DEPS=1` — same as `--skip-deps`
- `NO_COLOR` — disable colored output
- `SETUP_BREW_PREFIXES` — Homebrew prefixes to probe (default: `/opt/homebrew /usr/local`)
- `SETUP_WEZTERM_APP` — WezTerm app bundle path (default: `/Applications/WezTerm.app`)

The last two default to what normal Macs use; the test suite points them at its sandbox.

## Layout

```
icaro-personal-computer-setup/
├── install.sh    installer — menu, symlinking, dependencies
├── modules/      config payload — everything that gets linked into $HOME
│   ├── claude/
│   ├── wezterm/
│   └── zsh/
└── tests/        sandboxed bats suite + lint harness (tests/run)
```

## Modules

| Module | Links into `$HOME` | Installs when missing |
| --- | --- | --- |
| `claude` | `~/.claude/CLAUDE.md`, `~/.claude/settings.json`, `~/.claude/statusline.sh`, `~/.claude/hooks/notify.sh` | `jq`, [Claude Code](https://claude.ai/code) |
| `wezterm` | `~/.wezterm.lua` | [WezTerm](https://wezterm.org), MesloLGS / Hack / Symbols Nerd Fonts |
| `zsh` | `~/.zshrc`, `~/.zprofile`, `~/.p10k.zsh` | [Oh My Zsh](https://ohmyz.sh), [powerlevel10k](https://github.com/romkatv/powerlevel10k), [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions), [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting), [fzf](https://junegunn.github.io/fzf/), [eza](https://github.com/eza-community/eza), [bat](https://github.com/sharkdp/bat), [zoxide](https://github.com/ajeetdsouza/zoxide) |

Only individual files are linked into `~/.claude/` — the rest of that directory is machine state (projects, history, caches) and stays out of git.

## Claude in WezTerm

Claude Code sessions announce their state to WezTerm: `settings.json` wires the session's hook events to `~/.claude/hooks/notify.sh`, which publishes a `claude_status` user var that `~/.wezterm.lua` renders in the tab bar.

- 🔔 on the tab while a session waits for approval or input — plus the Submarine sound and the usual macOS banner.
- ✅ on the tab when a turn finishes; it clears a moment after the tab is actually viewed.
- `leader+a` jumps straight to the session that wants attention (🔔 first, ✅ as fallback).

Hooks are read when a session starts, so restart any running `claude` after changing them.

## Everyday use

The live files are symlinks, so edit them wherever is convenient (`code ~/.zshrc` or in the repo) — either way the repo sees the change:

```bash
git diff
git add -p && git commit
```

- **Machine-local overrides:** `~/.zshrc` sources `~/.zshrc.local` when it exists. Put machine-specific exports and secrets there — that file is never tracked by this repo.
- **Claude settings caveat:** Claude Code sometimes rewrites `settings.json` (e.g. through `/config`), which can replace the symlink with a regular file. Re-run `./install.sh claude` — the rewritten file is kept as `settings.json-backup`, the link is restored, and you can diff the backup against the repo copy to decide what to keep.

## Development

Adding a module:

1. Create a directory under `modules/` with the config files (non-hidden names).
2. Add a `name|description` line to `MODULE_TABLE` in `install.sh`.
3. Write an `install_<name>` function: dependency checks first, then `link_file "$MODULES_DIR/<module>/<file>" "$HOME/<dotfile>"` calls.

Run the suite before committing and add tests for the new module's links:

```bash
./tests/run                       # lint (bash -n + shellcheck + shfmt) and full suite
./tests/run lint                  # lint only
./tests/run test --filter menu    # subset of tests
```

The first run clones [bats-core](https://github.com/bats-core/bats-core) into the gitignored `tests/.deps/` (cached in CI). Formatting is enforced with `shfmt -i 2 -ci` across `install.sh`, the test harness and the `modules/claude/` scripts.

## After installing

- Open a new terminal (or WezTerm) so zsh loads the linked configs.
- Run `claude` and log in on first use.
- If prompt glyphs look wrong, run `p10k configure` once.

## License

[MIT](LICENSE)
