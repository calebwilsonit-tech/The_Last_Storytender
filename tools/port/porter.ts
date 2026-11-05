/**
 * Port tool: builds the Tilewright project of The Last Storytender (in ../../tilewright) from what the Godot game really
 * builds: the scene snapshots (snapshot.gd), the figure and prop pictures (capture_art.gd) and the tile pictures
 * (capture_tiles.gd), all quantized by quantize.py. It uses the engine's own code for every file it writes (the tile map,
 * the PNG import, the scene and project formats), so what comes out is exactly what the editor would save.
 *
 * Bundled and run by run_porter.sh. Inputs come from environment variables: SNAP, ART, TILES, OUT.
 */
import { buildScreens, equipmentOf, mapNamesFrom, uiTheme, wornBy, type ItemRow, type MapConstants, type MapNames } from './screens';
import { decorateForge, forgeExtras, forgeRows, writeForgePrefabs, writeForgeTalk } from './forge';
import { decoratePip, pipExtras, pipGapCells, pipMap, writePipTalk, type PipMap } from './pip';
import { decorateMaud, maudExtras, maudGaps, maudMap, writeMaudTalk, type MaudMap } from './maud';
import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { TileMap, FLAG, SLOPE, tileMapToRows, currentFlags, stringifySprite, decodePng, pauseButtonRow, makeAnimator, locomotionController, encodePng, CURRENT_SCHEMA_VERSION, type EntityData, type SceneData, type ProjectData } from '@tilewright/runtime';
import { baseProject, playerEntity, setActivePacks, attachBehavior } from '@tilewright/plugin-sdk/legacy';
import '@tilewright/bundled-plugins';
import { importPng } from '@tw-editor/renderer/studio/assets';
import { decorateOverworld, writeOverworldTalk, type World } from './overworld';
import { bridgeCells, siteExtras } from './sites';
import { decorateScissor, scissorExtras, writeScissorTalk } from './scissor';
import { writeCutscenes } from './cutscenes';
import { decorateSide, sideExtras, sideMap, writeSideTalk, type SideMap } from './side';

const SNAP = process.env.SNAP!;
const ART = process.env.ART!;
const TILES = process.env.TILES!;
const POSES = process.env.POSES ?? '';
const DATA = process.env.DATA ?? '';
const PEOPLE = process.env.PEOPLE ?? '';
const ERRORS = process.env.ERRORS ?? '';
const OBJECTS = process.env.OBJECTS ?? '';
const ICONS = process.env.ICONS ?? '';
const HERE = process.env.HERE!;
const OUT = process.env.OUT!;

const PLUGINS = ['combat', 'inventory', 'story', 'ai', 'lighting', 'storytender', 'prebuilt-screens', 'parchment'];
const LEVEL_PX = 28; // Iso.LEVEL_H in the game
setActivePacks(PLUGINS);

type Snap = {
  scene: string;
  floor: { cells: Record<string, string>; heights: Record<string, number>; stairs: Record<string, [number, number]>; blockers: [number, number][] };
  start: [number, number] | null;
  nodes: { class: string; name: string; pos: [number, number]; grid: [number, number]; visible: boolean; props: Record<string, unknown>; parent: string }[];
};
type ArtEntry = { scene: string; key: string; node: string; cls: string; grid: [number, number]; file: string; feet?: [number, number]; size?: [number, number] };
type TileEntry = { scene: string; kind: string; parity?: number; what: 'top' | 'left' | 'right'; file: string; grid?: [number, number]; period?: number };

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
  const clips: Record<string, Record<string, number[]>> = { idle: {}, walk: {}, strike: {} };
  poses.frames.forEach((f, i) => {
    const c = (clips[f.pose] ??= {});
    (c[f.facing] ??= []).push(i);
  });
  // the walk at 120 ms a frame; the strike quick (its three frames fill the quill's 0.18 s)
  sprite.frames.forEach((fr, i) => (fr.duration = poses.frames[i]!.pose === 'strike' ? 60 : 120));
  sprite.clips = [
    { name: 'idle', loop: true, mirror: false, all: clips.idle!.S ?? [0], dirs: clips.idle!, events: [] },
    { name: 'walk', loop: true, mirror: false, all: clips.walk!.S ?? [1], dirs: clips.walk!, events: [] },
    ...(Object.keys(clips.strike!).length ? [{ name: 'strike', loop: false, mirror: false, all: clips.strike!.S ?? [0], dirs: clips.strike!, events: [] }] : []),
  ];
  writeFileSync(join(spriteDir, 'storytender.sprite.json'), stringifySprite(sprite));
  storytender = 'storytender';
  return storytender;
}

// ---------------------------------------------------------------- tiles

type Kind = { base: number; variants: number[][] /* by parity */; name: string; grid?: { period: number; ids: number[] } /* a seamless floor: the tile of (x mod period, y mod period) */ };
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
      // a seamless floor (sheet_tiles.py): one tile per cell of its period, placed by position
      const gridTops = lend.filter((t) => t.what === 'top' && t.grid);
      if (gridTops.length > 0) {
        const period = gridTops[0]!.period!;
        const ids: number[] = new Array(period * period).fill(0);
        for (const t of gridTops) {
          const id = nextTile++;
          tileset.push({ id, name: `${kname} ${t.grid![0]},${t.grid![1]}`, top: meanColour(join(TILES, t.file)), left: fb[1], right: fb[2], art: spriteFor(join(TILES, t.file), safe(`t_${kname}_g${t.grid![0]}${t.grid![1]}`)), ...sideArt, faceLevels: 1, props: {} });
          ids[t.grid![1] * period + t.grid![0]] = id;
        }
        kinds.set(key, { base: ids[0]!, variants: [ids, ids], name: kname, grid: { period, ids } });
        continue;
      }
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
  // in Pip's memory the gaps a sentence can fill are floor under a cover (PitCover), not pits
  const gaps = scene === 'pip' ? pipGapCells((pipMapCache ??= pipMap(join(HERE, '..', '..')))) : scene === 'maud' ? new Set(maudGaps((maudMapCache ??= maudMap(join(HERE, '..', '..')))).keys()) : scene === 'overworld' && world ? bridgeCells(world.map.SITES) : scene === 'weighing' ? new Set((sideCache.weighing ??= sideMap(join(HERE, '..', '..'), 'weighing')).pan.map(([x, y]) => `${x},${y}`)) : new Set<string>();
  for (const [x, y] of keys) {
    const gap = gaps.has(`${x},${y}`);
    const floorKind = scene === 'maud' ? 'w' : scene === 'weighing' ? 'm' : 'p';
    const kind = gap && kinds.has(`${scene}|${floorKind}`) ? floorKind : snap.floor.cells[`${x},${y}`]!;
    const k = kinds.get(`${scene}|${kind}`)!;
    const vs = k.variants[(x + y) % 2]!;
    const tile = k.grid ? k.grid.ids[(y % k.grid.period) * k.grid.period + (x % k.grid.period)]! : vs[hash(x, y) % vs.length]!;
    const stair = snap.floor.stairs[`${x},${y}`];
    const level = snap.floor.heights[`${x},${y}`] ?? 0;
    map.set(x, y, tile, level);
    if (stair) {
      const [dx, dy] = stair;
      map.setSlope(x, y, dx === 1 ? SLOPE.E : dx === -1 ? SLOPE.W : dy === 1 ? SLOPE.S : SLOPE.N, 'stairs');
    }
    if (kind === '#') map.setFlag(x, y, FLAG.PIT);
  }
  // Outside the land (the gaps and the margin all round) no tile is set, so the renderer draws nothing there and the scene's dark
  // background shows (V-01); the cells still block, so nobody can walk off the land. (Tile 0 is "no tile": the engine does not build it,
  // and the world map leaves it transparent.)
  for (let y = 0; y < h + 4; y++)
    for (let x = 0; x < w + 4; x++)
      if (!snap.floor.cells[`${x},${y}`]) map.setFlag(x, y, FLAG.BLOCK);
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

