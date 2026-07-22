# .files

My personal dotfiles, managed with [chezmoi](https://www.chezmoi.io/).

## cli
- kitty
- neovim
- zsh
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
- firefox browser extensions (vimium)

## Installation

Requires [chezmoi](https://www.chezmoi.io/install/) and the underlying apps
above (kitty, neovim, karabiner, etc.) to already be installed — chezmoi only
manages their config files, not the apps themselves.

This repo is private, so clone over SSH rather than HTTPS.

```sh
# install chezmoi (macOS)
brew install chezmoi

# initialize from this repo and apply immediately
chezmoi init --apply git@github.com:jonathanphung/dotfiles.git
```

`chezmoi init --apply jonathanphung` also works, since chezmoi's default
convention is to assume a repo named `dotfiles` for the given GitHub user —
but it clones over HTTPS, which will fail auth against a private repo unless
your git credential helper is already set up for GitHub.

On first apply, a `run_once_before` script also clones the
[`base16-kitty`](https://github.com/kdrag0n/base16-kitty) theme repo into
`~/base16-kitty` automatically — no separate step needed.

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
