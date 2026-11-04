// The Scissor-Man and the Cutting Room (editor_scissor.gd, scissor_man.gd). His verb is the clipboard: he cuts the arena apart along telegraphed lines.
// Each cut leaves clippings she can pick up (strike them) and paste back (V). A patched cell cannot be cut; if his line crosses a patch his
// shears jam and he can be hurt (90 ink). At two thirds and one third of it he sends little copies of the things that hurt.
//   the cells of the arena are covered by flat pictures (Cell x,y, tag scell) that show a cut line, a hole, a patch or where a paste would land
const K = 35.8;
const SHAPES: [number, number][][] = [
  [[0, 0]],
  [[0, 0], [1, 0], [2, 0]],
  [[0, 0], [0, 1], [0, 2]],
  [[0, 0], [1, 0], [0, 1]],
  [[0, 0], [1, 0], [0, 1], [1, 1]],
];
const SHAPE_TEXT = ['one page', 'a strip of three', 'a strip of three', 'a corner of three', 'a square of four'];
const PHASE_LINES = ['', 'He is cutting wider, and he has begun to cut out little copies of the things that hurt.', 'Two cuts at once. He does not enjoy this, but he cannot stop.'];
const MAX_CLIPPINGS = 4;
const key = (x: number, y: number): string => `${x},${y}`;

interface Cell { x: number; y: number; cut: number; patch: number; warn: boolean }
interface Line { cells: string[]; t: number }

