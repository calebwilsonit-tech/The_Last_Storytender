// Static checks of the generated Tilewright project (no editor, no browser): reads tilewright/ and prints PASS / FAIL lines.
//   node tools/port/static_check.mjs [project_dir]        (default: ./tilewright, relative to the repo)
// V-01  no beige "paper" tile anywhere; the cells outside the land are empty (tile 0) and still block.
// V-02  every raised back edge, the land's edge on the void and the map border use a ledge variant of the floor (name ends " nw" / " ne" / " nwne"),
//       on the meadow and moss floors too.
// M-03  every gate, bar and stone of the overworld has a collider; every prop that is not a crystal (prop-3, walked into) has one.
import { readFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = process.argv[2] ?? join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'tilewright');
const project = JSON.parse(readFileSync(join(root, 'project.json'), 'utf8'));
const scene = (f) => JSON.parse(readFileSync(join(root, f), 'utf8'));
let pass = 0;
let fail = 0;
const check = (name, ok, detail = '') => {
  if (ok) pass++;
  else fail++;
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? ' - ' + detail : ''}`);
};

const byId = new Map(project.tileset.map((t) => [t.id, t]));
const paper = project.tileset.filter((t) => t.name.includes('paper')).map((t) => t.id);
const BLOCK = 2; // FLAG.BLOCK (tilemap.ts); read from the engine if it is checked out beside this repo
const variantOf = (name) => (/ (nw|ne|nwne)$/.exec(name)?.[1] ?? '');

for (const file of project.scenes) {
  const s = scene(file);
  const m = s.map;
  const tag = file.replace('scenes/', '').replace('.scene.json', '');
  // V-01
  let paperCells = 0;
  let voidUnblocked = 0;
  m.tiles.forEach((row, y) =>
    row.forEach((t, x) => {
      if (paper.includes(t)) paperCells++;
      if (t === 0 && m.flags && !(m.flags[y][x] & BLOCK)) voidUnblocked++;
    }),
  );
  check(`${tag}: no paper tiles`, paperCells === 0, `${paperCells} paper cells`);
  if (m.flags) check(`${tag}: every empty cell blocks`, voidUnblocked === 0, `${voidUnblocked} empty cells you could walk onto`);
  // V-02: land cells whose back neighbour is lower, void or off the map use a ledge variant
  const outlinedFloor = (t) => {
    const n = byId.get(t)?.name ?? '';
    return /^(overworld_plains|scissor_mat|overworld_town|forge_memory|proof_memory|weighing_memory|pip_page|maud_wood) /.test(n);
  };
  const lower = (x, y, h) => x < 0 || y < 0 || m.tiles[y][x] === 0 || (m.heights[y][x] < h && !m.slopes[y][x]);
  let unlined = 0;
  m.tiles.forEach((row, y) =>
    row.forEach((t, x) => {
      if (!t || !outlinedFloor(t) || m.slopes[y][x]) return;
      const h = m.heights[y][x];
      const want = (lower(x - 1, y, h) ? 1 : 0) | (lower(x, y - 1, h) ? 2 : 0);
      const got = { '': 0, nw: 1, ne: 2, nwne: 3 }[variantOf(byId.get(t).name)];
      if (got !== want) unlined++;
    }),
  );
  check(`${tag}: back ledges and the land's edge carry the ledge line`, unlined === 0, `${unlined} cells differ`);
  // M-03 (the overworld only)
  if (tag === 'overworld') {
    const ent = s.entities;
    for (const cls of ['StoryGate', 'Redactor', 'SentenceStone']) {
      const list = ent.filter((e) => e.name.startsWith(cls));
      const bare = list.filter((e) => !e.components.collider);
      check(`overworld: every ${cls} has a collider`, list.length > 0 && bare.length === 0, `${bare.length} of ${list.length} without`);
    }
    const bars = ent.filter((e) => e.name.startsWith('Redactor'));
    check('overworld: every Redactor has its script', bars.every((e) => e.components.script_Redactor), '');
    const props = ent.filter((e) => e.name.startsWith('Prop'));
    const loose = props.filter((e) => !e.components.collider && !e.tags.includes('prop-3'));
    check('overworld: every prop but the crystals has a collider', loose.length === 0, loose.slice(0, 5).map((e) => `${e.name}@${e.components.transform.x},${e.components.transform.y}`).join(' '));
  }
}
console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
