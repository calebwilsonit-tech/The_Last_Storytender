/**
 * Port tool: what the game's objects DO, for the Tilewright port (main.gd, level_base.gd, puzzle_sites.gd, story.gd):
 * who talks, what a sign says, what a chest or a pickup gives, where a door goes. Conversations are dialogue graphs
 * that branch on story flags (the same flags the game saves); the scripts in ./scripts handle what a conversation
 * cannot (travel, crystals, things that appear or vanish with the story, the Storytender's own rules).
 */
import type { EntityData } from '@tilewright/runtime';
import type { SiteData } from './sites';

type Line = { who: string; text: string; style: string };
type Node = Record<string, unknown> & { id: string };

/** Builds one dialogue graph: lines, flag branches, sets and gifts, in order. */
export class Talk {
  nodes: Node[] = [];
  private n = 0;
  constructor(readonly name: string) {}
  private id(): string {
    return `n${++this.n}`;
  }
  /** A run of lines; returns [first id, last id]. */
  lines(lines: Line[], keyed: (t: string) => string): [string, string] {
    const ids = lines.map(() => this.id());
    lines.forEach((l, i) =>
      this.nodes.push({ id: ids[i]!, type: 'line', speaker: l.who, text: keyed(l.style === 'action' ? `[i]${l.text}[/i]` : l.text), ...(i + 1 < ids.length ? { next: ids[i + 1] } : {}) }),
    );
    return [ids[0]!, ids[ids.length - 1]!];
  }
  set(variable: string, value: number | string, op: 'set' | 'add' = 'set'): [string, string] {
    const id = this.id();
    this.nodes.push({ id, type: 'set', variable, op, value });
    return [id, id];
  }
  give(item: string, amount: number): [string, string] {
    const id = this.id();
    this.nodes.push({ id, type: 'give', item, amount });
    return [id, id];
  }
  /** Chains steps one after another; returns [first, last]. */
  seq(...steps: [string, string][]): [string, string] {
    for (let i = 0; i + 1 < steps.length; i++) {
      const last = this.nodes.find((x) => x.id === steps[i]![1])!;
      last.next = steps[i + 1]![0];
    }
    return [steps[0]![0], steps[steps.length - 1]![1]];
  }
  /** If the flag (or `variable op value`) holds, `then`, otherwise `otherwise`. */
  when(cond: { name: string; op?: string; value?: number | string }, then: [string, string], otherwise: [string, string]): [string, string] {
    const id = this.id();
    this.nodes.push({ id, type: 'branch', if: { kind: 'variable', name: cond.name, op: cond.op ?? '>=', value: cond.value ?? 1 }, then: then[0], else: otherwise[0] });
    return [id, id];
  }
  /** A question with answers; each answer goes on to a step. */
  choice(prompt: string, options: { text: string; next: string }[], keyed: (t: string) => string): [string, string] {
    const id = this.id();
    this.nodes.push({ id, type: 'choice', speaker: '', prompt: keyed(prompt), options: options.map((o) => ({ text: keyed(o.text), next: o.next })) });
    return [id, id];
  }
  end(): [string, string] {
    const id = this.id();
    this.nodes.push({ id, type: 'end' });
    return [id, id];
  }
  data(start: string): object {
    return { schemaVersion: 1, name: this.name, start, nodes: this.nodes };
  }
}

export interface World {
  story: { functions: Record<string, Line[] | Record<string, Line[]>>; constants: Record<string, unknown> };
  map: { WAYPOINTS: { id: string; name: string; cell: [number, number] }[]; LORE: Record<string, [number, number]>; LORE_TEXT: Record<string, string>; CHESTS: Record<string, string>; PORTALS: Record<string, { cell: [number, number]; name: string; blurb: string; return: [number, number] }>; SITES: Record<string, SiteData>; RIDDLES: Record<string, { axis: [number, number]; chest: [number, number]; gate: [number, number]; stone: [number, number]; options: string[]; prefix: string; suffix: string; tier: number }> };
  rolls: Record<string, string>;
  items: Record<string, { name?: string }>;
  keyed: (t: string) => string;
  write: (name: string, data: object) => void;
  attach: (components: Record<string, unknown>, id: string, settings: object) => void;
}

