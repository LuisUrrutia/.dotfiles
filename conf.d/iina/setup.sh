#!/usr/bin/env bash
set -euo pipefail

for extension in mp4 m4v mov qt mkv avi webm mpeg mpg wmv flv ogv ogm m2ts vob 3gp 3g2 rmvb mxf; do
  duti -s com.colliderli.iina "$extension" all
done
