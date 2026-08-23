# browser-extensions

A record of the extensions installed in [Zen](https://zen-browser.app/) (a
Firefox fork), plus the settings exports worth keeping.

This directory is listed in `.chezmoiignore`, so it is repo-only — `chezmoi
apply` will not deploy it into `$HOME`. Extensions are installed by the
browser, not by chezmoi; this is a rebuild checklist, not a managed config.

## What's here

| File | Contents |
| --- | --- |
| `zen-extensions.json` | Every non-Mozilla add-on installed, with id, version, enabled state, and AMO link |
| `vimium-options.json` | Vimium's exported settings (keybindings, search engines, exclusion rules) |
| `dump-zen-extensions.py` | Regenerates `zen-extensions.json` from the live profile |

## Restoring on a new machine

1. Install each add-on from the `url` in `zen-extensions.json`. Anything marked
   `"install": "local"` is side-loaded and has to be rebuilt from its own
   source — currently just the Leetion dev build.
2. Re-disable anything with `"enabled": false`. The AMO build of Leetion is off
   because the dev build supersedes it.
3. Vimium → Options → paste `vimium-options.json` into the import box.
4. Configure the rest by hand (see below).

## Why only Vimium's settings are here

Firefox-family extensions keep their settings in per-extension IndexedDB under
`<profile>/storage/default/moz-extension+++<uuid>/`, as structured-clone blobs.
There is no supported way to read those out of the profile, so settings can only
be captured through whatever export button each extension ships. Vimium has one;
that is why its options are checked in.

uBlock Origin also has one — Dashboard → Settings → *Backup to file* — but its
stored data is mostly regenerable filter-list cache, so it is not tracked here.
Export it manually if the custom filters ever become worth keeping.

**Bitwarden and Leetion settings are deliberately excluded.** Bitwarden's
extension storage holds vault and session material, and Leetion's holds a Notion
API token. Neither belongs in a git repo, private or not.

## Regenerating the inventory

```sh
./dump-zen-extensions.py            # refreshes zen-extensions.json
./dump-zen-extensions.py --offline  # skips the AMO lookups
```

It reads the profile that `profiles.ini` marks as the running installation's
default, so it follows along if the active profile changes.
