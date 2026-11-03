/**
 * Port tool: Maud's memory, The Empty Table (memory_maud.gd). This memory's verb is FORMAT: choose a style (1 underline,
 * 2 bold, 3 italic) and strike a word with the quill. The Pantry: underline BREAD and it bridges the gap. The Kitchen: make
 * SALT bold, then italic, and it slides; stand in its way so it stops on the plate, and the COLD door opens. The Cellar:
 * the DOUGH rises in its own time (the lantern's warmth helps; a strike too early collapses it), then underline it. The
 * Hall: lead six guests to their chairs with the lantern while cold waves sweep the room (shelter behind a bold word); then
 * the Cold Shoulder. Beaten, sit with Maud.
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import type { EntityData } from '@tilewright/runtime';
import { Talk, type World } from './overworld';

type Line = { who: string; text: string; style: string };
const line = (text: string, style = 'action', who = ''): Line => ({ who, text, style });
const COLLIDER = (w: number, d: number, height: number): object => ({ w, d, height, solid: true, trigger: false, layer: 16, mask: 65535, enabled: true, inside: [] });

export const MAUD_RETURN = '90.5,59.5';
/** The hall (memory_maud.gd: floor cells with y <= 9, x >= 28). */
export const HALL = { x0: 29, y0: 0, x1: 43, y1: 9 };

