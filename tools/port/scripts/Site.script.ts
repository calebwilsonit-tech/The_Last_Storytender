// A puzzle site of the overworld (puzzle_sites.gd). One invisible controller per site; it knows the site's rule and sets `site_<id>` when
// the site is solved (+4 renown), which opens the chest's seal, the WEIGHED / PROOF gate (StoryGate.script.ts) and the bridge (PitCover).
//   echo     both plates (plate_<id>_0 and _1) pressed at once
//   words    the three sentence stones (stone_<id>_<i>) read the sentence the sign gives; they lock and a bridge unrolls
//   arena    the plate (plate_<id>_t) shuts the gate (arena_<id>_open = 0) and wakes wave 0, then wave 1 (arena_<id>_w<n>); all beaten: it opens
//   crumble  loose pages: 0.8 s after she steps on one it falls away for 5 s (she falls and is put back at the start); reaching the chest makes them solid
export default defineScript({
  name: 'Site',
  description: 'A puzzle site: echo plates, sentence stones, an arena or a crumbling causeway.',
  settings: {
    id: { value: '', label: 'Site id' },
    type: { value: '', label: 'echo / words / arena / crumble' },
    data: { value: '', label: 'The site (JSON)' },
    lookCrack: { value: '', label: 'Picture of a cracking page' },
    lookHole: { value: '', label: 'Picture of a gap' },
  },
  start(me, game) {
    const s = me.state;
    s.d = JSON.parse(String(me.settings.data || '{}'));
    s.mode = 'idle';
    s.wave = 0;
    s.waveT = 0;
    s.cells = {};
    s.shown = false;
    if (me.settings.type === 'arena' && !game.vars[`site_${me.settings.id}`]) {
      // a fight left half-way (walked out, saved, loaded) is not kept: the gate is open and every wave sleeps again
      game.vars[`arena_${me.settings.id}_open`] = 1;
      for (let n = 0; n < Number(s.d.waves); n++) game.vars[`arena_${me.settings.id}_w${n}`] = 0;
    }
  },
  update(me, game) {
    const v = game.vars;
    const id = String(me.settings.id);
    const s = me.state;
    const d = s.d;
    const flag = `site_${id}`;
    const died = game.eventsOf('died').some((e) => ((e.tags as string[]) ?? []).includes('player'));
    const solve = (text: string): void => {
      v[flag] = 1;
      v.renown = Number(v.renown ?? 0) + Number(d.bonus ?? 4);
      game.say(d.text ? String(d.text) : text);
    };
    const done = !!v[flag];
    switch (String(me.settings.type)) {
      case 'echo': {
        if (!done && (d.plates as string[]).every((p) => v[p])) solve('The plates settle. The way is open.');
        break;
      }
      case 'words': {
        const stones = game.findAll(`tag:site-${id}-stone`);
        const lock = (st: ScriptEntity, to: number): void => {
          const ss = st.get('sentenceStone');
          if (ss && (ss.reach !== 0.01 || ss.selected !== to)) st.set('sentenceStone', { ...ss, reach: 0.01, selected: to });
        };
        if (done) {
          // a solved site is read right, whenever the scene is loaded
          if (!s.shown) {
            s.shown = true;
            stones.forEach((st) => lock(st, Number((d.goodIndex as number[])[Number(st.tags.has('i0') ? 0 : st.tags.has('i1') ? 1 : 2)])));
          }
          break;
        }
        const right = (d.good as string[]).every((w, i) => v[`stone_${id}_${i}`] === w);
        if (right && stones.length > 0) {
          for (const st of stones) lock(st, Number((d.goodIndex as number[])[st.tags.has('i0') ? 0 : st.tags.has('i1') ? 1 : 2]));
          solve('The sentence holds. A bridge of pages unrolls.');
        }
        break;
      }
      case 'arena': {
        if (done) break;
        const w = (n: number): string => `arena_${id}_w${n}`;
        const open = `arena_${id}_open`;
        const reset = (): void => {
          s.mode = 'idle';
          s.wave = 0;
          for (let n = 0; n < Number(d.waves); n++) v[w(n)] = 0;
          v[open] = 1;
          game.emit('error-reset', { tag: `arena-${id}` });
        };
        if (s.mode === 'idle') {
          v[open] = 1;
          if (v[d.plate as string]) {
            s.mode = 'fight';
            s.wave = 0;
            s.waveT = 0.6;
            v[open] = 0;
            v[w(0)] = 1;
            game.say('The gate slams shut behind you.');
          }
        } else if (s.mode === 'fight') {
          if (died) {
            reset();
            break;
          }
          s.waveT -= game.dt;
          if (s.waveT > 0) break;
          const alive = game.findAll(`tag:arena-${id}-w${s.wave}`).some((e) => e.visible);
          if (alive) break;
          v[w(s.wave)] = 0;
          s.wave++;
          if (s.wave >= Number(d.waves)) {
            s.mode = 'done';
            v[open] = 1;
            solve('The ring falls quiet. The gate is open.');
          } else {
            v[w(s.wave)] = 1;
            s.waveT = 0.6;
            game.say('Another wave.');
          }
        }
        break;
      }
      case 'crumble': {
        const p = game.player;
        if (!p) break;
        const cells = s.cells as Record<string, { state: string; t: number }>;
        const key = (x: number, y: number): string => `${x},${y}`;
        for (const c of d.cells as [number, number][]) cells[key(c[0], c[1])] ??= { state: 'solid', t: 0 };
        const px = Math.floor(p.x);
        const py = Math.floor(p.y);
        const ch = d.chest as [number, number];
        let fin = done;
        if (!fin && Math.abs(px - ch[0]) <= 1 && Math.abs(py - ch[1]) <= 1) {
          solve('Solid ground. The causeway will hold now.');
          fin = true;
        }
        const overlays = game.findAll(`tag:crack-${id}`);
        const show = (x: number, y: number, look: string, on: boolean): void => {
          const o = overlays.find((e) => Math.floor(e.x) === x && Math.floor(e.y) === y);
          const spr = o?.get('sprite');
          if (o && spr && (spr.visible !== on || (look && spr.asset !== look))) o.set('sprite', { ...spr, visible: on, ...(look ? { asset: look } : {}) });
        };
        for (const [k, c] of Object.entries(cells)) {
          const [x, y] = k.split(',').map(Number) as [number, number];
          if (c.state === 'solid') {
            if (!fin && px === x && py === y) {
              c.state = 'cracking';
              c.t = 0.8;
              show(x, y, String(me.settings.lookCrack), true);
            }
          } else if (c.state === 'cracking') {
            c.t -= game.dt;
            if (fin || died) {
              c.state = 'solid';
              show(x, y, '', false);
            } else if (c.t <= 0) {
              c.state = 'gone';
              c.t = 5;
              show(x, y, String(me.settings.lookHole), true);
            }
          } else if (c.state === 'gone') {
            c.t -= game.dt;
            if (fin || died || c.t <= 0) {
              c.state = 'solid';
              show(x, y, '', false);
            } else if (px === x && py === y) {
              // she falls, and is put back where the causeway starts
              const st = d.start as [number, number];
              game.damage(p, 15);
              p.moveTo(st[0] + 0.5, st[1] + 0.5);
              game.say('The page gives way.');
            }
          }
        }
        break;
      }
    }
  },
});
