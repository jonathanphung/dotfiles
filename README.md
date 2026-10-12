# .files

My personal dotfiles, managed with [chezmoi](https://www.chezmoi.io/).

## cli
- kitty
- wezterm (Windows)
- neovim
- zsh
- bash (Homebrew)
- starship
- bat
- lazygit
- gh (GitHub CLI)
- git (`.gitconfig`)
- fsh

## mac
- karabiner
- codexbar
- herdr
- zen browser extensions (see `browser-extensions/`)

## Installation

Requires [chezmoi](https://www.chezmoi.io/install/) and the underlying apps
above (kitty/WezTerm, neovim, karabiner, etc.) to already be installed. Chezmoi
manages their config files, except that it installs Homebrew Bash automatically
on macOS.

This repo is private, so clone over SSH rather than HTTPS.

```sh
# install chezmoi (macOS)
brew install chezmoi

# initialize from this repo and apply immediately
chezmoi init --apply git@github.com:jonathanphung/dotfiles.git
```

On Windows, the WezTerm config is deployed to
`%USERPROFILE%\.config\wezterm\wezterm.lua`. It uses the native Windows shell
unless `default_prog` or `default_domain` is set locally. Put background images
in `%USERPROFILE%\.config\wezterm\backgrounds`; it will also reuse images from
the existing Kitty backgrounds directory.

`chezmoi init --apply jonathanphung` also works, since chezmoi's default
convention is to assume a repo named `dotfiles` for the given GitHub user —
but it clones over HTTPS, which will fail auth against a private repo unless
your git credential helper is already set up for GitHub.

On first apply outside Windows, `run_once_before` scripts clone the
[`base16-kitty`](https://github.com/kdrag0n/base16-kitty) theme repo into
`~/base16-kitty` automatically. The macOS setup also installs Homebrew Bash.

To pull future updates from the repo onto this machine:

```sh
chezmoi update
```

To pick up a local edit made directly to a deployed config (e.g. editing
`~/.config/kitty/kitty.conf` by hand) back into this repo:

```sh
chezmoi re-add ~/.config/kitty/kitty.conf
cd $(chezmoi source-path) && git add -A && git commit -m "..." && git push
```

## Neovim on Linux / UTCS

The same Neovim config supports macOS and Linux and requires Neovim 0.12+.
Homebrew/BasicTeX paths and Skim are enabled only on macOS. Over SSH, split
navigation stays inside Neovim, terminal color synchronization is skipped,
and VimTeX PDF viewing is disabled. Kitty itself runs on the client.

For a Neovim-only install, run these commands on your Mac. Back up an existing
remote `~/.config/nvim` first. This copies your active config without applying
the rest of the dotfiles or their install scripts.

```sh
ssh jonat@linux.cs.utexas.edu 'mkdir -p ~/.config/nvim'
scp -r ~/.config/nvim/init.lua ~/.config/nvim/nvim-pack-lock.json ~/.config/nvim/lua jonat@linux.cs.utexas.edu:~/.config/nvim/
kitten ssh jonat@linux.cs.utexas.edu
```

Launch `nvim` on UTCS to install plugins, then run `:checkhealth`. Git, a C
compiler, make, ripgrep, and language-specific tools may be needed for full
plugin functionality. Java linting additionally expects Checkstyle and
`~/repos/cs314-hygiene-checker/checkstyle.xml`.

## One-command Linux setup

From a clone of this private repository:

```sh
bash setup-linux.sh
exec zsh -l
```

Re-run the same command to apply updated configs. Working tools are skipped;
Neovim, fzf, fd, Tree-sitter, and Node are upgraded if too old for this config.
Use `bash setup-linux.sh --check` for a read-only prerequisite/tool check.

Supports glibc Linux on x86_64 and ARM64 with Python 3.9+, curl, Git, Zsh,
make, and a C compiler already installed. Missing prerequisites are reported
with no sudo or package-manager changes. Alpine/musl and other architectures
need distro packages instead. Downloaded binaries must work with the host's
glibc; incompatible builds stop before deploying configs.

Installs tools into `~/.local/bin`, with Neovim and Node bundles in
`~/.local/lib/dotfiles`. Downloads come from official releases and are checked
against pinned SHA-256 hashes; Node 24 uses the official release checksum list.
Includes eza, bat, ripgrep, fd, fzf, Starship, Zoxide, Yazi, Lazygit, Neovim,
Tree-sitter CLI, and Node/npm/npx. Existing compatible tools are reused.

Copies the shared Neovim, Zsh, Lazygit, bat, syntax-highlighting, and Starship
configs. Changed files and replaced executable links are backed up under
`~/.local/state/dotfiles/backups/<timestamp>/`. Identical files are untouched.
Zsh is redirected through `~/.zshenv`; any existing `~/.zshrc` stays on disk
but the new shell uses `~/.config/zsh/.zshrc`. Zsh plugins install on first load.

Kitty stays on the client. Connect with `kitten ssh` for remote terminal
support. Open Neovim after setup for plugin installation and `:checkhealth`.
Optional PDF/image/video preview tools and language-specific requirements
(such as Java/Checkstyle and TeX) are not installed by this script.

For UTCS without GitHub authentication on the server, copy the repo from your
Mac (excluding its Git metadata), then run the installer inside SSH:

```sh
# On your Mac, from the dotfiles repository:
ssh jonat@linux.cs.utexas.edu 'mkdir -p ~/dotfiles'
tar --exclude=.git --exclude=.DS_Store -czf - . | ssh jonat@linux.cs.utexas.edu 'tar -xzf - -C ~/dotfiles'
# Inside your UTCS SSH session:
bash ~/dotfiles/setup-linux.sh
```
