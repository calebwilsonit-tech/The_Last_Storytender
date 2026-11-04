/**
 * Port tool: the two side rooms of the overworld (side_weighing.gd, side_proof.gd), which were only pictures until now.
 *   The Weighing Room  echo plates hold gates open (the Tare Room, the Relay, Night Shift, the Counterweights), the Pan Room's bridge exists only
 *                      while its plate is held, the Locket of Second Thoughts gives a third echo, three weights open the scale door and the vault
 *                      (the Hourglass of Drafts).
 *   The Proof Room     black bars hide three plaques (the lantern reveals them); they give the words three sentence stones need; the gate opens
 *                      when the stones read right; the press is full of Censors; the last proof, guarded by Ellipses, holds the Censor's Monocle.
 */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import type { EntityData } from '@tilewright/runtime';
import { Talk, type World } from './overworld';

type Line = { who: string; text: string; style: string };
const line = (text: string, style = 'action'): Line => ({ who: '', text, style });
const COLLIDER = (w: number, d: number, height: number): object => ({ w, d, height, solid: true, trigger: false, layer: 16, mask: 65535, enabled: true, inside: [] });

export const WEIGHING_RETURN = '107.5,76.5';
export const PROOF_RETURN = '13.5,27.5';

/** Echo gates: gate letter -> the plates that hold it open; the Tare Room's gate (A) stays open behind her. */
const ECHO_GATES: Record<string, string[]> = { A: ['a'], x: ['b'], y: ['c'], B: ['d', 'e'], s: ['p'], t: ['q'], W: ['p', 'q', 'r'] };
const GATE_AXIS: Record<string, [number, number]> = { A: [1, 0], x: [1, 0], y: [0, 1], B: [1, 0], s: [0, 1], t: [0, 1], W: [1, 0], D: [1, 0] };
const PLAQUES = [
  'COLOPHON: \'Set in a living hand. The author is ALIVE, whatever the cover says.\'',
  'ERRATA: \'The ending is UNWRITTEN. Anyone who tells you otherwise is guessing.\'',
  'DEDICATION: \'For the reader, who is always WELCOME, even when late.\'',
];
const STONES: Record<string, { prefix: string; options: string[]; good: number }> = {
  s: { prefix: 'The author is', options: ['DEAD', 'ALIVE', 'ABSENT'], good: 1 },
  t: { prefix: 'The ending is', options: ['KNOWN', 'TRAGIC', 'UNWRITTEN'], good: 2 },
  u: { prefix: 'The reader is', options: ['BORED', 'WELCOME', 'LATE'], good: 1 },
};

export interface SideMap {
  rows: string[];
  pan: [number, number][];
}

export function sideMap(repo: string, scene: 'weighing' | 'proof'): SideMap {
  const s = readFileSync(join(repo, 'data', scene === 'weighing' ? 'side_weighing_map.gd' : 'side_proof_map.gd'), 'utf8');
  const body = /const ROWS[^=]*=\s*\[([\s\S]*?)\]/.exec(s)![1]!;
  const pan = [...(/const PAN_CELLS[^=]*=\s*\[([^\]]*)\]/.exec(s)?.[1] ?? '').matchAll(/Vector2i\((\d+),\s*(\d+)\)/g)].map((m): [number, number] => [Number(m[1]), Number(m[2])]);
  return { rows: [...body.matchAll(/"([^"]*)"/g)].map((m) => m[1]!), pan };
}

