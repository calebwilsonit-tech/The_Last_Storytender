// The Storytender's own rules, ported from player.gd and main.gd: the lantern is held (Q / right mouse) and burns
// its fuel, creeping is slower and quieter, the quill only hits hard once Garrick gives it, echoes come with the
// forge memory, Garrick's lesson (strike the dummy, dash, hold the lantern) is followed here, and so are the effects
// of the items she uses (level_base.gd use_item).
const K = 35.8; // the game's ground pixels per cell
const ATTR_VARS = ['attr_ink', 'attr_grit', 'attr_pen', 'attr_wit', 'attr_foot', 'attr_luck', 'attr_points', 'free_points', 'b_ink_1', 'b_grit_1', 'b_pen_1', 'b_pen_2', 'b_wit_1', 'b_wit_2', 'b_foot_1', 'b_foot_2', 'b_luck_1', 'b_luck_2'];
const CRUMPLED = 'A crumpled page can be smoothed. That is the whole trick of it.';
const FALL_FIRST = 'And so the Storytender learned that plot holes are, in fact, holes.';
const TOWN = [87.5, 53.5];
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
    equipFx: { value: '', label: 'What each binding and amulet does (JSON: item -> stat -> amount)' },
  },
  start(me, game) {
    if (game.vars.light === undefined) game.vars.light = 100;
    for (const v of ['mnemosynth', 'renown', 'saved_run', 'weights']) if (game.vars[v] === undefined) game.vars[v] = 0;
    for (const v of ATTR_VARS) if (game.vars[v] === undefined) game.vars[v] = 0;
    if (game.vars.level === undefined) game.vars.level = 1;
    for (const [i, t] of ['Damage taken   no change', 'Move speed   no change', 'Dash cooldown   no change', 'Grace after a hit   0.9s', 'Quill damage   no change    Reach   no change', 'Lantern burn   no change    Ink regen   0.0/s'].entries()) if (game.vars[`st${i}`] === undefined) game.vars[`st${i}`] = t;
    if (game.vars.boss_name === undefined) game.vars.boss_name = '';
    game.vars.dungeon_menu = me.settings.regions ? 0 : 1; // the pause menu of a memory or a side room offers Travel and Restart
    for (const k of ['slot:1', 'slot:2']) if (game.vars[k] === undefined) game.vars[k] = '';
    if (game.vars.attr_cost === undefined) game.vars.attr_cost = 20;
    if (game.vars.index_pick === undefined) game.vars.index_pick = 'ink';
    me.state.off = 99;
    me.state.start = { x: me.x, y: me.y }; // where a memory or side room puts her back when she crumples with no post of its own rested at
    me.state.lesson = { hits: 0, dashed: false, lit: 0 };
  },
  update(me, game) {
    const v = game.vars;
    v.boss_on = v.boss_name ? 1 : 0; // the boss bar shows while a boss script has named itself
    // what the points bought at a lantern post (Revise Your Draft) do, and what she does when she rests
    const stat = (k: string): number => Number(v[`attr_${k}`] ?? 0);
    const dt = game.dt;
    // what is worn (the binder sets worn_binding and worn_amulet to an item's id) adds to the points bought (item_catalog.gd fx, game_state.gd equipped_stat)
    if (me.state.fx === undefined) {
      try { me.state.fx = JSON.parse(String(me.settings.equipFx || '{}')); } catch { me.state.fx = {}; }
    }
    const worn = [v.worn_binding, v.worn_amulet].map((id) => (me.state.fx as Record<string, Record<string, number>>)[String(id ?? '')] ?? {});
    const eq = (k: string): number => worn.reduce((n, f) => n + Number(f[k] ?? 0), 0);
    const armor = Math.min(0.75, Math.max(0, 0.005 * stat('grit') + eq('armor')));
    const regen = 0.025 * stat('wit') + eq('regen');
    const burn = Math.max(0.1, 1 - 0.005 * stat('wit') + eq('lantern_eff'));
    const speedMul = 1 + 0.003 * stat('foot') + eq('speed');
    const dashMul = Math.max(0.2, 1 - 0.005 * stat('foot') + eq('dash_cd'));
    const dmgMul = 1 + 0.01 * stat('pen') + eq('dmg');
    const reachMul = 1 + 0.0025 * stat('pen') + eq('reach');
    const grace = 0.9 + eq('invuln');
    v.stat_luck = 0.005 * stat('luck') + eq('luck');
    v.stat_mnemo = 0.0025 * stat('luck') + eq('mnemo');
    v.stat_renown = eq('renown');
    // the binder's list of what she is wearing does
    const pct = (x: number): string => (Math.abs(x) < 0.0005 ? 'no change' : `${x > 0 ? '+' : ''}${Math.round(x * 100)}%`);
    const lines = [`Damage taken   ${pct(-armor)}`, `Move speed   ${pct(speedMul - 1)}`, `Dash cooldown   ${pct(dashMul - 1)}`, `Grace after a hit   ${grace.toFixed(1)}s`, `Quill damage   ${pct(dmgMul - 1)}    Reach   ${pct(reachMul - 1)}`, `Lantern burn   ${pct(burn - 1)}    Ink regen   ${regen.toFixed(1)}/s`];
    lines.forEach((t, i) => { if (v[`st${i}`] !== t) v[`st${i}`] = t; });
    v.level = 1 + ['ink', 'grit', 'pen', 'wit', 'foot', 'luck'].reduce((n, k) => n + stat(k), 0);
    const ink = me.get('health') as { max: number } | undefined;
    const maxInk = 100 + 2 * stat('ink'); // Inkwell: +2 maximum ink a point
    const hurt = me.get('state:health') as { hp: number; dead?: boolean } | undefined;
    // falls: 8 in Story, 15 in Normal, and never the last of her ink (player.gd)
    const fall = Math.max(0, Math.min(v.difficulty === 'story' ? 8 : 15, (hurt?.hp ?? 100) - 1));
    const h0 = ink as { max: number; invulnerableSeconds?: number; fallDamage?: number; onDeath?: string } | undefined;
    // in a memory or a side room the engine would carry her to the last post she rested at, which is out on the overworld (a checkpoint belongs to one
    // scene): there she stays down, and this script stands her up again inside (below)
    const dungeon = !me.settings.regions;
    const dies = dungeon ? 'stay' : h0?.onDeath;
    if (h0 && (h0.max !== maxInk || h0.invulnerableSeconds !== grace || h0.fallDamage !== fall || h0.onDeath !== dies)) me.set('health', { ...h0, max: maxInk, invulnerableSeconds: grace, fallDamage: fall, onDeath: dies });
    if (hurt && !hurt.dead && hurt.hp > 0) {
      let hp = hurt.hp;
      // Thick Paper: -0.5% damage taken a point (what a blow took is given back at once)
      for (const e of game.eventsOf('damaged')) if (e.entity === me.id) hp += Number(e.amount ?? 0) * armor;
      hp += regen * dt; // ink regeneration: Wit and what she wears
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
    // the first visit to a region (other than the start, the town's edge and the orchard's lane): +10 Mnemosynth, +6 renown (main.gd _update_region)
    if (me.settings.regions && letter !== me.state.letter) {
      me.state.letter = letter;
      if (letter && letter !== ' ' && !v[`seen_${letter}`]) {
        v[`seen_${letter}`] = 1;
        if (!['m', 's', 'o'].includes(letter) && me.state.names[letter]) {
          v.mnemosynth = Number(v.mnemosynth ?? 0) + 10;
          v.renown = Number(v.renown ?? 0) + 6;
          game.say(`Discovered: ${me.state.names[letter]}`);
        }
      }
    }
    if (region && region !== v.region_name) {
      v.region_name = region;
      v.region_show = 1;
      me.state.regionT = 3.5;
    } else if (me.state.regionT > 0 && (me.state.regionT -= game.dt) <= 0) v.region_show = 0;
    // ---- falling and crumpling (player.gd, main.gd _on_crumpled, FLOW_SPEC 2)
    const prev = me.state.prev as { x: number; y: number } | undefined;
    if (game.eventsOf('pit-recovered').length > 0 && !v[`fall_seen_${me.settings.place || 'overworld'}`]) {
      v[`fall_seen_${me.settings.place || 'overworld'}`] = 1;
      game.say(FALL_FIRST);
    }
    if (game.eventsOf('died').some((e) => ((e.tags as string[]) ?? []).includes('player')) && prev) {
      const story = v.difficulty === 'story';
      v.crumples = Number(v.crumples ?? 0) + 1;
      game.say(CRUMPLED);
      // Story: back with 100 ink; Normal: 50 ink, and a seventh of what she carried is left where she fell, as crystals of 5
      const hs2 = me.get('state:health') as { hp: number } | undefined;
      if (hs2) me.set('state:health', { ...hs2, hp: Math.min(maxInk, story ? 100 : 50), ...(dungeon ? { dead: false, iframes: 1.5, knock: null, trail: [] } : {}) });
      // a dungeon's own last post, else where she came in
      if (dungeon) {
        const at = (me.state.post as { x: number; y: number } | undefined) ?? (me.state.start as { x: number; y: number });
        me.moveTo(at.x, at.y);
      }
      if (!story) {
        const lost = Math.floor((Number(v.mnemosynth ?? 0) * 0.15) / 5) * 5;
        if (lost > 0) {
          v.mnemosynth = Number(v.mnemosynth) - lost;
          for (let i = 0; i < lost / 5; i++) {
            const c = game.spawn('DroppedCrystal', prev.x + (game.random() - 0.5) * 1.4, prev.y + (game.random() - 0.5) * 0.7, me.h);
            // what she lost comes back as it was: no bonus on top, or dying would pay
            const cs = c?.get('script_Collect');
            if (c && cs) c.set('script_Collect', { ...cs, bonus: false });
          }
        }
      }
      // the page resets: the Errors come back (once she is away from them), the echoes go
      game.emit('error-reset', { tag: 'error' });
      for (const e of game.findAll('tag:echo')) e.destroy();
      // with no post rested at she wakes at the start; one that fell in the town wakes in the town's square instead
      if (!v.rested_once && me.settings.regions && me.state.rows[Math.floor(prev.y)]?.[Math.floor(prev.x)] === 't') me.moveTo(TOWN[0]!, TOWN[1]!);
    }
    for (const e of game.eventsOf('rested')) {
      v.rested_once = 1;
      const post = game.findAll('tag:lantern-post').find((x) => x.id === e.entity);
      if (post) me.state.post = { x: post.x, y: post.y + 1 }; // she wakes one cell in front of it, as the engine does
    }
    me.state.prev = { x: me.x, y: me.y };
    // only things that can be used belong in the quick slots (a picked-up scrap is not one)
    for (const k of ['slot:1', 'slot:2']) if (v[k] && !USES[String(v[k])] && v[k] !== 'eraser_crumbs') v[k] = '';
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
      v.light = Math.max(0, Number(v.light) - 24 * burn * game.dt); // Wit and what she wears
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
      s *= speedMul; // Footwork and what she wears
      s *= Number(v.puddle_slow ?? 1); // a Run-on's ink trail (0.55)
      if (Number(v.slow_until ?? 0) > game.time) s *= 0.55; // a slowing word of the Critic
      if (pc.speed !== s) me.set('playerController', { ...pc, speed: s });
    }
    // the quill: the pencil stub hits for 0.55 of the quill's 2 until Garrick hands it over
    const melee = me.get('meleeAttack');
    if (melee) {
      // Penmanship: +1% damage and +0.25% reach a point
      const dmg = (v.has_quill || v.has_sword ? 2 : 1.1) * dmgMul;
      const range = 2.1 * reachMul;
      if (melee.damage !== dmg || melee.range !== range) me.set('meleeAttack', { ...melee, damage: dmg, range });
    }
    const dodge = me.get('dodge');
    if (dodge) {
      const cooldown = 0.75 * dashMul;
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
  game.do('sound', { name: u.ink ? 'heal' : 'item_use', volume: 1 });
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
