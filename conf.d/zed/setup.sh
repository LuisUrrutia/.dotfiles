#!/usr/bin/env bash
set -euo pipefail

for extension in json yaml toml sh; do
  duti -s dev.zed.Zed "$extension" all
done
