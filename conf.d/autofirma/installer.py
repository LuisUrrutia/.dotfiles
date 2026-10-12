"""Run AutoFirma's vendor UI and verify that installation completed."""

import plistlib
import shlex
import subprocess
from pathlib import Path

APP_INFO = Path("/Applications/AutoFirma.app/Contents/Info.plist")


def installed(version):
    if not APP_INFO.is_file():
        return False
    info = plistlib.loads(APP_INFO.read_bytes())
    if info.get("CFBundleIdentifier") != "es.gob.afirma.simpleafirma.osx":
        return False
    receipt = subprocess.run(
        ["/usr/sbin/pkgutil", "--pkg-info-plist", "es.gob.afirma"],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        timeout=10,
    )
    if receipt.returncode:
        return False
    installed_version = plistlib.loads(receipt.stdout)["pkg-version"]
    if tuple(map(int, installed_version.split("."))) < tuple(
        map(int, version.split("."))
    ):
        return False
    print(f"AutoFirma {installed_version} is installed")
    return True


def complete_installation(installer, version):
    try:
        with open("/dev/tty", "rb") as terminal:
            interactive = terminal.isatty()
    except OSError:
        interactive = False
    if not interactive:
        raise RuntimeError(
            "AutoFirma requires its graphical installer. Run mise -C ~ run config apply "
            "from a terminal, or open the verified package:\n"
            f"open {shlex.quote(str(installer))}"
        )
    print(
        "Opening AutoFirma's installer. Complete its dialogs and close Installer; "
        "setup will then continue.",
        flush=True,
    )
    subprocess.run(
        [
            "/usr/bin/open",
            "-W",
            "-a",
            "/System/Library/CoreServices/Installer.app",
            str(installer),
        ],
        stdin=subprocess.DEVNULL,
        check=True,
        timeout=1800,
    )
    if not installed(version):
        raise RuntimeError(
            "AutoFirma installation is incomplete. Rerun setup to reopen its installer."
        )
