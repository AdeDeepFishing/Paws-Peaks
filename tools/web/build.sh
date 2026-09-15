#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
VERSION=4.7.2
TOOLS="${TMPDIR:-/tmp}/tale-godot-$VERSION"
mkdir -p "$TOOLS" web-build
if [[ ! -x "$TOOLS/godot" ]]; then
  curl -fL --retry 3 "https://github.com/godotengine/godot-builds/releases/download/$VERSION-stable/Godot_v$VERSION-stable_linux.x86_64.zip" -o "$TOOLS/editor.zip"
  unzip -qo "$TOOLS/editor.zip" -d "$TOOLS"
  mv "$TOOLS/Godot_v$VERSION-stable_linux.x86_64" "$TOOLS/godot"
  chmod +x "$TOOLS/godot"
fi
python3 tools/web/templates.py "$TOOLS/templates"
TEMPLATE_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$VERSION.stable"
mkdir -p "$TEMPLATE_HOME"
cp "$TOOLS/templates/"*.zip "$TEMPLATE_HOME/"
# Only public connection settings enter the exported game.
TALE_WEB_TEMPLATES="$TOOLS/templates" python3 tools/web/configure.py
"$TOOLS/godot" --headless --path 3d_game --editor --import > "$TOOLS/import.log" 2>&1
"$TOOLS/godot" --headless --path 3d_game --export-release Web ../web-build/index.html

python3 tools/web/compress.py
