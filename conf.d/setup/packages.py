"""Validate package prerequisites before native installation or upgrades."""

import argparse
import json
import platform
import subprocess
import sys
import urllib.request

import config
from runtime import mise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "action", nargs="?", choices=["apply", "upgrade"], default="apply"
    )
    args = parser.parse_args()
    config.check()
    if sys.platform == "darwin":
        with urllib.request.urlopen(
            "https://formulae.brew.sh/api/cask/macfuse.json", timeout=30
        ) as response:
            version = json.load(response)["version"]
        if version == "5.3.3":
            raise RuntimeError(
                "macFUSE 5.3.3 is blocked by this setup; wait for a corrected cask before installing packages"
            )
        # Native package selectors cannot express a macOS version range.
        if int(platform.mac_ver()[0].split(".")[0]) < 27:
            mise("bootstrap", "packages", args.action, "brew-cask:thaw", "--yes")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
