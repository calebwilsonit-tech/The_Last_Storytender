/**
 * Port tool: Pip's memory, The Unfinished Library (memory_pip.gd). Sentence stones rewrite the world: the bridge HOLDS, the
 * wolves and guards fall ASLEEP for 18 s, the gate is OPEN, the river FROZEN for 12 s, the floor SOLID for 10 s, the stairs
 * PRESENT, the Archive door OPEN. Echo plates hold FORGOTTEN gates; the lantern lifts black bars; three Torn Pages fit THE END
 * door; behind it the Spoiler reads disasters aloud and a strike rewrites them. Beaten, Pip turns the page.
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import type { EntityData } from '@tilewright/runtime';
import { Talk, type World } from './overworld';

type Line = { who: string; text: string; style: string };
const line = (text: string, style = 'action', who = ''): Line => ({ who, text, style });
const COLLIDER = (w: number, d: number, height: number): object => ({ w, d, height, solid: true, trigger: false, layer: 16, mask: 65535, enabled: true, inside: [] });

/** Where the Storytender steps back out into the Prologue (memory_pip.gd RETURN_CELL), in the overworld's cells. */
export const PIP_RETURN = '90.5,53.5';
const GATES: Record<string, { needs: string; closeFar: number }> = {
  G: { needs: 'gate_G', closeFar: 0 },
  v: { needs: 'gate_v', closeFar: 0 },
  w: { needs: 'gate_w', closeFar: 0 },
  u: { needs: 'plate_k', closeFar: 2.5 },
  y: { needs: 'plate_m+plate_n+lock_read', closeFar: 2.5 },
  H: { needs: 'door_H', closeFar: 0 },
};
const PAGES: Record<string, number> = { f: 1, F: 2, N: 3 };

export interface PipMap {
  rows: string[];
  bridge: [number, number][];
  river: [number, number][];
  floor: [number, number][];
}

