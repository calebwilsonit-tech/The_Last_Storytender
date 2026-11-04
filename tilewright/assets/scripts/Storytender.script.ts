// The Storytender's own rules, ported from player.gd and main.gd: the lantern is held (Q / right mouse) and burns
// its fuel, creeping is slower and quieter, the quill only hits hard once Garrick gives it, echoes come with the
// forge memory, Garrick's lesson (strike the dummy, dash, hold the lantern) is followed here, and so are the effects
// of the items she uses (level_base.gd use_item).
const K = 35.8; // the game's ground pixels per cell
const ATTR_VARS = ['attr_ink', 'attr_grit', 'attr_pen', 'attr_wit', 'attr_foot', 'attr_luck', 'attr_points', 'free_points', 'b_ink_1', 'b_grit_1', 'b_pen_1', 'b_pen_2', 'b_wit_1', 'b_wit_2', 'b_foot_1', 'b_foot_2', 'b_luck_1', 'b_luck_2'];
const INDEX_FIRST = 'Every lantern post keeps a page of the Index: a bench to mend things on, a stall run by a voice, and a map of everywhere you have been.';
/** What each usable item does (item_catalog.gd "use"); `none` is the toast when it would do nothing right now. */
const USES: Record<string, { ink?: number; lantern?: number; sleep?: number; radius?: number; renown?: number; mnemo?: number; msg: string; none?: string }> = {
  ink_vial: { ink: 45, msg: 'Ink restored', none: 'Your ink is already full' },
  warm_loaf: { ink: 60, msg: 'A warm loaf. You feel looked after.', none: 'Your ink is already full' },
  ink_flask: { ink: 9999, msg: 'Ink flask: all your ink is back', none: 'Your ink is already full' },
  lantern_oil: { lantern: 100, msg: 'The Lantern burns bright', none: 'The Lantern is already full' },
  herbal_tea: { ink: 25, lantern: 25, msg: 'Warm tea. You feel looked after.' },
  honey_biscuit: { ink: 30, msg: 'Sweet, crumbly, and exactly enough.' },
  clarity_tonic: { ink: 40, lantern: 100, msg: 'Everything is suddenly very clear.' },
  ghost_pepper_ink: { sleep: 4, radius: 280, msg: 'Nearby Errors forget how to move.' },
  reader_digest: { renown: 12, msg: 'You skim your own legend and feel a bit taller.' },
  memory_jar: { mnemo: 60, msg: "The jar opens. Someone's afternoon floats out." },
  phoenix_draught: { ink: 9999, lantern: 100, msg: 'You burn bright and begin again.' },
  time_in_a_bottle: { sleep: 9, radius: 360, msg: 'The page holds its breath.' },
  sticky_note: { sleep: 6, radius: 240, msg: 'Stuck to the page', none: 'Nothing nearby to stick' },
};
export default defineScript({
  name: 'Storytender',
  description: 'The Storytender: lantern, creeping, quill power, echoes and the lesson.',
  settings: {
    speed: { value: 4.2, label: 'Walking speed (cells per second)' },
    lanternRadius: { value: 4.9, label: 'Lantern reach (cells)' },
    regions: { value: '', label: 'Region map: one letter per cell, rows split by |' },
    regionNames: { value: '', label: 'Region names (JSON: letter -> name)' },
    place: { value: '', label: 'Name of this place (when there is no region map)' },
    echoesHere: { value: 0, label: 'Echoes she has here before the forge memory is done' },
  },
  start(me, game) {
    if (game.vars.light === undefined) game.vars.light = 100;
    for (const v of ['mnemosynth', 'renown', 'saved_run']) if (game.vars[v] === undefined) game.vars[v] = 0;
    for (const v of ATTR_VARS) if (game.vars[v] === undefined) game.vars[v] = 0;
    if (game.vars.level === undefined) game.vars.level = 1;
    if (game.vars.boss_name === undefined) game.vars.boss_name = '';
    for (const k of ['slot:1', 'slot:2']) if (game.vars[k] === undefined) game.vars[k] = '';
    if (game.vars.attr_cost === undefined) game.vars.attr_cost = 20;
    if (game.vars.index_pick === undefined) game.vars.index_pick = 'ink';
    me.state.off = 99;
    me.state.lesson = { hits: 0, dashed: false, lit: 0 };
  },
  update(me, game) {
    const v = game.vars;
    v.boss_on = v.boss_name ? 1 : 0; // the boss bar shows while a boss script has named itself
    // what the points bought at a lantern post (Revise Your Draft) do, and what she does when she rests
    const stat = (k: string): number => Number(v[`attr_${k}`] ?? 0);
    const dt = game.dt;
    v.level = 1 + ['ink', 'grit', 'pen', 'wit', 'foot', 'luck'].reduce((n, k) => n + stat(k), 0);
    const ink = me.get('health') as { max: number } | undefined;
    const maxInk = 100 + 2 * stat('ink'); // Inkwell: +2 maximum ink a point
    if (ink && ink.max !== maxInk) me.set('health', { ...ink, max: maxInk });
    const hurt = me.get('state:health') as { hp: number; dead?: boolean } | undefined;
    if (hurt && !hurt.dead && hurt.hp > 0) {
      let hp = hurt.hp;
      // Thick Paper: -0.5% damage taken a point (what a blow took is given back at once)
      for (const e of game.eventsOf('damaged')) if (e.entity === me.id) hp += Number(e.amount ?? 0) * 0.005 * stat('grit');
      // Wit: +0.025 ink a second a point
      hp += 0.025 * stat('wit') * dt;
      hp = Math.min(maxInk, hp);
      if (hp !== hurt.hp) me.set('state:health', { ...hurt, hp });
    }
    // resting at a post: the lantern is full again, and the first time the Index is explained and fifteen points are given (main.gd _rest)
    if (game.eventsOf('rested').length > 0) {
      v.light = 100;
      if (!v.index_seen) {
        v.index_seen = 1;
        v.free_points = 15;
        game.say(INDEX_FIRST);
        me.state.indexAt = game.time + 1.6;
      } else me.state.indexAt = game.time + 0.25;
    }
    if (me.state.indexAt && game.time >= me.state.indexAt) {
      me.state.indexAt = 0;
      game.do('uiScreen', { op: 'open', screen: 'storytender-index' });
    }
    // the name of the region, shown in the corner for a few seconds when it changes (hud.gd set_region)
    if (me.state.rows === undefined) {
      me.state.rows = String(me.settings.regions || '').split('|');
      try { me.state.names = me.settings.regionNames ? JSON.parse(String(me.settings.regionNames)) : {}; } catch { me.state.names = {}; }
      me.state.regionT = 0;
    }
    const letter = me.state.rows[Math.floor(me.y)]?.[Math.floor(me.x)] ?? '';
    let region = me.state.names[letter] ?? String(me.settings.place || '');
    if (letter === 't' && me.state.names.t) region = v.town_published ? 'Thistledown — Prologue complete' : 'Thistledown (Draft)'; // main.gd _update_region
    if (region && region !== v.region_name) {
      v.region_name = region;
      v.region_show = 1;
      me.state.regionT = 3.5;
    } else if (me.state.regionT > 0 && (me.state.regionT -= game.dt) <= 0) v.region_show = 0;
    // two quick slots (slot:1 and slot:2): F uses the active one, G swaps which is active
    if (game.input.pressed('quick_switch')) v.quick_active = v.quick_active ? 0 : 1;
    if (game.input.pressed('use_item')) {
      const item = String(v[`slot:${v.quick_active ? 2 : 1}`] ?? '');
      if (item) game.do('useItem', { item });
    }
    // items she used (the porter gives each one use_<id>): ink, lantern, sleep, renown and Mnemosynth, or the thrown crumbs
    for (const id of Object.keys(USES)) if (v[`use_${id}`]) { v[`use_${id}`] = 0; useItem(me, game, id); }
    if (v.use_eraser_crumbs) { v.use_eraser_crumbs = 0; throwCrumbs(me, game); }
    stepBombs(me, game);
    const held = game.input.down('lantern') && Number(v.light) > 0;
    // lantern fuel: drains 24 a second while shining, comes back 14 a second after 0.9 s off (player.gd)
    if (held) {
      v.light = Math.max(0, Number(v.light) - 24 * (1 - 0.005 * stat('wit')) * game.dt); // Wit: -0.5% burn a point
      me.state.off = 0;
    } else {
      me.state.off += game.dt;
      if (me.state.off > 0.9) v.light = Math.min(100, Number(v.light) + 14 * game.dt);
    }
    const light = me.get('light');
    if (light) me.set('light', { ...light, radius: held ? Number(me.settings.lanternRadius) : 1.2, intensity: held ? 1 : 0.35 });
    v.lantern_on = held ? 1 : 0;
    // speed: x0.72 with the lantern up, x0.55 creeping, x0.55 in ink
    const pc = me.get('playerController');
    if (pc) {
      let s = Number(me.settings.speed);
      if (held) s *= 0.72;
      if (game.input.down('sneak')) s *= 0.55;
      s *= 1 + 0.003 * stat('foot'); // Footwork: +0.3% speed a point
      s *= Number(v.puddle_slow ?? 1); // a Run-on's ink trail (0.55)
      if (Number(v.slow_until ?? 0) > game.time) s *= 0.55; // a slowing word of the Critic
      if (pc.speed !== s) me.set('playerController', { ...pc, speed: s });
    }
    // the quill: the pencil stub hits for 0.55 of the quill's 2 until Garrick hands it over
    const melee = me.get('meleeAttack');
    if (melee) {
      // Penmanship: +1% damage and +0.25% reach a point
      const dmg = (v.has_quill || v.has_sword ? 2 : 1.1) * (1 + 0.01 * stat('pen'));
      const range = 2.1 * (1 + 0.0025 * stat('pen'));
      if (melee.damage !== dmg || melee.range !== range) me.set('meleeAttack', { ...melee, damage: dmg, range });
    }
    const dodge = me.get('dodge');
    if (dodge) {
      const cooldown = 0.75 * (1 - 0.005 * stat('foot')); // Footwork: -0.5% dash cooldown a point
      if (dodge.cooldown !== cooldown) me.set('dodge', { ...dodge, cooldown });
    }
    // echoes: two once the forge memory is done, three with the Locket (echo_third)
    const echo = me.get('echoRecorder');
    if (echo) {
      const cap = v.memory_done ? (v.echo_third ? 3 : 2) : Number(me.settings.echoesHere ?? 0);
      if (echo.capacity !== cap) me.set('echoRecorder', { ...echo, capacity: cap });
    }
    // format styles (1 2 3), once Maud's memory grants them
    if (v.format_mark) {
      if (game.input.pressed('style_underline')) v.format_style = 'underline';
      if (game.input.pressed('style_bold')) v.format_style = 'bold';
      if (game.input.pressed('style_italic')) v.format_style = 'italic';
    }
    // Garrick's lesson: three strikes on the dummy, one dash, the lantern held 1.2 s
    if (v.has_quill && !v.lesson_done) {
      const l = me.state.lesson;
      // the combat plugin's 'damaged' event names the hurt object by its runtime id, which is what a script object's .id is
      // (game.find('id:..') takes the scene id instead, and found nothing here)
      const dummies = game.findAll('tag:dummy').map((d) => d.id);
      for (const e of game.eventsOf('damaged')) if (dummies.includes(e.entity as never)) l.hits++;
      if (game.eventsOf('dodge').length > 0) l.dashed = true;
      if (held) l.lit += game.dt;
      const step = l.hits < 3 ? 1 : !l.dashed ? 2 : l.lit < 1.2 ? 3 : 4;
      if (step !== me.state.step) {
        me.state.step = step;
        if (step < 4) {
          v.lesson_step = step;
          if (step > 1) game.startDialogue(`garrick_lesson_hint_${step}`);
        } else {
          v.lesson_done = 1;
          game.giveItem('hardcover_binding', 1);
          game.giveItem('eraser_crumbs', 2);
          v.mnemosynth = Number(v.mnemosynth) + 20;
          game.startDialogue('garrick_lesson_end');
          game.say('Lesson complete');
        }
      }
    }
  },
});

