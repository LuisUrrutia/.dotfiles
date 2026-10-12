"""Verify the current AutoFirma package and complete its vendor installation."""

import hashlib
import io
import json
import platform
import re
import subprocess
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "setup"))
from downloads import download
from installer import complete_installation, installed
from runtime import STATE, atomic, regular_parents

CASK = "https://formulae.brew.sh/api/cask/autofirma.json"


def current_release():
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise RuntimeError("AutoFirma setup requires macOS arm64")
    cask = json.loads(download(CASK))
    packages = [
        installer["manual"]
        for artifact in cask["artifacts"]
        for installer in artifact.get("installer", [])
        if "manual" in installer
    ]
    if (
        not re.fullmatch(r"\d+(?:\.\d+)*", cask["version"])
        or not re.fullmatch(r"[a-f0-9]{64}", cask["sha256"])
        or not cask["url"].startswith("https://")
        or len(packages) != 1
        or Path(packages[0]).name != packages[0]
        or not packages[0].endswith(".pkg")
    ):
        raise RuntimeError(
            "AutoFirma cask must declare a version, HTTPS URL, SHA-256 and one manual package"
        )
    return cask["version"], cask["url"], cask["sha256"], packages[0]


def main():
    version, url, checksum, package = current_release()
    print(f"AutoFirma cask release: {version}")
    if installed(version):
        return
    installer = STATE / "installers/autofirma" / version / package
    regular_parents(installer)
    archive = download(url, timeout=60)
    if hashlib.sha256(archive).hexdigest() != checksum:
        raise RuntimeError("AutoFirma archive checksum does not match its current cask")
    with zipfile.ZipFile(io.BytesIO(archive)) as bundle:
        # Casks use macOS's case-insensitive filenames; ZIP member lookup does not.
        members = [
            name for name in bundle.namelist() if name.casefold() == package.casefold()
        ]
        if len(members) != 1:
            raise RuntimeError(
                "AutoFirma archive must contain exactly the cask's manual package"
            )
        atomic(installer, bundle.read(members[0]))
    subprocess.run(
        ["/usr/sbin/pkgutil", "--check-signature", str(installer)],
        stdin=subprocess.DEVNULL,
        check=True,
        timeout=30,
    )
    complete_installation(installer, version)


if __name__ == "__main__":
    try:
        main()
    except (
        RuntimeError,
        ValueError,
        TypeError,
        OSError,
        KeyError,
        zipfile.BadZipFile,
        subprocess.SubprocessError,
    ) as error:
        sys.exit(str(error))
