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
