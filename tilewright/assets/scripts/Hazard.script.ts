// One sentence the Spoiler reads aloud (memory_pip.gd _spawn_spoiler_event): its cells are marked while it reads; strike
// the book before it finishes and the sentence is rewritten into flowers that heal (8 s). Otherwise it comes true: the
// floor collapses (14 damage to whoever stands there, then a gap for 7 s), lightning strikes (16), or Mites pour in.
export default defineScript({
  name: 'Hazard',
  description: "A sentence of the Spoiler's coming true unless it is rewritten.",
  settings: {
    kind: { value: 'lightning', label: 'collapse, lightning or wolves' },
    window: { value: 5.6, label: 'Seconds before it comes true' },
  },
  start(me) {
    me.state.t = Number(me.settings.window);
    me.state.phase = 'warn';
  },
  update(me, game) {
    const s = me.state;
    const p = game.player;
    const mult = game.vars.difficulty === 'story' ? 0.6 : 1;
    const inside = !!p && Math.abs(p.x - me.x) < 1.5 && Math.abs(p.y - me.y) < 1.5;
    s.t -= game.dt;
    const spr = me.get('sprite');
    const look = (asset: string): void => { if (spr && asset && spr.asset !== asset) me.set('sprite', { ...spr, asset }); };
    if (s.phase === 'warn') {
      me.alpha = 0.35 + 0.25 * Math.abs(Math.sin(s.t * 6));
      if (me.hasTag('rewritten')) {
        s.phase = 'flowers';
        s.t = 8;
        look('fx_flowers');
        me.alpha = 0.9;
        return;
      }
      if (s.t <= 0) {
        me.tags.add('spent');
        s.phase = 'done';
        s.t = 0.6;
        const kind = String(me.settings.kind);
        if (kind === 'wolves') for (let k = 0; k < 3; k++) game.spawn('SpoilerMite', me.x + (k - 1) * 0.8, me.y, me.h);
        else if (inside && p) game.damage(p, (kind === 'lightning' ? 16 : 14) * mult);
        look(kind === 'collapse' ? 'fx_hole' : 'fx_flash');
        me.alpha = 1;
        if (kind === 'collapse') s.t = 7;
      }
    } else if (s.phase === 'flowers') {
      if (inside && p) game.heal(p, 12 * game.dt);
      if (s.t <= 0) me.destroy();
    } else if (s.t <= 0) me.destroy();
  },
});
