"""Validate package prerequisites before native installation or upgrades."""

import argparse
import platform
import subprocess
import sys

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
        # Native package selectors cannot express a macOS version range.
        if int(platform.mac_ver()[0].split(".")[0]) < 27:
            mise("bootstrap", "packages", args.action, "brew-cask:thaw", "--yes")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