/** Adds a behaviour with settings; a script behaviour (script_<Name>) is just its settings, checked when the editor compiles it. */
function attach(components: Record<string, unknown>, id: string, settings: object): void {
  if (id.startsWith('script_')) {
    components[id] = { ...settings };
    return;
  }
  attachBehavior(components, id);
  Object.assign(components[id] as object, settings);
}

// ---------------------------------------------------------------- the Errors (enemy.gd, enemy_kinds.gd)

const ERROR_HP = [9, 2, 10, 5, 12, 4];
const ERROR_LETTERS: Record<string, number> = { g: 0, x: 1, l: 2, d: 3, n: 4, z: 5 };
/** Which flag lets a kind out in the Prologue (main.gd _kind_unlocked). */
const ERROR_UNLOCK = ['', '', 'restored_pip', 'restored_pip', 'restored_maud', 'restored_maud'];
const ERROR_COLOUR = [0x8a6f5a, 0x2a2236, 0x3a3150, 0x5a4a7a, 0x1b1722, 0x2f2a3a];
const ERROR_DROPS = ['bare', 'mite', 'slug', 'dangler', 'censor', 'ellipsis'];
/** The picture of each kind, from wherever the Godot game showed one. */
const errorArt = new Map<number, string>();
let mobDrops: Record<string, [string, number, number, number][]> = {};

function errorKit(e: EntityData, kind: number, unlock: string): void {
  const c = e.components;
  e.tags = [...new Set([...e.tags, 'enemy', 'error', `error-${kind}`])];
  // a body, so it can walk (it stops at ledges and pits rather than falling)
  c.body = { vx: 0, vy: 0, vz: 0, radius: kind === 1 ? 0.18 : 0.28, height: 1, state: 'ground', stepUp: 0.35, stepDown: 0.4, ledge: 'stop', pits: 'stop', wade: false, gravity: 1, peakZ: 0, layer: 4, mask: 65535, noclip: false, blockedBy: [], blockedTerrain: false };
  attach(c, 'health', { max: ERROR_HP[kind], invulnerableSeconds: 0.22, onDeath: 'stay', fallDamage: 0, team: 'enemy', showBar: false });
  if (kind === 1 || kind === 2 || kind === 5) attach(c, 'damageOnTouch', { amount: 0, hurts: 'player', range: 0.25, knockback: kind === 2 ? 3.4 : 4.2 });
  if (kind === 3) attach(c, 'rangedAttack', { target: 'nothing', range: 10, minRange: 0, cooldown: 2.5, windup: 0.55, volley: 1, speed: 6.4, damage: 6, lifetime: 2.5, needSight: true, color: 0x1b1722, hurts: 'player' });
  const drops = (mobDrops[ERROR_DROPS[kind]!] ?? []).map((d) => d.join(',')).join('; ');
  // the generated art (sd_errors.py), with the friendly look of the kinds the lantern proofreads
  const art = ['bare', 'mite', 'runon', 'dangler', 'censor', 'ellipsis'][kind]!;
  let friendlyLook = '';
  let attackLook = '';
  const spr = c.sprite as Record<string, unknown>;
  if (ERRORS && existsSync(join(ERRORS, `${art}.png`))) {
    const feet = JSON.parse(readFileSync(join(ERRORS, 'errors.json'), 'utf8')) as Record<string, [number, number]>;
    spr.asset = spriteFor(join(ERRORS, `${art}.png`), `err_${art}`, feet[art]);
    spr.height = [1.6, 0.8, 0.9, 1.4, 1.7, 1.1][kind];
    if (existsSync(join(ERRORS, `${art}_friendly.png`))) friendlyLook = spriteFor(join(ERRORS, `${art}_friendly.png`), `err_${art}_friendly`, feet[`${art}_friendly`]);
    if (existsSync(join(ERRORS, `${art}_attack.png`))) attackLook = spriteFor(join(ERRORS, `${art}_attack.png`), `err_${art}_attack`, feet[`${art}_attack`]);
  }
  attach(c, 'script_Error', { kind, unlock, drops, friendlyLook, attackLook });
  if (!spr.asset) Object.assign(spr, { color: ERROR_COLOUR[kind], w: kind === 1 ? 0.35 : 0.6, d: kind === 1 ? 0.35 : 0.6, height: kind === 1 ? 0.5 : 1 });
  else if (!errorArt.has(kind)) errorArt.set(kind, String(spr.asset));
}

/** The Errors of the Prologue: one per letter of the map (g x l d n z), let out as the story allows. */
function prologueErrors(levelOf: (x: number, y: number) => number, next: () => string): EntityData[] {
  if (!DATA) return [];
  const rows = (JSON.parse(readFileSync(join(DATA, 'prologue_map.json'), 'utf8')) as { constants: { ROWS: string[] } }).constants.ROWS;
  const out: EntityData[] = [];
  rows.forEach((row, y) =>
    [...row].forEach((ch, x) => {
      const kind = ERROR_LETTERS[ch];
      if (kind === undefined) return;
      const asset = errorArt.get(kind);
      const sprite = { shape: 'box', color: 0xcccccc, w: 0.6, d: 0.6, height: 1, sortOffset: 0, visible: true, ...(asset ? { asset } : {}) };
      const e: EntityData = { id: next(), name: `Error ${['Bare', 'Mite', 'Run-on', 'Dangler', 'Censor', 'Ellipsis'][kind]}`, tags: [], components: { transform: { x: x + 0.5, y: y + 0.5, h: levelOf(x, y), facing: 2 }, sprite } };
      errorKit(e, kind, ERROR_UNLOCK[kind]!);
      out.push(e);
    }),
  );
  return out;
}

/** The crystal a beaten Error drops (Error.script.ts spawns it): the Prologue's crystal picture, picked up by walking into it. */
function writeCrystalPrefab(overworld: SceneData): void {
  const crystal = overworld.entities.find((e) => e.tags.includes('prop-3'));
  const sprite = { ...((crystal?.components.sprite as object) ?? { shape: 'box', color: 0x9fe8ff, w: 0.3, d: 0.3, height: 0.5 }), visible: true };
  const prefab = {
    schemaVersion: CURRENT_SCHEMA_VERSION,
    name: 'DroppedCrystal',
    root: { name: 'Dropped crystal', tags: ['crystal', 'dropped'], components: { sprite, script_Collect: { flag: '', mnemo: 5, light: 12, radius: 30 / 35.8 + 0.25 } }, children: [] },
  };
  mkdirSync(join(OUT, 'assets/prefabs'), { recursive: true });
  writeFileSync(join(OUT, 'assets/prefabs/DroppedCrystal.prefab.json'), JSON.stringify(prefab, null, 2) + '\n');
}

