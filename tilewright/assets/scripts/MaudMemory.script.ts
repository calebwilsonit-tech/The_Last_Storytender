// The rules of Maud's memory (memory_maud.gd) that belong to no one object: the kitchen plate (weight 2: bold SALT, or
// SALT and the Storytender) opens the COLD gate for good; in the hall six guests arrive one by one, cold waves sweep across
// it from one side (warned 2.6 s ahead) hurting whoever is not sheltered behind a bold word and unseating or erasing guests;
// with all six seated the Cold Shoulder comes.
export default defineScript({
  name: 'MaudMemory',
  description: "Maud's memory: the plate, the guests and the cold waves.",
  settings: {
    plate: { value: '', label: 'The pressure plate (x,y)' },
    area: { value: '', label: 'The hall: minX,minY,maxX,maxY' },
    cells: { value: '', label: "The hall's floor cells (x,y;...)" },
  },
  start(me) {
    me.state.guestT = 0.5;
    me.state.guests = 0;
    me.state.waveCd = 9;
  },
  update(me, game) {
    const v = game.vars;
    const s = me.state;
    const p = game.player;
    if (!p) return;
    const mult = v.difficulty === 'story' ? 0.6 : 1;
    // the kitchen plate
    if (!v.cold_gate) {
      const [px, py] = String(me.settings.plate).split(',').map(Number);
      const on = (x: number, y: number): boolean => Math.floor(x) === px && Math.floor(y) === py;
      let w = on(p.x, p.y) ? 1 : 0;
      for (const b of game.findAll('tag:word')) if (on(b.x, b.y)) w += b.hasTag('bold') ? 2 : 1;
      if (w >= 2) { v.cold_gate = 1; game.say('Something heavy settles on the plate. The cold door creaks open.'); }
    }
    const [x0, y0, x1, y1] = String(me.settings.area).split(',').map(Number) as [number, number, number, number];
    const inHall = p.x >= x0 && p.x <= x1 + 1 && p.y >= y0 && p.y <= y1 + 1;
    if (!inHall || v.maud_finale) return;
    if (!v.table_seen) { v.table_seen = 1; game.startDialogue('maud_table'); return; }
    if (!v.table_awake) return;
    // all six seated: the Cold Shoulder comes, in the middle of the hall
    if (v.cold_spawn && !s.cold) {
      s.cold = true;
      game.spawn('ColdShoulder', (x0 + x1) / 2 + 0.5, (y0 + y1) / 2 + 1.5, p.h);
    }
    // the guests arrive, one every 3.5 s, at the hall's edge
    if (s.guests < 6 && (s.guestT -= game.dt) <= 0) {
      s.guestT = 3.5;
      const edge = game.random() < 0.5 ? { x: x0 + 0.5, y: y0 + 1.5 + game.random() * (y1 - y0 - 1) } : { x: x1 + 0.5, y: y0 + 1.5 + game.random() * (y1 - y0 - 1) };
      const g = game.spawn('Guest', edge.x, edge.y, p.h);
      if (g) { g.set('script_Guest', { ...g.get('script_Guest'), area: String(me.settings.area) }); s.guests++; }
    }
    const seated = game.findAll('tag:guest').filter((g) => g.hasTag('seated')).length;
    v.guests_seated = seated;
    if (seated >= 6 && !v.table_full) { v.table_full = 1; game.startDialogue('maud_reckon'); }
    // the cold waves
    const DIRS: [string, number, number][] = [['WEST', 1, 0], ['EAST', -1, 0], ['NORTH', 0, 1], ['SOUTH', 0, -1]];
    if (!s.wave) {
      if ((s.waveCd -= game.dt) <= 0) {
        const [name, dx, dy] = DIRS[Math.floor(game.random() * 4)]!;
        s.wave = { dx, dy, t: 0, phase: 'warn', line: -1 };
        game.say(`The cold comes from the ${name}. Get behind something heavy.`);
      }
      return;
    }
    const w = s.wave;
    w.t += game.dt;
    const cells = String(me.settings.cells).split(';').map((c) => c.split(',').map(Number) as [number, number]);
    const lineOf = (x: number, y: number): number => (w.dx === 1 ? x - x0 : w.dx === -1 ? x1 - x : w.dy === 1 ? y - y0 : y1 - y);
    const dim = w.dx !== 0 ? x1 - x0 + 1 : y1 - y0 + 1;
    if (w.phase === 'warn') {
      if (w.t >= 2.6) { w.phase = 'sweep'; w.t = 0; }
      return;
    }
    const bold = game.findAll('tag:bold');
    const shielded = (x: number, y: number): boolean => bold.some((b) => { for (let k = 1; k <= 3; k++) if (Math.floor(b.x) === x - w.dx * k && Math.floor(b.y) === y - w.dy * k) return true; return false; });
    const line = Math.min(Math.floor((w.t / 2.4) * dim), dim - 1);
    while (w.line < line) {
      w.line++;
      for (const [cx, cy] of cells) {
        if (lineOf(cx, cy) !== w.line) continue;
        game.spawn('Frost', cx + 0.5, cy + 0.5, p.h);
        if (shielded(cx, cy)) continue;
        if (Math.floor(p.x) === cx && Math.floor(p.y) === cy) game.damage(p, 14 * mult);
        for (const g of game.findAll('tag:guest')) {
          if (Math.floor(g.x) !== cx || Math.floor(g.y) !== cy || !g.visible) continue;
          g.tags.add('chilled'); // the guest unseats itself, or is erased if it was standing
        }
      }
    }
    if (w.t >= 2.8) { s.wave = null; s.waveCd = v.difficulty === 'story' ? 15 : 11; }
  },
});