/** Use one of the effects in USES; the item is only used up when it does something (the game says "nothing to gain" otherwise). */
function useItem(me: ScriptEntity, game: ScriptGame, id: string): void {
  const u = USES[id]!;
  if (game.itemCount(id) <= 0) return;
  const v = game.vars;
  let did = false;
  if (u.ink) {
    const hs = me.get('state:health') as { hp: number } | undefined;
    const max = (me.get('health') as { max: number } | undefined)?.max ?? 100;
    if (hs && hs.hp < max - 0.5) {
      game.heal(me, Math.min(u.ink, max - hs.hp));
      did = true;
    }
  }
  if (u.lantern && Number(v.light) < 99) {
    v.light = Math.min(100, Number(v.light) + u.lantern);
    did = true;
  }
  let msg = u.msg;
  if (u.sleep) {
    let n = 0;
    for (const e of game.findAll('tag:error')) {
      if (!e.visible || e.hasTag('friendly') || me.distanceTo(e) > (u.radius ?? 240) / K) continue;
      e.tags.add(`sleep:${u.sleep}`); // the Error reads this and dozes (Error.script.ts: another object's state cannot be reached)
      n++;
    }
    if (n > 0) did = true;
    if (id === 'sticky_note') msg = `Stuck ${n} Error${n === 1 ? '' : 's'} to the page`;
  }
  if (u.renown) {
    v.renown = Number(v.renown ?? 0) + u.renown;
    did = true;
  }
  if (u.mnemo) {
    v.mnemosynth = Number(v.mnemosynth ?? 0) + u.mnemo;
    did = true;
  }
  if (!did) {
    game.say(u.none ?? "That wouldn't do anything right now");
    return;
  }
  game.do('takeItem', { item: id, amount: 1 });
  game.say(msg);
}

