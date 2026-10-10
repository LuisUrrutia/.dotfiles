#!/usr/bin/env python3
"""Real parsers, four integration boundaries, and an isolated shell smoke path."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import tomllib

ROOT = Path(__file__).resolve().parents[1]


def run(*command, **kwargs):
    print('+ ' + ' '.join(map(str, command)), flush=True)
    return subprocess.run([str(a) for a in command], cwd=ROOT, stdin=subprocess.DEVNULL,
                            check=True, **kwargs)


def main():
    paths = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
    files = [ROOT / p for p in paths if p and (ROOT / p).is_file()]
    bash = []
    fish = []
    yaml = []
    toml = []
    for path in files:
        if path.suffix == '.py':
            compile(path.read_text(), str(path), 'exec')
        elif path.suffix == '.toml':
            tomllib.loads(path.read_text())
            toml.append(path)
        elif path.suffix == '.json':
            json.loads(path.read_text())
        elif path.suffix == '.jsonc':
            run('pyjson5', path, stdout=subprocess.DEVNULL)
        elif path.suffix in ('.yaml', '.yml'):
            yaml.append(path)
        elif path.suffix in ('.js', '.cjs', '.mjs'):
            run('esbuild', path, '--format=esm', '--log-level=error', '--outfile=/dev/null')
        elif path.suffix == '.fish':
            fish.append(path)
        if path.read_bytes().startswith(b'#!/usr/bin/env bash'):
            bash.append(path)
    for path in bash:
        run('/bin/bash', '-n', path)
    run('taplo', 'check', *toml)
    run('editorconfig-checker', '-no-color')
    run('shellcheck', *bash)
    for path in fish:
        run('fish', '--no-execute', path)
    if yaml:
        run('/usr/bin/ruby', '-e', 'require "yaml"; ARGV.each { |p| Psych.parse_stream(File.read(p)) }', *yaml)
    run('check-jsonschema', '--schemafile', 'tests/schemas/claude-settings.schema.json', 'conf.d/claude/settings.json')
    run('luacheck', 'conf.d/hammerspoon')
    run('stylua', '--check', 'conf.d/nvim')
    run('git', 'config', '--file', 'conf.d/git/defaults.gitconfig', '--list', stdout=subprocess.DEVNULL)
    run('actionlint')
    run('/bin/bash', 'conf.d/bin/gha-pins', 'audit', '.github/workflows')
    run('/bin/bash', 'install.sh', '--dry-run')
    with tempfile.TemporaryDirectory(prefix='dotfiles-public-check-') as temporary:
        public = Path(temporary) / 'source'
        for path in files:
            target = public / path.relative_to(ROOT)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, target)
        run('gitleaks', 'detect', '--no-git', '--source', public, '--redact', '--no-banner')
    run(sys.executable, '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_*.py', '-v')
    run('git', 'diff', '--check')
    run('git', 'diff', '--cached', '--check')
    print('Verification passed; package installation and GUI acceptance require a fresh Mac.')


if __name__ == '__main__':
    main()
