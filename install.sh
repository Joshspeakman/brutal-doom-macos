#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
# Data stays outside the app and the repository; artwork is extracted locally.
collection_dir="${BRUTAL_DOOM_DATA_DIR:-$HOME/Games/Brutal Doom}"
app_dir="${BRUTAL_DOOM_APP_DIR:-$HOME/Applications}"
if [[ ! -x "$collection_dir/Engine/GZDoom.app/Contents/MacOS/gzdoom" ]]; then
  echo "Install the GZDoom Mac app at: $collection_dir/Engine/GZDoom.app" >&2
  echo 'See README.md for the required game and mod files.' >&2
  exit 1
fi
./build.sh
python3 tools/install.py "$collection_dir" "$app_dir"
