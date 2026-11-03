// The rules of Pip's memory (memory_pip.gd) that belong to no one object: what each rewritten sentence does, how long the
// spells last (the wolves and guards sleep 18 s, the river stays frozen 12 s, the floor solid 10 s, and never melts under the
// Storytender's feet), which stones lock once they have done their work, and the Archive gate that latches open.
const TIMED: Record<string, { word: string; flag: string; secs: number; cells?: string; said: string; worn: string }> = {
  b: { word: 'ASLEEP', flag: 'sleep_wood', secs: 18, said: 'The wolves curl up mid-snarl. Snoring, now.', worn: 'The wolves stir.' },
  i: { word: 'ASLEEP', flag: 'sleep_archive', secs: 18, said: 'The guards slump at their posts.', worn: 'The guards stir.' },
  d: { word: 'FROZEN', flag: 'river_frozen', secs: 12, cells: 'river', said: 'The river stops mid-ripple and turns to ice.', worn: 'The words wear off.' },
  h: { word: 'SOLID', flag: 'floor_solid', secs: 10, cells: 'floor', said: 'The floor is there, because the sentence says so.', worn: 'The words wear off.' },
};
export default defineScript({
  name: 'PipMemory',
  description: "Pip's memory: sentence effects, timers, locks and latches.",
  settings: {
    river: { value: '', label: 'River cells (x,y;...)' },
    floor: { value: '', label: 'Missing floor cells (x,y;...)' },
  },
  start(me) {
    me.state.until = {};
  },
  update(me, game) {
    const v = game.vars;
    const s = me.state;
    const stone = (k: string): ScriptEntity | undefined => game.find(`tag:stone-${k}`);
    const word = (k: string): string => String(v[`stone_${k}`] ?? '');
    const lock = (k: string): void => {
      const st = stone(k);
      const ss = st?.get('sentenceStone');
      if (st && ss && ss.reach !== 0.01) st.set('sentenceStone', { ...ss, reach: 0.01 });
    };
    const reset = (k: string): void => {
      const st = stone(k);
      const ss = st?.get('sentenceStone');
      if (st && ss && ss.selected !== 0) st.set('sentenceStone', { ...ss, selected: 0 });
    };
    // the bridge holds while it says so
    v.bridge_holds = word('a') === 'HOLDS' ? 1 : 0;
    // the sentences that open something for good
    if (word('c') === 'OPEN' && !v.gate_G) { v.gate_G = 1; lock('c'); game.say('The gate is open. It always was; it only had to be written.'); }
    if (word('e') === 'PRESENT' && !v.gate_v) { v.gate_v = 1; lock('e'); game.say('The stairs are there. They always were; nobody had written them down.'); }
    if (word('j') === 'OPEN' && !v.lock_read) { v.lock_read = 1; lock('j'); game.say('The door is open, in words at least.'); }
    if (v.plate_l && !v.gate_w) v.gate_w = 1; // the Archive's first gate latches once its plate is pressed
    // the spells that wear off
    const p = game.player;
    for (const [k, t] of Object.entries(TIMED)) {
      const on = word(k) === t.word;
      if (on && !v[t.flag]) {
        v[t.flag] = 1;
        s.until[k] = game.time + t.secs;
        game.say(t.said);
      }
      if (!on && v[t.flag]) v[t.flag] = 0;
      if (v[t.flag] && game.time >= s.until[k]) {
        // it does not melt under your feet
        const cells = t.cells ? String(me.settings[t.cells]).split(';') : [];
        const under = p && cells.some((c) => { const [x, y] = c.split(',').map(Number); return Math.floor(p.x) === x && Math.floor(p.y) === y; });
        if (under) continue;
        v[t.flag] = 0;
        reset(k);
        game.say(t.worn);
      }
    }
  },
});
