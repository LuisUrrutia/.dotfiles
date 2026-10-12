"""Refresh the local .NET LTS alias; mise owns SDK installation."""

import json
import re
import sys
import urllib.request
from datetime import date, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "setup"))
from runtime import STATE, atomic

METADATA = "https://builds.dotnet.microsoft.com/dotnet/release-metadata"


def read_json(url):
    with urllib.request.urlopen(url, timeout=30) as response:
        return json.load(response)


def latest_lts(read=read_json, today=None):
    cutoff = (today or date.today()) - timedelta(days=3)
    channels = [
        channel["channel-version"]
        for channel in read(f"{METADATA}/releases-index.json")["releases-index"]
        if channel["release-type"] == "lts"
        and channel["support-phase"] in {"active", "maintenance"}
        and re.fullmatch(r"\d+\.\d+", channel["channel-version"])
    ]
    for channel in sorted(
        channels, key=lambda v: tuple(map(int, v.split("."))), reverse=True
    ):
        versions = set()
        for release in read(f"{METADATA}/{channel}/releases.json")["releases"]:
            if date.fromisoformat(release["release-date"]) > cutoff:
                continue
            for sdk in [release.get("sdk", {}), *release.get("sdks", [])]:
                version = sdk.get("version", "")
                if re.fullmatch(re.escape(channel) + r"\.\d+", version):
                    versions.add(version)
        if versions:
            return max(versions, key=lambda v: tuple(map(int, v.split("."))))
    raise RuntimeError("No supported .NET LTS SDK has passed the three-day cooldown")


def main():
    version = latest_lts()
    atomic(STATE / "dotnet-lts", version + "\n")
    print(f".NET LTS alias: {version}")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, KeyError, OSError) as error:
        sys.exit(str(error))
