/**
 * Rebuilds only the game's screens (assets/screens.json), the menu colours (assets/ui.json) and the Storytender's swing setting in the
 * scenes, in the Tilewright project that is already built (./tilewright), without Godot: for when a screen changes and the whole porter
 * (run_porter.sh, which needs Godot and xvfb) is not at hand. The porter writes the same files, so a full run gives the same result.
 *
 *   esbuild tools/port/screens_only.ts --bundle --platform=node --format=esm --outfile=/tmp/screens_only.mjs && node /tmp/screens_only.mjs <repo>
 */
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { buildScreens, equipmentOf, mapNamesFrom, uiTheme, wornBy, type ItemRow, type MapConstants } from './screens';

const repo = process.argv[2] ?? '.';
const out = join(repo, 'tilewright');
const read = (p: string): string => readFileSync(p, 'utf8');

// the constants of the Godot game's prologue map: each is a GDScript literal that is also valid JSON, but for the array of region rows
function gdConst(source: string, name: string): string {
  const m = new RegExp(`^const ${name}\\b[^=]*:?=\\s*`, 'm').exec(source);
  if (!m) throw new Error(`${name} not found in data/prologue_map.gd`);
  let i = m.index + m[0].length;
  const open = source[i]!;
  const close = open === '{' ? '}' : ']';
  const start = i;
  let depth = 0;
  let inString = false;
  for (; i < source.length; i++) {
    const ch = source[i]!;
    if (inString) {
      if (ch === '\\') i++;
      else if (ch === '"') inString = false;
    } else if (ch === '"') inString = true;
    else if (ch === open) depth++;
    else if (ch === close && --depth === 0) break;
  }
  return source.slice(start, i + 1).replace(/,\s*([\]}])/g, '$1');
}

const gd = read(join(repo, 'data', 'prologue_map.gd'));
const constants: MapConstants = {
  REGION_ROWS: JSON.parse(gdConst(gd, 'REGION_ROWS')) as string[],
  REGIONS: JSON.parse(gdConst(gd, 'REGIONS')) as Record<string, string>,
  WAYPOINTS: JSON.parse(gdConst(gd, 'WAYPOINTS')) as MapConstants['WAYPOINTS'],
  PORTALS: JSON.parse(gdConst(gd, 'PORTALS')) as MapConstants['PORTALS'],
};

// what the built project already says: its schema, which tile is the map's paper, the item icons and the items that can be used
const old = JSON.parse(read(join(out, 'assets', 'screens.json'))) as { schemaVersion: number; screens: { id: string; root: unknown }[] };
const palette = /"palette":\s*"(\d+):#00000000"/.exec(JSON.stringify(old))?.[1];
if (!palette) throw new Error('could not find the map paper tile in the old screens.json');
const itemIds = readdirSync(join(out, 'assets', 'sprites')).filter((f) => f.startsWith('icon_')).map((f) => f.slice(5).replace('.sprite.json', ''));
const itemList = (JSON.parse(read(join(out, 'assets', 'items.json'))) as { items: ItemRow[] }).items;
const usable = itemList.filter((it) => it.use && !wornBy(it)).map((it) => it.id);
const equipment = equipmentOf(itemList);

writeFileSync(join(out, 'assets', 'screens.json'), JSON.stringify(buildScreens(itemIds, old.schemaVersion, Number(palette), usable, mapNamesFrom(constants), equipment), null, 2) + '\n');
writeFileSync(join(out, 'assets', 'ui.json'), JSON.stringify(uiTheme(old.schemaVersion), null, 2) + '\n');

// the strike pose is the swing: no pale diamond on the ground (the engine's melee attack draws one unless showSwing is off)
let scenes = 0;
for (const f of readdirSync(join(out, 'scenes')).filter((n) => n.endsWith('.scene.json'))) {
  const file = join(out, 'scenes', f);
  const text = read(file);
  const next = text.replace(/("meleeAttack":\{[^}]*?"shake":[\d.]+)\}/g, '$1,"showSwing":false}');
  if (next !== text) {
    writeFileSync(file, next);
    scenes++;
  }
}
console.log(`screens ${itemIds.length} icons, ${constants.WAYPOINTS.length} posts, ${Object.keys(constants.REGIONS).length} regions; swing marker off in ${scenes} scenes`);