export function writeSideTalk(w: World): void {
  const k = (name: string): string => name;
  const plain = (name: string, lines: Line[], ...sets: [string, number][]): void => {
    const t = new Talk(name);
    w.write(name, t.data(t.seq(t.lines(lines, w.keyed), ...sets.map(([v, n]) => t.set(v, n)))[0]));
  };
  plain('weighing_enter', [line('A counting-house that has weighed every word ever spoken in it and found each one a little short. The scales are still swinging.')], ['weighing_entered', 1]);
  plain('proof_enter', [line('Proofs, galleys, red pencil. Every wall has a mark on it, and every mark is a question.')], ['proof_entered', 1]);
  plain('leave_weighing', [line('You step out of the Weighing Room, and the Prologue comes back.')], ['leave_weighing', 1]);
  plain('leave_proof', [line('You step out of the Proof Room, and the Prologue comes back.')], ['leave_proof', 1]);
  // the three weights
  for (const ch of ['T', 'U', 'V']) {
    const t = new Talk(`take_weight_${ch}`);
    const take = t.seq(
      t.set(`got_weight_${ch}`, 1),
      t.set('weights', 1, 'add'),
      t.lines([line('Found: a weight', 'sign')], w.keyed),
      t.when({ name: 'weights', op: '>=', value: 3 }, t.lines([line('Three weights on the scale. It sighs, and for once it is satisfied. The scale tips, and the vault is open.')], w.keyed), t.end()),
    );
    w.write(t.name, t.data(t.when({ name: `got_weight_${ch}` }, t.end(), take)[0]));
  }
  {
    const t = new Talk('take_locket');
    const take = t.seq(t.set('echo_third', 1), t.lines([line('Found: the Locket of Second Thoughts. You can keep three Echoes.', 'sign'), line('A locket on a thin chain. Inside, three tiny portraits of the same person, none of them quite agreeing.')], w.keyed));
    w.write(t.name, t.data(t.when({ name: 'echo_third' }, t.end(), take)[0]));
  }
  // what each vault gives
  for (const [room, item, finale] of [['weighing', 'hourglass_of_drafts', 'The scales settle at last. Whatever you weighed, it was worth the weight.'], ['proof', 'censors_monocle', 'Approved for release, the stamp says. It is the first approval you have ever seen that did not feel like a verdict.']] as const) {
    const t = new Talk(`take_reward_${room}`);
    const name = w.items[item]?.name ?? item;
    const take = t.seq(t.give(item, 1), t.set(`side_${room}_done`, 1), t.set('renown', 15, 'add'), t.lines([line(`Received: ${name}`, 'sign'), line(finale)], w.keyed));
    w.write(t.name, t.data(t.when({ name: `side_${room}_done` }, t.end(), take)[0]));
  }
  // the plaques of the Proof Room: unreadable under their bars
  PLAQUES.forEach((text, i) => {
    const t = new Talk(`plaque_${i}`);
    w.write(t.name, t.data(t.when({ name: `plaque_seen_${i}` }, t.lines([line(text)], w.keyed), t.lines([line('A black bar covers it. Whatever is written there needs light to matter.')], w.keyed))[0]));
  });
  void k;
}

