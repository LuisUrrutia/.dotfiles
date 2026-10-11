"""Integration boundaries owned by this repository; native mise and Git are real."""

import json
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import tomllib
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
MISE = str(Path(os.environ.get("MISE_BIN") or shutil.which("mise")).resolve())
FISH = shutil.which("fish")
WT = shutil.which("wt")


class Machine:
    def __init__(self, root, name):
        self.home = root.resolve() / name
        self.config = self.home / ".config/mise"
        self.config.mkdir(parents=True)
        (self.home / ".local/bin").mkdir(parents=True)
        (self.home / ".local/bin/mise").symlink_to(MISE)
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

    def test_seed_and_native_deployment_preserve_user_files(self):
        machine = Machine(self.root, "safe")
        machine.payload()
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
        machine.env["PAGER"] = "fixture-pager"
        smoke = machine.run(
            FISH, "-c", 'test "$PAGER" = fixture-pager; and not set -q FZF_DEFAULT_OPTS'
        )
        self.assertEqual(smoke.stdout, "")

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
        machine.write(
            "conf.d/fisher-test/mise.toml",
            "[dotfiles]\n"
            + "\n".join(
                f"{json.dumps(target)} = {json.dumps(source)}"
                for target, source in linux["dotfiles"].items()
            ),
        )
        machine.mise("dot", "apply", "--yes")
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

    def test_git_identities_keep_other_keys_and_match_worktrees(self):
        for kind in ("personal", "work", "agent", "unknown"):
            with self.subTest(kind=kind):
                machine = Machine(self.root, kind)
                module = machine.config / "conf.d/git"
                shutil.copytree(REPO / "conf.d/git", module)
                (module / "mise.macos.toml").unlink()
                machine.env["MISE_HISTORY_ENABLED"] = "false"
                record = {
                    "git": {
                        "default": {
                            "name": "Personal User",
                            "email": "personal@example.invalid",
                        }
                    }
                }
                if kind == "unknown":
                    record["git"]["default"] = {}
                if kind == "agent":
                    record["git"]["default"]["signing_key"] = "~/.ssh/id_ed25519.pub"
                if kind in ("work", "agent"):
                    record["git"]["accounts"] = {
                        "team": {
                            "name": 'Work "Team" Urrutía',
                            "email": "work@example.invalid",
                            "directories": [
                                str(machine.home / 'work "space"'),
                                "~/other work",
                            ],
                        }
                    }
                if kind == "work":
                    record["git"]["default"] = {}
                    record["git"]["accounts"]["second-team"] = {
                        "name": "Other User",
                        "email": "other@example.invalid",
                        "directories": [str(machine.home / "second team")],
                        "signing_key": "~/.ssh/work key.pub",
                    }
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
                for name, account in record["git"].get("accounts", {}).items():
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
            '{"schemes":[]}\n',
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
assert json.loads((HOME/'.config/linearmouse/linearmouse.json').read_text()) == {'schemes':[]}
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