/** The other pictures of a boss (sd_errors.py: attack, reckoning, slam...): its script switches to them as its moves change. */
function dressBoss(e: EntityData, cls: string): void {
  if (!ERRORS || !existsSync(join(ERRORS, 'errors.json'))) return;
  const feet = JSON.parse(readFileSync(join(ERRORS, 'errors.json'), 'utf8')) as Record<string, [number, number]>;
  const look = (name: string): string => (existsSync(join(ERRORS, `${name}.png`)) ? spriteFor(join(ERRORS, `${name}.png`), `boss_${name}`, feet[name]) : '');
  const set = (script: string, looks: Record<string, string>): void => {
    const c = e.components[script] as Record<string, unknown> | undefined;
    if (c) Object.assign(c, Object.fromEntries(Object.entries(looks).filter(([, v]) => v)));
  };
  if (cls === 'Critic') set('script_Critic', { lookAttack: look('critic_attack'), lookReckoning: look('critic_reckoning') });
  if (cls === 'ScissorMan') set('script_Scissor', { lookCut: look('scissor_cut'), lookJam: look('scissor_jammed') });
  if (cls === 'Spoiler') set('script_Spoiler', { lookRead: look('spoiler_read'), lookAttack: look('spoiler_attack') });
}

/** A villager in the generated art: the graphite placeholder until their restoration, then in colour (sd_people.py). */
function dressPerson(e: EntityData): void {
  const who = ['garrick', 'pip', 'maud'].find((x) => e.tags.includes(x));
  if (!who || !PEOPLE || !existsSync(join(PEOPLE, `${who}.png`))) return;
  const feet = JSON.parse(readFileSync(join(PEOPLE, 'people.json'), 'utf8')) as Record<string, [number, number]>;
  const colour = spriteFor(join(PEOPLE, `${who}.png`), `npc_${who}`, feet[who]);
  const ghost = spriteFor(join(PEOPLE, `${who}_ghost.png`), `npc_${who}_ghost`, feet[`${who}_ghost`]);
  Object.assign(e.components.sprite as object, { asset: ghost, height: who === 'pip' ? 1.9 : 2.4 });
  attach(e.components, 'script_Flagged', { hideWhen: '', showWhen: '', lookWhen: `restored_${who}`, look: colour });
}

/**
 * Objects that change with the story, in the generated art (sd_objects.py): a chest opens, a lantern post lights, the forge
 * burns once Garrick is restored and the oven once Maud is. The first look until the flag, then the second (Flagged).
 */
function dressObject(e: EntityData, kind: number, cell: [number, number], sceneFile: string): void {
  if (!OBJECTS || !existsSync(join(OBJECTS, 'objects.json'))) return;
  const feet = JSON.parse(readFileSync(join(OBJECTS, 'objects.json'), 'utf8')) as Record<string, [number, number]>;
  const pair: Record<number, [string, string, string, number]> = {
    18: ['chest_closed', 'chest_open', `got_chest_${cell[0]}_${cell[1]}`, 0.9],
    16: ['post_unlit', 'post_lit', `lit:${sceneFile}:${e.id}`, 1.8],
    2: ['forge_frozen', 'forge_warm', 'restored_garrick', 3],
    14: ['oven_cold', 'oven_warm', 'restored_maud', 2.6],
  };
  const p = pair[kind];
  if (!p || !existsSync(join(OBJECTS, `${p[0]}.png`))) return;
  const [first, second, flag, height] = p;
  const a = spriteFor(join(OBJECTS, `${first}.png`), `obj_${first}`, feet[first]);
  const b = spriteFor(join(OBJECTS, `${second}.png`), `obj_${second}`, feet[second]);
  Object.assign(e.components.sprite as object, { asset: a, height });
  const f = e.components.script_Flagged as Record<string, string> | undefined;
  if (f) Object.assign(f, { lookWhen: flag, look: b });
  else attach(e.components, 'script_Flagged', { hideWhen: '', showWhen: '', lookWhen: flag, look: b });
}

let forgeRowsCache: string[] | undefined;
let pipMapCache: PipMap | undefined;
let maudMapCache: MaudMap | undefined;
let figureArt = '';

/** What Maud's memory spawns: the guests, the frost of a cold wave, and the Cold Shoulder. */
function writeMaudPrefabs(): void {
  const write = (name: string, root: object): void => writeFileSync(join(OUT, `assets/prefabs/${name}.prefab.json`), JSON.stringify({ schemaVersion: CURRENT_SCHEMA_VERSION, name, root }, null, 2) + '\n');
  const feet = OBJECTS && existsSync(join(OBJECTS, 'objects.json')) ? (JSON.parse(readFileSync(join(OBJECTS, 'objects.json'), 'utf8')) as Record<string, [number, number]>) : {};
  const seated = feet.guest ? spriteFor(join(OBJECTS, 'guest.png'), 'obj_guest', feet.guest) : '';
  // the standing guest: its own picture (art/incoming2 guest_standing) if there is one, else the memory figure's
  const standing = feet.guest_standing ? spriteFor(join(OBJECTS, 'guest_standing.png'), 'obj_guest_standing', feet.guest_standing) : figureArt;
  const body = { vx: 0, vy: 0, vz: 0, radius: 0.25, height: 1, state: 'ground', stepUp: 0.35, stepDown: 0.4, ledge: 'stop', pits: 'stop', wade: false, gravity: 1, peakZ: 0, layer: 4, mask: 65535, noclip: false, blockedBy: [], blockedTerrain: false };
  write('Guest', { name: 'Guest', tags: ['guest'], components: { sprite: { shape: 'box', color: 0x9fe0ff, w: 0.4, d: 0.4, height: 1.2, sortOffset: 0, visible: true, ...(standing ? { asset: standing } : {}) }, body, script_Guest: { area: '', lookSeated: seated, lookStanding: standing } }, children: [] });
  const frost = flatArt('frost', [200, 230, 250], 64, 32, true, 200, [150, 200, 230]);
  write('Frost', { name: 'Frost', tags: ['frost'], components: { sprite: { shape: 'box', color: 0xc8e6fa, w: 1, d: 1, height: 0.02, sortOffset: -1, visible: true, asset: frost }, lifetime: { seconds: 0.4 } }, children: [] });
  const ef = ERRORS && existsSync(join(ERRORS, 'errors.json')) ? (JSON.parse(readFileSync(join(ERRORS, 'errors.json'), 'utf8')) as Record<string, [number, number]>) : {};
  const cold = ef.cold_shoulder ? spriteFor(join(ERRORS, 'cold_shoulder.png'), 'boss_cold_shoulder', ef.cold_shoulder) : '';
  write('ColdShoulder', {
    name: 'The Cold Shoulder',
    tags: ['boss', 'coldshoulder', 'enemy'],
    components: {
      sprite: { shape: 'box', color: 0xbfe8f0, w: 1, d: 1, height: 3, sortOffset: 0, visible: true, ...(cold ? { asset: cold } : {}) },
      health: { max: 170, invulnerableSeconds: 0.25, onDeath: 'stay', fallDamage: 0, team: 'enemy', showBar: false },
      body: { ...body, radius: 0.6, height: 2.5 },
      script_ColdShoulder: { ...(ef.cold_slam ? { lookSlam: spriteFor(join(ERRORS, 'cold_slam.png'), 'boss_cold_slam', ef.cold_slam) } : {}) },
    },
    children: [],
  });
}

