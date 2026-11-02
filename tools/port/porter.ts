/**
 * Port tool: builds the Tilewright project of The Last Storytender (in ../../tilewright) from what the Godot game really
 * builds: the scene snapshots (snapshot.gd), the figure and prop pictures (capture_art.gd) and the tile pictures
 * (capture_tiles.gd), all quantized by quantize.py. It uses the engine's own code for every file it writes (the tile map,
 * the PNG import, the scene and project formats), so what comes out is exactly what the editor would save.
 *
 * Bundled and run by run_porter.sh. Inputs come from environment variables: SNAP, ART, TILES, OUT.
 */
import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { TileMap, FLAG, SLOPE, tileMapToRows, currentFlags, stringifySprite, decodePng, pauseButtonRow, makeAnimator, locomotionController, encodePng, CURRENT_SCHEMA_VERSION, type EntityData, type SceneData, type ProjectData } from '@tilewright/runtime';
import { baseProject, playerEntity, setActivePacks, attachBehavior } from '@tilewright/plugin-sdk/legacy';
import '@tilewright/bundled-plugins';
import { importPng } from '@tw-editor/renderer/studio/assets';

const SNAP = process.env.SNAP!;
const ART = process.env.ART!;
const TILES = process.env.TILES!;
const POSES = process.env.POSES ?? '';
const HERE = process.env.HERE!;
const OUT = process.env.OUT!;

const PLUGINS = ['combat', 'inventory', 'story', 'ai', 'lighting', 'storytender', 'prebuilt-screens'];
const LEVEL_PX = 28; // Iso.LEVEL_H in the game
setActivePacks(PLUGINS);

type Snap = {
  scene: string;
  floor: { cells: Record<string, string>; heights: Record<string, number>; stairs: Record<string, [number, number]>; blockers: [number, number][] };
  start: [number, number] | null;
  nodes: { class: string; name: string; pos: [number, number]; grid: [number, number]; visible: boolean; props: Record<string, unknown>; parent: string }[];
};
type ArtEntry = { scene: string; key: string; node: string; cls: string; grid: [number, number]; file: string; feet?: [number, number]; size?: [number, number] };
type TileEntry = { scene: string; kind: string; parity?: number; what: 'top' | 'left' | 'right'; file: string };

const SCENES: Record<string, { file: string; name: string }> = {
  overworld: { file: 'scenes/overworld.scene.json', name: 'The Prologue Plains' },
  forge: { file: 'scenes/forge.scene.json', name: "The Blacksmith's Regret" },
  pip: { file: 'scenes/pip.scene.json', name: 'The Unfinished Library' },
  maud: { file: 'scenes/maud.scene.json', name: 'The Empty Table' },
  proof: { file: 'scenes/proof.scene.json', name: 'The Proof Room' },
  weighing: { file: 'scenes/weighing.scene.json', name: 'The Weighing Room' },
  scissor: { file: 'scenes/scissor.scene.json', name: 'The Cutting Room' },
};

// ---------------------------------------------------------------- sprites

const sprites = new Map<string, string>(); // png file -> sprite name
const spriteDir = join(OUT, 'assets/sprites');

function spriteFor(file: string, name: string, feet?: [number, number]): string {
  const have = sprites.get(file);
  if (have) return have;
  const bytes = new Uint8Array(readFileSync(file));
  const { sprite } = importPng(bytes, name);
  if (feet) sprite.origin = { x: Math.round(feet[0]), y: Math.round(feet[1]) };
  writeFileSync(join(spriteDir, `${name}.sprite.json`), stringifySprite(sprite));
  sprites.set(file, name);
  return name;
}

const safe = (s: string): string => s.replace(/[^A-Za-z0-9_-]/g, '_').slice(0, 40);

