#!/usr/bin/env python3
"""Dump the Zen browser's installed extensions to zen-extensions.json.

Records what is installed, not each extension's settings -- those live in
per-extension IndexedDB and are only exportable through each extension's own
backup UI. See README.md in this directory.

Usage: ./dump-zen-extensions.py [--offline]
"""

import configparser
import json
import os
import sys
import subprocess
import urllib.parse

ZEN = os.path.expanduser("~/Library/Application Support/zen")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "zen-extensions.json")


def default_profile():
    """Resolve the profile Zen actually uses, from profiles.ini.

    The [Install*] section names the profile the running installation opens,
    which is authoritative; the legacy [ProfileN] Default=1 flag is only a
    fallback, and on a browser that has been re-profiled the two disagree.
    """
    ini_path = os.path.join(ZEN, "profiles.ini")
    cp = configparser.RawConfigParser()
    cp.optionxform = str
    cp.read(ini_path)

    candidates = []
    for sec in cp.sections():
        if sec.startswith("Install") and cp.has_option(sec, "Default"):
            candidates.append(cp.get(sec, "Default"))
    for sec in cp.sections():
        if sec.startswith("Profile") and cp.get(sec, "Default", fallback="") == "1":
            candidates.append(cp.get(sec, "Path"))

    for rel in candidates:
        path = os.path.join(ZEN, rel)
        if os.path.exists(os.path.join(path, "extensions.json")):
            return path
    sys.exit("no profile with an extensions.json found in %s" % ini_path)


def amo_slug(guid):
    """Look up an add-on's AMO listing URL by GUID. None if unlisted.

    Shells out to curl rather than using urllib: the system Python on macOS
    has no CA bundle wired up, so urllib fails SSL verification while curl
    uses the system trust store.
    """
    url = "https://addons.mozilla.org/api/v5/addons/addon/%s/" % urllib.parse.quote(guid, safe="")
    try:
        out = subprocess.run(
            ["curl", "-sfL", "--max-time", "10", url],
            capture_output=True, text=True, check=True,
        ).stdout
        listing = json.loads(out).get("url", "")
        return listing.split("?")[0] or None
    except subprocess.CalledProcessError:
        # 404 means the add-on was pulled from AMO or was never listed.
        print("  ! no AMO listing for %s" % guid, file=sys.stderr)
    except Exception as e:
        print("  ! AMO lookup failed for %s: %s" % (guid, e), file=sys.stderr)
    return None


def main():
    offline = "--offline" in sys.argv
    profile = default_profile()
    data = json.load(open(os.path.join(profile, "extensions.json")))

    addons = []
    for a in data.get("addons", []):
        guid = a.get("id", "")
        # Mozilla ships these with the browser; they are not user choices.
        if guid.endswith("@mozilla.org") or guid.endswith("@mozilla.com"):
            continue
        src = a.get("sourceURI") or ""
        entry = {
            "name": (a.get("defaultLocale") or {}).get("name") or guid,
            "id": guid,
            "type": a.get("type"),
            "version": a.get("version"),
            "enabled": bool(a.get("active")) and not a.get("userDisabled"),
            "install": "amo" if src.startswith("https://addons.mozilla.org/") else "local",
        }
        if entry["install"] == "amo":
            entry["url"] = None if offline else amo_slug(guid)
        else:
            entry["note"] = "side-loaded, not on AMO -- rebuild from source"
        addons.append(entry)

    addons.sort(key=lambda e: e["name"].lower())
    with open(OUT, "w") as f:
        json.dump({"browser": "zen", "addons": addons}, f, indent=2)
        f.write("\n")
    print("wrote %s (%d add-ons)" % (OUT, len(addons)))


if __name__ == "__main__":
    main()