interface Bomb { e: ScriptEntity | undefined; t: number; x0: number; y0: number; h0: number; x1: number; y1: number; done: boolean }

/** Eraser Crumbs: thrown 150 px the way she faces (shortened until it lands on the page), 0.5 s in the air, 0.45 s of fizzing, then everything within 85 px takes 5. */
function throwCrumbs(me: ScriptEntity, game: ScriptGame): void {
  if (game.itemCount('eraser_crumbs') <= 0) return;
  // her facing is a screen direction; make it a grid one (a grid step (dx, dy) moves the screen by (dx - dy, (dx + dy) / 2))
  const a = (me.facing * Math.PI) / 4;
  const sx = Math.cos(a);
  const sy = Math.sin(a);
  let gx = (sx + 2 * sy) / 2;
  let gy = (2 * sy - sx) / 2;
  const n = Math.hypot(gx, gy) || 1;
  gx /= n;
  gy /= n;
  let reach = 150 / K;
  while (reach > 30 / K && !game.findPath({ x: me.x, y: me.y }, { x: me.x + gx * reach, y: me.y + gy * reach })) reach -= 25 / K;
  game.do('takeItem', { item: 'eraser_crumbs', amount: 1 });
  const list = (me.state.bombs ??= []) as Bomb[];
  list.push({ e: game.spawn('EraserBomb', me.x, me.y, me.h), t: 0, x0: me.x, y0: me.y, h0: me.h, x1: me.x + gx * reach, y1: me.y + gy * reach, done: false });
}

function stepBombs(me: ScriptEntity, game: ScriptGame): void {
  const list = me.state.bombs as Bomb[] | undefined;
  if (!list || list.length === 0) return;
  for (const b of list) {
    b.t += game.dt;
    const p = Math.min(1, b.t / 0.5);
    if (b.e?.alive) {
      b.e.x = b.x0 + (b.x1 - b.x0) * p;
      b.e.y = b.y0 + (b.y1 - b.y0) * p;
      b.e.h = b.h0 + Math.sin(Math.PI * p) * 1.4;
    }
    if (!b.done && b.t >= 0.95) {
      b.done = true;
      for (const tag of ['error', 'dummy']) {
        for (const t of game.findAll(`tag:${tag}`)) {
          if (!t.visible || Math.hypot(t.x - b.x1, t.y - b.y1) > 85 / K + 0.45) continue;
          game.damage(t, 5);
        }
      }
      if (b.e?.alive) b.e.alpha = 0.5;
    }
    if (b.t >= 1.5) b.e?.destroy();
  }
  me.state.bombs = list.filter((b) => b.t < 1.5);
}