export default defineScript({
  name: 'Scissor',
  description: 'The Scissor-Man: cuts the arena along marked lines; a patch on his line jams his shears.',
  settings: {
    lookCut: { value: '', label: 'His picture while the blades swing (sprite name; empty: unchanged)' },
    lookJam: { value: '', label: 'His picture while his shears are jammed (sprite name; empty: unchanged)' },
    lookHole: { value: '', label: 'Picture of a cut page (a hole)' },
    lookWarn: { value: '', label: 'Picture of a cell on a cut line' },
    lookPatch: { value: '', label: 'Picture of a patch' },
    lookGhost: { value: '', label: 'Picture of where a paste would land' },
    minions: { value: 5, label: 'Little copies waiting (scissor_minion_0 ...)' },
  },
  start(me, game) {
    const s = me.state;
    s.home = { x: me.x, y: me.y, h: me.h };
    s.cells = {} as Record<string, Cell>;
    s.over = {} as Record<string, ScriptEntity>;
    s.lines = [] as Line[];
    s.started = false;
    s.done = false;
    s.phase = 1;
    s.cd = 5;
    s.sweep = -1;
    s.jam = 0;
    s.idle = String(me.get('sprite')?.asset ?? '');
    s.move = null;
    s.held = -1;
    s.hp = -1;
    s.fall = 0;
    s.clang = 0;
    s.minions = {};
    game.vars.clip_held = 0;
    game.vars.clip_text = '';
  },
  update(me, game) {
    const v = game.vars;
    const s = me.state;
    const p = game.player;
    const dt = game.dt;
    if (!p) return;
    if (s.finale) {
      finale(me, game);
      return;
    }
    // the cells of the arena: the covers are found once
    if (!s.ready) {
      for (const o of game.findAll('tag:scell')) {
        const x = Math.floor(o.x);
        const y = Math.floor(o.y);
        s.cells[key(x, y)] = { x, y, cut: 0, patch: 0, warn: false };
        s.over[key(x, y)] = o;
      }
      s.ready = true;
      s.minX = Math.min(...Object.values<Cell>(s.cells).map((c) => c.x));
      s.maxX = Math.max(...Object.values<Cell>(s.cells).map((c) => c.x));
      s.minY = Math.min(...Object.values<Cell>(s.cells).map((c) => c.y));
      s.maxY = Math.max(...Object.values<Cell>(s.cells).map((c) => c.y));
    }
    const story = v.difficulty === 'story';
    const cells = s.cells as Record<string, Cell>;
    const pcell = key(Math.floor(p.x), Math.floor(p.y));
    const died = game.eventsOf('died').some((e) => ((e.tags as string[]) ?? []).includes('player'));
    if (died) reset(me, game);
    // ---- the boss's ink: only a jammed Scissor-Man can be hurt (the blades turn the Quill aside)
    const hs = me.get('state:health') as { hp: number; dead?: boolean } | undefined;
    const max = (me.get('health') as { max: number } | undefined)?.max ?? 90;
    if (hs) {
      if (s.hp < 0) s.hp = hs.hp;
      if (hs.hp < s.hp) {
        if (s.jam > 0) s.hp = hs.hp;
        else {
          me.set('state:health', { ...hs, hp: s.hp });
          if (s.clang <= 0) {
            s.clang = 1.5;
            game.say('Clang. His blades turn the Quill aside.');
          }
        }
      }
      s.clang -= dt;
      v.boss_hp = s.hp;
      v.boss_max = max;
      if (s.hp <= 0 && !s.finale) {
        s.finale = true;
        s.ft = 0;
        return;
      }
    }
    // ---- clippings: struck to be picked up
    for (const e of game.eventsOf('damaged')) {
      const c = game.findAll('tag:clipping').find((x) => x.id === e.entity);
      if (!c) continue;
      if (s.held >= 0) {
        game.say('Your clipboard is full. Paste it first (V).');
        const ch = c.get('state:health') as { hp: number } | undefined;
        if (ch) c.set('state:health', { ...ch, hp: 1 });
      } else {
        s.held = game.randomInt(0, SHAPES.length - 1);
        c.destroy();
        if (!s.first) {
          s.first = true;
          game.say('Patched paper will not be cut. Paste a clipping onto the line before he cuts it, and his shears will jam.');
        }
      }
    }
    v.clip_held = s.held >= 0 ? 1 : 0;
    v.clip_text = s.held >= 0 ? SHAPE_TEXT[s.held]! : '';
    // ---- paste: V puts the clipping on the page ahead (96 px along where she faces)
    const a = (p.facing * Math.PI) / 4;
    const sx = Math.cos(a);
    const sy = Math.sin(a);
    let gx = (sx + 2 * sy) / 2;
    let gy = (2 * sy - sx) / 2;
    const gn = Math.hypot(gx, gy) || 1;
    gx /= gn;
    gy /= gn;
    const ax = Math.floor(p.x + (gx * 96) / K);
    const ay = Math.floor(p.y + (gy * 96) / K);
    const target: string[] = s.held >= 0 ? SHAPES[s.held]!.map(([dx, dy]) => key(ax + dx, ay + dy)) : [];
    if (s.held >= 0 && game.input.pressed('paste')) {
      if (target.some((k) => !cells[k])) game.say("There's nowhere to paste that.");
      else {
        const life = story ? 26 : 18;
        for (const k of target) {
          cells[k]!.cut = 0;
          cells[k]!.patch = life;
        }
        s.held = -1;
        v.clip_held = 0;
        v.clip_text = '';
      }
    }
    // ---- the fight begins when she walks up the room
    if (!s.started) {
      if (Math.floor(p.y) <= 13) {
        s.started = true;
        v.boss_name = 'The Scissor-Man';
        game.startDialogue('scissor_boss_intro');
      }
      draw(me, game, target);
      return;
    }
    // ---- paper heals, patches wear off
    for (const c of Object.values(cells)) {
      if (c.cut > 0) c.cut -= dt;
      if (c.patch > 0) c.patch -= dt;
    }
    // ---- she falls through a cut page and is put back on the nearest whole one
    s.fall -= dt;
    if (cells[pcell] && cells[pcell]!.cut > 0 && cells[pcell]!.patch <= 0 && s.fall <= 0) {
      s.fall = 1;
      game.damage(p, 15);
      const near = Object.values<Cell>(cells).filter((c) => c.cut <= 0).sort((u, w) => Math.hypot(u.x + 0.5 - p.x, u.y + 0.5 - p.y) - Math.hypot(w.x + 0.5 - p.x, w.y + 0.5 - p.y))[0];
      if (near) p.moveTo(near.x + 0.5, near.y + 0.5);
      game.say('The paper gives way.');
    }
    // ---- his movement
    if (s.move) {
      const m = s.move as { fx: number; fy: number; tx: number; ty: number; t: number; d: number };
      m.t = Math.min(1, m.t + dt / m.d);
      const e = m.t * m.t * (3 - 2 * m.t);
      me.x = m.fx + (m.tx - m.fx) * e;
      me.y = m.fy + (m.ty - m.fy) * e;
      if (m.t >= 1) s.move = null;
    }
    // ---- the cuts
    if (s.jam > 0) {
      s.jam -= dt;
      if (s.jam <= 0) {
        s.cd = 3;
        game.say('He pulls the shears free.');
      }
    } else if (s.sweep >= 0) {
      s.sweep += dt;
      if (s.sweep >= 0.45 && !s.cutDone) {
        s.cutDone = true;
        resolve(me, game, story);
      }
      if (s.sweep >= 0.9) {
        s.sweep = -1;
        s.lines = [];
        s.cd = [6.5, 5.5, 5.0][s.phase - 1]! + (story ? 1.5 : 0);
      }
    } else if ((s.lines as Line[]).length === 0) {
      s.cd -= dt;
      if (s.cd <= 0) startSnip(me, game, story);
    } else {
      for (const l of s.lines as Line[]) l.t -= dt;
      if ((s.lines as Line[])[0]!.t <= 0) {
        s.sweep = 0;
        s.cutDone = false;
        const last = (s.lines as Line[])[0]!.cells.slice(-1)[0]!;
        const c = cells[last]!;
        s.move = { fx: me.x, fy: me.y, tx: c.x + 0.5, ty: c.y + 0.5, t: 0, d: 0.7 };
      }
    }
    // ---- phases: little copies of the things that hurt
    const frac = hs ? Math.max(0, s.hp) / max : 1;
    const phase = frac > 0.66 ? 1 : frac > 0.33 ? 2 : 3;
    if (phase !== s.phase) {
      s.phase = phase;
      game.say(PHASE_LINES[phase - 1]!);
      const wake = phase === 2 ? [0, 1] : [2, 3, 4];
      for (const i of wake) v[`scissor_minion_${i}`] = 1;
    }
    // ---- his picture
    const spr = me.get('sprite');
    const want = s.jam > 0 ? String(me.settings.lookJam) || s.idle : s.sweep >= 0 ? String(me.settings.lookCut) || s.idle : s.idle;
    if (spr && want && spr.asset !== want) me.set('sprite', { ...spr, asset: want });
    draw(me, game, target);
  },
});

