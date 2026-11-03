/**
 * Port tool: Garrick's memory, The Blacksmith's Regret (memory_forge.gd). Echo plates hold FORGOTTEN gates open; three
 * of Garrick's tools open the forge door; the lantern lifts the black bar over the tongs; the figures can be looked at; in
 * the forge hall the Critic waits, and three memory shards strip its layers. Beaten, the First Sword lies on the anvil.
 */
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import type { EntityData } from '@tilewright/runtime';
import { Talk, type World } from './overworld';

type Line = { who: string; text: string; style: string };
const line = (text: string, style = 'action', who = ''): Line => ({ who, text, style });

/** Gate letter -> the plates (letters) that hold it open (memory_forge.gd ROOM_GATES). */
const ROOM_GATES: Record<string, string[]> = { g: ['a'], h: ['b', 'c'], i: ['d'], l: ['e'], n: ['j'] };
const TOKENS: Record<string, string> = { T: 'hammer', U: 'tongs', V: 'bellows' };
const FIGURES: Record<string, number> = { f: 0, y: 1, z: 2 };
/** Where the Storytender steps back out into the Prologue (main.gd RETURN_CELL), in the overworld's cells. */
export const FORGE_RETURN = '94.5,56.5';

export function forgeRows(repo: string): string[] {
  const s = readFileSync(join(repo, 'data/memory_forge_map.gd'), 'utf8');
  const body = /const ROWS[^=]*=\s*\[([\s\S]*?)\]/.exec(s)![1]!;
  return [...body.matchAll(/"([^"]*)"/g)].map((m) => m[1]!);
}

const COLLIDER = (w: number, d: number, height: number): object => ({ w, d, height, solid: true, trigger: false, layer: 16, mask: 65535, enabled: true, inside: [] });

/** The forge's conversations, written once. */
export function writeForgeTalk(w: World): void {
  const fn = (name: string): Line[] => (w.story.functions[name] as Line[]) ?? [];
  const at = (name: string, i: number): Line[] => ((w.story.functions[name] as Record<string, Line[]>)?.[String(i)] ?? []);
  const k = (s: string): string => String(w.story.constants[s] ?? '');
  const simple = (name: string, lines: Line[], ...sets: [string, number][]): void => {
    const t = new Talk(name);
    const steps = [...(lines.length ? [t.lines(lines, w.keyed)] : []), ...sets.map(([v, n]) => t.set(v, n))];
    w.write(name, t.data(t.seq(...steps)[0]));
  };
  simple('critic_intro', fn('boss_intro'), ['critic_awake', 1]);
  simple('critic_reckon', fn('critic_reckoning'), ['critic_reckoning', 1]);
  simple('critic_end', [...fn('critic_finale'), line('On the anvil, something small is waiting.')], ['critic_down', 1]);
  for (const i of [1, 2, 3]) {
    const t = new Talk(`shard_${i}`);
    const hold = t.seq(t.lines(at('shard_memory', i), w.keyed), t.set(`shard_${i}`, 1), t.lines([line(((w.story.constants.MEMORY_SHARD_NARRATION as string[]) ?? [])[i - 1] ?? '')], w.keyed));
    const start = t.when({ name: 'critic_awake' }, t.when({ name: `shard_${i}` }, t.end(), hold), t.lines([line('A splinter of something remembered. It is not time yet.')], w.keyed));
    w.write(t.name, t.data(start[0]));
  }
  for (const [n, kind] of Object.values(TOKENS).entries()) {
    const t = new Talk(`take_${kind}`);
    const narr = ((w.story.constants.FORGE_TOKEN_NARRATION as string[]) ?? [])[n] ?? '';
    const take = t.seq(t.set(`tok_${kind}`, 1), t.set('forge_tokens', 1, 'add'), t.lines([line(`Found: Garrick's ${kind}`, 'sign'), ...(narr ? [line(narr)] : [])], w.keyed));
    w.write(t.name, t.data(t.when({ name: `tok_${kind}` }, t.end(), take)[0]));
  }
  {
    const t = new Talk('take_sword');
    const take = t.seq(t.lines(fn('memory_sword'), w.keyed), t.set('has_sword', 1), t.set('memory_done', 1), t.lines([line('Found: The First Sword', 'sign'), line(k('MEMORY_SWORD_NARRATION'))], w.keyed), t.set('leave_forge', 1));
    w.write(t.name, t.data(t.when({ name: 'has_sword' }, t.end(), take)[0]));
  }
  simple('leave_forge', [line('You let go of the memory, and the Prologue comes back.')], ['leave_forge', 1]);
  simple('forge_enter', [line(k('MEMORY_INTRO')), ...fn('echo_grant')], ['echo_granted', 1]);
}

