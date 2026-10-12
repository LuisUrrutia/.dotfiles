"""Download HTTPS resources using the operating system's certificate trust."""

from runtime import run


def download(url: str, *, timeout: int = 30) -> bytes:
    # The mise Python runtime can use different CA roots from the operating system.
    result = run(
        [
            "/usr/bin/curl",
            "--disable",
            "--fail",
            "--silent",
            "--show-error",
            "--location",
            "--proto",
            "=https",
            "--proto-redir",
            "=https",
            "--connect-timeout",
            "15",
            "--speed-limit",
            "1",
            "--speed-time",
            str(timeout),
            "--url",
            url,
        ],
        capture=True,
        check=False,
    )
    if result.returncode:
        detail = result.stderr.decode(errors="replace").strip()
        raise RuntimeError(f"HTTPS download failed for {url}: {detail}")
    return result.stdout
