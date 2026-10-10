"""Shared process and filesystem boundaries for setup adapters."""

from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import tomllib
from urllib.parse import urlsplit

RAW_HOME = Path.home()
HOME = RAW_HOME.resolve()


def home_path(path):
    path = Path(path).expanduser().absolute()
    return HOME / path.relative_to(RAW_HOME) if path.is_relative_to(RAW_HOME) else path


ROOT = home_path(os.environ.get("MISE_CONFIG_DIR", HOME / ".config/mise"))
STATE = home_path(os.environ.get("MISE_STATE_DIR", HOME / ".local/state/mise")) / "dotfiles"
MISE = os.environ.get("MISE_BIN") or shutil.which("mise") or str(HOME / ".local/bin/mise")


def run(args, *, capture=False, check=True, timeout=900, input=None, **kwargs):
    env = os.environ.copy()
    env.update(GIT_TERMINAL_PROMPT="0", GH_PROMPT_DISABLED="1", MISE_YES="1",
                GIT_SSH_COMMAND="ssh -o BatchMode=yes", MISE_CONFIG_DIR=str(ROOT),
                MISE_DISABLE_UPDATE_WARNING="1")
    command = [str(a) for a in args]
    with subprocess.Popen(command, cwd=HOME, env=env, start_new_session=True,
                            stdin=subprocess.PIPE if input is not None else subprocess.DEVNULL,
                            stdout=subprocess.PIPE if capture else None,
                            stderr=subprocess.PIPE if capture else None, **kwargs) as process:
        try:
            stdout, stderr = process.communicate(input=input, timeout=timeout)
        except BaseException:
            # Keep the operation lock until its descendants have been stopped too.
            for sig in (signal.SIGTERM, signal.SIGKILL):
                try:
                    os.killpg(process.pid, sig)
                except ProcessLookupError:
                    pass
                if sig == signal.SIGTERM:
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        pass
            process.communicate()
            raise
        result = subprocess.CompletedProcess(command, process.returncode, stdout, stderr)
        if check:
            result.check_returncode()
        return result


def mise(*args, capture=False, **kwargs):
    return run([MISE, *args], capture=capture, **kwargs)


def native_json(*args):
    result = native_checked(*args, "--json")
    return json.loads(result.stdout)


def native_checked(*args):
    result = mise(*args, capture=True)
    if b"WARN" in result.stderr:
        raise RuntimeError(result.stderr.decode(errors="replace"))
    return result


def read_toml(path):
    return tomllib.loads(Path(path).read_text()) if Path(path).exists() else {}


def toml(value):
    if isinstance(value, dict):
        return "{ " + ", ".join(f"{json.dumps(k)} = {toml(v)}" for k, v in value.items()) + " }"
    if isinstance(value, list):
        return "[" + ", ".join(toml(v) for v in value) + "]"
    return json.dumps(value, ensure_ascii=False, allow_nan=False)


def document(value, prefix=()):
    lines = [f"[{'.'.join(json.dumps(p) for p in prefix)}]"] if prefix else []
    lines += [f"{json.dumps(k)} = {toml(v)}" for k, v in value.items() if not isinstance(v, dict)]
    for key, child in value.items():
        if isinstance(child, dict):
            lines.extend(["", document(child, (*prefix, key))])
    return "\n".join(lines) + "\n"


def local():
    return read_toml(ROOT / "config.local.toml").get("_", {}).get("machine", {})


def selected():
    return read_toml(ROOT / "miserc.local.toml").get("env", [])


def regular_parents(path):
    path = home_path(path)
    if not path.is_relative_to(HOME):
        raise RuntimeError(f"Destination is outside HOME: {path}")
    for parent in path.parents:
        if parent == HOME:
            break
        if parent.is_symlink() or (parent.exists() and not parent.is_dir()):
            raise RuntimeError(f"Refusing redirected parent: {parent}")


def atomic(path, data, mode=0o600):
    path = home_path(path)
    regular_parents(path)
    if path.is_symlink():
        raise RuntimeError(f"Refusing symlink: {path}")
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    descriptor, temporary = tempfile.mkstemp(prefix=".pending-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(data if isinstance(data, bytes) else data.encode())
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def digest(path):
    path = Path(path)
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None


def read_state(name):
    path = STATE / f"{name}.json"
    return json.loads(path.read_text()) if path.exists() else {}


def write_state(name, value):
    atomic(STATE / f"{name}.json", json.dumps(value, indent=2) + "\n")


@contextmanager
def lock():
    regular_parents(STATE / "apply.lock")
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    path = STATE / "apply.lock"
    if path.is_symlink():
        raise RuntimeError(f"Refusing symlink: {path}")
    with path.open("a") as stream:
        try:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise RuntimeError("Another setup operation is running") from error
        previous = signal.signal(signal.SIGTERM, lambda number, _: sys.exit(128 + number))
        try:
            yield
        finally:
            signal.signal(signal.SIGTERM, previous)


def git_origin(value):
    # Local bare repositories are useful for offline recovery and integration checks.
    if value.startswith("/") or value.startswith("ssh://"):
        return value
    if ":" in value and "@" in value.split(":", 1)[0] and "://" not in value:
        return value
    url = urlsplit(value)
    if (url.scheme == "https" and url.hostname and url.path.strip("/")
            and url.username is None and not url.query and not url.fragment):
        return value
    raise ValueError("Use an HTTPS or SSH Git origin; keep HTTPS credentials in a credential helper, not the URL")