/** A line is marked, and he walks to its start. */
function startSnip(me: ScriptEntity, game: ScriptGame, story: boolean): void {
  const s = me.state;
  const p = game.player!;
  const cells = s.cells as Record<string, Cell>;
  const width = s.phase === 2 ? 2 : 1;
  const count = s.phase === 3 ? 2 : 1;
  const lines: Line[] = [];
  let horizontal = game.random() < 0.5;
  for (let i = 0; i < count; i++) {
    const idx = horizontal
      ? Math.max(s.minY + 1, Math.min(s.maxY - width, Math.floor(p.y) + game.randomInt(-3, 3)))
      : Math.max(s.minX + 1, Math.min(s.maxX - width, Math.floor(p.x) + game.randomInt(-3, 3)));
    const list = Object.values<Cell>(cells).filter((c) => (horizontal ? c.y : c.x) >= idx && (horizontal ? c.y : c.x) < idx + width).sort((u, w) => (horizontal ? u.x - w.x : u.y - w.y));
    lines.push({ cells: list.map((c) => key(c.x, c.y)), t: story ? 3.8 : 3.0 });
    horizontal = !horizontal;
  }
  for (const l of lines) for (const k of l.cells) if (cells[k]!.patch <= 0) cells[k]!.warn = true;
  s.lines = lines;
  const f = cells[lines[0]!.cells[0]!]!;
  s.move = { fx: me.x, fy: me.y, tx: f.x + 0.5, ty: f.y + 0.5, t: 0, d: 1.2 };
  game.say('He is going to cut along the marked line.');
}