/** What one object of the forge does. `letter` is the map's letter under it. */
export function decorateForge(e: EntityData, cls: string, kind: number, letter: string, axis: number[], w: World): void {
  const c = e.components;
  const talk = (dialogue: string, reach = 2.2): void => w.attach(c, 'npcTalk', { dialogue, reach, facePlayer: false, once: false, hint: true });
  if (cls === 'EchoPlate') {
    w.attach(c, 'script_Plate', { flag: `plate_${letter}`, radius: 0.85 });
    e.tags.push('plate');
    return;
  }
  if (cls === 'StoryGate') {
    const along = Number(axis[1] ?? 1); // the gate spans y (1) or x (0)
    if (letter === 'D') {
      w.attach(c, 'script_StoryGate', { needs: 'forge_tokens>=3', closeFar: 0, said: String(w.story.constants.FORGE_DOOR_NARRATION ?? '') });
      c.collider = COLLIDER(0.7, 5, 2);
    } else {
      const needs = (ROOM_GATES[letter] ?? []).map((p) => `plate_${p}`).join('+') || 'never';
      w.attach(c, 'script_StoryGate', { needs, closeFar: 2.5, said: String(w.story.constants.FORGE_GATE_OPEN ?? '') });
      c.collider = along ? COLLIDER(0.7, 3, 2) : COLLIDER(3, 0.7, 2);
    }
    e.tags.push('gate');
    return;
  }
  if (cls === 'DungeonKey') {
    const kindName = TOKENS[letter] ?? 'hammer';
    talk(`take_${kindName}`, 1.6);
    w.attach(c, 'script_Flagged', { hideWhen: `tok_${kindName}`, showWhen: '', lookWhen: '', look: '' });
    e.tags.push('token');
    return;
  }
  if (cls === 'Redactor') {
    w.attach(c, 'script_Redactor', { flag: 'forge_bar', said: "The black bar lifts. Underneath, in a master's hand: 'Check the bench.'" });
    c.collider = COLLIDER(3, 0.7, 2);
    e.tags.push('redactor');
    return;
  }
  if (cls === 'Critic') {
    e.tags.push('boss', 'critic', 'enemy');
    w.attach(c, 'health', { max: 110, invulnerableSeconds: 0.25, onDeath: 'stay', fallDamage: 0, team: 'enemy', showBar: false });
    c.body = { vx: 0, vy: 0, vz: 0, radius: 0.5, height: 2, state: 'ground', stepUp: 0.35, stepDown: 0.4, ledge: 'stop', pits: 'stop', wade: false, gravity: 1, peakZ: 0, layer: 4, mask: 65535, noclip: true, blockedBy: [], blockedTerrain: false };
    w.attach(c, 'script_Critic', { arenaX: 42 });
    return;
  }
  if (cls !== 'Prop') return;
  if (kind === 8) {
    talk('leave_forge', 2.2);
    w.attach(c, 'script_Gateway', { flag: 'leave_forge', scene: 'scenes/overworld.scene.json', spawn: FORGE_RETURN });
  } else if (kind === 9 && letter in FIGURES) talk(`forge_look_${FIGURES[letter]}`, 2.2);
  else if (kind === 6 && '123'.includes(letter)) {
    talk(`shard_${letter}`, 2.2);
    w.attach(c, 'script_Flagged', { hideWhen: `shard_${letter}`, showWhen: '', lookWhen: '', look: '' });
    e.tags.push('shard');
  }
}

/** Things the forge adds: the First Sword on the anvil (after the Critic), and what greets the Storytender as she arrives. */
export function forgeExtras(anvil: { x: number; y: number; h: number }, swordArt: string, next: () => string): EntityData[] {
  const sword: EntityData = {
    id: next(),
    name: 'The First Sword',
    tags: ['sword'],
    components: {
      transform: { x: anvil.x, y: anvil.y + 0.05, h: anvil.h + 0.9, facing: 2 },
      sprite: { shape: 'box', color: 0xc8ccd6, w: 0.3, d: 0.3, height: 0.4, sortOffset: 0.2, visible: false, ...(swordArt ? { asset: swordArt } : {}) },
      npcTalk: { dialogue: 'take_sword', reach: 2.4, facePlayer: false, once: false, hint: true },
      script_Flagged: { hideWhen: 'has_sword', showWhen: 'critic_down', lookWhen: '', look: '' },
      script_Gateway: { flag: 'leave_forge', scene: 'scenes/overworld.scene.json', spawn: FORGE_RETURN },
    },
  };
  const greeter: EntityData = {
    id: next(),
    name: 'Memory start',
    tags: ['controller'],
    components: { transform: { x: 1, y: 1, h: 0, facing: 2 }, script_OnEnter: { dialogue: 'forge_enter', flag: 'echo_granted' } },
  };
  return [sword, greeter];
}

/** The Critic's thrown word, and its pools of red ink, as prefabs it spawns. */
export function writeForgePrefabs(out: string, schemaVersion: number, poolArt: string, boltArt: string): void {
  mkdirSync(join(out, 'assets/prefabs'), { recursive: true });
  const bolt = {
    schemaVersion,
    name: 'WordBolt',
    root: { name: 'Word', tags: ['bolt'], components: { sprite: { shape: 'box', color: 0x7a1010, w: 0.25, d: 0.25, height: 0.25, sortOffset: 0, visible: true, ...(boltArt ? { asset: boltArt } : {}) }, projectile: { speed: 5.3, lifetime: 3.5, useFacing: false, dirX: 1, dirY: 0, damage: 9, hurts: 'player', knockback: 4 } }, children: [] },
  };
  const pool = {
    schemaVersion,
    name: 'InkPool',
    root: { name: 'Red ink', tags: ['pool'], components: { sprite: { shape: 'box', color: 0x8a1414, w: 3, d: 3, height: 0.02, sortOffset: -1, visible: true, ...(poolArt ? { asset: poolArt } : {}) }, script_InkPool: {} }, children: [] },
  };
  writeFileSync(join(out, 'assets/prefabs/WordBolt.prefab.json'), JSON.stringify(bolt, null, 2) + '\n');
  writeFileSync(join(out, 'assets/prefabs/InkPool.prefab.json'), JSON.stringify(pool, null, 2) + '\n');
}
