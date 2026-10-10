#!/usr/bin/env bash
set -euo pipefail

rustup toolchain install stable --profile default
rustup default stable
rustup component add rustfmt clippy
