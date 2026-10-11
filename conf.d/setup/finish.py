"""Complete the few setup steps that do not have native declarations."""

import json
import plistlib
import sys
from pathlib import Path

import config
import preferences
from runtime import HOME, ROOT, atomic, local, regular_parents, run, selected


def link(source, target):
    regular_parents(target)
    if target.is_symlink() and target.resolve() == source.resolve():
        return
    if target.exists() or target.is_symlink():
        raise RuntimeError(f"Refusing unowned destination: {target}")
    target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    target.symlink_to(source)


def instructions():
    link(HOME / ".agents/AGENTS.md", HOME / ".codex/AGENTS.md")
    source = ROOT / "machines" / (local()["id"] + ".agents.md")
    target = HOME / ".agents/AGENTS_LOCAL.md"
    if source.is_file():
        link(source, target)
    elif target.is_symlink() and target.resolve().is_relative_to(ROOT / "machines"):
        target.unlink()


def seed_linearmouse():
    mouse = HOME / ".config/linearmouse/linearmouse.json"
    definition = json.loads((ROOT / "conf.d/linearmouse/preferences.json").read_text())
    definition["name"] = "linearmouse"
    if (
        not mouse.exists()
        and not mouse.is_symlink()
        and not preferences.snapshots(definition)
    ):
        atomic(mouse, (ROOT / "conf.d/linearmouse/initial.json").read_bytes())


def macos():
    hostname = local().get("hostname")
    if hostname:
        for key in ("ComputerName", "HostName", "LocalHostName"):
            result = run(["/usr/sbin/scutil", "--get", key], capture=True, check=False)
            if result.stdout.decode().strip() != hostname:
                run(["sudo", "-n", "/usr/sbin/scutil", "--set", key, hostname])
    if local().get("xcode"):
        developer = "/Applications/Xcode.app/Contents/Developer"
        if (
            run(["xcode-select", "-p"], capture=True).stdout.decode().strip()
            != developer
        ):
            run(["sudo", "-n", "xcode-select", "--switch", developer])
        if run(
            ["xcodebuild", "-checkFirstLaunchStatus"], capture=True, check=False
        ).returncode:
            run(["sudo", "-n", "xcodebuild", "-license", "accept"])
            run(["sudo", "-n", "xcodebuild", "-runFirstLaunch"])
    for name in ("auth.json", "skills/comment-style", "skills/communicate-clearly"):
        source = HOME / (
            ".codex/auth.json" if name == "auth.json" else ".agents/" + name
        )
        link(source, HOME / ".local/share/voiceink-codex" / name)
    seed_linearmouse()
    if "displaylink" in selected():
        run(
            [
                "osascript",
                "-e",
                'tell application "System Events" to if exists login item "DisplayLink Manager" then delete login item "DisplayLink Manager"',
            ]
        )
    titles = {
        "Delete Conversation…",
        "Delete Conversations…",
        "Eliminar conversación…",
        "Eliminar conversaciones…",
    }
    table = Path(
        "/System/iOSSupport/System/Library/PrivateFrameworks/ChatKit.framework/Versions/A/Resources/ChatKit.loctable"
    )
    if table.exists():
        for values in plistlib.loads(table.read_bytes()).values():
            if isinstance(values, dict):
                titles.update(
                    value
                    for key, value in values.items()
                    if key
                    in ("DELETE_CONVERSATION_ELLIPSIS", "DELETE_CONVERSATIONS_ELLIPSIS")
                    and isinstance(value, str)
                )
    pairs = [value for title in sorted(titles) for value in (title, "@\b")]
    run(
        [
            "defaults",
            "write",
            "com.apple.MobileSMS",
            "NSUserKeyEquivalents",
            "-dict-add",
            *pairs,
        ]
    )


def main():
    if not local().get("id"):
        raise RuntimeError("Enroll this machine before bootstrapping")
    instructions()
    if sys.platform == "darwin":
        macos()
    config.remember()


if __name__ == "__main__":
    main()