const line = (text: string, style = 'action', who = ''): Line => ({ who, text, style });
const near = (g: [number, number], c: [number, number], d = 1.2): boolean => Math.abs(g[0] - c[0]) <= d && Math.abs(g[1] - c[1]) <= d;
const cellKey = (c: [number, number]): string => `${c[0]},${c[1]}`;
const PX = 35.8; // ground pixels per cell, for the game's interaction ranges
/** A solid box that blocks the Storytender and the Errors (layer 16, like every collider the port makes). */
const COLLIDER = (w: number, d: number, height: number): object => ({ w, d, height, solid: true, trigger: false, layer: 16, mask: 65535, enabled: true, inside: [] });

const PORTAL_NEEDS: Record<string, string> = { weighing: 'memory_done', proof: 'has_quill' };
const PORTAL_NEED_TEXT: Record<string, string> = {
  weighing: "It does not open yet. Something in you has to learn to be in two places at once first: finish Garrick's memory.",
  proof: 'It does not open yet. You would need something to write with before a place like this would take you seriously.',
};
const PORTAL_SCENE: Record<string, string> = { weighing: 'scenes/weighing.scene.json', proof: 'scenes/proof.scene.json' };

/** Reward strings of the game ("mnemo:20", "item:ink_vial:2") as dialogue steps. */
function reward(t: Talk, r: string, w: World): [string, string][] {
  const p = r.split(':');
  if (p[0] === 'mnemo') return [t.set('mnemosynth', Number(p[1]), 'add'), t.lines([line(`Received: ${p[1]} Mnemosynth`, 'sign')], w.keyed)];
  if (p[0] === 'item') {
    const n = Number(p[2] ?? 1);
    return [t.give(p[1]!, n), t.lines([line(`Received: ${w.items[p[1]!]?.name ?? p[1]}${n > 1 ? ` x${n}` : ''}`, 'sign')], w.keyed)];
  }
  return [];
}

const fn = (w: World, name: string): Line[] => (w.story.functions[name] as Line[]) ?? [];
const fnAt = (w: World, name: string, i: number): Line[] => ((w.story.functions[name] as Record<string, Line[]>)?.[String(i)] ?? []);
const constText = (w: World, name: string): string => String(w.story.constants[name] ?? '');

