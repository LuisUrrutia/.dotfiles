"""Validate package prerequisites before native installation or upgrades."""

import json
import subprocess
import sys
import urllib.request

import config


def main():
    config.check()
    if sys.platform == "darwin":
        with urllib.request.urlopen("https://formulae.brew.sh/api/cask/macfuse.json", timeout=30) as response:
            version = json.load(response)["version"]
        if version == "5.3.3":
            raise RuntimeError("macFUSE 5.3.3 is blocked by this setup; wait for a corrected cask before installing packages")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
