"""Prepare the signed AutoFirma installer without waiting on its GUI prompts."""

import hashlib
import io
import os
from pathlib import Path
import plistlib
import shlex
import subprocess
import sys
import urllib.request
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "setup"))
from runtime import STATE, atomic, regular_parents


def main():
    version = os.environ["AUTOFIRMA_VERSION"]
    info = Path("/Applications/AutoFirma.app/Contents/Info.plist")
    if info.is_file():
        installed = plistlib.loads(info.read_bytes())
        if installed.get("CFBundleIdentifier") == "es.gob.afirma.simpleafirma.osx":
            receipt = subprocess.run(
                ["/usr/sbin/pkgutil", "--pkg-info-plist", "es.gob.afirma"],
                stdin=subprocess.DEVNULL, capture_output=True, timeout=10,
            )
            if receipt.returncode == 0:
                installed_version = plistlib.loads(receipt.stdout)["pkg-version"]
                if tuple(map(int, installed_version.split("."))) >= tuple(map(int, version.split("."))):
                    print(f"AutoFirma {installed_version} is installed")
                    return
    installer = STATE / "installers/autofirma" / version / os.environ["AUTOFIRMA_PACKAGE"]
    regular_parents(installer)
    with urllib.request.urlopen(os.environ["AUTOFIRMA_URL"], timeout=60) as response:
        archive = response.read()
    if hashlib.sha256(archive).hexdigest() != os.environ["AUTOFIRMA_SHA256"]:
        raise RuntimeError("AutoFirma archive checksum does not match its reviewed declaration")
    with zipfile.ZipFile(io.BytesIO(archive)) as bundle:
        atomic(installer, bundle.read(os.environ["AUTOFIRMA_PACKAGE"]))
    subprocess.run(
        ["/usr/sbin/pkgutil", "--check-signature", str(installer)],
        stdin=subprocess.DEVNULL, check=True, timeout=30,
    )
    # The vendor's postinstall requires GUI interaction even with the CLI installer.
    raise RuntimeError(
        f"Complete AutoFirma's vendor installer: open {shlex.quote(str(installer))}\n"
        "Then rerun mise -C ~ run config apply. Automatic setup remains pending."
    )


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError, KeyError, zipfile.BadZipFile, subprocess.SubprocessError) as error:
        sys.exit(str(error))