/** The people of Thistledown: what they say depends on how far the story has come (main.gd beats 1-12). */
function people(w: World): void {
  // Garrick
  {
    const t = new Talk('garrick');
    const restoredTalk = t.when({ name: 'lesson_done' }, t.lines(fn(w, 'garrick_restored'), w.keyed), t.when({ name: 'has_quill' }, t.lines(fnAt(w, 'garrick_lesson_hint', 1), w.keyed), t.seq(t.lines(fn(w, 'garrick_lesson_start'), w.keyed), t.set('has_quill', 1), t.lines([line("Received: Garrick's Quill", 'sign')], w.keyed))));
    const restoring = t.seq(t.set('play_k_garrick', 1)); // the cutscene (Director.script.ts) plays the words and pays the rewards
    const ghost = t.when({ name: 'met_garrick' }, t.lines(fn(w, 'garrick_ghost_repeat'), w.keyed), t.seq(t.lines(fn(w, 'garrick_ghost'), w.keyed), t.set('met_garrick', 1)));
    const start = t.when({ name: 'restored_garrick' }, restoredTalk, t.when({ name: 'memory_done' }, restoring, ghost));
    w.write('garrick', t.data(start[0]));
  }
  // Pip
  {
    const t = new Talk('pip');
    const restoring = t.seq(t.set('play_k_pip', 1)); // the cutscene (Director.script.ts) plays the words and pays the rewards
    const start = t.when({ name: 'restored_pip' }, t.lines(fn(w, 'pip_restored'), w.keyed), t.when({ name: 'pip_memory_done' }, restoring, t.lines(fn(w, 'pip_ghost'), w.keyed)));
    w.write('pip', t.data(start[0]));
  }
  // Maud
  {
    const t = new Talk('maud');
    const restoring = t.seq(t.set('play_k_maud', 1)); // the cutscene (Director.script.ts) plays the words and pays the rewards
    const start = t.when({ name: 'restored_maud' }, t.lines(fn(w, 'maud_restored'), w.keyed), t.when({ name: 'maud_memory_done' }, restoring, t.lines(fn(w, 'maud_ghost'), w.keyed)));
    w.write('maud', t.data(start[0]));
  }
  // the frozen flame of the forge: into Garrick's memory
  {
    const t = new Talk('forge');
    const enter = t.seq(t.lines(fn(w, 'forge_flame'), w.keyed), t.set('go_forge', 1));
    const start = t.when({ name: 'memory_done' }, t.lines([line('The forge is quiet now. Whatever it was holding, it has let go.')], w.keyed), t.when({ name: 'met_garrick' }, enter, t.lines([line('The fire in the forge is frozen in a single moment. Someone nearby might know why.')], w.keyed)));
    w.write('forge', t.data(start[0]));
  }
  // Pip's storybook: into Pip's memory once the Storytender has something to rewrite with
  {
    const t = new Talk('pip_book');
    const start = t.when({ name: 'has_quill' }, t.seq(t.lines(fn(w, 'pip_book_enter'), w.keyed), t.set('go_pip', 1)), t.lines([line(constText(w, 'PIP_BOOK_HINT'))], w.keyed));
    w.write('pip_book', t.data(start[0]));
  }
  // Maud's cold oven
  {
    const t = new Talk('maud_oven');
    const start = t.when({ name: 'maud_memory_done' }, t.lines([line('The oven is warm again.')], w.keyed), t.when({ name: 'pip_memory_done' }, t.seq(t.lines(fn(w, 'maud_oven_enter'), w.keyed), t.set('go_maud', 1)), t.lines([line(constText(w, 'MAUD_OVEN_HINT'))], w.keyed)));
    w.write('maud_oven', t.data(start[0]));
  }
  // the Margin Gate
  {
    const t = new Talk('margin_gate');
    const renown = t.lines([line("The ribbon on the Margin Gate stays tied. A small tag hangs from it: 'Not enough people know your name yet.'"), line('Renown {renown} / 220. Beat Errors, open chests, solve riddles, light posts, explore: any of it counts. The page remembers what you do.')], w.keyed);
    const start = t.when({ name: 'town_published' }, t.when({ name: 'renown', op: '>=', value: 220 }, t.set('play_k_ending', 1), renown), t.lines(fn(w, 'gate_locked'), w.keyed));
    w.write('margin_gate', t.data(start[0]));
  }
}

/** One-line conversations: signs and lore stones. */
function sayOnce(w: World, name: string, lines: Line[]): void {
  const t = new Talk(name);
  w.write(name, t.data(t.lines(lines.length ? lines : [line('The stone is blank, and a little embarrassed about it.')], w.keyed)[0]));
}