/** What the Spoiler spawns: a read sentence's patch of floor (Hazard), its paper cuts, and the Mites its wolves become. */
function writePipPrefabs(): void {
  flatArt('flowers', [236, 150, 190], 192, 96, true, 210, [120, 170, 80]);
  flatArt('flash', [255, 244, 170], 192, 96, true, 230, [255, 255, 255]);
  flatArt('hole', [22, 18, 30], 64, 32, true, 255, [10, 8, 14]);
  const warn = flatArt('warn', [214, 90, 60], 192, 96, true, 150, [120, 30, 20]);
  const page = flatArt('page', [246, 240, 226], 14, 14, false, 255, [60, 50, 40]);
  const write = (name: string, root: object): void => writeFileSync(join(OUT, `assets/prefabs/${name}.prefab.json`), JSON.stringify({ schemaVersion: CURRENT_SCHEMA_VERSION, name, root }, null, 2) + '\n');
  write('Hazard', { name: 'Read sentence', tags: ['hazard'], components: { sprite: { shape: 'box', color: 0xd65a3c, w: 3, d: 3, height: 0.02, sortOffset: -1, visible: true, asset: warn }, script_Hazard: { kind: 'lightning', window: 5.6 } }, children: [] });
  write('PageCut', { name: 'Paper cut', tags: ['bolt', 'pagecut'], components: { sprite: { shape: 'box', color: 0xf6f0e2, w: 0.25, d: 0.25, height: 0.25, sortOffset: 0, visible: true, asset: page }, projectile: { speed: 4.2, lifetime: 3, useFacing: false, dirX: 1, dirY: 0, damage: 8, hurts: 'player', knockback: 3 } }, children: [] });
  const mite: EntityData = { id: 'm', name: 'Error Mite', tags: [], components: { sprite: { shape: 'box', color: 0x2a2236, w: 0.35, d: 0.35, height: 0.5, sortOffset: 0, visible: true } } };
  errorKit(mite, 1, '');
  write('SpoilerMite', { name: 'Error Mite', tags: mite.tags, components: mite.components, children: [] });
}
/** The vault trials of the riddle stones above tier 1 (Trial.script.ts plays them): the engine's own "repeat the pattern" game. */
function writeMinigames(): void {
  if (!world) return;
  const games = Object.entries(world.map.RIDDLES)
    .filter(([, r]) => r.tier > 1)
    .map(([id, r]) => ({ kind: 'sequence', name: `Vault Trial ${id}`, title: 'The Vault Trial', instructions: 'The stone shows arrows, one after another. Press them back in the same order.', winVariable: '', scoreVariable: '', rewardItem: '', rewardAmount: 1, canQuit: true, length: 4 + r.tier, buttons: 4, showSeconds: 0.55, allowedMistakes: 1 }));
  writeFileSync(join(OUT, 'assets/minigames.json'), JSON.stringify({ schemaVersion: CURRENT_SCHEMA_VERSION, minigames: games }, null, 2) + '\n');
}

/** What a used item leaves in the world: the thrown Eraser Crumbs (Storytender.script.ts moves it along its arc and rubs things out). */
function writeItemPrefabs(): void {
  const icon = sprites.get(join(ICONS ?? '', 'icon_eraser_crumbs.png')) ?? (ICONS && existsSync(join(ICONS, 'icon_eraser_crumbs.png')) ? spriteFor(join(ICONS, 'icon_eraser_crumbs.png'), 'icon_eraser_crumbs') : '');
  const sprite = icon ? { shape: 'box', color: 0xf4f0e6, w: 0.45, d: 0.45, height: 0.55, sortOffset: 0, visible: true, asset: icon } : { shape: 'box', color: 0xf4f0e6, w: 0.3, d: 0.3, height: 0.3, sortOffset: 0, visible: true };
  const prefab = { schemaVersion: CURRENT_SCHEMA_VERSION, name: 'EraserBomb', root: { name: 'Eraser Crumbs', tags: ['eraser-bomb'], components: { sprite }, children: [] } };
  mkdirSync(join(OUT, 'assets/prefabs'), { recursive: true });
  writeFileSync(join(OUT, 'assets/prefabs/EraserBomb.prefab.json'), JSON.stringify(prefab, null, 2) + '\n');
}
let forgeAnvil: { x: number; y: number; h: number } | null = null;

/** A plain flat picture: a diamond on the floor (a pool) or a round blot (a word in flight). */
function flatArt(name: string, rgb: [number, number, number], w: number, h: number, flat = name === 'pool', alpha = flat ? 200 : 255, edgeRgb: [number, number, number] = [40, 8, 10]): string {
  const px = new Uint8Array(w * h * 4);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const nx = (x + 0.5) / w - 0.5, ny = (y + 0.5) / h - 0.5;
    const inside = flat ? Math.abs(nx) + Math.abs(ny) < 0.5 : nx * nx + ny * ny < 0.25;
    const edge = flat ? Math.abs(nx) + Math.abs(ny) > 0.46 : nx * nx + ny * ny > 0.18;
    if (!inside) continue;
    const o = (y * w + x) * 4;
    const c = edge ? edgeRgb : rgb;
    px[o] = c[0]; px[o + 1] = c[1]; px[o + 2] = c[2]; px[o + 3] = alpha;
  }
  const { sprite } = importPng(encodePng(w, h, px), `fx_${name}`, w, h);
  sprite.origin = { x: Math.round(w / 2), y: flat ? Math.round(h / 2) : h };
  writeFileSync(join(spriteDir, `fx_${name}.sprite.json`), stringifySprite(sprite));
  return `fx_${name}`;
}

/** The First Sword's picture: the sword item's icon, if there is one. */
function forgeSwordArt(): string {
  if (OBJECTS && existsSync(join(OBJECTS, 'first_sword.png'))) {
    const feet = JSON.parse(readFileSync(join(OBJECTS, 'objects.json'), 'utf8')) as Record<string, [number, number]>;
    return spriteFor(join(OBJECTS, 'first_sword.png'), 'obj_first_sword', feet.first_sword);
  }
  return '';
}

let world: World | null = null;
const sideCache: Partial<Record<'weighing' | 'proof', SideMap>> = {};
function loadWorld(): World | null {
  if (!DATA) return null;
  const read = (k: string) => JSON.parse(readFileSync(join(DATA, `${k}.json`), 'utf8'));
  const cat = read('catalog').constants.ITEMS;
  mkdirSync(join(OUT, 'assets/dialogues'), { recursive: true });
  return {
    story: read('story'),
    map: read('prologue_map').constants,
    rolls: read('chest_rolls'),
    items: { ...cat, ...read('items').constants.ITEMS },
    keyed,
    write: (name, data) => writeFileSync(join(OUT, `assets/dialogues/${name}.dialogue.json`), JSON.stringify(data, null, 2) + '\n'),
    attach,
  };
}

/** The Storytender's abilities (player.gd): ink, the quill, the dash, the lantern, echoes, and the script for the rest. */
/** Where the Storytender is, for the region name in the corner: the Prologue's region map, or the name of a memory. */
function placeSettings(scene: string): { regions: string; regionNames: string; place: string } {
  if (scene !== 'overworld' || !DATA) return { regions: '', regionNames: '', place: SCENES[scene]!.name };
  const c = (JSON.parse(readFileSync(join(DATA, 'prologue_map.json'), 'utf8')) as { constants: { REGION_ROWS: string[]; REGIONS: Record<string, string> } }).constants;
  return { regions: c.REGION_ROWS.join('|'), regionNames: JSON.stringify(c.REGIONS), place: '' };
}

/** What the map screen names: each region (a spot inside it, nearest its middle), every lantern post and the memory doors. */
function mapNames(): MapNames {
  const none: MapNames = { regions: [], posts: [], doors: [] };
  if (!DATA || !existsSync(join(DATA, 'prologue_map.json'))) return none;
  return mapNamesFrom((JSON.parse(readFileSync(join(DATA, 'prologue_map.json'), 'utf8')) as { constants: MapConstants }).constants);
}

