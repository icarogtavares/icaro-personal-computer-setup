# Icaro's PC Setup

[![CI](https://img.shields.io/github/actions/workflow/status/icarogtavares/icaro-personal-computer-setup/ci.yml?branch=main&label=ci)](https://github.com/icarogtavares/icaro-personal-computer-setup/actions/workflows/ci.yml)
![Platform](https://img.shields.io/badge/platform-macOS-blue)
[![License](https://img.shields.io/github/license/icarogtavares/icaro-personal-computer-setup)](LICENSE)

Everything needed to rebuild my macOS machine. Configuration files live in this repo, grouped in topic modules under `modules/`; an interactive installer writes them into `$HOME` as real files — never symlinks — and installs the tools they depend on. Each module is split into components so a machine can take only what it needs: `~/.claude/settings.json` is composed from the fragments of the selected claude components, and `~/.zshrc` is rendered from the repo template with unselected Oh My Zsh plugins and shell-tool sections removed. The repo stays the single source of truth: edit under `modules/`, re-run the installer to apply.

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

> [x] 1. claude-settings         Claude Code CLI + CLAUDE.md + base settings
  [x] 2. claude-statusline       statusline script + statusLine setting
  [ ] 3. claude-notify           notification hooks + notify preferences
  [ ] 4. wezterm                 WezTerm config + app and Nerd Fonts
  [x] 5. zsh-core                Oh My Zsh, p10k + zsh dotfiles
  [x] 6. zsh-git                 git plugin (Oh My Zsh built-in)
  [x] 7. zsh-autosuggestions     zsh-autosuggestions plugin
  [ ] 8. zsh-syntax-highlighting zsh-syntax-highlighting plugin
  [x] 9. zoxide                  zoxide (smarter cd) + zshrc init
  [x] 10. eza                    eza (modern ls) + aliases
  [ ] 11. fzf                    fzf (fuzzy finder) + key bindings
  [ ] 12. bat                    bat (better cat) + theme

  ↑↓ move · space/1-9 toggle · a all · n none · enter install · q quit
```

## Safe to run

- **Nothing on the machine is ever deleted.** Before a config is written over, the existing file is renamed next to it: `~/.zshrc` → `~/.zshrc-backup` (timestamped when a backup already exists). To restore an original: delete the written file, rename the backup back.
- **Idempotent** — run it as many times as you want; anything already installed or already up to date is skipped.
- **`--dry-run`** previews every action without changing anything.
- **100+ tests** run the installer against a throwaway `$HOME` with a stripped `PATH` and stub `brew`/`curl`/`git` — nothing on the machine is touched and no network is used; the menu is driven through a real pty. CI runs the suite on macOS (stock bash 3.2) and Ubuntu for every push and pull request.

## Usage

```bash
./install.sh --all                          # everything
./install.sh claude-statusline              # a single component
./install.sh zsh wezterm                    # module aliases: every component of both
./install.sh claude-settings zsh-core       # mix and match
./install.sh --all --dry-run                # preview without changing anything
./install.sh --all --yes                    # unattended: never prompt
./install.sh --all --skip-deps              # only write configs, install nothing
./install.sh --list                         # component names
./install.sh --help                         # all options
```

A bare module name (`claude`, `wezterm`, `zsh`) selects every component of that module. Selecting a zsh plugin or shell tool without `zsh-core` adds `zsh-core` automatically — their setup lives in the rendered `~/.zshrc`.

Environment variables:

- `SETUP_SKIP_DEPS=1` — same as `--skip-deps`
- `NO_COLOR` — disable colored output
- `SETUP_BREW_PREFIXES` — Homebrew prefixes to probe (default: `/opt/homebrew /usr/local`)
- `SETUP_WEZTERM_APP` — WezTerm app bundle path (default: `/Applications/WezTerm.app`)

The last two default to what normal Macs use; the test suite points them at its sandbox.

## Layout

```
icaro-personal-computer-setup/
├── install.sh    installer — menu, file writing, dependencies
├── modules/      config payload — everything that gets written into $HOME
│   ├── claude/   CLAUDE.md, statusline.sh, hooks/, settings/ fragments
│   ├── wezterm/
│   └── zsh/
└── tests/        sandboxed bats suite + lint harness (tests/run)
```

## Components

| Component | Writes into `$HOME` | Installs when missing |
| --- | --- | --- |
| `claude-settings` | `~/.claude/CLAUDE.md`; base keys of `~/.claude/settings.json` | `jq`, [Claude Code](https://claude.ai/code) |
| `claude-statusline` | `~/.claude/statusline.sh`; the `statusLine` key | `jq` |
| `claude-notify` | `~/.claude/hooks/notify.sh`; the `hooks` + notification keys | `jq` |
| `wezterm` | `~/.wezterm.lua` | [WezTerm](https://wezterm.org), MesloLGS / Hack / Symbols Nerd Fonts |
| `zsh-core` | `~/.zshrc` (rendered), `~/.zprofile`, `~/.p10k.zsh` | [Oh My Zsh](https://ohmyz.sh), [powerlevel10k](https://github.com/romkatv/powerlevel10k) |
| `zsh-git` | its entry in the `plugins=(...)` array of `~/.zshrc` | — (Oh My Zsh built-in) |
| `zsh-autosuggestions` | its entry in the `plugins=(...)` array of `~/.zshrc` | [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) |
| `zsh-syntax-highlighting` | its entry in the `plugins=(...)` array of `~/.zshrc` | [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) |
| `zoxide` | its init line in `~/.zshrc` | [zoxide](https://github.com/ajeetdsouza/zoxide) |
| `eza` | its `ls`/`ll`/`la`/`lt` aliases in `~/.zshrc` | [eza](https://github.com/eza-community/eza) |
| `fzf` | its key bindings + completion setup in `~/.zshrc` | [fzf](https://junegunn.github.io/fzf/) |
| `bat` | its theme export in `~/.zshrc` | [bat](https://github.com/sharkdp/bat) |

`~/.claude/settings.json` is composed from the fragments under `modules/claude/settings/` (`base.json`, `statusline.json`, `notify.json`) — only the selected components' keys end up in the file. `~/.zshrc` is rendered from `modules/zsh/zshrc` with unselected plugins stripped from the `plugins=(...)` array and unselected tool sections (fenced by `# >>> <component…>` / `# <<< <component…>` markers in the template) removed — the fzf preview config lists `fzf eza bat`, so it is only rendered when all three are selected. Only individual files are written into `~/.claude/` — the rest of that directory is machine state (projects, history, caches) and stays out of git.

## Claude in WezTerm

With the `claude-notify` component installed, Claude Code sessions announce their state to WezTerm: `settings.json` wires the session's hook events to `~/.claude/hooks/notify.sh`, which publishes a `claude_status` user var that `~/.wezterm.lua` renders in the tab bar.

- 🔔 on the tab while a session waits for approval or input — plus the Submarine sound and the usual macOS banner.
- ✅ on the tab when a turn finishes; it clears a moment after the tab is actually viewed.
- `leader+a` jumps straight to the session that wants attention (🔔 first, ✅ as fallback).

Hooks are read when a session starts, so restart any running `claude` after changing them.

## Everyday use

Edit configs in the repo under `modules/`, then re-run the installer to apply them:

```bash
code modules/zsh/zshrc
./install.sh --skip-deps zsh
git add -p && git commit
```

The live files are plain copies, so a hand-edited live file never touches the repo; when the installer writes over one, the edited version is kept as `<name>-backup` to diff against.

- **Machine-local overrides:** `~/.zshrc` sources `~/.zshrc.local` when it exists. Put machine-specific exports and secrets there — that file is never tracked by this repo.
- **Claude settings:** Claude Code rewriting `~/.claude/settings.json` (e.g. through `/config`) is harmless now that the file is a real file. Re-run `./install.sh claude` to regenerate it — the rewritten version is kept as `settings.json-backup` so you can diff it and fold anything worth keeping into the fragments under `modules/claude/settings/`.
- **Upgrading from the symlink era:** installs made by v1 left symlinks in place; the first v2 run backs each one up (`<name>-backup`) and writes a real file. The backups can be deleted once you trust the new files — the installer never deletes them for you.

## Development

Adding a component:

1. Create or extend a directory under `modules/` with the config files (non-hidden names).
2. Add a `component|module|description` line to `COMPONENT_TABLE` in `install.sh` — components of a module stay contiguous.
3. For a new module, write an `install_<module>` function: dependency checks first, then `copy_file "$MODULES_DIR/<module>/<file>" "$HOME/<dotfile>"` calls. For a new component of an existing module, add a `component_selected <component>` branch to its function.

Run the suite before committing and add tests for the new component's files:

```bash
./tests/run                       # lint (bash -n + shellcheck + shfmt) and full suite
./tests/run lint                  # lint only
./tests/run test --filter menu    # subset of tests
```

The first run clones [bats-core](https://github.com/bats-core/bats-core) into the gitignored `tests/.deps/` (cached in CI). Formatting is enforced with `shfmt -i 2 -ci` across `install.sh`, the test harness and the `modules/claude/` scripts.

## After installing

- Open a new terminal (or WezTerm) so zsh loads the new configs.
- Run `claude` and log in on first use.
- If prompt glyphs look wrong, run `p10k configure` once.

## License

[MIT](LICENSE)
