#!/usr/bin/env python3
"""Repository lint, four integration boundaries, and an isolated shell smoke path."""

import shutil
import sys
import tempfile
from pathlib import Path

from lint import ROOT, run, source_files


def main():
    run(sys.executable, "tests/lint.py")
    run("/bin/bash", "install.sh", "--dry-run")
    with tempfile.TemporaryDirectory(prefix="dotfiles-public-check-") as temporary:
        public = Path(temporary) / "source"
        for path in source_files():
            target = public / path
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / path, target)
        run(
            "gitleaks",
            "detect",
            "--no-git",
            "--source",
            public,
            "--redact",
            "--no-banner",
        )
    run(
        sys.executable,
        "-m",
        "unittest",
        "discover",
        "-s",
        "tests",
        "-p",
        "test_*.py",
        "-v",
    )
    run("git", "diff", "--check")
    run("git", "diff", "--cached", "--check")
    print(
        "Verification passed; full setup acceptance requires disposable macOS and Ubuntu machines."
    )


if __name__ == "__main__":
    main()
