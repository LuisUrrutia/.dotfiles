"""Prepare macOS's declared login shell using existing sudo authorization."""

import os
from pathlib import Path
import pwd
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "setup"))
from runtime import native_json, run


def main():
    status = native_json("bootstrap", "user", "status").get("login_shell")
    if not status:
        return
    if not status.get("available"):
        raise RuntimeError("The declared login shell cannot be applied on this system")
    shell = status["shell"]
    if status["state"] == "set":
        return
    if os.geteuid() == 0 or status["user"] != pwd.getpwuid(os.geteuid()).pw_name:
        raise RuntimeError("Run setup as the user whose login shell should change")
    if not Path(shell).is_absolute() or not os.access(shell, os.X_OK):
        raise RuntimeError(f"Install the declared login shell first: {shell}")
    # Mise invokes chsh for an unlisted shell even when the account already matches.
    if not status["shell_listed"]:
        run(["/usr/bin/sudo", "-n", "/bin/sh", "-c",
                'printf "%s\\n" "$1" >> /etc/shells', "sh", shell], timeout=30)
    if status["current"] != shell:
        run(["/usr/bin/sudo", "-n", "/usr/bin/chsh", "-s", shell, status["user"]], timeout=30)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError, subprocess.SubprocessError) as error:
        sys.exit(str(error))