/** The Storytender, standing and walking in the eight directions (capture_art.gd's pose pass), as one animated sprite. */
let storytender: string | null | undefined;
function storytenderSprite(): string | null {
  if (storytender !== undefined) return storytender;
  storytender = null;
  if (!POSES || !existsSync(join(POSES, 'poses.json'))) return null;
  const poses = JSON.parse(readFileSync(join(POSES, 'poses.json'), 'utf8')) as { frame: [number, number]; feet: [number, number]; frames: { facing: string; pose: string; step: number; file: string }[] };
  const [fw, fh] = poses.frame;
  const sheet = new Uint8Array(fw * fh * 4 * poses.frames.length);
  poses.frames.forEach((f, i) => {
    const img = decodePng(new Uint8Array(readFileSync(join(POSES, f.file))));
    for (let y = 0; y < fh; y++) for (let x = 0; x < fw; x++) {
      const src = (y * img.width + x) * 4;
      const dst = ((i * fh + y) * fw + x) * 4;
      for (let k = 0; k < 4; k++) sheet[dst + k] = img.rgba[src + k]!;
    }
  });
  const { sprite } = importPng(encodePng(fw, fh * poses.frames.length, sheet), 'storytender', fw, fh);
  sprite.origin = { x: poses.feet[0], y: poses.feet[1] };
  const idle: Record<string, number[]> = {};
  const walk: Record<string, number[]> = {};
  poses.frames.forEach((f, i) => {
    (f.pose === 'idle' ? idle : walk)[f.facing] ??= [];
    (f.pose === 'idle' ? idle : walk)[f.facing]!.push(i);
  });
  for (const fr of sprite.frames) fr.duration = 120;
  sprite.clips = [
    { name: 'idle', loop: true, mirror: false, all: idle.S ?? [0], dirs: idle, events: [] },
    { name: 'walk', loop: true, mirror: false, all: walk.S ?? [1], dirs: walk, events: [] },
  ];
  writeFileSync(join(spriteDir, 'storytender.sprite.json'), stringifySprite(sprite));
  storytender = 'storytender';
  return storytender;
}

// ---------------------------------------------------------------- tiles

type Kind = { base: number; variants: number[][] /* by parity */; name: string };
const tileset: ProjectData['tileset'] = [];
const kinds = new Map<string, Kind>(); // "scene|kind" -> tiles
let nextTile = 1;

const KIND_NAMES: Record<string, string> = { '.': 'plains', ',': 'town', '#': 'pit', m: 'memory', p: 'page', w: 'wood', c: 'mat' };
const FALLBACK: Record<string, [number, number, number]> = {
  '.': [0x86b75a, 0x6b8a44, 0x5a7538],
  ',': [0xebe0c5, 0xc9b892, 0xb3a27c],
  '#': [0x1c1824, 0x15121b, 0x100e15],
  m: [0x425270, 0x2c3850, 0x232c40],
  p: [0xe9dcbc, 0xc7b58f, 0xb09f7c],
  w: [0x9a6a3a, 0x6e4a28, 0x5a3c20],
  c: [0x2d6a4f, 0x1f4a37, 0x183a2b],
};

function meanColour(file: string): number {
  // the average opaque colour of a picture, for the flat colour a tile shows before its art loads
  const img = decodePng(new Uint8Array(readFileSync(file)));
  let r = 0, g = 0, b = 0, n = 0;
  for (let i = 0; i < img.rgba.length; i += 4) {
    if (img.rgba[i + 3]! < 200) continue;
    r += img.rgba[i]!; g += img.rgba[i + 1]!; b += img.rgba[i + 2]!; n++;
  }
  return n ? (Math.round(r / n) << 16) | (Math.round(g / n) << 8) | Math.round(b / n) : 0x888888;
}

function buildKinds(tiles: TileEntry[], snaps: Record<string, Snap>): void {
  for (const [scene, snap] of Object.entries(snaps)) {
    const used = new Set(Object.values(snap.floor.cells));
    for (const kind of used) {
      const key = `${scene}|${kind}`;
      const kname = `${scene}_${KIND_NAMES[kind] ?? safe(kind)}`;
      const own = tiles.filter((t) => t.scene === scene && t.kind === kind);
      // the same kind of floor in another scene can lend its pictures (the town floor in a dungeon, say)
      const lend = own.length > 0 ? own : tiles.filter((t) => t.kind === kind);
      const left = lend.find((t) => t.what === 'left');
      const right = lend.find((t) => t.what === 'right');
      const fb = FALLBACK[kind] ?? [0x999999, 0x777777, 0x555555];
      const sideArt = {
        ...(left ? { leftArt: spriteFor(join(TILES, left.file), safe(`t_${kname}_left`)) } : {}),
        ...(right ? { rightArt: spriteFor(join(TILES, right.file), safe(`t_${kname}_right`)) } : {}),
      };
      const variants: number[][] = [[], []];
      for (const par of [0, 1]) {
        const tops = lend.filter((t) => t.what === 'top' && t.parity === par);
        for (const [i, t] of tops.entries()) {
          const id = nextTile++;
          tileset.push({
            id,
            name: `${kname} ${par ? 'dark' : 'light'} ${i + 1}`,
            top: meanColour(join(TILES, t.file)),
            left: fb[1],
            right: fb[2],
            art: spriteFor(join(TILES, t.file), safe(`t_${kname}_${par}_${i}`)),
            ...sideArt,
            faceLevels: 1,
            props: kind === '#' ? { pit: true } : {},
          });
          variants[par]!.push(id);
        }
      }
      if (variants[0]!.length === 0 && variants[1]!.length === 0) {
        const id = nextTile++;
        tileset.push({ id, name: kname, top: fb[0], left: fb[1], right: fb[2], ...sideArt, props: kind === '#' ? { pit: true } : {} });
        variants[0]!.push(id);
        variants[1]!.push(id);
      }
      if (variants[0]!.length === 0) variants[0] = variants[1]!;
      if (variants[1]!.length === 0) variants[1] = variants[0]!;
      kinds.set(key, { base: variants[0]![0]!, variants, name: kname });
    }
  }
}

