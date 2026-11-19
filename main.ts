// Doomscroll Dash, a roblox-brainrot-01 entry (Node 22, standard library only). The game is built in
// Roblox Studio and saved as game.rbxl; src/ holds every script of that place (tools/sync-src.sh writes it
// with `rojo syncback`), so this program never builds the place: it hands it in. It copies game.rbxl, src/,
// screenshots/ and PLAY.json from beside this file to /output and writes /output/dossier.json, the summary
// the judge reads, with the vendored make.fun library. screenshots/1-cover.jpg is the cover and the
// thumbnail uploaded for the game on Roblox.
//
// Every name under /output starts with a letter, a digit or _ and holds only letters, digits, . _ and -: the
// grader fails an entry whose output holds any other, so a file such as .gitkeep or .DS_Store copied in fails it.
// So src/ and screenshots/ are copied without any name that starts with a dot, at any depth.
//
// Outside the grader's container, MAKEFUN_OUTPUT_DIR stands in for /output:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, cpSync, existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const here = fileURLToPath(new URL('.', import.meta.url));
const out = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

/** cpSync's filter: leave out every file and directory whose name starts with a dot (.gitkeep, .DS_Store, .git). */
const notDotted = (path: string): boolean => !basename(path).startsWith('.');

// Doomscroll Dash hands in a place saved from Roblox Studio, so nothing here rebuilds it. Before copying,
// refuse the two mistakes that are easy to make by hand and that the gate would refuse later anyway:
// a PLAY.json still naming no published place, and a screenshots/ folder that is not 3 or 4 pictures.
const play = JSON.parse(readFileSync(join(here, 'PLAY.json'), 'utf8')) as { place_id?: unknown; universe_id?: unknown };
for (const key of ['place_id', 'universe_id'] as const) {
  const id = play[key];
  if (typeof id !== 'number' || !Number.isSafeInteger(id) || id <= 0) throw new Error(`PLAY.json: ${key} must be the published experience's id, not ${String(id)}`);
}
const pictures = readdirSync(join(here, 'screenshots')).filter((name) => /\.(png|jpe?g)$/i.test(name) && notDotted(name));
if (pictures.length < 3 || pictures.length > 4) throw new Error(`screenshots/ holds ${pictures.length} pictures: the entry needs 3 or 4`);

copyFileSync(join(here, 'game.rbxl'), join(out, 'game.rbxl'));
copyFileSync(join(here, 'PLAY.json'), join(out, 'PLAY.json'));
cpSync(join(here, 'src'), join(out, 'src'), { recursive: true, filter: notDotted });
mkdirSync(join(out, 'screenshots'), { recursive: true });
if (existsSync(join(here, 'screenshots'))) cpSync(join(here, 'screenshots'), join(out, 'screenshots'), { recursive: true, filter: notDotted });

// The scorer's own caps (reference/gate.json): only text_max_bytes shapes the bytes; the others refuse an entry the
// scorer would refuse (more than 4 screenshots or one over 256 KiB; a place of more than 500000 instances, whose
// scripts' sources come to over 8 MiB or whose scripts' paths come to over 1048576 characters, in all).
writeFileSync(
  join(out, 'dossier.json'),
  buildDossier(out, { text_max_bytes: 65536, screenshots: { max: 4, max_bytes: 262144 }, max_instances: 500000, scripts_max_source_bytes: 8388608, scripts_max_path_chars: 1048576 }),
);