/** The music and the sound of her steps in each place. */
const PLACE_AUDIO: Record<string, [string, string]> = {
  overworld: ['music_overworld', 'step_grass'],
  forge: ['music_forge', 'step_stone'],
  pip: ['music_pip', 'step_wood'],
  maud: ['music_maud', 'step_wood'],
  scissor: ['music_scissor', 'step_wood'],
  proof: ['music_forge', 'step_stone'],
  weighing: ['music_forge', 'step_stone'],
};

/** What each binding and amulet does (item_catalog.gd fx), for Storytender.script.ts. */
function equipFxJson(): string {
  if (!DATA) return '';
  const read = (k: string) => JSON.parse(readFileSync(join(DATA, `${k}.json`), 'utf8'));
  const all = { ...read('catalog').constants.ITEMS, ...read('items').constants.ITEMS } as Record<string, { type?: string; fx?: Record<string, number> }>;
  const out: Record<string, Record<string, number>> = {};
  for (const [id, d] of Object.entries(all)) if ((d.type === 'binding' || d.type === 'amulet') && d.fx) out[id] = d.fx;
  return JSON.stringify(out);
}

function storytenderKit(p: EntityData, scene: string): void {
  const c = p.components;
  Object.assign(c.playerController as object, { speed: 4.2, runMultiplier: 1, jumpSpeed: 0 });
  attach(c, 'health', { max: 100, invulnerableSeconds: 0.9, onDeath: 'respawn', fallDamage: 15, team: 'player', showBar: false });
  // reach 74 px of ground (2.1 cells), a swing of +-1.2 rad, 0.3 s between strikes (the combo's finisher is not ported yet)
  attach(c, 'meleeAttack', { damage: 1.1, range: 2.1, arc: 137, windup: 0.04, active: 0.14, cooldown: 0.3, knockback: 4.7, hurts: 'enemies', hitStop: 0.05, shake: 2, showSwing: false }); // the strike pose is the swing: no pale diamond on the ground
  attach(c, 'dodge', { speed: 14.5, seconds: 0.2, cooldown: 0.75, invulnerable: true });
  attach(c, 'light', { radius: 1.2, intensity: 0.35, color: 'cool', shadows: true, flicker: 0.15, mode: 'always' });
  attach(c, 'echoRecorder', { seconds: 9, capacity: 0, capacityVariable: '', ending: 'hold', ghostAlpha: 0.55 });
  attach(c, 'script_Director', { music: PLACE_AUDIO[scene]?.[0] ?? 'music_overworld', step: PLACE_AUDIO[scene]?.[1] ?? 'step_grass' });
  // Garrick's memory lets her keep two echoes at once (its puzzles are easy; harder ones come later)
  attach(c, 'script_Storytender', { speed: 4.2, lanternRadius: 4.9, echoesHere: scene === 'forge' ? 2 : 0, equipFx: equipFxJson(), ...placeSettings(scene) });
  if (scene === 'proof') (c.script_Storytender as { lanternRadius: number }).lanternRadius = 4.9 * 1.7; // side_proof.gd: lantern_power 1.7 in the dark
}