/** The edge of the page: the game shows its parchment there. Tilewright has no background picture or colour per scene, so the
 * void around the land is filled with flat, blocked paper tiles at the lowest level. */
let paperTile = 0;
function addPaper(): void {
  paperTile = nextTile++;
  tileset.push({ id: paperTile, name: 'page edge (paper)', top: 0xdecea6, left: 0xc9b58a, right: 0xb8a47a, art: spriteFor(join(HERE, 'paper_tile.png'), 't_paper'), props: { solid: true, walkable: false } });
}

const hash = (x: number, y: number): number => (((x * 73856093) ^ (y * 19349663)) >>> 0) % 9973;

// ---------------------------------------------------------------- scenes

function buildMap(scene: string, snap: Snap): TileMap {
  const keys = Object.keys(snap.floor.cells).map((k) => k.split(',').map(Number) as [number, number]);
  const w = Math.max(...keys.map((k) => k[0])) + 2;
  const h = Math.max(...keys.map((k) => k[1])) + 2;
  // (the map is a little bigger than the land, so the paper shows all round it)
  const map = new TileMap(w + 4, h + 4);
  for (const [x, y] of keys) {
    const kind = snap.floor.cells[`${x},${y}`]!;
    const k = kinds.get(`${scene}|${kind}`)!;
    const vs = k.variants[(x + y) % 2]!;
    const tile = vs[hash(x, y) % vs.length]!;
    const stair = snap.floor.stairs[`${x},${y}`];
    const level = snap.floor.heights[`${x},${y}`] ?? 0;
    map.set(x, y, tile, level);
    if (stair) {
      const [dx, dy] = stair;
      map.setSlope(x, y, dx === 1 ? SLOPE.E : dx === -1 ? SLOPE.W : dy === 1 ? SLOPE.S : SLOPE.N, 'stairs');
    }
    if (kind === '#') map.setFlag(x, y, FLAG.PIT);
  }
  for (let y = 0; y < h + 4; y++)
    for (let x = 0; x < w + 4; x++)
      if (!snap.floor.cells[`${x},${y}`]) {
        map.set(x, y, paperTile, 0);
        map.setFlag(x, y, FLAG.BLOCK);
      }
  return map;
}

/** How tall a picture stands, in levels, from its height in pixels (for draw order). */
const levelsOf = (px: number): number => Math.max(0.2, Math.round(((px - 16) / LEVEL_PX) * 10) / 10);

function entityFor(scene: string, n: Snap['nodes'][number], art: ArtEntry | undefined, id: string, levelOf: (x: number, y: number) => number): EntityData | null {
  const gx = n.grid[0] + 0.5;
  const gy = n.grid[1] + 0.5;
  const h = levelOf(Math.round(n.grid[0]), Math.round(n.grid[1]));
  const asset = art?.file ? spriteFor(join(ART, art.file), safe(`a_${art.file.replace(/\.png$/, '')}`), art.feet) : undefined;
  const height = art?.size ? levelsOf(art.size[1]) : 1;
  const sprite = { shape: 'box', color: 0xcccccc, w: 0.6, d: 0.6, height, sortOffset: 0, visible: n.visible, ...(asset ? { asset } : {}) };
  const tags = [n.class.toLowerCase()];
  const kind = n.props.kind;
  if (n.class === 'Prop' && typeof kind === 'number') tags.push(`prop-${kind}`);
  return { id, name: `${n.class} ${n.name}`, tags, components: { transform: { x: gx, y: gy, h, facing: 2 }, sprite } };
}