export function pipMap(repo: string): PipMap {
  const s = readFileSync(join(repo, 'data/memory_pip_map.gd'), 'utf8');
  const cells = (name: string): [number, number][] => [...(new RegExp(`const ${name}[^=]*=\\s*\\[([^\\]]*)\\]`).exec(s)?.[1] ?? '').matchAll(/Vector2i\((\d+),\s*(\d+)\)/g)].map((m) => [Number(m[1]), Number(m[2])]);
  const body = /const ROWS[^=]*=\s*\[([\s\S]*?)\]/.exec(s)![1]!;
  return { rows: [...body.matchAll(/"([^"]*)"/g)].map((m) => m[1]!), bridge: cells('BRIDGE_CELLS'), river: cells('RIVER_CELLS'), floor: cells('FLOOR_CELLS') };
}

/** The gap cells, which the map draws as floor and covers with a PitCover each. */
export const pipGapCells = (m: PipMap): Set<string> => new Set([...m.bridge, ...m.river, ...m.floor].map(([x, y]) => `${x},${y}`));

export function writePipTalk(w: World): void {
  const fn = (name: string): Line[] => (w.story.functions[name] as Line[]) ?? [];
  const k = (s: string): string => String(w.story.constants[s] ?? '');
  const simple = (name: string, lines: Line[], ...sets: [string, number][]): void => {
    const t = new Talk(name);
    const steps = [...(lines.length ? [t.lines(lines, w.keyed)] : []), ...sets.map(([v, n]) => t.set(v, n))];
    w.write(name, t.data(t.seq(...steps)[0]));
  };
  simple('pip_enter', [line(k('PIP_INTRO')), line(k('PIP_STONE_HINT'))], ['pip_entered', 1]);
  simple('spoiler_intro', [...fn('pip_boss_intro'), line('Strike the book while it is reading, and what it reads is rewritten.')], ['spoiler_awake', 1]);
  simple('spoiler_reckon', fn('spoiler_reckoning'), ['spoiler_reckoning', 1]);
  simple('spoiler_end', fn('pip_finale'), ['spoiler_down', 1]);
  const pages = (w.story.constants.PIP_PAGE_NARRATION as string[]) ?? [];
  for (const n of [1, 2, 3]) {
    const t = new Talk(`take_page_${n}`);
    const take = t.seq(t.set(`page_${n}`, 1), t.set('pip_pages', 1, 'add'), t.lines([line('Found: a Torn Page', 'sign')], w.keyed),
      t.when({ name: 'pip_pages', op: '>=', value: 3 }, t.lines([line(k('PIP_ALL_PAGES'))], w.keyed), t.lines([line(pages[n - 1] ?? '')], w.keyed)));
    w.write(t.name, t.data(t.when({ name: `page_${n}` }, t.end(), take)[0]));
  }
  {
    const t = new Talk('pip_door');
    const fit = t.seq(t.lines(fn('pip_door_fit'), w.keyed), t.set('door_H', 1));
    w.write(t.name, t.data(t.when({ name: 'door_H' }, t.end(), t.when({ name: 'pip_pages', op: '>=', value: 3 }, fit, t.lines([line(k('PIP_DOOR_LOCKED'))], w.keyed)))[0]));
  }
  {
    const t = new Talk('pip_turn');
    const turn = t.seq(t.lines(fn('pip_resolution'), w.keyed), t.set('pip_memory_done', 1), t.set('mnemosynth', 40, 'add'), t.give('bookmark', 1), t.lines([line('Received: Bookmark and 40 Mnemosynth', 'sign')], w.keyed), t.set('leave_pip', 1));
    w.write(t.name, t.data(t.when({ name: 'pip_memory_done' }, t.end(), t.when({ name: 'spoiler_down' }, turn, t.lines([line('Pip is hiding behind the book. Not yet.')], w.keyed)))[0]));
  }
  simple('leave_pip', [line('You let go of the memory, and the Prologue comes back.')], ['leave_pip', 1]);
}

/** What one object of the library does. */
export function decoratePip(e: EntityData, cls: string, kind: number, letter: string, cell: [number, number], w: World, props: Record<string, unknown>): void {
  const c = e.components;
  const talk = (dialogue: string, reach = 2.2): void => w.attach(c, 'npcTalk', { dialogue, reach, facePlayer: false, once: false, hint: true });
  if (cls === 'SentenceStone') {
    const words = ((props.options as string[]) ?? ['', '']).join(', ');
    w.attach(c, 'sentenceStone', { before: String(props.prefix ?? ''), words, after: '.', selected: 0, reach: 2.2, variable: `stone_${letter}` });
    e.tags.push('stone', `stone-${letter}`);
    return;
  }
  if (cls === 'EchoPlate') {
    w.attach(c, 'script_Plate', { flag: `plate_${letter}`, radius: 0.85 });
    e.tags.push('plate');
    return;
  }
  if (cls === 'StoryGate') {
    const g = GATES[letter] ?? { needs: 'never', closeFar: 0 };
    w.attach(c, 'script_StoryGate', { needs: g.needs, closeFar: g.closeFar, said: '' });
    c.collider = COLLIDER(3, 0.7, 2);
    e.tags.push('gate', `gate-${letter}`);
    if (letter === 'H') talk('pip_door', 2.6);
    return;
  }
  if (cls === 'Redactor') {
    w.attach(c, 'script_Redactor', { flag: `pip_bar_${cell[0]}_${cell[1]}`, said: "The black bar lifts. Underneath: 'keep climbing'." });
    c.collider = Number((props.axis as number[])?.[1] ?? 0) ? COLLIDER(0.7, 3, 2) : COLLIDER(3, 0.7, 2);
    e.tags.push('redactor');
    return;
  }
  if (cls === 'DungeonKey') {
    const n = PAGES[letter] ?? 1;
    talk(`take_page_${n}`, 1.6);
    w.attach(c, 'script_Flagged', { hideWhen: `page_${n}`, showWhen: '', lookWhen: '', look: '' });
    e.tags.push('page');
    return;
  }
  if (cls === 'Spoiler') {
    e.tags.push('boss', 'spoiler', 'enemy');
    w.attach(c, 'health', { max: 190, invulnerableSeconds: 0.25, onDeath: 'stay', fallDamage: 0, team: 'enemy', showBar: false });
    c.body = { vx: 0, vy: 0, vz: 0, radius: 0.6, height: 2, state: 'ground', stepUp: 0.35, stepDown: 0.4, ledge: 'stop', pits: 'stop', wade: false, gravity: 1, peakZ: 0, layer: 4, mask: 65535, noclip: true, blockedBy: [], blockedTerrain: false };
    w.attach(c, 'script_Spoiler', {});
    return;
  }
  if (cls !== 'Prop') return;
  if (kind === 8) {
    talk('leave_pip', 2.2);
    w.attach(c, 'script_Gateway', { flag: 'leave_pip', scene: 'scenes/overworld.scene.json', spawn: PIP_RETURN });
  } else if (kind === 9) {
    talk('pip_turn', 2.4);
    w.attach(c, 'script_Gateway', { flag: 'leave_pip', scene: 'scenes/overworld.scene.json', spawn: PIP_RETURN });
    e.tags.push('pip');
  }
}

/** The memory's own rules and its opening words, and a cover over every gap a sentence can fill. */
export function pipExtras(m: PipMap, level: (x: number, y: number) => number, looks: { hole: string; plank: string; ice: string }, next: () => string): EntityData[] {
  const out: EntityData[] = [];
  const list = (cells: [number, number][]): string => cells.map(([x, y]) => `${x},${y}`).join(';');
  out.push({ id: next(), name: 'Pip memory', tags: ['controller'], components: { transform: { x: 1, y: 1, h: 0, facing: 2 }, script_PipMemory: { river: list(m.river), floor: list(m.floor) }, script_OnEnter: { dialogue: 'pip_enter', flag: 'pip_entered' } } });
  const cover = (cells: [number, number][], flag: string, on: string): void => {
    for (const [x, y] of cells) {
      out.push({
        id: next(),
        name: `Gap ${x},${y}`,
        tags: ['gap', flag],
        components: {
          transform: { x: x + 0.5, y: y + 0.5, h: level(x, y), facing: 2 },
          sprite: { shape: 'box', color: 0x1c1824, w: 1, d: 1, height: 0.02, sortOffset: -1, visible: true, asset: looks.hole },
          collider: COLLIDER(1, 1, 2),
          script_PitCover: { flag, lookOn: on, lookOff: looks.hole },
        },
      });
    }
  };
  cover(m.bridge, 'bridge_holds', looks.plank);
  cover(m.river, 'river_frozen', looks.ice);
  cover(m.floor, 'floor_solid', looks.plank);
  return out;
}
