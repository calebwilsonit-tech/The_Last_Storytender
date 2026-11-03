// A guest of the Empty Table (guest.gd): wanders the hall, follows the Storytender while her lantern shines on it, and sits
// on the first free chair it comes near. A cold wave unseats a seated guest, or erases one standing (it comes back at
// the hall's edge 3.5 s later), unless it is sheltered behind a bold word.
const K = 35.8;
export default defineScript({
  name: 'Guest',
  description: 'A guest to lead to the table.',
  settings: {
    area: { value: '', label: 'The hall: minX,minY,maxX,maxY (cells)' },
    lookSeated: { value: '', label: 'Picture once seated' },
    lookStanding: { value: '', label: 'Picture standing' },
  },
  start(me) {
    me.state.mode = 'wander';
    me.state.lit = 0;
    me.state.wt = 0;
  },
  update(me, game) {
    const s = me.state;
    const p = game.player;
    const [x0, y0, x1, y1] = String(me.settings.area).split(',').map(Number) as [number, number, number, number];
    // caught by a cold wave
    if (me.hasTag('chilled')) {
      me.tags.delete('chilled');
      if (s.mode === 'seated') {
        const ch = game.findAll('tag:chair').find((c) => c.id === s.chair);
        if (ch) ch.tags.delete('taken');
        me.tags.delete('seated');
        s.mode = 'wander';
        const sp = me.get('sprite');
        if (sp && me.settings.lookStanding) me.set('sprite', { ...sp, asset: me.settings.lookStanding });
      } else if (s.mode !== 'erased') {
        s.mode = 'erased';
        s.back = 3.5;
        me.moveTo(game.random() < 0.5 ? x0 + 0.5 : x1 + 0.5, y0 + 1.5 + game.random() * Math.max(0, y1 - y0 - 1), me.h);
      }
    }
    if (s.mode === 'erased') {
      me.visible = false;
      if ((s.back -= game.dt) <= 0) { s.mode = 'wander'; me.visible = true; }
      return;
    }
    if (s.mode === 'seated') return;
    // in the lantern's beam: it follows
    if (p && game.vars.lantern_on) {
      const d = me.distanceTo(p);
      let off = Math.abs(Math.atan2(me.y - p.y, me.x - p.x) - (p.facing * Math.PI) / 4);
      if (off > Math.PI) off = 2 * Math.PI - off;
      if (d <= 175 / K + 0.6 && (d < 0.8 || off <= 0.8)) { s.mode = 'follow'; s.lit = 0.5; }
    }
    if (s.mode === 'follow') {
      if ((s.lit -= game.dt) <= 0) s.mode = 'wander';
      else if (p && me.distanceTo(p) > 56 / K) me.walkTo(p.x, p.y, 80 / K);
      // a free chair near: sit
      for (const c of game.findAll('tag:chair')) {
        if (c.hasTag('taken') || me.distanceTo(c) > 60 / K + 0.4) continue;
        c.tags.add('taken');
        s.chair = c.id;
        s.mode = 'seated';
        me.moveTo(c.x, c.y + 0.05, c.h);
        me.tags.add('seated');
        const sp = me.get('sprite');
        if (sp && me.settings.lookSeated) me.set('sprite', { ...sp, asset: me.settings.lookSeated });
        return;
      }
      return;
    }
    if ((s.wt -= game.dt) <= 0) {
      s.wt = 1 + game.random() * 1.5;
      s.goal = game.random() > 0.35 ? { x: x0 + 0.5 + game.random() * (x1 - x0), y: y0 + 0.5 + game.random() * (y1 - y0) } : null;
    }
    if (s.goal) me.walkTo(s.goal.x, s.goal.y, 34 / K);
  },
});