/** The blades come down: marked cells fall away, unless a patch is on the line, which jams his shears. */
function resolve(me: ScriptEntity, game: ScriptGame, story: boolean): void {
  const s = me.state;
  const cells = s.cells as Record<string, Cell>;
  let jammed = false;
  let n = 0;
  for (const l of s.lines as Line[]) {
    for (const k of l.cells) {
      const c = cells[k]!;
      c.warn = false;
      if (c.patch > 0) {
        jammed = true;
        continue;
      }
      if (c.cut <= 0) {
        c.cut = story ? 8 : 11;
        n++;
      }
    }
  }
  // what he cuts out stays behind as clippings
  const have = game.findAll('tag:clipping').length;
  for (let i = 0; i < Math.min(2, Math.floor(n / 3) + 1) && have + i < MAX_CLIPPINGS; i++) {
    const free = Object.values<Cell>(cells).filter((c) => c.cut <= 0 && Math.hypot(c.x + 0.5 - game.player!.x, c.y + 0.5 - game.player!.y) > 2);
    const at = free[game.randomInt(0, free.length - 1)];
    if (at) game.spawn('ClippingPiece', at.x + 0.5, at.y + 0.5, me.h);
  }
  if (jammed) {
    s.jam = story ? 7 : 5.5;
    s.lines = [];
    s.sweep = -1;
    game.say('The shears are caught in the patch. Now!');
  }
}

/** Everything back as it was when she falls (nothing of the fight is kept). */
function reset(me: ScriptEntity, game: ScriptGame): void {
  const s = me.state;
  if (!s.started) return;
  for (const c of Object.values<Cell>(s.cells)) {
    c.cut = 0;
    c.patch = 0;
    c.warn = false;
  }
  s.lines = [];
  s.sweep = -1;
  s.jam = 0;
  s.cd = 5;
  s.held = -1;
  s.move = { fx: me.x, fy: me.y, tx: s.home.x, ty: s.home.y, t: 0, d: 1 };
  for (let i = 0; i < Number(me.settings.minions); i++) game.vars[`scissor_minion_${i}`] = 0;
  game.emit('error-reset', { tag: 'scissor-minion' });
  const hs = me.get('state:health') as { hp: number } | undefined;
  const max = (me.get('health') as { max: number } | undefined)?.max ?? 90;
  if (hs) me.set('state:health', { ...hs, hp: max });
  s.hp = max;
  s.phase = 1;
  for (const c of game.findAll('tag:clipping')) if (c.hasTag('spawned')) c.destroy();
}

/** The covers show what the paper is doing. */
function draw(me: ScriptEntity, game: ScriptGame, ghost: string[]): void {
  const s = me.state;
  const cells = s.cells as Record<string, Cell>;
  const looks = { hole: String(me.settings.lookHole), warn: String(me.settings.lookWarn), patch: String(me.settings.lookPatch), ghost: String(me.settings.lookGhost) };
  for (const [k, c] of Object.entries(cells)) {
    const o = (s.over as Record<string, ScriptEntity>)[k];
    const spr = o?.get('sprite');
    if (!o || !spr) continue;
    const ok = ghost.includes(k);
    const want = c.patch > 0 ? 'patch' : ok ? 'ghost' : c.cut > 0 ? 'hole' : c.warn ? 'warn' : '';
    if (s.shown?.[k] === want) continue;
    (s.shown ??= {})[k] = want;
    o.set('sprite', { ...spr, visible: want !== '', ...(want ? { asset: looks[want as keyof typeof looks] } : {}) });
  }
}

/** Beaten: the room settles, he is told what he is, and she takes the Thimble home. */
function finale(me: ScriptEntity, game: ScriptGame): void {
  const s = me.state;
  const v = game.vars;
  s.ft += game.dt;
  if (s.ft < 0.05) {
    for (const c of Object.values<Cell>(s.cells)) {
      c.cut = 0;
      c.patch = 0;
      c.warn = false;
    }
    draw(me, game, []);
    for (let i = 0; i < Number(me.settings.minions); i++) v[`scissor_minion_${i}`] = 0;
    v.boss_name = '';
    v.clip_held = 0;
  }
  if (s.ft > 1.4 && !s.said) {
    s.said = true;
    game.startDialogue('scissor_finale');
  }
  if (v.scissor_finale_done && !s.paid) {
    s.paid = true;
    game.giveItem('thimble', 1);
    v.scissor_done = 1;
    v.mnemosynth = Number(v.mnemosynth ?? 0) + 60;
    v.renown = Number(v.renown ?? 0) + 40;
    game.say('Received: The Thimble, 60 Mnemosynth');
    s.leaveAt = s.ft + 2.4;
  }
  me.alpha = Math.max(0, me.alpha - game.dt * 0.45);
  if (s.paid && s.ft >= s.leaveAt && !s.left) {
    s.left = true;
    game.do('saveGame', { slot: 'autosave' });
    game.travel('scenes/overworld.scene.json', '88.5,54.5');
  }
}