/** What one object of a side room does. `ch` is the map's letter under it. */
export function decorateSide(e: EntityData, scene: 'weighing' | 'proof', cls: string, kind: number, ch: string, cell: [number, number], w: World): void {
  const c = e.components;
  const talk = (dialogue: string, reach = 2.2): void => w.attach(c, 'npcTalk', { dialogue, reach, facePlayer: false, once: false, hint: true });
  if (cls === 'EchoPlate') {
    w.attach(c, 'script_Plate', { flag: `wplate_${ch}`, radius: 0.85 });
    e.tags.push('plate');
    return;
  }
  if (cls === 'StoryGate') {
    const [ax, ay] = GATE_AXIS[ch] ?? [0, 1];
    void ax;
    const along = Number(ay) !== 0 || scene === 'proof';
    if (scene === 'weighing' && ch === 'D') w.attach(c, 'script_StoryGate', { needs: 'weights>=3', closeFar: 0, said: '' });
    else if (scene === 'weighing') w.attach(c, 'script_StoryGate', { needs: (ECHO_GATES[ch] ?? []).map((p) => `wplate_${p}`).join('+') || 'never', closeFar: ch === 'A' ? 0 : 2.5, said: 'The scales balance. The way opens.' });
    else w.attach(c, 'script_StoryGate', { needs: 'site_proof', closeFar: 0, said: 'Approved. The gate lifts.' });
    c.collider = along ? COLLIDER(0.7, 3, 2) : COLLIDER(3, 0.7, 2);
    e.tags.push('gate');
    return;
  }
  if (cls === 'DungeonKey') {
    if (ch === 'L') {
      talk('take_locket', 1.6);
      w.attach(c, 'script_Flagged', { hideWhen: 'echo_third', showWhen: '', lookWhen: '', look: '' });
    } else {
      talk(`take_weight_${ch}`, 1.6);
      w.attach(c, 'script_Flagged', { hideWhen: `got_weight_${ch}`, showWhen: '', lookWhen: '', look: '' });
    }
    return;
  }
  if (cls === 'SentenceStone') {
    const d = STONES[ch];
    if (!d) return;
    const i = ['s', 't', 'u'].indexOf(ch);
    w.attach(c, 'sentenceStone', { before: d.prefix, words: d.options.join(', '), after: '.', selected: 0, reach: 2.2, variable: `stone_proof_${i}` });
    e.tags.push('stone', 'site-proof-stone', `i${i}`);
    return;
  }
  if (cls === 'Redactor') {
    // a plaque's bar sits just under the plaque (x, y, z in the map are the plaques)
    const plaque = cell[1] === 5 ? [8, 12, 16].indexOf(cell[0]) : -1;
    // the bars are drawn to fit their length (the forge's bar is 3 cells, a plaque's is 2)
    const spr = c.sprite as { height: number };
    if (plaque >= 0) {
      w.attach(c, 'script_Redactor', { flag: `plaque_seen_${plaque}`, remember: true, said: 'Revealed: read the plaque.' });
      c.collider = COLLIDER(2, 0.7, 2);
      spr.height = 1.0;
    } else {
      w.attach(c, 'script_Redactor', { flag: '', remember: false, said: "The black bar lifts. Underneath, in red pencil: 'fine.'" });
      c.collider = COLLIDER(0.7, 3, 2);
      spr.height = 1.5;
    }
    e.tags.push('redactor');
    return;
  }
  if (cls !== 'Prop') return;
  if (kind === 8) {
    talk(`leave_${scene}`, 70 / 35.8 + 0.4);
    w.attach(c, 'script_Gateway', { flag: `leave_${scene}`, scene: 'scenes/overworld.scene.json', spawn: scene === 'weighing' ? WEIGHING_RETURN : PROOF_RETURN });
    c.collider = COLLIDER(0.8, 0.8, 1.5);
    return;
  }
  if (kind === 4) {
    // a plaque of the Proof Room
    const i = cell[0] === 8 ? 0 : cell[0] === 12 ? 1 : 2;
    talk(`plaque_${i}`, 2.2);
    c.collider = COLLIDER(0.8, 0.8, 1.2);
    return;
  }
  if (kind === 10) {
    // the vault's reward
    talk(`take_reward_${scene}`, 1.8);
    w.attach(c, 'script_Flagged', { hideWhen: `side_${scene}_done`, showWhen: '', lookWhen: '', look: '' });
    return;
  }
  if (kind === 16) {
    // the Proof Room's lantern post
    w.attach(c, 'checkpoint', { name: 'The Proof Room Lantern', reach: 100 / 35.8 + 0.4, lightRadius: 5, heals: true });
    e.tags.push('lantern-post');
  }
}

/** What a side room adds: its opening words, the Proof Room's sentence stones, and the Pan Room's bridge. */
export function sideExtras(scene: 'weighing' | 'proof', map: SideMap, levelOf: (x: number, y: number) => number, looks: { hole: string; plank: string }, next: () => string): EntityData[] {
  const out: EntityData[] = [];
  out.push({ id: next(), name: `${scene} intro`, tags: ['controller'], components: { transform: { x: 1, y: 1, h: 0, facing: 2 }, script_OnEnter: { dialogue: `${scene}_enter`, flag: `${scene}_entered` } } });
  if (scene === 'proof') {
    const good = ['s', 't', 'u'].map((ch) => STONES[ch]!.options[STONES[ch]!.good]!);
    const goodIndex = ['s', 't', 'u'].map((ch) => STONES[ch]!.good);
    out.push({
      id: next(),
      name: 'Site proof',
      tags: ['site'],
      components: {
        transform: { x: 1, y: 1, h: 0, facing: 2 },
        sprite: { shape: 'box', color: 0, w: 0.1, d: 0.1, height: 0.1, sortOffset: 0, visible: false },
        script_Site: { id: 'proof', type: 'words', data: JSON.stringify({ type: 'words', good, goodIndex, bonus: 0, text: 'Approved. The gate lifts.' }), lookCrack: '', lookHole: '' },
      },
    });
  } else {
    // the Pan Room's bridge: there only while the pan's plate is held
    for (const [x, y] of map.pan) {
      out.push({
        id: next(),
        name: `Pan ${x},${y}`,
        tags: ['gap', 'pan'],
        components: {
          transform: { x: x + 0.5, y: y + 0.5, h: levelOf(x, y), facing: 2 },
          sprite: { shape: 'box', color: 0x1c1824, w: 1, d: 1, height: 0.02, sortOffset: -1, visible: true, asset: looks.hole },
          collider: COLLIDER(1, 1, 2),
          script_PitCover: { flag: 'wplate_f', lookOn: looks.plank, lookOff: looks.hole },
        },
      });
    }
  }
  return out;
}
