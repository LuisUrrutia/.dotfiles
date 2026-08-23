#!/usr/bin/env python3

import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent


def strip_json_comments(source: str) -> str:
    result: list[str] = []
    index = 0
    in_string = False
    escaped = False

    while index < len(source):
        character = source[index]
        next_character = source[index + 1] if index + 1 < len(source) else ""

        if in_string:
            result.append(character)
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                in_string = False
            index += 1
            continue

        if character == '"':
            in_string = True
            result.append(character)
            index += 1
        elif character == "/" and next_character == "/":
            result.extend((" ", " "))
            index += 2
            while index < len(source) and source[index] not in "\r\n":
                result.append(" ")
                index += 1
        elif character == "/" and next_character == "*":
            result.extend((" ", " "))
            index += 2
            while index < len(source):
                if source[index : index + 2] == "*/":
                    result.extend((" ", " "))
                    index += 2
                    break
                result.append("\n" if source[index] == "\n" else " ")
                index += 1
        else:
            result.append(character)
            index += 1

    return "".join(result)


def strip_trailing_commas(source: str) -> str:
    result: list[str] = []
    index = 0
    in_string = False
    escaped = False

    while index < len(source):
        character = source[index]
        if in_string:
            result.append(character)
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                in_string = False
            index += 1
            continue

        if character == '"':
            in_string = True
        elif character == ",":
            next_index = index + 1
            while next_index < len(source) and source[next_index].isspace():
                next_index += 1
            if next_index < len(source) and source[next_index] in "}]":
                result.append(" ")
                index += 1
                continue

        result.append(character)
        index += 1

    return "".join(result)


def load_jsonc(path: Path) -> Any:
    source = path.read_text(encoding="utf-8")
    return json.loads(strip_trailing_commas(strip_json_comments(source)))


def validate_policies(parsed: dict[Path, Any]) -> list[str]:
    errors: list[str] = []
    opencode = parsed[ROOT / "tools/opencode/config/.config/opencode/opencode.json"]
    tlrc_source = (ROOT / "tools/tlrc/config/.config/tlrc/config.toml").read_text(encoding="utf-8")
    rulebook_path = ROOT / "tools/cc-safety-net/config/.cc-safety-net/rules/user-rules/rulebook.json"
    rulebook = parsed[rulebook_path]

    if opencode.get("autoupdate") is not False:
        errors.append("OpenCode autoupdate must stay disabled; dotfiles update owns upgrades")
    if "auto_update = false" not in tlrc_source:
        errors.append("tlrc auto_update must stay disabled; dotfiles update owns cache refreshes")

    rule_names = [rule.get("name") for rule in rulebook.get("rules", [])]
    if len(rule_names) != len(set(rule_names)):
        errors.append(f"{rulebook_path.relative_to(ROOT)}: rule names must be unique")
    known_rules = set(rule_names)
    for test in rulebook.get("tests", []):
        referenced_rule = test.get("rule")
        if referenced_rule is not None and referenced_rule not in known_rules:
            errors.append(
                f"{rulebook_path.relative_to(ROOT)}: test references unknown rule {referenced_rule!r}"
            )

    return errors


def main() -> int:
    errors: list[str] = []
    parsed: dict[Path, Any] = {}
    config_files = sorted(path for path in (ROOT / "tools").glob("*/config/**/*") if path.is_file())

    for path in config_files:
        try:
            if path.suffix in {".json", ".jsonc"}:
                parsed[path] = load_jsonc(path)
        except (OSError, UnicodeError, json.JSONDecodeError) as error:
            errors.append(f"{path.relative_to(ROOT)}: {error}")

    if not errors:
        errors.extend(validate_policies(parsed))

    for error in errors:
        print(f"config validation: {error}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