function buildScene(scene: string, snap: Snap, art: ArtEntry[]): SceneData {
  const map = buildMap(scene, snap);
  const blocked = new Set(snap.floor.blockers.map(([x, y]) => `${x},${y}`));
  const taken = new Set<string>();
  const levelOf = (x: number, y: number): number => snap.floor.heights[`${x},${y}`] ?? 0;
  const entities: EntityData[] = [];
  const byNode = new Map(art.filter((a) => a.scene === scene).map((a) => [a.node, a]));
  let i = 1;
  let player: EntityData | null = null;
  for (const n of snap.nodes) {
    if (n.class === 'Player') {
      if (player) continue;
      const start = snap.start ?? n.grid;
      const p = playerEntity(`e${i++}`, start[0] + 0.5, start[1] + 0.5);
      const a = byNode.get(n.name);
      const t = p.components.transform as { h: number };
      t.h = levelOf(Math.round(start[0]), Math.round(start[1]));
      const anim = storytenderSprite();
      if (anim) {
        (p.components.sprite as Record<string, unknown>).asset = anim;
        p.components.animator = makeAnimator({ clip: 'idle', controller: locomotionController({ idle: 'idle', walk: 'walk' }) });
      } else if (a?.file) (p.components.sprite as Record<string, unknown>).asset = spriteFor(join(ART, a.file), 'storytender', a.feet);
      attachBehavior(p.components, 'followCamera');
      Object.assign(p.components.followCamera as object, { zoom: 1.5 }); // LevelBase.ZOOM
      player = p;
      entities.push(p);
      continue;
    }
    if (['IsoFloor', 'GroundChunks', 'AmbientDrift', 'PasteGhost'].includes(n.class)) continue;
    const e = entityFor(scene, n, byNode.get(n.name), `e${i++}`, levelOf);
    if (!e) continue;
    const cell = `${Math.round(n.grid[0])},${Math.round(n.grid[1])}`;
    if (blocked.has(cell) && !taken.has(cell)) {
      taken.add(cell);
      e.components.collider = { w: 0.9, d: 0.9, height: Math.max(1, (e.components.sprite as { height: number }).height), solid: true, trigger: false, layer: 16, mask: 65535, enabled: true, inside: [] };
    }
    entities.push(e);
  }
  for (const c of blocked) if (!taken.has(c)) {
    const [x, y] = c.split(',').map(Number) as [number, number];
    map.setFlag(x, y, FLAG.BLOCK);
  }
  return {
    schemaVersion: CURRENT_SCHEMA_VERSION,
    name: SCENES[scene]!.name,
    map: tileMapToRows(map),
    entities,
    regions: [],
    wires: [],
    variables: [],
    events: [pauseButtonRow()],
    graphs: [],
  } as SceneData;
}

// ---------------------------------------------------------------- main

function main(): void {
  if (existsSync(join(OUT, 'assets/sprites'))) rmSync(join(OUT, 'assets/sprites'), { recursive: true });
  mkdirSync(spriteDir, { recursive: true });
  mkdirSync(join(OUT, 'scenes'), { recursive: true });
  const snaps: Record<string, Snap> = {};
  for (const k of Object.keys(SCENES)) snaps[k] = JSON.parse(readFileSync(join(SNAP, `${k}.json`), 'utf8'));
  const art: ArtEntry[] = JSON.parse(readFileSync(join(ART, 'index.json'), 'utf8'));
  const tiles: TileEntry[] = JSON.parse(readFileSync(join(TILES, 'index.json'), 'utf8'));
  buildKinds(tiles, snaps);
  addPaper();
  const scenes: string[] = [];
  for (const k of Object.keys(SCENES)) {
    const scene = buildScene(k, snaps[k]!, art);
    writeFileSync(join(OUT, SCENES[k]!.file), JSON.stringify(scene) + '\n');
    scenes.push(SCENES[k]!.file);
    console.log(`scene ${k}: ${scene.entities.length} objects, map ${scene.map.width} x ${scene.map.height}`);
  }
  const project = baseProject('The Last Storytender', PLUGINS);
  project.iso = { tileW: 64, tileH: 32, heightPx: LEVEL_PX };
  project.tileset = tileset;
  project.scenes = scenes;
  project.startScene = SCENES.overworld!.file;
  (project as ProjectData & { compat?: Record<string, boolean> }).compat = currentFlags();
  writeFileSync(join(OUT, 'project.json'), JSON.stringify(project, null, 2) + '\n');
  writeFileSync(join(OUT, '.gdignore'), '');
  console.log(`tiles ${tileset.length}, sprites ${readdirSync(spriteDir).length}`);
}

main();