function buildScene(scene: string, snap: Snap, art: ArtEntry[]): SceneData {
  const map = buildMap(scene, snap);
  const blocked = new Set(snap.floor.blockers.map(([x, y]) => `${x},${y}`));
  const taken = new Set<string>();
  const levelOf = (x: number, y: number): number => snap.floor.heights[`${x},${y}`] ?? 0;
  const entities: EntityData[] = [];
  const sceneArt = art.filter((a) => a.scene === scene);
  const byNode = new Map(sceneArt.map((a) => [a.node, a]));
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
        // idle and walk, and the strike while the quill swings (the combat plugin's "attacking")
        const controller = locomotionController({ idle: 'idle', walk: 'walk' });
        controller.states.strike = { clip: 'strike' };
        controller.transitions.unshift(
          { from: '*', to: 'strike', when: [{ param: 'attacking', op: '==', value: true }] },
          { from: 'strike', to: 'idle', when: [{ param: 'attacking', op: '==', value: false }], waitForEnd: true },
        );
        p.components.animator = makeAnimator({ asset: anim, clip: 'idle', controller });
      } else if (a?.file) (p.components.sprite as Record<string, unknown>).asset = spriteFor(join(ART, a.file), 'storytender', a.feet);
      attachBehavior(p.components, 'followCamera');
      Object.assign(p.components.followCamera as object, { zoom: 1.5 }); // LevelBase.ZOOM
      storytenderKit(p, scene);
      player = p;
      entities.push(p);
      continue;
    }
    if (['IsoFloor', 'GroundChunks', 'AmbientDrift', 'PasteGhost'].includes(n.class)) continue;
    // the capture and the snapshot are separate runs of the game, and names repeat between them: match a picture by kind of
  // object and place, and by name only when that finds nothing
    const named = byNode.get(n.name);
    const art0 = sceneArt.find((a) => a.cls === n.class && Math.abs(a.grid[0] - n.grid[0]) < 0.6 && Math.abs(a.grid[1] - n.grid[1]) < 0.6) ?? (named && named.cls === n.class ? named : undefined);
    const e = entityFor(scene, n, art0, `e${i++}`, levelOf);
    if (!e) continue;
    if (scene === 'forge' && world) {
      const rows = (forgeRowsCache ??= forgeRows(join(HERE, '..', '..')));
      const gx = Math.round(n.grid[0]);
      const gy = Math.round(n.grid[1]);
      decorateForge(e, n.class, Number(n.props.kind ?? -1), rows[gy]?.[gx] ?? '', (n.props.axis as number[]) ?? [0, 1], world);
      // the forge's stone blocks (memory_forge.gd "B"): slate, about a level tall
      if (n.class === 'IsoBlock') Object.assign(e.components.sprite as object, { color: 0x56627a, w: 1, d: 1, height: 1.05 });
      if (n.class === 'Prop' && Number(n.props.kind) === 7) forgeAnvil = { x: gx + 0.5, y: gy + 0.5, h: levelOf(gx, gy) };
    }
    if (scene === 'pip' && world) {
      const m = (pipMapCache ??= pipMap(join(HERE, '..', '..')));
      const gx = Math.round(n.grid[0]);
      const gy = Math.round(n.grid[1]);
      decoratePip(e, n.class, Number(n.props.kind ?? -1), m.rows[gy]?.[gx] ?? '', [gx, gy], world, n.props);
    }
    if (scene === 'scissor' && world) decorateScissor(e, n.class, Number(n.props.kind ?? -1), world);
    if ((scene === 'weighing' || scene === 'proof') && world) {
      const m = (sideCache[scene] ??= sideMap(join(HERE, '..', '..'), scene));
      const gx = Math.round(n.grid[0]);
      const gy = Math.round(n.grid[1]);
      decorateSide(e, scene, n.class, Number(n.props.kind ?? -1), m.rows[gy]?.[gx] ?? '', [gx, gy], world);
    }
    if (scene === 'maud' && world) {
      const m = (maudMapCache ??= maudMap(join(HERE, '..', '..')));
      const gx = Math.round(n.grid[0]);
      const gy = Math.round(n.grid[1]);
      decorateMaud(e, n.class, Number(n.props.kind ?? -1), m.rows[gy]?.[gx] ?? '', [gx, gy], n.props, m, world);
    }
    if (scene === 'forge' && n.class === 'Prop' && Number(n.props.kind) === 9 && !figureArt) figureArt = String((e.components.sprite as { asset?: string }).asset ?? '');
    if (n.class === 'EchoPlate' && e.components.script_Plate && OBJECTS && existsSync(join(OBJECTS, 'echo_plate_dim.png'))) {
      const feet = JSON.parse(readFileSync(join(OBJECTS, 'objects.json'), 'utf8')) as Record<string, [number, number]>;
      const off = spriteFor(join(OBJECTS, 'echo_plate_dim.png'), 'obj_echo_plate_dim', feet.echo_plate_dim);
      const on = spriteFor(join(OBJECTS, 'echo_plate_lit.png'), 'obj_echo_plate_lit', feet.echo_plate_lit);
      Object.assign(e.components.sprite as object, { asset: off, height: 0.3, sortOffset: -0.4 });
      Object.assign(e.components.script_Plate as object, { lookOn: on, lookOff: off });
    }
    // Maud's kitchen plate: up until something heavy settles on it (the cold door opens), then pressed down
    if (n.class === 'PressurePlate' && OBJECTS && existsSync(join(OBJECTS, 'plate_up.png'))) {
      const feet = JSON.parse(readFileSync(join(OBJECTS, 'objects.json'), 'utf8')) as Record<string, [number, number]>;
      const up = spriteFor(join(OBJECTS, 'plate_up.png'), 'obj_plate_up', feet.plate_up);
      const down = spriteFor(join(OBJECTS, 'plate_down.png'), 'obj_plate_down', feet.plate_down);
      Object.assign(e.components.sprite as object, { asset: up, height: 0.3, sortOffset: -0.4 });
      attach(e.components, 'script_Flagged', { hideWhen: '', showWhen: '', lookWhen: 'cold_gate', look: down });
    }
    // a sentence stone: a blank board, and the engine writes the live sentence over it
    if (e.components.sentenceStone && OBJECTS && existsSync(join(OBJECTS, 'sign_wide.png'))) {
      const feet = JSON.parse(readFileSync(join(OBJECTS, 'objects.json'), 'utf8')) as Record<string, [number, number]>;
      Object.assign(e.components.sprite as object, { asset: spriteFor(join(OBJECTS, 'sign_wide.png'), 'obj_sign_wide', feet.sign_wide), height: 1.6 });
      attach(e.components, 'script_StoneLabel', {});
    }
    // a Mnemosynth crystal in a memory: walked into
    if (scene !== 'overworld' && n.class === 'Prop' && Number(n.props.kind) === 3) attach(e.components, 'script_Collect', { flag: `got_${scene}_C_${Math.round(n.grid[0])}_${Math.round(n.grid[1])}`, mnemo: 5, light: 12, radius: 1.2 });
    if (n.class === 'Enemy') {
      if (scene === 'overworld') continue; // the Prologue's Errors come from its map letters (below)
      errorKit(e, Number(n.props.kind ?? 0), '');
      if (scene === 'pip') {
        const gx = n.grid[0], gy = n.grid[1];
        const sleepWhen = gy >= 20 && gx <= 29 ? 'sleep_wood' : gx >= 45 ? 'sleep_archive' : '';
        if (sleepWhen) Object.assign(e.components.script_Error as object, { sleepWhen });
      }
    }
    if (world && scene === 'overworld') decorateOverworld(e, n, [Math.round(n.grid[0]), Math.round(n.grid[1])], world);
    if (n.class === 'Npc') dressPerson(e);
    if (n.class === 'Critic' || n.class === 'Spoiler' || n.class === 'ScissorMan') dressBoss(e, n.class);
    // a doorway or exit is tall and stands in the middle of a cell: it is drawn behind whoever stands beside or just behind it (V-06)
    if (n.class === 'Prop' && Number(n.props.kind) === 8) (e.components.sprite as { sortOffset: number }).sortOffset = -1.2;
    if (n.class === 'Prop' && scene === 'overworld') dressObject(e, Number(n.props.kind ?? -1), [Math.round(n.grid[0]), Math.round(n.grid[1])], SCENES[scene]!.file);
    const cell = `${Math.round(n.grid[0])},${Math.round(n.grid[1])}`;
    if (blocked.has(cell) && !taken.has(cell)) {
      taken.add(cell);
      e.components.collider = { w: 0.9, d: 0.9, height: Math.max(1, (e.components.sprite as { height: number }).height), solid: true, trigger: false, layer: 16, mask: 65535, enabled: true, inside: [] };
    }
    entities.push(e);
  }
  if (scene === 'overworld') entities.push(...prologueErrors(levelOf, () => `e${i++}`));
  if ((scene === 'weighing' || scene === 'proof') && world) {
    const m = (sideCache[scene] ??= sideMap(join(HERE, '..', '..'), scene));
    entities.push(...sideExtras(scene, m, levelOf, { hole: flatArt('hole', [22, 18, 30], 64, 32, true, 255, [10, 8, 14]), plank: flatArt('plank', [150, 104, 60], 64, 32, true, 255, [70, 44, 24]) }, () => `e${i++}`));
  }
  if (scene === 'scissor' && world) {
    // the cells of the arena, each with a cover; the clippings she can strike; the little copies he wakes
    const hole = flatArt('hole', [22, 18, 30], 64, 32, true, 255, [10, 8, 14]);
    const looks = { hole, warn: flatArt('warn', [214, 90, 60], 192, 96, true, 150, [120, 30, 20]), patch: flatArt('patch', [244, 238, 220], 64, 32, true, 255, [120, 100, 70]), ghost: flatArt('ghost', [120, 210, 200], 64, 32, true, 170, [30, 110, 110]) };
    const mkMinion = (kind: number, x: number, y: number, unlock: string): EntityData => {
      const asset = errorArt.get(kind);
      const e: EntityData = { id: `e${i++}`, name: `Error ${['Bare', 'Mite'][kind]}`, tags: [], components: { transform: { x: x + 0.5, y: y + 0.5, h: levelOf(x, y), facing: 2 }, sprite: { shape: 'box', color: 0xcccccc, w: 0.6, d: 0.6, height: 1, sortOffset: 0, visible: true, ...(asset ? { asset } : {}) } } };
      errorKit(e, kind, unlock);
      return e;
    };
    const arena = Object.keys(snap.floor.cells).map((k) => k.split(',').map(Number) as [number, number]);
    entities.push(...scissorExtras(arena, levelOf, { hole }, mkMinion, () => `e${i++}`));
    const boss = entities.find((x) => x.tags.includes('scissor'));
    if (boss) Object.assign(boss.components.script_Scissor as object, { lookHole: looks.hole, lookWarn: looks.warn, lookPatch: looks.patch, lookGhost: looks.ghost });
    // the clippings she strikes come back as a prefab whenever he cuts
    const clip = entities.find((x) => x.tags.includes('clipping'));
    if (clip) {
      const piece = { name: 'Clipping', tags: ['clipping', 'spawned'], components: { sprite: clip.components.sprite, health: clip.components.health }, children: [] };
      mkdirSync(join(OUT, 'assets/prefabs'), { recursive: true });
      writeFileSync(join(OUT, 'assets/prefabs/ClippingPiece.prefab.json'), JSON.stringify({ schemaVersion: CURRENT_SCHEMA_VERSION, name: 'ClippingPiece', root: piece }, null, 2) + '\n');
    }
  }
  if (scene === 'overworld' && world) {
    // the tear in the square (Rift.script.ts): hidden until Garrick, Pip and Maud are restored
    const portal = entities.find((x) => x.tags.includes('prop-8'));
    const asset = (portal?.components.sprite as { asset?: string } | undefined)?.asset;
    entities.push({
      id: `e${i++}`,
      name: 'Rift',
      tags: ['rift'],
      components: {
        transform: { x: 88.5, y: 53.5, h: levelOf(88, 53), facing: 2 },
        sprite: { shape: 'box', color: 0xf6f3ea, w: 0.8, d: 0.8, height: 3, sortOffset: 0, visible: false, ...(asset ? { asset } : {}) },
        collider: { w: 0.9, d: 0.9, height: 2, solid: true, trigger: false, layer: 16, mask: 65535, enabled: false, inside: [] },
        npcTalk: { dialogue: 'rift_enter', reach: 0.01, facePlayer: false, once: false, hint: true },
        script_Gateway: { flag: 'go_scissor', scene: 'scenes/scissor.scene.json', spawn: '' },
        script_Rift: { reach: 110 / 35.8 + 0.4 },
      },
    });
  }
  if (scene === 'overworld' && world) {
    // the puzzle sites (sites.ts): a controller each, the covers of a bridge, the cracks of a causeway, the waves of an arena
    const looks = { hole: flatArt('hole', [22, 18, 30], 64, 32, true, 255, [10, 8, 14]), plank: flatArt('plank', [150, 104, 60], 64, 32, true, 255, [70, 44, 24]), crack: flatArt('crack', [70, 56, 44], 64, 32, true, 230, [26, 20, 14]) };
    const mkError = (kind: number, x: number, y: number, unlock: string): EntityData => {
      const asset = errorArt.get(kind);
      const e: EntityData = { id: `e${i++}`, name: `Error ${['Bare', 'Mite', 'Run-on', 'Dangler', 'Censor', 'Ellipsis'][kind]}`, tags: [], components: { transform: { x: x + 0.5, y: y + 0.5, h: levelOf(x, y), facing: 2 }, sprite: { shape: 'box', color: 0xcccccc, w: 0.6, d: 0.6, height: 1, sortOffset: 0, visible: true, ...(asset ? { asset } : {}) } } };
      errorKit(e, kind, unlock);
      return e;
    };
    entities.push(...siteExtras(world.map.SITES, levelOf, looks, mkError, () => `e${i++}`));
  }
  if (scene === 'forge' && forgeAnvil) entities.push(...forgeExtras(forgeAnvil, forgeSwordArt(), () => `e${i++}`));
  if (scene === 'maud' && maudMapCache) {
    entities.push(...maudExtras(maudMapCache, levelOf, flatArt('hole', [22, 18, 30], 64, 32, true, 255, [10, 8, 14]), flatArt('plank', [150, 104, 60], 64, 32, true, 255, [70, 44, 24]), () => `e${i++}`));
    writeMaudPrefabs();
  }
  if (scene === 'pip' && pipMapCache) {
    const looks = { hole: flatArt('hole', [22, 18, 30], 64, 32, true, 255, [10, 8, 14]), plank: flatArt('plank', [150, 104, 60], 64, 32, true, 255, [70, 44, 24]), ice: flatArt('ice', [190, 228, 240], 64, 32, true, 235, [110, 160, 190]) };
    entities.push(...pipExtras(pipMapCache, levelOf, looks, () => `e${i++}`));
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

// ---------------------------------------------------------------- data: items, conversations

/** What the game's own key names stand for in its text ("{interact} to speak"): the default keys, as the game writes them. */
const KEYS: Record<string, string> = {
  move: 'WASD', interact: 'E', attack: 'J', lantern: 'Q', dash: 'Shift', sneak: 'Ctrl', inventory: 'Tab', use_item: 'F',
  quick_switch: 'G', style_underline: '1', style_bold: '2', style_italic: '3', paste: 'V', map: 'M', echo: 'R', aim: 'the mouse',
};
const keyed = (t: string): string => t.replace(/\{([a-z_]+)\}/g, (m, k: string) => (KEYS[k] ? `[${KEYS[k]}]` : m));

type Line = { who: string; text: string; style: string; cue?: string };

function dialogueOf(name: string, lines: Line[]): object {
  const nodes = lines.map((l, i) => ({
    id: `n${i + 1}`,
    type: 'line',
    speaker: l.who,
    // the game draws action lines in italics and signs as plain text with no name tab
    text: keyed(l.style === 'action' ? `[i]${l.text}[/i]` : l.text),
    ...(i + 1 < lines.length ? { next: `n${i + 2}` } : {}),
  }));
  // the end of the Scissor-Man's last words is what lets Scissor.script.ts pay out and send her home
  if (name === 'scissor_finale' && nodes.length) {
    (nodes[nodes.length - 1] as { next?: string }).next = 'nEnd';
    (nodes as object[]).push({ id: 'nEnd', type: 'set', variable: 'scissor_finale_done', op: 'set', value: 1 });
  }
  return { schemaVersion: CURRENT_SCHEMA_VERSION, name, start: 'n1', nodes: nodes.length ? nodes : [{ id: 'n1', type: 'end' }] };
}

/** The game's controls (input_setup.gd), on the engine's actions where they mean the same thing, and as the game's own actions where not. */
function writeInput(): void {
  const input = {
    schemaVersion: CURRENT_SCHEMA_VERSION,
    overrides: {
      interact: ['key:KeyE', 'key:Space', 'key:Enter', 'pad:button0'],
      jump: [], // the Storytender does not jump
      run: [], // Shift is the dash
      dodge: ['key:ShiftLeft', 'key:ShiftRight', 'pad:button1'],
      attack: ['key:KeyJ', 'mouse:0', 'pad:button2', 'pad:axis5+'],
      echo: ['key:KeyR', 'pad:button4'],
      inventory: ['key:Tab', 'key:KeyI', 'pad:button8'],
      map: ['key:KeyM', 'pad:button13'],
      quick_1: [], quick_2: [], quick_3: [], quick_4: [], // the game has two quick slots, on F and G (1 2 3 are the styles)
    },
    actions: [
      { id: 'lantern', label: 'Lantern (hold)', bindings: ['key:KeyQ', 'mouse:2', 'pad:axis4+'] },
      { id: 'sneak', label: 'Creep (hold)', bindings: ['key:ControlLeft', 'key:KeyC', 'pad:button10'] },
      { id: 'use_item', label: 'Use quick item', bindings: ['key:KeyF', 'pad:button3'] },
      { id: 'quick_switch', label: 'Switch quick item', bindings: ['key:KeyG', 'pad:button11'] },
      { id: 'style_underline', label: 'Underline style', bindings: ['key:Digit1', 'pad:button14'] },
      { id: 'style_bold', label: 'Bold style', bindings: ['key:Digit2', 'pad:button12'] },
      { id: 'style_italic', label: 'Italic style', bindings: ['key:Digit3', 'pad:button15'] },
      { id: 'paste', label: 'Paste clipping', bindings: ['key:KeyV', 'pad:button5'] },
    ],
  };
  writeFileSync(join(OUT, 'assets/input.json'), JSON.stringify(input, null, 2) + '\n');
}

function writeData(): { items: number; dialogues: number } {
  if (!DATA) return { items: 0, dialogues: 0 };
  const read = (k: string) => JSON.parse(readFileSync(join(DATA, `${k}.json`), 'utf8'));
  // ---- items: the game's item table and its catalog, in the engine's item format
  const db = read('items').constants.ITEMS as Record<string, Record<string, unknown>>;
  const cat = read('catalog').constants as { ITEMS: Record<string, Record<string, unknown>>; RARITY_COLORS: Record<string, string> };
  const all = { ...cat.ITEMS, ...db };
  const HEAL: Record<string, number> = { ink_vial: 45, warm_loaf: 60, ink_flask: 100 }; // level_base.gd use_item
  const items = Object.entries(all).map(([id, d]) => {
    const rar = String(d.rarity ?? 'common');
    const col = (cat.RARITY_COLORS[rar] ?? '#ccccccff').slice(1, 7);
    const desc = [d.desc, d.flavor].filter((x) => typeof x === 'string' && x).join('\n');
    // every usable item sets use_<id>; Storytender.script.ts does the rest (ink, lantern, sleep, renown, Mnemosynth, the thrown crumbs) and
    // takes the item itself, so an item that would do nothing right now is not used up (level_base.gd use_item)
    // a binding or an amulet is worn by using it (the binder sets worn_binding / worn_amulet; Storytender.script.ts adds what it does)
    const slot = d.type === 'binding' ? 'binding' : d.type === 'amulet' ? 'amulet' : '';
    const use = slot
      ? { heal: 0, setVariable: `worn_${slot}`, setValue: id, consume: false, message: `${String(d.name ?? id)} is worn` }
      : d.type === 'consumable' || d.use || HEAL[id]
      ? { heal: 0, setVariable: `use_${id}`, setValue: 1, consume: false, message: '' }
      : undefined;
    return { id, name: String(d.name ?? id), description: desc, color: parseInt(col, 16), max: 0, ...(use ? { use } : {}) };
  });
  writeFileSync(join(OUT, 'assets/items.json'), JSON.stringify({ schemaVersion: CURRENT_SCHEMA_VERSION, items }, null, 2) + '\n');
  // item pictures, named icon_<id>, for the binder and the quick slots
  if (ICONS) for (const id of Object.keys(all)) {
    const f = join(ICONS, `icon_${id}.png`);
    if (existsSync(f)) spriteFor(f, safe(`icon_${id}`));
  }
  // ---- conversations: every scripted conversation of Story (story.gd), one dialogue each
  const story = read('story') as { functions: Record<string, Line[] | Record<string, Line[]>> };
  mkdirSync(join(OUT, 'assets/dialogues'), { recursive: true });
  let n = 0;
  for (const [fn, v] of Object.entries(story.functions)) {
    const sets: [string, Line[]][] = Array.isArray(v) ? [[fn, v]] : Object.entries(v).filter(([, l]) => Array.isArray(l) && l.length > 0).map(([i, l]) => [`${fn}_${i}`, l as Line[]]);
    for (const [name, lines] of sets) {
      writeFileSync(join(OUT, `assets/dialogues/${name}.dialogue.json`), JSON.stringify(dialogueOf(name, lines), null, 2) + '\n');
      n++;
    }
  }
  return { items: items.length, dialogues: n };
}

// ---------------------------------------------------------------- main

function main(): void {
  if (existsSync(join(OUT, 'assets/sprites'))) rmSync(join(OUT, 'assets/sprites'), { recursive: true });
  mkdirSync(spriteDir, { recursive: true });
  mkdirSync(join(OUT, 'scenes'), { recursive: true });
  mkdirSync(join(OUT, 'assets'), { recursive: true });
  const snaps: Record<string, Snap> = {};
  for (const k of Object.keys(SCENES)) snaps[k] = JSON.parse(readFileSync(join(SNAP, `${k}.json`), 'utf8'));
  const art: ArtEntry[] = JSON.parse(readFileSync(join(ART, 'index.json'), 'utf8'));
  const tiles: TileEntry[] = JSON.parse(readFileSync(join(TILES, 'index.json'), 'utf8'));
  buildKinds(tiles, snaps);
  addPaper();
  world = loadWorld();
  if (world) {
    writeOverworldTalk(world);
    writeForgeTalk(world);
    writePipTalk(world);
    writeScissorTalk(world);
    writeCutscenes(OUT, CURRENT_SCHEMA_VERSION, world);
    writeSideTalk(world);
    writeMaudTalk(world);
  }
  writeForgePrefabs(OUT, CURRENT_SCHEMA_VERSION, flatArt('pool', [138, 20, 20], 192, 96), flatArt('bolt', [70, 12, 16], 18, 18));
  writePipPrefabs();
  writeItemPrefabs();
  writeMinigames();
  if (existsSync(join(HERE, 'scripts'))) {
    mkdirSync(join(OUT, 'assets/scripts'), { recursive: true });
    for (const f of readdirSync(join(HERE, 'scripts'))) writeFileSync(join(OUT, 'assets/scripts', f), readFileSync(join(HERE, 'scripts', f)));
  }
  if (DATA) mobDrops = (JSON.parse(readFileSync(join(DATA, 'drops.json'), 'utf8')) as { constants: { MOBS: typeof mobDrops } }).constants.MOBS;
  const scenes: string[] = [];
  const order = [...Object.keys(SCENES).filter((k) => k !== 'overworld'), 'overworld'];
  for (const k of order) {
    const scene = buildScene(k, snaps[k]!, art);
    if (k === 'overworld') writeCrystalPrefab(scene);
    writeFileSync(join(OUT, SCENES[k]!.file), JSON.stringify(scene) + '\n');
    scenes.push(SCENES[k]!.file);
    console.log(`scene ${k}: ${scene.entities.length} objects, map ${scene.map.width} x ${scene.map.height}`);
  }
  writeInput();
  const data = writeData();
  // the game's own HUD, title, pause, binder and map screens (the quick slots show the items that can be used)
  const itemList = (JSON.parse(readFileSync(join(OUT, 'assets/items.json'), 'utf8')) as { items: ItemRow[] }).items;
  const usableItems = itemList.filter((it) => it.use && !wornBy(it)).map((it) => it.id);
  const equipment = equipmentOf(itemList);
  const itemIds = readdirSync(spriteDir).filter((f) => f.startsWith('icon_')).map((f) => f.slice(5).replace('.sprite.json', ''));
  writeFileSync(join(OUT, 'assets/screens.json'), JSON.stringify(buildScreens(itemIds, CURRENT_SCHEMA_VERSION, paperTile, usableItems, mapNames(), equipment), null, 2) + '\n');
  // the engine's own menus (settings, controls, saves, the conversation box) in the game's colours: parchment, ink and gold
  writeFileSync(join(OUT, 'assets/ui.json'), JSON.stringify(uiTheme(CURRENT_SCHEMA_VERSION), null, 2) + '\n');
  console.log(`items ${data.items}, dialogues ${data.dialogues}`);
  const project = baseProject('The Last Storytender', PLUGINS);
  project.iso = { tileW: 64, tileH: 32, heightPx: LEVEL_PX };
  project.tileset = tileset;
  project.scenes = Object.keys(SCENES).map((k) => SCENES[k]!.file); // (built with the overworld last, listed in the usual order)
  project.startScene = SCENES.overworld!.file;
  project.title = { enabled: true, subtitle: 'The world is not ending; it is being edited.' };
  (project as ProjectData & { compat?: Record<string, boolean> }).compat = currentFlags();
  writeFileSync(join(OUT, 'project.json'), JSON.stringify(project, null, 2) + '\n');
  writeFileSync(join(OUT, '.gdignore'), '');
  console.log(`tiles ${tileset.length}, sprites ${readdirSync(spriteDir).length}`);
}

main();