let made = false;
export function writeOverworldTalk(w: World): void {
  if (made) return;
  made = true;
  people(w);
  sayOnce(w, 'tutorial_sign', fn(w, 'tutorial_sign'));
  sayOnce(w, 'town_sign', fn(w, 'town_sign'));
  const lore = w.story.constants.LORE as Record<string, string>;
  for (const id of Object.keys(w.map.LORE)) sayOnce(w, `lore_${id}`, [line(lore[id] ?? w.map.LORE_TEXT[id] ?? '')]);
  // the tear in the square: stepping in takes her to the Cutting Room (Rift.script.ts shows it once the three are restored)
  {
    const t = new Talk('rift_enter');
    w.write('rift_enter', t.data(t.set('play_k_rift', 1)[0]));
  }
  // the two riddle stones: a word trial opens from a short conversation (Trial.script.ts runs it when start_<id> is set)
  for (const [id, r] of Object.entries(w.map.RIDDLES)) {
    const t = new Talk(`riddle_${id}`);
    const stars = '★'.repeat(r.tier);
    const text = `${r.prefix} [ ${r.options.join(' / ')} ]${r.suffix}`;
    const go = t.seq(t.set(`start_${id}`, 1), t.end());
    const no = t.end();
    const ask = t.seq(t.lines([line(`A stone with a sentence cut into it, and a word game set in its face: "${text}"`)], w.keyed), t.choice('Attempt the trial?', [{ text: `Attempt the trial  ${stars}`, next: go[0] }, { text: 'Leave it', next: no[0] }], w.keyed));
    const done = t.lines([line(`The stone has settled on its last word: "${r.prefix} ${r.options[r.options.length - 1]}${r.suffix}"`)], w.keyed);
    w.write(t.name, t.data(t.when({ name: `riddle_${id}` }, done, ask)[0]));
  }
  // the sign beside each puzzle site: the echo sites' hint, the words sites' answer
  for (const s of Object.values(w.map.SITES)) for (const id of [s.hint_id, s.sign_id]) if (id) sayOnce(w, `lore_${id}`, [line(lore[id] ?? w.map.LORE_TEXT[id] ?? '')]);
}

