// The Storytender's own rules, ported from player.gd and main.gd: the lantern is held (Q / right mouse) and burns
// its fuel, creeping is slower and quieter, the quill only hits hard once Garrick gives it, echoes come with the
// forge memory, and Garrick's lesson (strike the dummy, dash, hold the lantern) is followed here.
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
    for (const v of ['mnemosynth', 'renown']) if (game.vars[v] === undefined) game.vars[v] = 0;
    me.state.off = 99;
    me.state.lesson = { hits: 0, dashed: false, lit: 0 };
  },
  update(me, game) {
    const v = game.vars;
    // rank, from renown (game_state.gd RANK_STEPS)
    const steps = [0, 40, 100, 180, 280, 400, 560, 760, 1000, 1300, 1650];
    const renown = Number(v.renown ?? 0);
    const rank = steps.filter((x) => renown >= x).length;
    if (v.rank !== rank) {
      v.rank = rank;
      v.rank_next = steps[Math.min(rank, steps.length - 1)]!;
    }
    // the name of the region, shown in the corner for a few seconds when it changes (hud.gd set_region)
    if (me.state.rows === undefined) {
      me.state.rows = String(me.settings.regions || '').split('|');
      try { me.state.names = me.settings.regionNames ? JSON.parse(String(me.settings.regionNames)) : {}; } catch { me.state.names = {}; }
      me.state.regionT = 0;
    }
    const letter = me.state.rows[Math.floor(me.y)]?.[Math.floor(me.x)] ?? '';
    const region = me.state.names[letter] ?? String(me.settings.place || '');
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
    const held = game.input.down('lantern') && Number(v.light) > 0;
    // lantern fuel: drains 24 a second while shining, comes back 14 a second after 0.9 s off (player.gd)
    if (held) {
      v.light = Math.max(0, Number(v.light) - 24 * game.dt);
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
      s *= Number(v.puddle_slow ?? 1); // a Run-on's ink trail (0.55)
      if (Number(v.slow_until ?? 0) > game.time) s *= 0.55; // a slowing word of the Critic
      if (pc.speed !== s) me.set('playerController', { ...pc, speed: s });
    }
    // the quill: the pencil stub hits for 0.55 of the quill's 2 until Garrick hands it over
    const melee = me.get('meleeAttack');
    if (melee) {
      const dmg = v.has_quill || v.has_sword ? 2 : 1.1;
      if (melee.damage !== dmg) me.set('meleeAttack', { ...melee, damage: dmg });
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
      for (const e of game.eventsOf('damaged')) {
        const t = game.find(`id:${e.entity}`);
        if (t && t.hasTag('dummy')) l.hits++;
      }
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