export interface MaudMap {
  rows: string[];
}
export function maudMap(repo: string): MaudMap {
  const s = readFileSync(join(repo, 'data/memory_maud_map.gd'), 'utf8');
  const body = /const ROWS[^=]*=\s*\[([\s\S]*?)\]/.exec(s)![1]!;
  return { rows: [...body.matchAll(/"([^"]*)"/g)].map((m) => m[1]!) };
}
/** The cells a word lies over that are a gap ("a" BREAD and "d" DOUGH lie over their gaps, 3 cells each). */
export function maudGaps(m: MaudMap): Map<string, string> {
  const out = new Map<string, string>();
  m.rows.forEach((r, y) => [...r].forEach((c, x) => {
    if (c === 'a') for (let i = 0; i < 3; i++) out.set(`${x + i},${y}`, 'bread_bridge');
    if (c === 'd') for (let i = 0; i < 3; i++) out.set(`${x + i},${y}`, 'dough_bridge');
  }));
  return out;
}
/** Where an italic word stops: the last floor cell along its slant before a wall, a gap or a block. */
function slideEnd(m: MaudMap, x: number, y: number, dx: number, dy: number, len: number): [number, number] {
  let cx = x;
  let cy = y;
  for (;;) {
    const nx = cx + dx * (dx > 0 ? len : 1);
    const ny = cy + dy;
    const ch = m.rows[ny]?.[nx] ?? ' ';
    if (ch === ' ' || ch === '#' || ch === 'B' || ch === 'M' || ch === 'h' || ch === 'e') return [cx, cy];
    cx += dx;
    cy += dy;
  }
}

export function writeMaudTalk(w: World): void {
  const fn = (name: string): Line[] => (w.story.functions[name] as Line[]) ?? [];
  const k = (s: string): string => String(w.story.constants[s] ?? '');
  const simple = (name: string, lines: Line[], ...sets: [string, number][]): void => {
    const t = new Talk(name);
    const steps = [...(lines.length ? [t.lines(lines, w.keyed)] : []), ...sets.map(([v, n]) => t.set(v, n))];
    w.write(name, t.data(t.seq(...steps)[0]));
  };
  simple('maud_enter', [...fn('maud_format_grant'), line('Press [1] [2] [3] to choose underline, bold or italic, then strike a word with the quill.'), line(k('MAUD_INTRO'))], ['format_mark', 1], ['maud_entered', 1]);
  simple('maud_table', fn('maud_boss_intro'), ['table_awake', 1]);
  simple('maud_reckon', fn('maud_reckoning'), ['cold_spawn', 1]);
  simple('maud_end', fn('maud_finale'), ['maud_finale', 1], ['cold_down', 1]);
  {
    const t = new Talk('maud_sit');
    const sit = t.seq(t.lines(fn('maud_resolution'), w.keyed), t.set('maud_memory_done', 1), t.set('mnemosynth', 40, 'add'), t.lines([line('Received: 40 Mnemosynth', 'sign')], w.keyed), t.set('leave_maud', 1));
    w.write(t.name, t.data(t.when({ name: 'maud_memory_done' }, t.end(), t.when({ name: 'maud_finale' }, sit, t.lines([line('Maud is watching the door. Not yet.')], w.keyed)))[0]));
  }
  simple('leave_maud', [line('You let go of the memory, and the Prologue comes back.')], ['leave_maud', 1]);
}

/** What one object of the kitchen does. */
export function decorateMaud(e: EntityData, cls: string, kind: number, letter: string, cell: [number, number], props: Record<string, unknown>, m: MaudMap, w: World): void {
  const c = e.components;
  const talk = (dialogue: string, reach = 2.2): void => w.attach(c, 'npcTalk', { dialogue, reach, facePlayer: false, once: false, hint: true });
  if (cls === 'TextBlock') {
    const word = String(props.word ?? '');
    const len = Number(props.length ?? 1);
    const lean = (props.lean as number[]) ?? [1, 0];
    const start = (props.cell as number[]) ?? cell;
    e.tags.push('word', `word-${word.toLowerCase()}`);
    w.attach(c, 'health', { max: 999, invulnerableSeconds: 0.2, onDeath: 'stay', fallDamage: 0, team: 'enemy', showBar: false });
    w.attach(c, 'textBlock', { text: word, format: 'plain', playerCanFormat: false, reach: 1.5, wallHeight: 1.6, slideSpeed: 5 });
    c.collider = { ...(COLLIDER(len, 1, 0.1) as object), solid: false, enabled: false };
    const gapFlag = word === 'BREAD' ? 'bread_bridge' : word === 'DOUGH' ? 'dough_bridge' : '';
    const [ex, ey] = word === 'SALT' ? slideEnd(m, start[0]!, start[1]!, lean[0]!, lean[1]!, len) : [0, 0];
    w.attach(c, 'script_WordBlock', { gapFlag, leanX: lean[0], leanY: lean[1], slideTo: word === 'SALT' ? `${ex + 0.5},${ey + 0.5}` : '', riseTime: word === 'DOUGH' ? 36 : 0 });
    return;
  }
  if (cls === 'StoryGate') {
    w.attach(c, 'script_StoryGate', { needs: 'cold_gate', closeFar: 0, said: '' });
    c.collider = COLLIDER(0.7, 3, 2);
    e.tags.push('gate');
    return;
  }
  if (cls === 'PressurePlate') {
    e.tags.push('plate');
    return;
  }
  if (cls !== 'Prop') return;
  if (kind === 8) {
    talk('leave_maud', 2.2);
    w.attach(c, 'script_Gateway', { flag: 'leave_maud', scene: 'scenes/overworld.scene.json', spawn: MAUD_RETURN });
  } else if (kind === 12) e.tags.push('chair');
  else if (kind === 9 && letter === 'Y') {
    talk('maud_sit', 2.4);
    w.attach(c, 'script_Gateway', { flag: 'leave_maud', scene: 'scenes/overworld.scene.json', spawn: MAUD_RETURN });
    e.tags.push('maud');
  }
}

/** The memory's rules, its opening words, and a cover over the gaps BREAD and DOUGH bridge. */
export function maudExtras(m: MaudMap, level: (x: number, y: number) => number, hole: string, plank: string, next: () => string): EntityData[] {
  const plate = m.rows.flatMap((r, y) => [...r].map((ch, x) => (ch === 'L' ? `${x},${y}` : ''))).find(Boolean) ?? '24,17';
  const cells: string[] = [];
  m.rows.forEach((r, y) => [...r].forEach((ch, x) => {
    if (y >= HALL.y0 && y <= HALL.y1 && x >= HALL.x0 - 1 && ch !== ' ' && ch !== 'M') cells.push(`${x},${y}`);
  }));
  const out: EntityData[] = [{
    id: next(),
    name: 'Maud memory',
    tags: ['controller'],
    components: { transform: { x: 1, y: 1, h: 0, facing: 2 }, script_MaudMemory: { plate, area: `${HALL.x0},${HALL.y0},${HALL.x1},${HALL.y1}`, cells: cells.join(';') }, script_OnEnter: { dialogue: 'maud_enter', flag: 'maud_entered' } },
  }];
  for (const [key, flag] of maudGaps(m)) {
    const [x, y] = key.split(',').map(Number) as [number, number];
    out.push({ id: next(), name: `Gap ${key}`, tags: ['gap', flag], components: { transform: { x: x + 0.5, y: y + 0.5, h: level(x, y), facing: 2 }, sprite: { shape: 'box', color: 0x1c1824, w: 1, d: 1, height: 0.02, sortOffset: -1, visible: true, asset: hole }, collider: COLLIDER(1, 1, 2), script_PitCover: { flag, lookOn: plank, lookOff: hole } } });
  }
  return out;
}