/** Gives one object of the overworld (a node the game built) what it does. Returns extra tags. */
export function decorateOverworld(e: EntityData, node: { class: string; props: Record<string, unknown> }, cell: [number, number], w: World): void {
  const c = e.components;
  const talk = (dialogue: string, reachPx = 64): void => w.attach(c, 'npcTalk', { dialogue, reach: Math.max(1, reachPx / PX + 0.4), facePlayer: false, once: false, hint: true });
  const gate = (flag: string, scene: string, spawn = ''): void => w.attach(c, 'script_Gateway', { flag, scene, spawn });
  const kind = Number(node.props.kind ?? -1);
  if (node.class === 'Npc') {
    const who = near(cell, [93, 55], 1.5) ? 'garrick' : near(cell, [91, 52], 1.5) ? 'pip' : 'maud';
    e.name = who[0]!.toUpperCase() + who.slice(1);
    e.tags.push('npc', who);
    talk(who);
    return;
  }
  if (node.class === 'Dummy') {
    e.tags.push('dummy');
    w.attach(c, 'health', { max: 999, onDeath: 'stay', showBar: false, team: 'enemy', invulnerableSeconds: 0.2 });
    c.collider = { w: 0.6, d: 0.6, height: 1.4, solid: true, trigger: false, layer: 16, mask: 65535, enabled: true, inside: [] };
    return;
  }
  // the gates, bars and stones of the overworld's puzzle sites and its way up: they block (M-02, M-03). A bar or gate spans three cells along
  // its axis (props.axis = [dx, dy]; [0, 1] runs along y), a stone is a small block.
  const alongY = Number((node.props.axis as number[] | undefined)?.[1] ?? 0) !== 0;
  if (node.class === 'Redactor') {
    // the lantern lifts it (Redactor.script.ts); not saved, so it is back whenever the scene is loaded (FLOW_SPEC 3: "not saved")
    w.attach(c, 'script_Redactor', { flag: '', remember: false, said: constText(w, 'REDACTOR_OPEN') });
    c.collider = alongY ? COLLIDER(0.7, 3, 2) : COLLIDER(3, 0.7, 2);
    e.tags.push('redactor');
    return;
  }
  if (node.class === 'StoryGate') {
    // a site's gate: WEIGHED opens for good once the site is solved, PROOF is open until the fight starts and open again once it is won
    // (Site.script.ts); a riddle's gate opens with the riddle. Until then a wall.
    c.collider = alongY ? COLLIDER(0.7, 3, 2) : COLLIDER(3, 0.7, 2);
    e.tags.push('gate');
    const [sid, s] = Object.entries(w.map.SITES).find(([, x]) => x.gate && near(cell, x.gate, 0.6)) ?? [];
    const rid = Object.entries(w.map.RIDDLES).find(([, r]) => near(cell, r.gate, 0.6))?.[0];
    if (rid) w.attach(c, 'script_StoryGate', { needs: `riddle_${rid}`, closeFar: 0, said: '' });
    if (sid && s) w.attach(c, 'script_StoryGate', s.type === 'arena' ? { needs: `arena_${sid}_open`, closeFar: 1.2, said: '' } : { needs: `site_${sid}`, closeFar: 0, said: '' });
    return;
  }
  if (node.class === 'SentenceStone') {
    c.collider = COLLIDER(0.8, 0.8, 1);
    e.tags.push('stone');
    // a stone of a words site: the engine's sentence stone, its chosen word kept in stone_<site>_<n>
    for (const [sid, s] of Object.entries(w.map.SITES)) {
      const i = (s.stones ?? []).findIndex((st) => near(cell, st.cell, 0.6));
      if (i < 0) continue;
      const st = s.stones![i]!;
      w.attach(c, 'sentenceStone', { before: st.prefix, words: st.options.join(', '), after: st.suffix, selected: 0, reach: 2.2, variable: `stone_${sid}_${i}` });
      e.tags.push(`site-${sid}-stone`, `i${i}`);
    }
    // a riddle's stone: "Attempt the trial" (a conversation sets start_<id>; Trial.script.ts runs the game and settles the stone on its last word)
    const [rid, r] = Object.entries(w.map.RIDDLES).find(([, x]) => near(cell, x.stone, 0.6)) ?? [];
    if (rid && r) {
      w.attach(c, 'sentenceStone', { before: r.prefix, words: r.options.join(', '), after: r.suffix, selected: 0, reach: 0.01, variable: '' });
      w.attach(c, 'npcTalk', { dialogue: `riddle_${rid}`, reach: 80 / PX + 0.4, facePlayer: false, once: false, hint: false });
      w.attach(c, 'script_Trial', { id: rid, tier: r.tier, last: r.options.length - 1 });
      e.tags.push(`riddle-${rid}`);
    }
    return;
  }
  if (node.class === 'EchoPlate') {
    // a plate of an echo site (two plates) or an arena's trigger
    for (const [sid, s] of Object.entries(w.map.SITES)) {
      const i = (s.plates ?? []).findIndex((p) => near(cell, p, 0.6));
      if (i >= 0) w.attach(c, 'script_Plate', { flag: `plate_${sid}_${i}`, radius: 0.85 });
      else if (s.trigger && near(cell, s.trigger, 0.6)) w.attach(c, 'script_Plate', { flag: `plate_${sid}_t`, radius: 0.85 });
      else continue;
      e.tags.push('plate', `site-${sid}`);
    }
    return;
  }
  if (node.class !== 'Prop') return;
  switch (kind) {
    case 4: {
      // signs: the tutorial sign, the town sign, the lore stones, the signs beside the puzzle sites (all of them block)
      c.collider = COLLIDER(0.8, 0.8, 1.2);
      if (near(cell, [19, 53], 0.6)) talk('tutorial_sign');
      else if (near(cell, [87, 55], 0.6)) talk('town_sign');
      else {
        const id = Object.entries(w.map.LORE).find(([, p]) => near(cell, p, 0.6))?.[0];
        const site = Object.values(w.map.SITES).find((s) => (s.hint && near(cell, s.hint, 0.6)) || (s.sign && near(cell, s.sign, 0.6)));
        if (id) talk(`lore_${id}`);
        else if (site) talk(`lore_${near(cell, site.hint ?? [-9, -9], 0.6) ? site.hint_id : site.sign_id}`);
      }
      return;
    }
    case 2: // the forge
      talk('forge', 120);
      gate('go_forge', 'scenes/forge.scene.json');
      return;
    case 11: // Pip's storybook
      talk('pip_book', 90);
      gate('go_pip', 'scenes/pip.scene.json');
      w.attach(c, 'script_Flagged', { hideWhen: 'pip_memory_done', showWhen: '', lookWhen: '', look: '' });
      return;
    case 14: // Maud's oven
      talk('maud_oven', 110);
      gate('go_maud', 'scenes/maud.scene.json');
      return;
    case 17: // the Margin Gate
      e.tags.push('margin-gate');
      talk('margin_gate', 120);
      return;
    case 3: // a Mnemosynth crystal
      w.attach(c, 'script_Collect', { flag: `got_C_${cell[0]}_${cell[1]}`, mnemo: 5, light: 12, radius: 30 / PX + 0.4 });
      return;
    case 16: {
      // a lantern post
      const wp = w.map.WAYPOINTS.find((p) => near(cell, p.cell, 0.6));
      w.attach(c, 'checkpoint', { name: wp?.name ?? 'Lantern Post', reach: 100 / PX + 0.4, lightRadius: 5, heals: true });
      e.tags.push('lantern-post');
      return;
    }
    case 10: {
      // a one-time pickup: "Take <name>"
      const item = String(node.props.item_id ?? '');
      const flag = `got_k_${cell[0]}_${cell[1]}`;
      const t = new Talk(`take_${cell[0]}_${cell[1]}`);
      const take = t.seq(t.give(item, 1), t.set(flag, 1), t.lines([line(`Received: ${w.items[item]?.name ?? item}`, 'sign')], w.keyed));
      w.write(t.name, t.data(t.when({ name: flag }, t.end(), take)[0]));
      talk(t.name);
      w.attach(c, 'script_Flagged', { hideWhen: flag, showWhen: '', lookWhen: '', look: '' });
      return;
    }
    case 18: {
      // a chest
      const key = cellKey(cell);
      const flag = `got_chest_${cell[0]}_${cell[1]}`;
      const t = new Talk(`chest_${cell[0]}_${cell[1]}`);
      const lines = (w.story.constants.CHEST_LINES as string[]) ?? [''];
      const chestLine = lines[(cell[0] * 7 + cell[1] * 13) % lines.length]!;
      const open = t.seq(t.set(flag, 1), t.set('renown', 5, 'add'), ...reward(t, w.rolls[key] ?? w.map.CHESTS[key] ?? 'mnemo:20', w), t.lines([line(chestLine)], w.keyed));
      const site = Object.entries(w.map.SITES).find(([, s]) => s.type !== 'crumble' && s.chest && cellKey(s.chest) === key)?.[0];
      const guarded = site ? t.when({ name: `site_${site}` }, open, t.lines([line('The chest is sealed. Something nearby is holding it shut.')], w.keyed)) : open;
      w.write(t.name, t.data(t.when({ name: flag }, t.lines([line('The chest is empty.')], w.keyed), guarded)[0]));
      talk(t.name, 90);
      return;
    }
    case 8: {
      // a doorway into a side room
      const pid = Object.entries(w.map.PORTALS).find(([, p]) => near(cell, p.cell, 0.8))?.[0];
      if (!pid) return;
      const p = w.map.PORTALS[pid]!;
      const t = new Talk(`portal_${pid}`);
      const start = t.when({ name: PORTAL_NEEDS[pid] ?? 'never' }, t.seq(t.lines([line(`You step into ${p.name}.`)], w.keyed), t.set(`go_${pid}`, 1)), t.lines([line(p.blurb), line(PORTAL_NEED_TEXT[pid] ?? 'It does not open yet.')], w.keyed));
      w.write(t.name, t.data(start[0]));
      talk(t.name, 90);
      gate(`go_${pid}`, PORTAL_SCENE[pid] ?? '');
      return;
    }
  }
}
