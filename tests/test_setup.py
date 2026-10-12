"""Integration boundaries owned by this repository; native mise and Git are real."""

import http.server
import json
import os
import plistlib
import pty
import select
import shutil
import signal
import ssl
import subprocess
import sys
import tempfile
import threading
import time
import tomllib
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
MISE = os.environ.get("MISE_BIN") or shutil.which("mise")
if MISE is None:
    raise RuntimeError("mise is required to run the integration tests")
MISE = str(Path(MISE).resolve())
GIT = shutil.which("git")
if GIT is None:
    raise RuntimeError("git is required to run the integration tests")
FISH = shutil.which("fish")
WT = shutil.which("wt")


class Machine:
    def __init__(self, root, name):
        self.home = root.resolve() / name
        self.config = self.home / ".config/mise"
        self.config.mkdir(parents=True)
        (self.home / ".local/bin").mkdir(parents=True)
        (self.home / ".local/bin/mise").symlink_to(MISE)
        (self.home / ".local/bin/git").symlink_to(GIT)
        python = (
            self.home
            / "data/installs/python"
            / (".".join(map(str, sys.version_info[:3])))
        )
        python.parent.mkdir(parents=True)
        python.symlink_to(Path(sys.executable).resolve().parents[1])
        self.env = {
            "HOME": str(self.home),
            "PATH": str(self.home / ".local/bin") + ":/usr/bin:/bin:/usr/sbin:/sbin",
            "MISE_BIN": MISE,
            "MISE_CONFIG_DIR": str(self.config),
            "MISE_DATA_DIR": str(self.home / "data"),
            "MISE_CACHE_DIR": str(self.home / "cache"),
            "MISE_STATE_DIR": str(self.home / "state"),
            "MISE_SYSTEM_CONFIG_FILE": str(root / "absent"),
            "MISE_TRUSTED_CONFIG_PATHS": str(self.config),
            "MISE_YES": "1",
            "MISE_OFFLINE": "1",
            "MISE_CEILING_PATHS": str(self.home),
            "GIT_TERMINAL_PROMPT": "0",
            "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_CONFIG_GLOBAL": str(self.home / ".gitconfig"),
            "PYTHONPATH": str(REPO / "conf.d/setup")
            + os.pathsep
            + str(REPO / "bootstrap"),
        }
        self.write(
            "config.local.toml", '[_.machine]\nid="' + name + '"\nsync="manual"\n'
        )
        (self.home / ".gitconfig").write_text(
            "[user]\nname=Fixture\nemail=fixture@example.invalid\n"
        )

    def write(self, name, content):
        path = self.config / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def run(self, *args, ok=True, cwd=None):
        result = subprocess.run(
            [str(a) for a in args],
            cwd=cwd or self.home,
            env=self.env,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=90,
        )
        if ok and result.returncode:
            raise AssertionError(f"{args}:\n{result.stdout}\n{result.stderr}")
        return result

    def mise(self, *args, **kwargs):
        return self.run(MISE, *args, **kwargs)

    def python(self, code, **kwargs):
        return self.run(sys.executable, "-c", code, **kwargs)

    def password_command(self, *args, password="synthetic recovery test passphrase"):
        pid, terminal = pty.fork()
        if pid == 0:
            os.chdir(self.home)
            os.execve(sys.executable, [sys.executable, *map(str, args)], self.env)
        output = b""
        deadline = time.monotonic() + 30
        prompts = 0
        try:
            while time.monotonic() < deadline:
                if not select.select([terminal], [], [], 1)[0]:
                    continue
                try:
                    chunk = os.read(terminal, 4096)
                except OSError:
                    break
                if not chunk:
                    break
                output += chunk
                ready = (
                    output.count(b"Enter passphrase:")
                    + output.count(
                        b"Enter passphrase (leave empty to autogenerate a secure one):"
                    )
                    + output.count(b"Confirm passphrase:")
                )
                if ready > prompts:
                    os.write(terminal, password.encode() + b"\n")
                    prompts += 1
            else:
                raise AssertionError("age password prompt timed out")
        finally:
            os.close(terminal)
            if time.monotonic() >= deadline:
                os.kill(pid, 9)
            _, status = os.waitpid(pid, 0)
        return os.waitstatus_to_exitcode(status), output.decode(errors="replace")

    def payload(self):
        for file in ("config.toml", "miserc.toml"):
            shutil.copy2(REPO / file, self.config / file)
        shutil.copytree(
            REPO / "conf.d",
            self.config / "conf.d",
            ignore=shutil.ignore_patterns("__pycache__"),
        )
        shutil.copytree(REPO / "tasks", self.config / "tasks")
        self.env["MISE_HISTORY_ENABLED"] = "false"

    def encryption(self, key=None):
        (self.home / ".ssh").mkdir(exist_ok=True)
        identity = self.home / ".ssh/id_ed25519"
        if key is None:
            self.run("ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", identity)
        else:
            shutil.copy2(key, identity)
            shutil.copy2(str(key) + ".pub", str(identity) + ".pub")
        self.write(
            "conf.d/history/mise.toml",
            "[history.encryption]\nrecipients = ["
            + json.dumps(Path(str(identity) + ".pub").read_text().strip())
            + "]\n",
        )
        if (self.config / "config.toml").exists():
            self.python("import preferences; preferences.prepare_history()")
        return identity

    def minimal(self):
        shutil.copytree(
            REPO / "conf.d/setup",
            self.config / "conf.d/setup",
            ignore=shutil.ignore_patterns("__pycache__"),
        )
        self.write(
            "config.toml",
            """[settings.history]
sync = "manual"
[dotfiles]
"~/.config/mise" = { mode = "track", exclude = ["/private", "*.local.toml", "age.txt", "__pycache__"] }
"~/.config/mise/private/preferences" = { mode = "track", encrypt = true }
"~/shared.txt" = "~/.config/mise/shared.txt"
""",
        )
        self.write("shared.txt", "initial\n")


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix="dotfiles-test-")
        self.root = Path(self.scratch.name)

    def tearDown(self):
        self.scratch.cleanup()

    def test_setup_downloads_use_system_trust(self):
        machine = Machine(self.root, "https")
        certificate = machine.home / "test-ca.pem"
        key = machine.home / "test-key.pem"
        options = machine.home / "openssl.cnf"
        options.write_text(
            "[req]\nprompt=no\ndistinguished_name=subject\nx509_extensions=extensions\n"
            "[subject]\nCN=localhost\n[extensions]\nsubjectAltName=DNS:localhost\n"
            "basicConstraints=critical,CA:true\nkeyUsage=critical,digitalSignature,keyEncipherment,keyCertSign\n"
        )
        machine.run(
            "openssl",
            "req",
            "-x509",
            "-newkey",
            "rsa:2048",
            "-nodes",
            "-days",
            "1",
            "-config",
            options,
            "-keyout",
            key,
            "-out",
            certificate,
        )

        class Metadata(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path == "/redirect":
                    self.send_response(302)
                    self.send_header("Location", "http://localhost/metadata")
                    self.end_headers()
                    return
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(b'{"version":"1.2.3"}')

            def log_message(self, format, *args):
                pass

        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(certificate, key)
        with http.server.ThreadingHTTPServer(("127.0.0.1", 0), Metadata) as server:
            server.socket = context.wrap_socket(server.socket, server_side=True)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                url = f"https://localhost:{server.server_port}/metadata"
                invocation = (
                    "import json, runpy; read = runpy.run_path("
                    + repr(str(REPO / "conf.d/languages/dotnet-lts.py"))
                    + ')["read_json"]; print(json.dumps(read('
                    + repr(url)
                    + ")))"
                )
                machine.env["CURL_CA_BUNDLE"] = str(certificate)
                machine.env["SSL_CERT_FILE"] = str(machine.home / "missing-roots.pem")

                downloaded = machine.python(invocation)

                self.assertEqual(json.loads(downloaded.stdout), {"version": "1.2.3"})
                refused = machine.python(
                    invocation.replace("/metadata", "/redirect"), ok=False
                )
                self.assertNotEqual(refused.returncode, 0)
                self.assertIn("HTTPS download failed", refused.stderr)
                self.assertIn("curl: (1)", refused.stderr)
                del machine.env["CURL_CA_BUNDLE"]
                del machine.env["SSL_CERT_FILE"]
                (machine.home / ".curlrc").write_text("insecure\n")

                refused = machine.python(invocation, ok=False)

                self.assertNotEqual(refused.returncode, 0)
                self.assertIn("HTTPS download failed", refused.stderr)
                self.assertIn("curl: (60)", refused.stderr)
                self.assertNotIn('"version":', refused.stdout)
            finally:
                server.shutdown()
                thread.join(timeout=5)

    def test_screen_lock_setup_and_native_diagnostic(self):
        machine = Machine(self.root, "screen-lock")
        script = REPO / "conf.d/macos/screen-lock.sh"
        target = machine.config / "conf.d/macos/screen-lock.sh"
        target.parent.mkdir(parents=True)
        shutil.copy2(script, target)
        native = tomllib.loads((REPO / "conf.d/macos/mise.macos.toml").read_text())
        machine.write(
            "config.toml",
            "[doctor.checks.screen-lock]\nrun = "
            + json.dumps(native["doctor"]["checks"]["screen-lock"]["run"])
            + "\n",
        )
        command = machine.home / ".local/bin/sysadminctl"
        command.write_text(
            """#!/bin/bash
set -euo pipefail
[[ "$1" == -screenLock ]]
if [[ "$2" == status ]]; then
  [[ ! -f "$HOME/unreadable" ]] || exit 2
  printf 'sysadminctl[123:456] screenLock delay is %s\\n' "$(cat "$HOME/delay")" >&2
else
  [[ "$*" == '-screenLock immediate -password -' ]]
  touch "$HOME/authorized"
  [[ -f "$HOME/rejected" ]] || echo immediate > "$HOME/delay"
fi
"""
        )
        command.chmod(0o755)
        delay = machine.home / "delay"
        authorized = machine.home / "authorized"
        for value in ("immediate", "0 seconds"):
            delay.write_text(value)
            machine.mise("doctor", "project")
            machine.run("/bin/bash", script, "apply")
            self.assertFalse(authorized.exists())

        delay.write_text("300 seconds")
        self.assertNotEqual(machine.mise("doctor", "project", ok=False).returncode, 0)
        self.assertNotEqual(
            machine.run("/bin/bash", script, "apply", ok=False).returncode, 0
        )
        self.assertFalse(authorized.exists())
        invocation = (
            "import subprocess; raise SystemExit(subprocess.call("
            + repr(["/bin/bash", str(script), "apply"])
            + "))"
        )
        code, output = machine.password_command("-c", invocation)
        self.assertEqual(code, 0, output)
        self.assertTrue(authorized.exists())
        machine.mise("doctor", "project")

        delay.write_text("off")
        (machine.home / "rejected").touch()
        code, output = machine.password_command("-c", invocation)
        self.assertNotEqual(code, 0, output)
        self.assertIn("macOS did not enable", output)
        authorized.unlink()
        (machine.home / "unreadable").touch()
        code, output = machine.password_command("-c", invocation)
        self.assertNotEqual(code, 0, output)
        self.assertFalse(authorized.exists())

        (machine.home / "unreadable").unlink()
        delay.write_text("immediate")
        target.unlink()
        machine.minimal()
        machine.encryption()
        machine.env["MISE_ENV"] = "macos"
        runtime = machine.config / "conf.d/setup/runtime.py"
        current_runtime = runtime.read_text()
        old_runtime = current_runtime.replace(
            "process_group=0,", "start_new_session=True,"
        ).replace('        MISE_RAW="1",\n', "")
        runtime.write_text(old_runtime + "\n# Keep my local setup changes.\n")
        runtime.chmod(0o640)
        ruby = machine.home / "data/installs/ruby/4.0.0/bin/ruby"
        ruby.parent.mkdir(parents=True)
        ruby.symlink_to(shutil.which("true"))
        local = machine.config / "config.local.toml"
        local.write_text(local.read_text() + '\n[tools]\nruby = "4.0.0"\n')
        previous = {
            "run": "/usr/sbin/sysadminctl -screenLock status 2>&1 | /usr/bin/grep -q 'delay is 0 seconds'",
            "hint": "Set Require password after screen saver or display is turned off to Immediately in System Settings.",
        }
        current = native["doctor"]["checks"]["screen-lock"]
        declaration = "[doctor.checks.screen-lock]\n" + "".join(
            f"{key} = {json.dumps(value)}\n"
            for key, value in current.items()
            if key != "os"
        )
        old = declaration
        for key, value in previous.items():
            old = old.replace(json.dumps(current[key]), json.dumps(value))
        personal = "\n# Keep my keyboard settings.\n[bootstrap.macos.keyboard]\nkey_repeat = 7\n"
        active = machine.write("conf.d/macos/mise.macos.toml", old + personal)
        active.chmod(0o640)
        checkout = machine.home / "public"
        (checkout / "bootstrap").mkdir(parents=True)
        shutil.copy2(REPO / "bootstrap/enroll.py", checkout / "bootstrap/enroll.py")
        shutil.copytree(
            REPO / "conf.d/setup",
            checkout / "conf.d/setup",
            ignore=shutil.ignore_patterns("__pycache__"),
        )
        (checkout / "conf.d/macos").mkdir()
        (checkout / "conf.d/macos/mise.macos.toml").write_text(declaration)
        shutil.copy2(script, checkout / "conf.d/macos/screen-lock.sh")
        (checkout / "tasks").mkdir()
        task = checkout / "tasks/config"
        task.write_text(
            """#!/bin/bash
#MISE description="Inspect or apply this machine setup"
#MISE raw=true
set -euo pipefail
mise doctor project
mise bootstrap --only packages --yes
mise exec python@3 -- python3 - <<'PY'
import os, sys
sys.path.insert(0, os.environ['MISE_CONFIG_DIR'] + '/conf.d/setup')
from runtime import run
if 'EXPECTED_SESSION' in os.environ:
    run([sys.executable, '-c', 'import os; assert os.getsid(0) == int(os.environ["EXPECTED_SESSION"]); open("/dev/tty").close()'])
PY
touch "$HOME/setup-applied"
"""
        )
        task.chmod(0o755)
        for name in ("sync", "update"):
            shutil.copy2(REPO / "tasks" / name, checkout / "tasks" / name)
        active_task = machine.write(
            "tasks/config", task.read_text().replace("#MISE raw=true\n", "")
        )
        active_task.chmod(0o755)
        machine.run("git", "init", "-q", checkout)
        machine.run("git", "-C", checkout, "add", "conf.d", "tasks")
        invocation = (
            "import runpy, sys; sys.platform = 'darwin'; sys.argv = "
            + repr([str(checkout / "bootstrap/enroll.py"), "--machine", "screen-lock"])
            + "; runpy.run_path(sys.argv[0], run_name='__main__')"
        )
        machine.python(
            invocation.replace("; runpy.", "; sys.argv.append('--seed-only'); runpy.")
        )
        self.assertEqual(active.read_text(), old + personal)
        self.assertEqual(
            runtime.read_text(), old_runtime + "\n# Keep my local setup changes.\n"
        )

        code, output = machine.password_command(
            "-c",
            "import os; os.environ['EXPECTED_SESSION'] = str(os.getsid(0)); "
            + invocation,
        )

        self.assertEqual(code, 0, output)
        self.assertIn("PASS screen-lock", output)
        self.assertNotIn("-run =", output)
        self.assertNotIn("+run =", output)
        self.assertTrue((machine.home / "setup-applied").exists())
        self.assertEqual(active.read_text(), declaration + personal)
        self.assertEqual(active.stat().st_mode & 0o777, 0o640)
        self.assertEqual(
            runtime.read_text(), current_runtime + "\n# Keep my local setup changes.\n"
        )
        self.assertEqual(runtime.stat().st_mode & 0o777, 0o640)
        self.assertFalse(authorized.exists())
        updated = active.stat().st_mtime_ns
        runtime_updated = runtime.stat().st_mtime_ns
        code, output = machine.password_command(
            "-c",
            "import os, subprocess; os.environ['EXPECTED_SESSION'] = str(os.getsid(0)); "
            "subprocess.run(['mise', 'run', 'config', 'apply'], check=True)",
        )
        self.assertEqual(code, 0, output)
        machine.python(invocation)
        self.assertEqual(active.stat().st_mtime_ns, updated)
        self.assertEqual(runtime.stat().st_mtime_ns, runtime_updated)
        custom = (declaration + personal).replace(
            json.dumps(current["run"]), '"exit 1"'
        )
        active.write_text(custom)
        (machine.home / "setup-applied").unlink()
        refused = machine.python(invocation, ok=False)
        self.assertNotEqual(refused.returncode, 0)
        self.assertEqual(active.read_text(), custom)
        self.assertFalse((machine.home / "setup-applied").exists())

    def test_enrollment_repairs_public_downloads_and_preserves_local_edits(self):
        machine = Machine(self.root, "downloads")
        machine.minimal()
        machine.encryption()
        previous = """import json
import urllib.request

from runtime import mise

def check_version():
        with urllib.request.urlopen(
            "https://formulae.brew.sh/api/cask/macfuse.json", timeout=30
        ) as response:
            version = json.load(response)["version"]
        return version

# Keep my local package policy.
BLOCKED_VERSION = "5.3.3"
"""
        active = machine.write("conf.d/setup/packages.py", previous)
        active.chmod(0o640)
        previous_skills = (
            '[bootstrap.repos]\n"~/Projects/LuisUrrutia/skills" = '
            '{url="git@github.com:LuisUrrutia/skills.git", ref="main"}\n'
            '\n# Keep my local skill task.\n[tasks.personal]\nrun="echo personal"\n'
        )
        skills = machine.write("conf.d/skills/mise.toml", previous_skills)
        skills.chmod(0o640)
        sync = machine.config / "conf.d/setup/sync.py"
        current_sync = sync.read_text()
        previous_sync = current_sync.replace(
            "        name = path.relative_to(HOME) if path.is_relative_to(HOME) else path\n"
            '        value.update(str(name).encode() + b"\\0" + path.read_bytes())\n',
            '        value.update(str(path.relative_to(HOME)).encode() + b"\\0" + path.read_bytes())\n',
        )
        sync.write_text(previous_sync + "\n# Keep my local sync changes.\n")
        sync.chmod(0o640)
        previous_autofirma = """import shlex
from runtime import STATE

def finish(installer, version):
    # The vendor's postinstall requires GUI interaction even with the CLI installer.
    raise RuntimeError(
        f"Complete AutoFirma's vendor installer: open {shlex.quote(str(installer))}\\n"
        "Then rerun mise -C ~ run config apply. Automatic setup remains pending."
    )

# Keep my local installer policy.
INSTALLER_POLICY = "local"
"""
        autofirma = machine.write("conf.d/autofirma/setup.py", previous_autofirma)
        autofirma.chmod(0o640)
        (machine.config / "conf.d/setup/downloads.py").unlink(missing_ok=True)
        checkout = machine.home / "public"
        (checkout / "bootstrap").mkdir(parents=True)
        shutil.copy2(REPO / "bootstrap/enroll.py", checkout / "bootstrap/enroll.py")
        shutil.copytree(
            REPO / "conf.d/setup",
            checkout / "conf.d/setup",
            ignore=shutil.ignore_patterns("__pycache__"),
        )
        shutil.copytree(REPO / "tasks", checkout / "tasks")
        shutil.copytree(REPO / "conf.d/skills", checkout / "conf.d/skills")
        shutil.copytree(
            REPO / "conf.d/autofirma",
            checkout / "conf.d/autofirma",
            ignore=shutil.ignore_patterns("__pycache__"),
        )
        machine.run("git", "init", "-q", checkout)
        machine.run("git", "-C", checkout, "add", "conf.d", "tasks")
        task = machine.write("tasks/config", "#!/bin/bash\n#MISE raw=true\nexit 0\n")
        task.chmod(0o755)
        invocation = (
            "import runpy, sys; sys.platform = 'linux'; sys.argv = "
            + repr([str(checkout / "bootstrap/enroll.py"), "--machine", "downloads"])
            + "; runpy.run_path(sys.argv[0], run_name='__main__')"
        )

        machine.python(invocation)

        self.assertNotIn("urllib.request", active.read_text())
        self.assertIn("from downloads import download", active.read_text())
        self.assertIn(
            '# Keep my local package policy.\nBLOCKED_VERSION = "5.3.3"',
            active.read_text(),
        )
        self.assertEqual(active.stat().st_mode & 0o777, 0o640)
        self.assertTrue((machine.config / "conf.d/setup/downloads.py").is_file())
        self.assertEqual(
            skills.read_text(),
            previous_skills.replace(
                "git@github.com:LuisUrrutia/skills.git",
                "https://github.com/LuisUrrutia/skills.git",
            ),
        )
        self.assertEqual(skills.stat().st_mode & 0o777, 0o640)
        self.assertEqual(
            sync.read_text(), current_sync + "\n# Keep my local sync changes.\n"
        )
        self.assertEqual(sync.stat().st_mode & 0o777, 0o640)
        self.assertIn(
            "complete_installation(installer, version)", autofirma.read_text()
        )
        self.assertIn('INSTALLER_POLICY = "local"', autofirma.read_text())
        self.assertEqual(autofirma.stat().st_mode & 0o777, 0o640)
        self.assertTrue((autofirma.parent / "installer.py").is_file())
        pending = machine.python(
            "import os, runpy, sys; os.setsid(); sys.path.insert(0, "
            + repr(str(autofirma.parent))
            + "); module = runpy.run_path("
            + repr(str(autofirma))
            + "); module['finish']('fixture.pkg', '2.4.0')",
            ok=False,
        )
        self.assertNotEqual(pending.returncode, 0)
        self.assertIn("from a terminal", pending.stderr)
        plan = machine.mise(
            "bootstrap", "repos", "update", "~/Projects/LuisUrrutia/skills", "--dry-run"
        )
        self.assertIn(
            "git clone --branch main https://github.com/LuisUrrutia/skills.git",
            plan.stdout,
        )
        updated = active.stat().st_mtime_ns
        skills_updated = skills.stat().st_mtime_ns
        sync_updated = sync.stat().st_mtime_ns
        autofirma_updated = autofirma.stat().st_mtime_ns
        machine.python(invocation)
        self.assertEqual(active.stat().st_mtime_ns, updated)
        self.assertEqual(skills.stat().st_mtime_ns, skills_updated)
        self.assertEqual(sync.stat().st_mtime_ns, sync_updated)
        self.assertEqual(autofirma.stat().st_mtime_ns, autofirma_updated)
        custom = previous_skills.replace(
            "git@github.com:LuisUrrutia/skills.git", "git@github.com:example/skills.git"
        )
        skills.write_text(custom)
        machine.python(invocation)
        self.assertEqual(skills.read_text(), custom)
        foreign = machine.home / "foreign.py"
        foreign.write_text(previous)
        active.unlink()
        active.symlink_to(foreign)

        refused = machine.python(invocation, ok=False)

        self.assertNotEqual(refused.returncode, 0)
        self.assertTrue(active.is_symlink())
        self.assertEqual(foreign.read_text(), previous)

    def test_native_apply_accepts_package_sources_outside_home(self):
        machine = Machine(self.root, "package-sources")
        machine.minimal()
        machine.encryption()
        sources = tomllib.loads((REPO / "conf.d/dev/mise.macos.toml").read_text())[
            "dotfiles"
        ]
        declarations = []
        for target, source in sources.items():
            external = self.root.resolve() / source.lstrip("/")
            external.parent.mkdir(parents=True, exist_ok=True)
            external.write_text("Package fixture\n")
            declarations.append(f"{json.dumps(target)} = {json.dumps(str(external))}")
        machine.write("conf.d/dev/mise.toml", "[dotfiles]\n" + "\n".join(declarations))

        machine.run(sys.executable, machine.config / "conf.d/setup/config.py", "apply")

        for target, source in sources.items():
            deployed = machine.home / target.removeprefix("~/")
            self.assertTrue(deployed.is_symlink())
            self.assertEqual(
                deployed.resolve(), self.root.resolve() / source.lstrip("/")
            )
        state = machine.home / "state/dotfiles/apply.json"
        applied = json.loads(state.read_text())["applied"]
        machine.python("import sync; sync.apply_setup()")
        self.assertEqual(json.loads(state.read_text())["applied"], applied)
        buildx = self.root.resolve() / sources[
            "~/.docker/cli-plugins/docker-buildx"
        ].lstrip("/")
        buildx.write_text("Updated package fixture\n")

        machine.python("import sync; sync.apply_setup()")

        self.assertNotEqual(json.loads(state.read_text())["applied"], applied)
        self.assertEqual(buildx.read_text(), "Updated package fixture\n")

    def test_autofirma_waits_for_interactive_installation(self):
        machine = Machine(self.root, "autofirma")
        invocation = (
            "import runpy, sys\n"
            + "sys.path.insert(0, "
            + repr(str(REPO / "conf.d/autofirma"))
            + ")\nmodule = runpy.run_path("
            + repr(str(REPO / "conf.d/autofirma/setup.py"))
            + ')["main"].__globals__\n'
            + """import hashlib, io, json, plistlib, subprocess, zipfile
from pathlib import Path
home = Path.home()
info = home / 'AutoFirma.app/Contents/Info.plist'
module['installed'].__globals__['APP_INFO'] = info
module['platform'].system = lambda: 'Darwin'
module['platform'].machine = lambda: 'arm64'
archive = io.BytesIO()
with zipfile.ZipFile(archive, 'w') as bundle:
    bundle.writestr('AutoFirma_fixture_signed.pkg', b'fixture vendor package')
archive = archive.getvalue()
metadata = {'version': '2.4.0', 'url': 'https://example.invalid/autofirma.zip',
            'sha256': hashlib.sha256(archive).hexdigest(),
            'artifacts': [{'installer': [{'manual': 'AutoFirma_fixture_signed.pkg'}]}]}
module['download'] = lambda url, **kwargs: json.dumps(metadata).encode() if url == module['CASK'] else archive
def vendor_command(args, **kwargs):
    if args[:2] == ['/usr/sbin/pkgutil', '--check-signature']:
        assert Path(args[2]).read_bytes() == b'fixture vendor package'
    elif args[:2] == ['/usr/sbin/pkgutil', '--pkg-info-plist']:
        receipt = home / 'receipt.plist'
        return subprocess.CompletedProcess(args, 0 if receipt.exists() else 1, receipt.read_bytes() if receipt.exists() else b'')
    elif args[:3] == ['/usr/bin/open', '-W', '-a']:
        assert args[3] == '/System/Library/CoreServices/Installer.app'
        assert Path(args[4]).read_bytes() == b'fixture vendor package'
        with (home / 'opened').open('a') as stream:
            stream.write('opened\\n')
        if not (home / 'cancel').exists():
            info.parent.mkdir(parents=True, exist_ok=True)
            info.write_bytes(plistlib.dumps({'CFBundleIdentifier': 'es.gob.afirma.simpleafirma.osx'}))
            (home / 'receipt.plist').write_bytes(plistlib.dumps({'pkg-version': '2.4.0'}))
    else:
        raise AssertionError(args)
    return subprocess.CompletedProcess(args, 0, b'')
module['subprocess'].run = vendor_command
module['main']()
"""
        )

        code, output = machine.password_command("-c", invocation)

        self.assertEqual(code, 0, output)
        self.assertIn("AutoFirma 2.4.0 is installed", output)
        opened = machine.home / "opened"
        self.assertEqual(opened.read_text(), "opened\n")
        machine.python(invocation)
        self.assertEqual(opened.read_text(), "opened\n")
        (machine.home / "receipt.plist").unlink()
        opened.unlink()

        pending = machine.python("import os; os.setsid()\n" + invocation, ok=False)

        self.assertNotEqual(pending.returncode, 0)
        self.assertIn("from a terminal", pending.stderr)
        self.assertFalse(opened.exists())
        (machine.home / "cancel").touch()

        code, output = machine.password_command("-c", invocation)

        self.assertNotEqual(code, 0, output)
        self.assertIn("AutoFirma installation is incomplete", output)
        self.assertFalse((machine.home / "receipt.plist").exists())

    def test_seed_and_native_deployment_preserve_user_files(self):
        machine = Machine(self.root, "safe")
        machine.python("""import enroll
from types import SimpleNamespace
enroll.sys.platform = 'darwin'
enroll.subprocess.run = lambda *args, **kwargs: SimpleNamespace(stdout='"IOPlatformUUID" = "00000000-1111-2222-3333-444444444444"')
assert enroll.machine_id() == 'd16fe322fd5b'
""")
        machine.payload()
        manager = machine.home / ".local/share/fisher/functions/fisher.fish"
        manager.parent.mkdir(parents=True)
        manager.write_text(
            """function fisher
    switch $argv[1]
        case install update
            printf 'one/plugin\\n' > "$HOME/.config/fish/fish_plugins"
            test "$argv[2]" != two/plugin; or test ! -e "$HOME/plugin-download-fails"
        case list
            echo one/plugin
            test ! -e "$HOME/plugins-ready"; or echo two/plugin
    end
end
"""
        )
        linux = tomllib.loads((REPO / "conf.d/fish/mise.linux.toml").read_text())
        macos = tomllib.loads((REPO / "conf.d/dev/mise.macos.toml").read_text())
        package_sources = {}
        for target, source in macos["dotfiles"].items():
            fixture = self.root.resolve() / source.lstrip("/")
            fixture.parent.mkdir(parents=True, exist_ok=True)
            fixture.write_text("Package fixture\n")
            package_sources[target] = str(fixture)
        with (machine.config / "config.local.toml").open("a") as stream:
            stream.write(
                "\n[dotfiles]\n"
                + "\n".join(
                    f"{json.dumps(target)} = {json.dumps(source)}"
                    for target, source in (linux["dotfiles"] | package_sources).items()
                )
                + "\n"
            )
        machine.mise("tasks", "validate")
        self.assertEqual(
            machine.mise("tool-alias", "ls", "dotnet").stdout.split(),
            ["dotnet", "lts", "10"],
        )
        machine.python("""import runpy
from datetime import date
from runtime import ROOT, STATE, atomic
module = runpy.run_path(str(ROOT/'conf.d/languages/dotnet-lts.py'))
metadata = module['METADATA']
channels = [
    {'channel-version': version, 'release-type': kind, 'support-phase': phase}
    for version, kind, phase in [('10.0','lts','maintenance'), ('13.0','sts','active'), ('12.0','lts','active'), ('14.0','lts','preview'), ('8.0','lts','eol')]
]
responses = {
    metadata+'/releases-index.json': {'releases-index': channels},
    metadata+'/12.0/releases.json': {'releases': [
        {'release-date':'2028-10-12','sdk':{'version':'12.0.102'}},
        {'release-date':'2028-10-09','sdks':[{'version':'12.0.99'},{'version':'12.0.100'}]},
        {'release-date':'2028-10-01','sdk':{'version':'12.0.101-preview.1'}},
    ]},
    metadata+'/10.0/releases.json': {'releases': [
        {'release-date':'2028-09-12','sdk':{'version':'10.0.500'}},
    ]},
}
resolve = module['latest_lts']
assert resolve(read=responses.__getitem__, today=date(2028,10,10)) == '10.0.500'
assert resolve(read=responses.__getitem__, today=date(2028,10,12)) == '12.0.100'
assert resolve(read=responses.__getitem__, today=date(2028,10,15)) == '12.0.102'
atomic(STATE/'dotnet-lts', '12.0.100\\n')
""")
        self.assertEqual(
            machine.mise("tool-alias", "ls", "dotnet").stdout.split(),
            ["dotnet", "lts", "12.0.100"],
        )
        (Path(machine.env["MISE_STATE_DIR"]) / "dotfiles/dotnet-lts").unlink()
        variants = sorted(
            {
                path.stem.removeprefix("mise.")
                for path in (machine.config / "conf.d").glob("*/mise.*.toml")
            }
            - {"macos", "linux", "local"}
        )
        choices = machine.write(
            "miserc.local.toml", "env = " + json.dumps(variants) + "\n"
        )
        machine.mise("tasks", "validate")
        choices.unlink()
        completions = machine.home / ".config/fish/completions"
        completions.mkdir(parents=True)
        foreign_completion = machine.home / "custom-completion.fish"
        foreign_completion.write_text("# User completion\n")
        for name, symlink in (("bun", False), ("uv", True)):
            target = completions / f"{name}.fish"
            if symlink:
                target.symlink_to(foreign_completion)
            else:
                target.write_text("# User completion\n")
            refused = machine.python("import config; config.check()", ok=False)
            self.assertNotEqual(refused.returncode, 0)
            self.assertEqual(target.read_text(), "# User completion\n")
            self.assertEqual(target.is_symlink(), symlink)
            target.unlink()
        (machine.home / ".codex").mkdir()
        (machine.home / ".codex/config.toml").write_text(
            "[plugins.example]\nenabled=true\n"
        )
        (machine.home / ".claude").mkdir()
        (machine.home / ".claude/settings.json").write_text(
            '{"customUserSetting": true}'
        )
        machine.mise("run", "config", "check")
        machine.mise("bootstrap", "--only", "files,dotfiles", "--yes")
        for target, source in package_sources.items():
            deployed = machine.home / target.removeprefix("~/")
            self.assertTrue(deployed.is_symlink())
            self.assertEqual(deployed.resolve(), Path(source))
        self.assertEqual((machine.home / ".ssh").stat().st_mode & 0o777, 0o700)
        machine.python("import finish; finish.instructions()")
        machine.python("import config; config.check(); config.remember()")
        self.assertTrue(
            tomllib.loads((machine.home / ".codex/config.toml").read_text())["plugins"][
                "example"
            ]["enabled"]
        )
        self.assertTrue(
            json.loads((machine.home / ".claude/settings.json").read_text())[
                "customUserSetting"
            ]
        )
        codex = machine.home / ".codex/config.toml"
        codex.write_text(codex.read_text().replace('"pragmatic"', '"friendly"'))
        claude = machine.home / ".claude/settings.json"
        settings = json.loads(claude.read_text())
        settings["theme"] = "light"
        claude.write_text(json.dumps(settings))
        machine.python("import edits; edits.capture()")
        shared = tomllib.loads(
            (machine.config / "conf.d/codex/settings.toml").read_text()
        )
        self.assertEqual(shared["personality"], "friendly")
        self.assertNotIn("plugins", shared)
        shared_claude = json.loads(
            (machine.config / "conf.d/claude/settings.json").read_text()
        )
        self.assertEqual(shared_claude["theme"], "light")
        self.assertNotIn("customUserSetting", shared_claude)
        source = machine.config / "conf.d/codex/settings.toml"
        source.write_text(source.read_text().replace('"friendly"', '"pragmatic"'))
        codex.write_text(codex.read_text().replace('"friendly"', '"none"'))
        self.assertNotEqual(
            machine.python("import edits; edits.capture()", ok=False).returncode, 0
        )
        machine.python(
            "import config; config.resolve('discard', '~/.codex/config.toml')"
        )
        self.assertEqual(tomllib.loads(codex.read_text())["personality"], "pragmatic")
        self.assertTrue(
            tomllib.loads(codex.read_text())["plugins"]["example"]["enabled"]
        )
        fish = machine.home / ".config/fish"
        self.assertFalse(fish.is_symlink())
        self.assertFalse((fish / "mise.toml").exists())
        self.assertTrue((fish / "config.fish").is_symlink())
        self.assertTrue((fish / "functions/fisher.fish").is_symlink())
        self.assertEqual((fish / "functions/fisher.fish").resolve(), manager)
        machine.env["PAGER"] = "fixture-pager"
        smoke = machine.run(
            FISH, "-c", 'test "$PAGER" = fixture-pager; and not set -q FZF_DEFAULT_OPTS'
        )
        self.assertEqual(smoke.stdout, "")

        origin = self.root / "skills origin"
        skill = origin / "personal-example"
        skill.mkdir(parents=True)
        (skill / "SKILL.md").write_text("Personal skill\n")
        machine.run("git", "init", "--initial-branch=main", origin)
        machine.run("git", "add", ".", cwd=origin)
        machine.run("git", "commit", "-m", "fixture", cwd=origin)
        checkout = machine.home / "Projects/LuisUrrutia/skills"
        plan = machine.mise("bootstrap", "repos", "update", str(checkout), "--dry-run")
        self.assertIn(
            "git clone https://github.com/LuisUrrutia/skills.git", plan.stdout
        )
        with (machine.config / "config.local.toml").open("a") as stream:
            stream.write(
                '\n[bootstrap.repos]\n"~/Projects/LuisUrrutia/skills" = {url='
                + json.dumps(str(origin))
                + "}\n"
            )
        machine.mise("bootstrap", "repos", "update", str(checkout), "--yes")
        (machine.home / ".local/bin/fish").symlink_to(FISH)
        installed = machine.home / ".agents/skills/personal-example"
        installed.mkdir(parents=True)
        (installed / "SKILL.md").write_text("Keep this edited installed copy\n")
        for _ in range(2):
            machine.mise("run", "skills:link")
        for agent in (".agents", ".claude"):
            target = machine.home / agent / "skills/personal-example"
            self.assertTrue(target.is_symlink())
            self.assertEqual(target.resolve(), checkout / "personal-example")
        backups = list((machine.home / ".agents/skills-backups").rglob("SKILL.md"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), "Keep this edited installed copy\n")
        added = origin / "new-personal-skill"
        added.mkdir()
        (added / "SKILL.md").write_text("Added upstream\n")
        machine.run("git", "add", ".", cwd=origin)
        machine.run("git", "commit", "-m", "add skill", cwd=origin)
        machine.mise("bootstrap", "repos", "update", str(checkout), "--yes")
        machine.mise("run", "skills:link")
        for agent in (".agents", ".claude"):
            target = machine.home / agent / "skills/new-personal-skill"
            self.assertEqual(target.resolve(), checkout / "new-personal-skill")
        owned = checkout / "personal-example/SKILL.md"
        owned.write_text("Uncommitted personal edit\n")
        refused = machine.mise(
            "bootstrap", "repos", "update", str(checkout), "--yes", ok=False
        )
        self.assertNotEqual(refused.returncode, 0)
        self.assertEqual(installed.joinpath("SKILL.md").read_text(), owned.read_text())
        agent_directory = installed.parent
        redirected = machine.home / "redirected-skills"
        agent_directory.rename(redirected)
        agent_directory.symlink_to(redirected)
        refused = machine.mise("run", "skills:link", ok=False)
        self.assertNotEqual(refused.returncode, 0)
        self.assertIn("Refusing redirected skill directory", refused.stderr)
        agent_directory.unlink()
        redirected.rename(agent_directory)

        self.assertEqual(machine.run(FISH, "-c", "fisher list").stdout, "one/plugin\n")
        manifest = fish / "fish_plugins"
        requested = "One/Plugin\nTwo/Plugin\n"
        manifest.write_text(requested)
        setup = machine.config / "conf.d/fish/setup.fish"
        partial = machine.run(FISH, setup, ok=False)
        self.assertNotEqual(partial.returncode, 0)
        self.assertIn("Fish plugin was not installed: two/plugin", partial.stderr)
        self.assertEqual(manifest.read_text(), requested)
        (machine.home / "plugins-ready").touch()
        machine.run(FISH, setup)
        self.assertEqual(manifest.read_text(), requested)
        (machine.home / "plugin-download-fails").touch()
        partial = machine.run(FISH, setup, ok=False)
        self.assertNotEqual(partial.returncode, 0)
        self.assertIn("Fish plugin update failed: two/plugin", partial.stderr)
        self.assertEqual(manifest.read_text(), requested)

        (fish / "runtime-state").write_text("keep me")
        (fish / "config.fish").unlink()
        (fish / "config.fish").write_text("set -g user_edit yes\n")
        refused = machine.python("import config; config.check()", ok=False)
        self.assertNotEqual(refused.returncode, 0)
        self.assertIn("Unmanaged or edited target", refused.stderr)
        machine.python(
            "import config; config.resolve('capture', '~/.config/fish/config.fish')"
        )
        self.assertEqual(
            (machine.config / "conf.d/fish/config.fish").read_text(),
            "set -g user_edit yes\n",
        )
        (machine.config / "conf.d/starship/starship.toml").unlink()
        machine.python("import enroll; enroll.seed()")
        self.assertTrue((machine.config / "conf.d/starship/starship.toml").is_file())
        self.assertEqual((fish / "config.fish").read_text(), "set -g user_edit yes\n")
        self.assertEqual((fish / "runtime-state").read_text(), "keep me")
        # Foreign file links and redirected parents cannot be overwritten by apply.
        (fish / "config.fish").unlink()
        foreign = machine.home / "foreign"
        foreign.write_text("foreign data")
        (fish / "config.fish").symlink_to(foreign)
        self.assertNotEqual(
            machine.python("import config; config.check()", ok=False).returncode, 0
        )
        self.assertEqual(foreign.read_text(), "foreign data")
        (fish / "config.fish").unlink()
        machine.mise("dot", "apply", "--yes")
        config_home = machine.home / ".config"
        config_home.rename(machine.home / "redirected")
        config_home.symlink_to(machine.home / "redirected")
        self.assertNotEqual(
            machine.python("import config; config.check()", ok=False).returncode, 0
        )

        for mode in ("empty", "excluded"):
            with self.subTest(stale_links=mode):
                stale = Machine(self.root, mode)
                stale.env["MISE_HISTORY_ENABLED"] = "false"
                declaration = '[dotfiles]\n"~/app"={source="source",mode="symlink-each"'
                stale.write("config.toml", declaration + "}\n")
                source = stale.write("source/removed/one", "managed source\n")
                apply = "import config; config.check(); config.apply_files(); config.remember()"
                stale.python(apply)
                target = stale.home / "app"
                if mode == "empty":
                    source.unlink()
                else:
                    target /= "removed"
                    stale.write("config.toml", declaration + ',exclude=["removed"]}\n')
                foreign = stale.home / "foreign"
                target.rename(foreign)
                target.symlink_to(foreign)
                link = foreign / ("removed/one" if mode == "empty" else "one")

                refused = stale.python(apply, ok=False)

                self.assertNotEqual(refused.returncode, 0)
                self.assertIn("Refusing redirected parent", refused.stderr)
                self.assertTrue(link.is_symlink())
                target.unlink()
                foreign.rename(target)
                stale.python(apply)
                self.assertFalse(
                    (
                        target / ("removed/one" if mode == "empty" else "one")
                    ).is_symlink()
                )

    def test_git_identities_keep_other_keys_and_match_worktrees(self):
        for kind in ("personal", "work", "agent", "unknown"):
            with self.subTest(kind=kind):
                machine = Machine(self.root, kind)
                module = machine.config / "conf.d/git"
                shutil.copytree(REPO / "conf.d/git", module)
                (module / "mise.macos.toml").unlink()
                machine.env["MISE_HISTORY_ENABLED"] = "false"
                default = {
                    "name": "Personal User",
                    "email": "personal@example.invalid",
                }
                accounts = {}
                if kind == "unknown":
                    default = {}
                if kind == "agent":
                    default["signing_key"] = "~/.ssh/id_ed25519.pub"
                if kind in ("work", "agent"):
                    accounts["team"] = {
                        "name": 'Work "Team" Urrutía',
                        "email": "work@example.invalid",
                        "directories": [
                            str(
                                machine.home
                                / (
                                    'work "space" [1]'
                                    if kind == "work"
                                    else r"work *?\[1]"
                                )
                            ),
                            "~/other work",
                        ],
                    }
                if kind == "work":
                    default = {}
                    accounts["second-team"] = {
                        "name": "Other User",
                        "email": "other@example.invalid",
                        "directories": [str(machine.home / "second team")],
                        "signing_key": "~/.ssh/work key.pub",
                    }
                record = {"git": {"default": default, "accounts": accounts}}
                code = """import enroll
record = RECORD
variables, files = enroll.git_settings(record)
values = {'vars': variables, 'bootstrap': {'files': files}}
enroll.atomic(enroll.ROOT / 'config.local.toml', enroll.document(values))
""".replace("RECORD", repr(record))
                machine.python(code)
                with (machine.home / ".gitconfig").open("a") as stream:
                    stream.write("[custom]\n  retained = yes\n")
                account_file = machine.home / ".config/git/account-team.gitconfig"
                if kind == "work":
                    account_file.parent.mkdir(parents=True)
                    account_file.write_text("Unmanaged account\n")
                    result = machine.python("import config; config.check()", ok=False)
                    self.assertIn("Unmanaged or edited target", result.stderr)
                    self.assertEqual(account_file.read_text(), "Unmanaged account\n")
                    account_file.unlink()
                apply = "import config; config.check(); config.apply_files(); config.remember()"
                machine.python(apply)
                machine.python(apply)
                self.assertEqual(
                    machine.run(
                        "git", "config", "--global", "--get", "custom.retained"
                    ).stdout.strip(),
                    "yes",
                )
                for url in (
                    "https://github.com/google/fonts.git",
                    "https://gitlab.com/example/project.git",
                    "git@github.com:example/private.git",
                ):
                    self.assertEqual(
                        machine.run(
                            "git", "ls-remote", "--get-url", url
                        ).stdout.strip(),
                        url,
                    )
                self.assertTrue(
                    (machine.home / ".gitconfig")
                    .read_text()
                    .startswith("[include] path =")
                )
                expected = (
                    "fixture@example.invalid"
                    if kind in ("work", "unknown")
                    else "personal@example.invalid"
                )
                self.assertEqual(
                    machine.run("git", "config", "user.email").stdout.strip(), expected
                )
                if kind == "agent":
                    self.assertEqual(
                        machine.run("git", "config", "commit.gpgsign").stdout.strip(),
                        "true",
                    )
                for name, account in accounts.items():
                    target = machine.home / f".config/git/account-{name}.gitconfig"
                    self.assertEqual(target.stat().st_mode & 0o777, 0o600)
                    repository = Path(account["directories"][0]) / "repo"
                    repository.mkdir(parents=True)
                    machine.run("git", "init", "--initial-branch=main", repository)
                    machine.run(
                        "git",
                        "-c",
                        "commit.gpgsign=false",
                        "commit",
                        "--allow-empty",
                        "-m",
                        "fixture",
                        cwd=repository,
                    )
                    self.assertEqual(
                        machine.run(
                            "git", "config", "user.name", cwd=repository
                        ).stdout.strip(),
                        account["name"],
                    )
                    self.assertEqual(
                        machine.run(
                            "git", "config", "user.email", cwd=repository
                        ).stdout.strip(),
                        account["email"],
                    )
                    for key in ("commit.gpgsign", "tag.gpgsign"):
                        self.assertEqual(
                            machine.run(
                                "git", "config", key, cwd=repository
                            ).stdout.strip(),
                            "true" if account.get("signing_key") else "false",
                        )
                    if account.get("signing_key"):
                        self.assertEqual(
                            machine.run(
                                "git", "config", "user.signingkey", cwd=repository
                            ).stdout.strip(),
                            account["signing_key"],
                        )
                    result = machine.run(
                        WT,
                        "switch",
                        "--create",
                        "feature",
                        "--no-cd",
                        "--no-hooks",
                        "--format=json",
                        cwd=repository,
                    )
                    data = json.loads(result.stdout)
                    worktree = data.get("path") or data.get("worktree_path")
                    self.assertIsNotNone(worktree, data)
                    self.assertEqual(
                        machine.run(
                            "git", "config", "user.email", cwd=worktree
                        ).stdout.strip(),
                        account["email"],
                    )
                    machine.run(
                        WT, "remove", "feature", "--no-hooks", "--yes", cwd=repository
                    )
                if kind == "work":
                    unrelated = machine.home / 'work "space" 1/repo'
                    unrelated.mkdir(parents=True)
                    machine.run("git", "init", "--initial-branch=main", unrelated)
                    self.assertEqual(
                        machine.run(
                            "git", "config", "user.email", cwd=unrelated
                        ).stdout.strip(),
                        "fixture@example.invalid",
                    )
                    repository = machine.home / "other work/repo"
                    repository.mkdir(parents=True)
                    machine.run("git", "init", "--initial-branch=main", repository)
                    machine.python("""from runtime import ROOT, read_toml, atomic, document
settings = read_toml(ROOT / 'config.local.toml')
settings['vars']['git_account_team_email'] = 'updated@example.invalid'
atomic(ROOT / 'config.local.toml', document(settings))
""")
                    machine.python(apply)
                    self.assertEqual(
                        machine.run(
                            "git", "config", "user.email", cwd=repository
                        ).stdout.strip(),
                        "updated@example.invalid",
                    )
                    account_file.write_text("Edited account\n")
                    result = machine.python("import config; config.check()", ok=False)
                    self.assertIn("Unmanaged or edited target", result.stderr)
                    self.assertEqual(account_file.read_text(), "Edited account\n")
                    machine.python(
                        f"import config; config.resolve('discard', {str(account_file)!r})"
                    )
                    self.assertEqual(
                        machine.run(
                            "git", "config", "user.email", cwd=repository
                        ).stdout.strip(),
                        "updated@example.invalid",
                    )

    def test_preferences_are_encrypted_and_pending_restore_survives_capture(self):
        machine = Machine(self.root, "encrypted")
        machine.minimal()
        machine.encryption()
        definition = {
            "name": "example",
            "application": "Example",
            "domain": "example.test",
            "scope": "machine",
            "keys": {},
            "files": {
                str(machine.home / "app.plist"): {
                    "type": "dict",
                    "fields": {"layout": "list", "volume": "int", "enabled": "bool"},
                }
            },
        }
        value = {"layout": ["display-a"], "volume": 42, "enabled": True}
        (machine.home / "app.plist").write_bytes(
            plistlib.dumps(value, fmt=plistlib.FMT_BINARY)
        )
        machine.python(
            "import preferences; preferences.policy(); preferences.capture(["
            + repr(definition)
            + "])"
        )
        machine.mise("dot", "save")
        repository = machine.home / "state/history/repo.git"
        paths = machine.run(
            "git",
            "--git-dir=" + str(repository),
            "ls-tree",
            "-r",
            "--name-only",
            "HEAD",
        ).stdout.splitlines()
        path = next(p for p in paths if p.endswith("app.plist"))
        blob = subprocess.check_output(
            ["git", "--git-dir=" + str(repository), "show", "HEAD:" + path],
            env=machine.env,
        )
        self.assertNotIn(b"display-a", blob)
        self.assertNotIn(b"<key>volume</key>", blob)
        self.assertFalse(
            any("config.local.toml" in p or "id_ed25519" in p for p in paths)
        )
        snapshot = (
            machine.config / "private/preferences/machines/encrypted/example/app.plist"
        )
        snapshot.write_bytes(plistlib.dumps({**value, "volume": 11}))
        machine.python(
            "import preferences; preferences.capture([" + repr(definition) + "])"
        )
        self.assertEqual(plistlib.loads(snapshot.read_bytes())["volume"], 11)
        restore = (
            "import preferences; preferences.is_running=lambda _:False; preferences.restore(["
            + repr(definition)
            + "])"
        )
        machine.python(restore)
        self.assertEqual(
            plistlib.loads((machine.home / "app.plist").read_bytes())["volume"], 11
        )
        snapshot.write_bytes(plistlib.dumps({**value, "volume": 12}))
        busy = machine.python(
            "import preferences; preferences.is_running=lambda _:True; preferences.restore(["
            + repr(definition)
            + "])",
            ok=False,
        )
        self.assertNotEqual(busy.returncode, 0)
        self.assertEqual(
            plistlib.loads((machine.home / "app.plist").read_bytes())["volume"], 11
        )
        (machine.home / "app.plist").write_bytes(
            plistlib.dumps({**value, "volume": 90})
        )
        self.assertNotEqual(machine.python(restore, ok=False).returncode, 0)
        self.assertEqual(plistlib.loads(snapshot.read_bytes())["volume"], 12)
        (machine.home / "app.plist").write_bytes(
            plistlib.dumps({**value, "volume": 11})
        )
        snapshot.write_bytes(plistlib.dumps(42))
        malformed = machine.python(restore, ok=False)
        self.assertNotEqual(malformed.returncode, 0)
        self.assertIn("incompatible preference structure", malformed.stderr)
        self.assertEqual(
            plistlib.loads((machine.home / "app.plist").read_bytes())["volume"], 11
        )
        machine.python("""import preferences, plistlib
entry = {'name':'reset','domain':'example.reset','application':'Example','keys':{'enabled':'bool'},'files':{},'scope':'machine'}
preferences.export_domain = lambda _: {'enabled':True}
preferences.capture([entry])
preferences.export_domain = lambda _: {}
preferences.capture([entry])
assert plistlib.loads((preferences.snapshot_root(entry)/'preferences.plist').read_bytes()) == {}
""")
        shutil.copytree(
            REPO / "conf.d/linearmouse", machine.config / "conf.d/linearmouse"
        )
        machine.write(
            "private/preferences/machines/encrypted/linearmouse/linearmouse.json",
            '{"schemes":[{"name":null}]}\n',
        )
        machine.python("""import finish, preferences, json
from runtime import ROOT, HOME
finish.seed_linearmouse()
assert not (HOME/'.config/linearmouse/linearmouse.json').exists()
entry = json.loads((ROOT/'conf.d/linearmouse/preferences.json').read_text())
entry['name'] = 'linearmouse'
preferences.export_domain = lambda _: {}
preferences.is_running = lambda _: False
preferences.restore([entry])
assert json.loads((HOME/'.config/linearmouse/linearmouse.json').read_text()) == {'schemes':[{'name':None}]}
""")
        shutil.copytree(REPO / "conf.d/audio", machine.config / "conf.d/audio")
        machine.write("miserc.local.toml", 'env=["loopback"]\n')
        machine.python("""import preferences, plistlib
from runtime import HOME, ROOT
applications = HOME/'Applications'
for name, version in [('Loopback', '2.4'), ('SoundSource', '6.1')]:
    bundle = applications/(name+'.app')/'Contents/Info.plist'
    bundle.parent.mkdir(parents=True)
    bundle.write_bytes(plistlib.dumps({'CFBundleShortVersionString':version}))
preferences.sys.platform = 'darwin'
entries = preferences.definitions(applications)
assert [entry['name'] for entry in entries] == ['loopback']
assert preferences.snapshot_root(entries[0]) == ROOT/'private/preferences/machines/encrypted/loopback'
""")
        machine.python("""import json, plistlib, preferences, unittest
from runtime import HOME, read_state
case = unittest.TestCase()
entry = {
    'name':'resume', 'domain':'example.resume', 'application':'Example', 'scope':'machine',
    'keys':{'enabled':'bool'},
    'files':{f'~/{name}.plist':{'type':'dict','fields':{'value':'int'}} for name in ('a','b')},
    'collections':{'profiles.plist':{'root':'~/profiles','include':['*.json']}},
}
domain = {'enabled':True, 'unowned':'retained'}
preferences.export_domain = lambda _: dict(domain)
preferences.is_running = lambda _: False
def import_domain(command, **kwargs):
    assert command[:3] == ['/usr/bin/defaults','import','example.resume']
    domain.clear()
    with open(command[3], 'rb') as stream:
        domain.update(plistlib.load(stream))
preferences.run = import_domain
profiles = HOME/'profiles'
profiles.mkdir()
for name in ('a','b'):
    (HOME/f'{name}.plist').write_bytes(plistlib.dumps({'value':1}))
    (profiles/f'{name}.json').write_text('{"value":1}')
(profiles/'local.json').write_text('{"local":true}')
preferences.capture([entry])
before = read_state('preferences')['resume']['snapshot']
root = preferences.snapshot_root(entry)
(root/'preferences.plist').write_bytes(plistlib.dumps({'enabled':False}))
for name in ('a','b'):
    (root/f'{name}.plist').write_bytes(plistlib.dumps({'value':2}))
(root/'profiles.plist').write_bytes(plistlib.dumps({'a.json':b'{"value":2}', 'b.json':b'{"value":2}'}))
incoming = preferences.snapshots(entry)
real_atomic = preferences.atomic
failure = HOME/'b.plist'
def interrupted_atomic(path, *args, **kwargs):
    if path == failure:
        raise OSError('simulated write failure')
    return real_atomic(path, *args, **kwargs)
preferences.atomic = interrupted_atomic
with case.assertRaisesRegex(OSError, 'simulated write failure'):
    preferences.restore([entry])
assert domain == {'enabled':False, 'unowned':'retained'}
assert plistlib.loads((HOME/'a.plist').read_bytes()) == {'value':2}
assert plistlib.loads((HOME/'b.plist').read_bytes()) == {'value':1}
assert read_state('preferences')['resume']['snapshot'] == before
preferences.atomic = real_atomic
(HOME/'a.plist').write_bytes(plistlib.dumps({'value':3}))
with case.assertRaisesRegex(RuntimeError, 'both versions preserved'):
    preferences.restore([entry])
assert plistlib.loads((HOME/'a.plist').read_bytes()) == {'value':3}
(HOME/'a.plist').write_bytes(incoming['a.plist'])
(root/'a.plist').write_bytes(plistlib.dumps({'value':3}))
with case.assertRaisesRegex(RuntimeError, 'both versions preserved'):
    preferences.restore([entry])
(root/'a.plist').write_bytes(incoming['a.plist'])
preferences.capture([entry])
assert preferences.snapshots(entry) == incoming
failure = profiles/'b.json'
preferences.atomic = interrupted_atomic
with case.assertRaisesRegex(OSError, 'simulated write failure'):
    preferences.restore([entry])
assert json.loads((profiles/'a.json').read_bytes()) == {'value':2}
assert json.loads((profiles/'b.json').read_bytes()) == {'value':1}
preferences.atomic = real_atomic
preferences.restore([entry])
for name in ('a','b'):
    assert plistlib.loads((HOME/f'{name}.plist').read_bytes()) == {'value':2}
    assert json.loads((profiles/f'{name}.json').read_bytes()) == {'value':2}
assert (profiles/'local.json').read_text() == '{"local":true}'
assert read_state('preferences')['resume']['snapshot'] == preferences.fingerprint(incoming)
""")

    def test_public_preferences_recover_with_only_a_password(self):
        old = Machine(self.root, "before")
        old.minimal()
        public = old.home / "public"
        (public / "bootstrap").mkdir(parents=True)
        for file in ("enroll.py", "backup.py"):
            shutil.copy2(REPO / "bootstrap" / file, public / "bootstrap" / file)
        shutil.copytree(old.config / "conf.d", public / "conf.d")
        shutil.copy2(old.config / "config.toml", public / "config.toml")
        shutil.copy2(REPO / "mise.toml", public / "mise.toml")
        shutil.copy2(REPO / "miserc.toml", public / "miserc.toml")
        (public / "conf.d/history").mkdir()
        shutil.copy2(
            REPO / "conf.d/history/mise.macos.toml",
            public / "conf.d/history/mise.macos.toml",
        )
        old.env["MISE_TRUSTED_CONFIG_PATHS"] += os.pathsep + str(public)
        definition = {
            "name": "example",
            "application": "Example",
            "domain": "example.test",
            "major_version": 1,
            "scope": "machine",
            "keys": {},
            "files": {"~/app.plist": {"type": "dict", "fields": {"layout": "list"}}},
        }
        shared = {
            **definition,
            "name": "shared-app",
            "scope": "shared",
            "files": {"~/shared.plist": {"type": "dict", "fields": {"layout": "list"}}},
        }
        obs = json.loads((REPO / "conf.d/media/preferences.obs.json").read_text())
        obs["name"] = "obs"
        for entry in (definition, shared, obs):
            folder = public / "conf.d" / entry["name"]
            folder.mkdir()
            (folder / "preferences.json").write_text(json.dumps(entry))
        for tool in ("age", "age-keygen"):
            executable = shutil.which(tool)
            if executable is None:
                self.fail(f"{tool} is required to test encrypted recovery")
            (old.home / ".local/bin" / tool).symlink_to(executable)
        age_install = (old.home / ".local/bin/age").resolve().parent
        age_target = old.home / "data/installs/age" / age_install.name
        age_target.parent.mkdir(parents=True)
        age_target.symlink_to(age_install)
        value = {"layout": ["private-display-routing"]}
        target = old.home / "old-dotfiles/preferences.data"
        target.parent.mkdir()
        target.write_bytes(plistlib.dumps(value))
        (old.home / "app.plist").symlink_to(target)
        (old.home / "shared.plist").write_bytes(plistlib.dumps(value))
        obs_files = {
            "global.ini": b"[General]\nName=Fixture\n",
            "user.ini": b"[Auth]\nRefreshToken=synthetic-obs-token\n",
            "basic/profiles/Work/basic.ini": b"[General]\nName=Work\n",
            "basic/profiles/Personal/basic.ini": b"[General]\nName=Personal\n",
            "basic/profiles/service.json": b'{"settings":{"key":"synthetic-obs-stream-key"}}',
            "basic/scenes/Scene.json": b'{"sources":[{"settings":{"password":"synthetic-source-password"}}]}',
            "plugin_config/obs-websocket/config.json": b'{"server_password":"synthetic-websocket-password"}',
            "plugin_config/advanced-scene-switcher/settings.json": b'{"macros":[]}',
            "plugin_manager/modules.json": b"[]",
        }
        obs_root = old.home / "Library/Application Support/obs-studio"
        for relative, content in obs_files.items():
            path = obs_root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
        excluded = obs_root / "plugin_config/rtmp-services/services.json"
        excluded.parent.mkdir(parents=True)
        excluded.write_text("Downloaded service cache, not a settings object")
        (obs_root / "basic/scenes/Scene.json.bak").write_text("Old backup")
        original_config = old.config / "config.toml"
        original_config.unlink()
        original_config.symlink_to(public / "config.toml")

        command = public / "bootstrap/backup.py"
        code, output = old.password_command(
            "-c",
            "import os; os.execv("
            + repr(MISE)
            + ", "
            + repr([MISE, "-C", str(public), "run", "backup", "init"])
            + ")",
        )
        self.assertEqual(code, 0, output)
        capture = (
            "import sys; sys.path.insert(0, "
            + repr(str(public / "bootstrap"))
            + "); import backup, preferences; preferences.definitions=lambda **kwargs: "
            + repr([definition, shared, obs])
            + "; backup.main()"
        )
        captured = old.run(sys.executable, "-c", capture, "capture")
        archive = public / "backups/preferences/before.plist.age"
        ciphertext = archive.read_bytes()
        self.assertNotIn(b"private-display-routing", ciphertext)
        self.assertNotIn(b"synthetic-obs-token", ciphertext)
        self.assertIn("basic/profiles/Work/basic.ini", captured.stdout)
        self.assertNotIn("synthetic-", captured.stdout + captured.stderr)
        obs_global = obs_root / "global.ini"
        obs_global.write_text("synthetic-obs-token is not valid INI")
        invalid_obs = old.run(sys.executable, "-c", capture, "capture", ok=False)
        self.assertNotEqual(invalid_obs.returncode, 0)
        self.assertNotIn("synthetic-obs-token", invalid_obs.stdout + invalid_obs.stderr)
        self.assertEqual(archive.read_bytes(), ciphertext)
        obs_global.write_bytes(obs_files["global.ini"])
        removed_profile = obs_root / "basic/profiles/Personal/basic.ini"
        removed_profile.unlink()
        old.run(sys.executable, "-c", capture, "capture")
        self.assertEqual(archive.read_bytes(), ciphertext)
        removed_profile.write_bytes(obs_files["basic/profiles/Personal/basic.ini"])
        self.assertTrue(original_config.is_symlink())
        self.assertTrue((old.home / "app.plist").is_symlink())
        self.assertEqual(plistlib.loads(target.read_bytes()), value)
        self.assertEqual((old.config / "age.txt").stat().st_mode & 0o777, 0o600)
        old.run(sys.executable, "-c", capture, "capture")
        self.assertEqual(archive.read_bytes(), ciphertext)
        daily = old.run(sys.executable, "-c", capture, "capture", "--daily")
        self.assertIn("already captured today", daily.stdout)
        stamp = Path(old.env["MISE_STATE_DIR"]) / "dotfiles/public-backup.json"
        successful = json.loads(stamp.read_text())
        yesterday = {**successful, "date": "2000-01-01"}
        stamp.write_text(json.dumps(yesterday))
        key = old.config / "age.txt"
        key.rename(old.config / "age.saved")
        failed = old.run(sys.executable, "-c", capture, "capture", "--daily", ok=False)
        self.assertNotEqual(failed.returncode, 0)
        self.assertEqual(json.loads(stamp.read_text()), yesterday)
        self.assertEqual(archive.read_bytes(), ciphertext)
        (old.config / "age.saved").rename(key)
        retried = old.run(sys.executable, "-c", capture, "capture", "--daily")
        self.assertIn("unchanged", retried.stdout)
        self.assertEqual(json.loads(stamp.read_text()), successful)
        (old.config / "age.txt").unlink()
        code, output = old.password_command(command, "verify")
        self.assertEqual(code, 0, output)
        self.assertFalse((old.config / "age.txt").exists())
        old.run("git", "init", "--quiet", public)
        old.run("git", "add", ".", cwd=public)
        old.run(
            "git", "commit", "--quiet", "-m", "Synthetic encrypted recovery", cwd=public
        )
        for path in old.run(
            "git", "ls-files", "backups", cwd=public
        ).stdout.splitlines():
            blob = old.run("git", "show", "HEAD:" + path, cwd=public).stdout
            self.assertNotIn("AGE-SECRET-KEY-", blob)
            self.assertNotIn("private-display-routing", blob)
            self.assertNotIn("synthetic-obs-token", blob)

        from lint import check_public_backup

        for path in (public / "backups").rglob("*"):
            if path.is_file():
                check_public_backup(path)
        invalid = old.home / "plaintext.plist.age"
        invalid.write_bytes(plistlib.dumps(value))
        with self.assertRaisesRegex(ValueError, "expected armored age ciphertext"):
            check_public_backup(invalid)

        fresh = Machine(self.root, "fresh")
        checkout = fresh.home / "public checkout"
        shutil.copytree(public, checkout)
        for tool in ("age", "age-keygen"):
            (fresh.home / ".local/bin" / tool).symlink_to(shutil.which(tool))
        (fresh.config / "config.local.toml").unlink()
        command = checkout / "bootstrap/enroll.py"
        args = (command, "--machine", "before", "--recover", "--seed-only")
        code, _ = fresh.password_command(
            *args, password="incorrect synthetic passphrase"
        )
        self.assertNotEqual(code, 0)
        self.assertFalse((fresh.config / "age.txt").exists())
        self.assertFalse((fresh.config / "private").exists())
        code, output = fresh.password_command(*args)
        self.assertEqual(code, 0, output)
        enrollment = tomllib.loads((fresh.config / "config.local.toml").read_text())
        self.assertEqual(enrollment["vars"]["dotfiles_repository"], str(checkout))
        if sys.platform == "darwin":
            launchctl = fresh.home / ".local/bin/launchctl"
            launchctl.write_text(
                '#!/bin/sh\nif [ "$1" = print ]; then exit 113; fi\nexit 0\n'
            )
            launchctl.chmod(0o755)
            fresh.mise("bootstrap", "macos", "launchd-agents", "apply", "--yes")
            agent = plistlib.loads(
                (
                    fresh.home / "Library/LaunchAgents/dev.mise.dotfiles-backup.plist"
                ).read_bytes()
            )
            self.assertTrue(agent["RunAtLoad"])
            self.assertEqual(agent["StartCalendarInterval"], [{"Minute": 0}])
            self.assertEqual(
                agent["ProgramArguments"],
                [
                    str(fresh.home / ".local/bin/mise"),
                    "-C",
                    str(checkout),
                    "run",
                    "backup",
                    "capture",
                    "--daily",
                ],
            )
        snapshot = (
            fresh.config / "private/preferences/machines/before/example/app.plist"
        )
        self.assertEqual(plistlib.loads(snapshot.read_bytes()), value)
        self.assertTrue(
            (
                fresh.config / "private/preferences/shared/shared-app/shared.plist"
            ).is_file()
        )
        self.assertFalse((fresh.home / "app.plist").exists())
        self.assertEqual((fresh.config / "age.txt").stat().st_mode & 0o777, 0o600)
        fresh.mise("dot", "save")
        history = fresh.home / "state/history/repo.git"
        tracked = fresh.run(
            "git", "--git-dir=" + str(history), "ls-tree", "-r", "--name-only", "HEAD"
        ).stdout.splitlines()
        obs_snapshot_path = next(p for p in tracked if p.endswith("obs-studio.plist"))
        encrypted_obs = subprocess.check_output(
            ["git", "--git-dir=" + str(history), "show", "HEAD:" + obs_snapshot_path],
            env=fresh.env,
        )
        self.assertNotIn(b"synthetic-obs-token", encrypted_obs)
        fresh.python(
            "import preferences; preferences.is_running=lambda _:False; preferences.restore("
            + repr([definition, shared, obs])
            + ")"
        )
        self.assertEqual(plistlib.loads((fresh.home / "app.plist").read_bytes()), value)
        restored_obs = fresh.home / "Library/Application Support/obs-studio"
        restored_files = {
            path.relative_to(restored_obs).as_posix(): path.read_bytes()
            for path in restored_obs.rglob("*")
            if path.is_file()
        }
        self.assertEqual(restored_files, obs_files)
        obs_snapshot = (
            fresh.config / "private/preferences/machines/before/obs/obs-studio.plist"
        )
        obs_snapshot.write_bytes(plistlib.dumps({"../outside.ini": b"[General]\n"}))
        invalid_obs = fresh.python(
            "import preferences; preferences.is_running=lambda _:False; preferences.restore(["
            + repr(obs)
            + "])",
            ok=False,
        )
        self.assertNotEqual(invalid_obs.returncode, 0)
        self.assertFalse((restored_obs.parent / "outside.ini").exists())
        self.assertEqual(
            (restored_obs / "global.ini").read_bytes(), obs_files["global.ini"]
        )
        obs_snapshot.write_bytes(
            plistlib.dumps(obs_files, fmt=plistlib.FMT_BINARY, sort_keys=True)
        )
        other = Machine(self.root, "other")
        other_checkout = other.home / "public"
        shutil.copytree(public, other_checkout)
        for tool in ("age", "age-keygen"):
            (other.home / ".local/bin" / tool).symlink_to(shutil.which(tool))
        (other.config / "config.local.toml").unlink()
        code, output = other.password_command(
            other_checkout / "bootstrap/enroll.py",
            "--machine",
            "other",
            "--recover",
            "--seed-only",
        )
        self.assertEqual(code, 0, output)
        self.assertTrue(
            (
                other.config / "private/preferences/shared/shared-app/shared.plist"
            ).is_file()
        )
        self.assertFalse((other.config / "private/preferences/machines").exists())
        snapshot.write_bytes(plistlib.dumps({"layout": ["pending"]}))
        refused = fresh.run(sys.executable, *args, ok=False)
        self.assertNotEqual(refused.returncode, 0)
        self.assertIn("both copies preserved", refused.stderr)
        self.assertEqual(plistlib.loads(snapshot.read_bytes()), {"layout": ["pending"]})
        self.assertEqual(plistlib.loads((fresh.home / "app.plist").read_bytes()), value)
        archive_copy = checkout / "backups/preferences/before.plist.age"
        archive_copy.write_bytes(ciphertext.replace(b"\n", b"\nx", 1))
        corrupted = fresh.run(sys.executable, *args, ok=False)
        self.assertNotEqual(corrupted.returncode, 0)
        self.assertEqual(plistlib.loads(snapshot.read_bytes()), {"layout": ["pending"]})

    def test_interrupted_setup_recovers_without_discarding_edits(self):
        invocation = "from runtime import lock; import sync\nwith lock(): sync.apply_setup(force=True)"

        def interrupt(machine):
            machine.minimal()
            machine.encryption()
            config = machine.config / "config.toml"
            config.write_text(
                config.read_text().replace(
                    '"~/shared.txt" = "~/.config/mise/shared.txt"',
                    '"~/shared.txt" = { source="shared.txt", mode="copy" }',
                )
                + "\n[tasks.bootstrap]\n"
                + 'run = \'if [ ! -f "$HOME/started" ]; then touch "$HOME/started"; sleep 60; fi\'\n'
            )
            log = machine.home / "interrupted.log"
            with log.open("w") as stream:
                process = subprocess.Popen(
                    [sys.executable, "-c", invocation],
                    cwd=machine.home,
                    env=machine.env,
                    stdin=subprocess.DEVNULL,
                    stdout=stream,
                    stderr=stream,
                    start_new_session=True,
                )
                try:
                    deadline = time.monotonic() + 20
                    while not (machine.home / "started").exists():
                        self.assertIsNone(process.poll(), log.read_text())
                        self.assertLess(time.monotonic(), deadline, log.read_text())
                        time.sleep(0.05)
                    process.send_signal(signal.SIGINT)
                    process.wait(timeout=10)
                finally:
                    if process.poll() is None:
                        process.terminate()
                        process.wait(timeout=10)
            self.assertNotEqual(process.returncode, 0)
            self.assertEqual(
                json.loads(machine.mise("dot", "status", "--json").stdout)["history"][
                    "pending_operations"
                ],
                1,
            )
            self.assertEqual((machine.home / "shared.txt").read_text(), "initial\n")
            state = machine.home / "state/dotfiles/apply.json"
            self.assertNotIn("applied", json.loads(state.read_text()))
            return state

        resumed = Machine(self.root, "resumed")
        state = interrupt(resumed)

        resumed.python(invocation)

        self.assertEqual((resumed.home / "shared.txt").read_text(), "initial\n")
        self.assertIn("applied", json.loads(state.read_text()))
        self.assertEqual(
            json.loads(resumed.mise("dot", "status", "--json").stdout)["history"][
                "pending_operations"
            ],
            0,
        )

        enrolled = Machine(self.root, "enrolled")
        state = interrupt(enrolled)
        checkout = enrolled.home / "public"
        (checkout / "bootstrap").mkdir(parents=True)
        shutil.copy2(REPO / "bootstrap/enroll.py", checkout / "bootstrap/enroll.py")
        shutil.copytree(
            REPO / "conf.d/setup",
            checkout / "conf.d/setup",
            ignore=shutil.ignore_patterns("__pycache__"),
        )
        shutil.copytree(REPO / "tasks", checkout / "tasks")
        enrolled.run("git", "init", "-q", checkout)
        enrolled.run("git", "-C", checkout, "add", "conf.d", "tasks")
        task = enrolled.write(
            "tasks/config",
            """#!/bin/bash
#MISE raw=true
set -euo pipefail
mise exec python@3 -- python3 - <<'PY'
from runtime import native_json
assert native_json('dot', 'status')['history']['pending_operations'] == 0
PY
exec mise exec python@3 -- python3 "$HOME/.config/mise/conf.d/setup/config.py" "$@"
""",
        )
        task.chmod(0o755)
        active = enrolled.config / "conf.d/setup/sync.py"
        before = active.read_bytes()

        enrolled.python(
            "import runpy, sys; sys.platform = 'linux'; sys.argv = "
            + repr([str(checkout / "bootstrap/enroll.py"), "--machine", "enrolled"])
            + "; runpy.run_path(sys.argv[0], run_name='__main__')"
        )

        self.assertIn("applied", json.loads(state.read_text()))
        self.assertEqual(active.read_bytes(), before)

        edited = Machine(self.root, "edited")
        state = interrupt(edited)
        before = state.read_bytes()
        (edited.home / "shared.txt").write_text("my edit after cancelling\n")

        refused = edited.python(invocation, ok=False)

        self.assertNotEqual(refused.returncode, 0)
        self.assertIn("changed after the operation", refused.stderr)
        self.assertEqual(
            (edited.home / "shared.txt").read_text(), "my edit after cancelling\n"
        )
        self.assertEqual(state.read_bytes(), before)
        self.assertEqual(
            json.loads(edited.mise("dot", "status", "--json").stdout)["history"][
                "pending_operations"
            ],
            1,
        )

    def test_native_sync_applies_declarations_and_preserves_local_choices(self):
        a, b = Machine(self.root, "a"), Machine(self.root, "b")
        a.minimal()
        a.python("""from runtime import git_origin
for origin in ('https://github.com/example/setup.git', 'git@github.com:example/setup.git', 'ssh://git@example.com/setup.git', '/tmp/setup.git'):
    assert git_origin(origin) == origin
for origin in ('http://github.com/example/setup.git', 'https://user:secret@example.com/setup.git', 'https://example.com/setup.git?token=secret', 'https://example.com/setup.git#secret', 'https://example.com'):
    try:
        git_origin(origin)
    except ValueError:
        pass
    else:
        raise AssertionError('Unsafe origin accepted')
""")
        key = a.encryption()
        a.write("codex.toml", 'personality="pragmatic"\n')
        with (a.config / "config.toml").open("a") as stream:
            stream.write(
                '"~/.codex/config.toml/shared" = { source="codex.toml", merge=true }\n'
            )
        a.mise("dot", "apply", "--yes")
        a.python("import config; config.remember()")
        a.write(
            "private/preferences/shared/example/synthetic.plist",
            "synthetic-private-data",
        )
        origin = self.root / "origin.git"
        a.run("git", "init", "--bare", "--initial-branch=main", origin)
        a.mise("dot", "save")
        a.mise("dot", "origin", "set", origin, "--sync", "manual", "--yes")
        missing = b.mise(
            "bootstrap", "--adopt", origin, "--only", "dotfiles", "--yes", ok=False
        )
        self.assertNotEqual(missing.returncode, 0)
        self.assertIn("unlock", missing.stderr)
        b.encryption(key)
        b.write("miserc.local.toml", 'env=["loopback"]\n')
        b.mise("bootstrap", "--adopt", origin, "--only", "dotfiles", "--yes")
        a.write("new.txt", "added declaration\n")
        with (a.config / "config.toml").open("a") as stream:
            stream.write('"~/new.txt" = "~/.config/mise/new.txt"\n')
        a.mise("dot", "save")
        a.mise("dot", "sync", "--yes")
        # No service manager is called in this isolated process. The native bootstrap,
        # history transfer, eligibility, file deployment and retry journal remain real.
        b.python("import sync; sync.schedule=lambda:None; sync.synchronize()")
        self.assertEqual((b.home / "new.txt").read_text(), "added declaration\n")
        self.assertEqual(
            (b.config / "miserc.local.toml").read_text(), 'env=["loopback"]\n'
        )
        self.assertIn('id="b"', (b.config / "config.local.toml").read_text())
        before = json.loads((b.home / "state/dotfiles/apply.json").read_text())
        b.python(
            "import sync; sync.schedule=lambda:None; sync.synchronize(automatic=True)"
        )
        self.assertEqual(
            json.loads((b.home / "state/dotfiles/apply.json").read_text()), before
        )
        a.mise("dot", "sync", "--yes")
        a.mise("dot", "pull", "--yes")
        local = b.config / "config.local.toml"
        local.write_text(local.read_text().replace('sync="manual"', 'sync="automatic"'))
        (b.home / ".codex/config.toml").write_text(
            'personality="friendly"\n[projects.local]\ntrust_level="trusted"\n'
        )
        a.write("task.sh", 'printf applied > "$HOME/applied-task"\n')
        with (a.config / "config.toml").open("a") as stream:
            stream.write(
                "\n[tasks.bootstrap]\nrun = 'sh \"$HOME/.config/mise/task.sh\"'\n"
            )
        a.write(
            "conf.d/optional/mise.obs.toml",
            '[dotfiles]\n"~/disabled-app" = { content="not selected" }\n',
        )
        a.mise("dot", "save")
        a.mise("dot", "sync", "--yes")
        b.python(
            "import sync; sync.schedule=lambda:None; sync.synchronize(automatic=True)"
        )
        self.assertEqual((b.home / "applied-task").read_text(), "applied")
        self.assertFalse((b.home / "disabled-app").exists())
        before = json.loads((b.home / "state/dotfiles/apply.json").read_text())
        a.mise("dot", "sync", "--yes")
        a.mise("dot", "pull", "--yes")
        received = tomllib.loads((a.config / "codex.toml").read_text())
        self.assertEqual(received["personality"], "friendly")
        self.assertNotIn("projects", received)
        a.write("shared.txt", "edited by a\n")
        b.write("shared.txt", "edited by b\n")
        a.mise("dot", "save")
        a.mise("dot", "sync", "--yes")
        conflict = b.python(
            "import sync; sync.schedule=lambda:None; sync.synchronize()", ok=False
        )
        self.assertNotEqual(conflict.returncode, 0)
        self.assertEqual((b.home / "shared.txt").read_text(), "edited by b\n")
        self.assertEqual(
            json.loads((b.home / "state/dotfiles/apply.json").read_text()), before
        )

        changing = Machine(self.root, "changing")
        changing.minimal()
        changing.encryption()
        changing.write("settings.toml", 'color="blue"\n')
        base = (
            changing.config / "config.toml"
        ).read_text() + '"~/app.toml/shared" = { source="settings.toml", merge=true }\n'
        changing.write(
            "config.toml",
            base + "\n[tasks.bootstrap]\nrun = 'sh \"$HOME/.config/mise/first.sh\"'\n",
        )
        changing.write(
            "next.txt",
            base + "\n[tasks.bootstrap]\nrun = 'touch \"$HOME/second-ran\"'\n",
        )
        changing.write(
            "first.sh",
            'cp "$HOME/.config/mise/next.txt" "$HOME/.config/mise/config.toml"\n',
        )
        changing.write(
            "conf.d/requirements/mise.toml",
            "[doctor.checks.ready]\nrun = 'test -f \"$HOME/ready\"'\n",
        )
        rejected = changing.python(
            "import sync; sync.schedule=lambda:False; sync.apply_setup()", ok=False
        )
        self.assertNotEqual(rejected.returncode, 0)
        self.assertFalse((changing.home / "app.toml").exists())
        pending = json.loads((changing.home / "state/dotfiles/apply.json").read_text())
        self.assertIn("failed", pending)
        self.assertNotIn("applied", pending)
        (changing.home / "ready").touch()
        changing.python("import sync; sync.schedule=lambda:False; sync.apply_setup()")
        self.assertFalse((changing.home / "second-ran").exists())
        changing.python("import sync; sync.schedule=lambda:False; sync.apply_setup()")
        self.assertTrue((changing.home / "second-ran").is_file())
        changing.write("settings.toml", 'color="green"\n')
        changing.python("import sync; sync.schedule=lambda:False; sync.apply_setup()")
        self.assertEqual(
            tomllib.loads((changing.home / "app.toml").read_text())["color"], "green"
        )
        changing.python("""import subprocess, sys, time
from runtime import HOME, lock, run
child = "import time; from pathlib import Path; time.sleep(1); Path('late-write').write_text('late')"
parent = "import subprocess,sys,time; subprocess.Popen([sys.executable,'-c'," + repr(child) + "]); time.sleep(60)"
with lock():
    try:
        run([sys.executable, '-c', parent], timeout=0.15)
        raise AssertionError('timeout expected')
    except subprocess.TimeoutExpired:
        pass
with lock():
    time.sleep(1.2)
    assert not (HOME/'late-write').exists()
""")
        with (changing.config / "config.toml").open("a") as stream:
            stream.write(
                '\n[bootstrap.macos.launchd.agents.invalid]\nprogram="/usr/bin/true"\nprocess_type="Invalid"\n'
            )
        rejected = changing.python("import sync; sync.assert_resources()", ok=False)
        self.assertNotEqual(rejected.returncode, 0)
        self.assertIn("process_type", rejected.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
