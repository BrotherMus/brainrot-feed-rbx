#!/usr/bin/env bash
# Writes src/ from the place saved in Roblox Studio (game.rbxl), then runs main.ts into out/
# and prints which scripts the dossier lists. The place is the source of truth: scripts are
# written in Studio, and this keeps src/ byte for byte equal to them.
#
#   bash tools/sync-src.sh
set -euo pipefail
cd "$(dirname "$0")/.."

ROJO="${ROJO:-$(find "$HOME/.rokit/tool-storage" -iname 'rojo*.exe' 2>/dev/null | head -1)}"
ROJO="${ROJO:-rojo}"

# syncback rewrites the project file with engine defaults; keep ours.
cp default.project.json "${TMPDIR:-/tmp}/doomscroll-project.json"
rm -rf src
mkdir -p src/shared src/server src/client
# a file-level $path must exist before syncback will fill it
touch src/shared/BrainrotCatalog.luau src/shared/GameConfig.luau
touch src/client/HudClient.client.luau src/client/MenuClient.client.luau
"$ROJO" syncback default.project.json --input game.rbxl -y 2>&1 | grep -v 'Unknown value type' | tail -1
find src -name '*.meta.json' -delete
cp "${TMPDIR:-/tmp}/doomscroll-project.json" default.project.json

rm -rf out
mkdir -p out
MAKEFUN_OUTPUT_DIR=out node main.ts
node -e "
const text = JSON.parse(require('fs').readFileSync('out/dossier.json', 'utf8')).text;
console.log('dossier text: ' + Buffer.byteLength(text) + ' bytes');
console.log(text.split('\n').slice(2, 6).join('\n'));
for (const m of text.matchAll(/^### (.*)\n\n(.*)$/gm)) console.log('  ' + m[1] + ' | ' + m[2].replace(/, matched.*/, ''));
console.log(text.trimEnd().split('\n').slice(-2).join('\n'));
"
