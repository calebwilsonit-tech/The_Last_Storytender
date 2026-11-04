// The Spoiler (spoiler.gd, memory_pip.gd): Pip's storybook, which read the last page and decided every story ends badly.
// It wakes when the Storytender comes through THE END door. It drifts, throws fans of paper, dives onto her, and every third
// move it READS: one or two sentences of disaster come up on the floor (Hazard), and a strike on the book while it reads
// rewrites the oldest. Five rewrites and the reckoning begins: now it can be hurt (190 HP, 133 in Story; double while it
// staggers). Beaten, it sets spoiler_down.
const K = 35.8;
const REGIONS: Record<string, [number, number]> = { WEST: [32, 2], EAST: [39, 2], NORTH: [36, 1], SOUTH: [36, 4], MIDDLE: [36, 3] };
export default defineScript({
  name: 'Spoiler',
  description: 'The boss of the library memory.',
  settings: {
    lookRead: { value: '', label: 'Its picture while it reads a sentence out (sprite name; empty: unchanged)' },
    lookAttack: { value: '', label: 'Its picture while it fans paper or dives (sprite name; empty: unchanged)' },
  },
  start(me) {
    const s = me.state;
    s.home = { x: me.x, y: me.y, h: me.h };
    s.t = 0;
    s.cd = 3;
    s.mode = 'roam';
    s.moves = 0;
    s.reading = [];
  },
  update(me, game) {
    const v = game.vars;
    if (v.cutscene_on) return;
    const s = me.state;
    const p = game.player;
    if (!p) return;
    const mult = v.difficulty === 'story' ? 0.6 : 1;
    s.t += game.dt;
    if (v.spoiler_down) {
      me.alpha = Math.max(0, me.alpha - game.dt / 2.6);
      if (me.alpha <= 0.02) me.destroy();
      return;
    }
    // the picture that fits what it is doing
    const spr = me.get('sprite');
    if (spr) {
      s.idleLook ??= spr.asset;
      const attacking = ['dive_tele', 'fan_tele', 'dive', 'fan'].includes(s.mode);
      const want = (s.mode === 'read' && me.settings.lookRead) || (attacking && me.settings.lookAttack) || s.idleLook;
      if (spr.asset !== want) me.set('sprite', { ...spr, asset: want });
    }
    const inside = p.x >= 30 && p.x <= 42 && p.y <= 6;
    if (inside && v.door_H && !v.spoiler_seen) {
      v.spoiler_seen = 1;
      v.play_k_spoiler_intro = 1;
      return;
    }
    let health = me.get('health');
    const want = v.difficulty === 'story' ? 133 : 190;
    if (health && health.max !== want) { me.set('health', { ...health, max: want }); health = me.get('health'); }
    let hp = me.get('state:health');
    if (hp && health && hp.hp > health.max) { me.set('state:health', { ...hp, hp: health.max }); hp = me.get('state:health'); }
    v.boss_name = v.spoiler_awake ? 'The Spoiler' : '';
    if (hp && health) { v.boss_hp = hp.hp; v.boss_max = health.max; }
    if (!v.spoiler_awake || !inside) return;
    const rewrites = Number(v.spoiler_rewrites ?? 0);
    const reck = !!v.spoiler_reckoning;
    // a strike: while it reads, it rewrites the oldest sentence; otherwise the book shrugs it off until the reckoning
    if (hp && health) {
      if (s.hp === undefined) s.hp = hp.hp;
      if (hp.hp < s.hp) {
        const lost = s.hp - hp.hp;
        const pending = game.findAll('tag:hazard').find((h) => !h.hasTag('rewritten') && !h.hasTag('spent'));
        if (s.mode === 'read' && pending) {
          pending.tags.add('rewritten');
          if (!reck) {
            v.spoiler_rewrites = rewrites + 1;
            game.say(['One sentence rewritten.', 'Two.', 'Three. The book hesitates.', 'Four.', 'Five. It is out of certainties.'][Math.min(rewrites, 4)]!);
          }
          if (!reck) me.set('state:health', { ...hp, hp: s.hp });
        } else if (!reck) me.set('state:health', { ...hp, hp: s.hp });
        else if (s.mode === 'stagger') me.set('state:health', { ...hp, hp: Math.max(0, hp.hp - lost) }); // double while it staggers
        s.hp = (me.get('state:health') as { hp: number }).hp;
      } else s.hp = hp.hp;
    }
    if (rewrites >= 5 && !reck) {
      if (!s.reckonAsked) { s.reckonAsked = true; v.play_k_spoiler_reckon = 1; }
      return;
    }
    if (reck && hp && (hp.dead || hp.hp <= 0)) {
      if (!s.endAsked) { s.endAsked = true; v.boss_name = ''; v.play_k_spoiler_end = 1; }
      return;
    }
    const fan = (n: number, speed: number, spread = 1.15, base = Math.atan2(p.y - me.y, p.x - me.x), full = false): void => {
      for (let i = 0; i < n; i++) {
        const a = full ? (Math.PI * 2 * i) / n : base + (i / (n - 1) - 0.5) * spread;
        const b = game.spawn('PageCut', me.x, me.y, me.h + 0.6);
        if (b) b.set('projectile', { ...b.get('projectile'), useFacing: false, dirX: Math.cos(a), dirY: Math.sin(a), speed: speed / K, damage: 8 * mult, hurts: 'player', lifetime: 3 });
      }
    };
    const drift = (rate: number): void => {
      let gx = s.home.x + (reck ? Math.cos(s.t * 0.5) * 4.7 : Math.cos(s.t * 0.4) * 1.7);
      let gy = s.home.y + (reck ? Math.sin(s.t * 0.8) * 1.9 : Math.sin(s.t * 0.7) * 0.6);
      if (reck) { gx += (p.x - gx) * 0.35; gy += (p.y - gy) * 0.35; }
      me.walkTo(gx, gy, rate * 2);
    };
    const gap = reck ? 1.1 : Math.max(1.9 - 0.2 * rewrites, 0.9);
    // it never leaves the Last Page
    if (me.x < 30.6 || me.x > 41.4 || me.y < 0.6 || me.y > 5.4) me.moveTo(Math.min(41.4, Math.max(30.6, me.x)), Math.min(5.4, Math.max(0.6, me.y)), s.home.h ?? me.h);
    switch (s.mode) {
      case 'roam':
        drift(1.2);
        if ((s.cd -= game.dt) <= 0) {
          s.moves++;
          if (s.moves % 3 === 0) {
            // reading: one sentence (two after three rewrites) comes up on the floor
            s.mode = 'read';
            s.reading = [];
            const window = Math.max(5.6 - 0.4 * rewrites, 3.8);
            s.st = window;
            s.spiral = 0.6;
            for (let i = 0; i < (rewrites >= 3 ? 2 : 1); i++) {
              const roll = game.random();
              const kind = roll < 0.4 ? 'collapse' : roll < 0.7 ? 'wolves' : 'lightning';
              const names = Object.keys(REGIONS);
              const where = names[Math.floor(game.random() * names.length)]!;
              const [cx, cy] = REGIONS[where]!;
              const h = game.spawn('Hazard', cx + 0.5, cy + 0.5, me.h);
              if (h) {
                h.set('script_Hazard', { ...h.get('script_Hazard'), kind, window });
                (s.reading as number[]).push(h.id);
              }
              const text = kind === 'collapse' ? `The floor beneath the ${where} COLLAPSES.` : kind === 'lightning' ? `Lightning in the ${where} STRIKES.` : `Wolves from the ${where} ATTACK.`;
              game.say(text);
            }
          } else if (s.last !== 'dive' && game.random() < 0.45) {
            s.mode = 'dive_tele';
            s.last = 'dive';
            s.st = reck ? 0.8 : 1.0;
          } else {
            s.mode = 'fan_tele';
            s.last = 'fan';
            s.st = reck ? 0.6 : 0.75;
          }
        }
        break;
      case 'fan_tele':
        drift(0.5);
        if ((s.st -= game.dt) <= 0) {
          fan(5 + (rewrites >= 3 || reck ? 2 : 0), reck ? 175 : 150);
          s.mode = 'rest';
          s.st = 0.55;
        }
        break;
      case 'dive_tele':
        if (s.st > 0.35) s.diveAt = { x: Math.min(41.4, Math.max(30.6, p.x)), y: Math.min(5.4, Math.max(0.6, p.y)) };
        if ((s.st -= game.dt) <= 0) { s.mode = 'dive'; s.st = 0.8; }
        break;
      case 'dive':
        me.walkTo(s.diveAt.x, s.diveAt.y, 12);
        s.st -= game.dt;
        if (me.distanceTo(s.diveAt) < 0.45 || s.st <= 0) {
          if (me.distanceTo(p) < 76 / K + 0.3) game.damage(p, 14 * mult);
          if (reck) fan(8, 120, 0, 0, true);
          s.mode = 'rest';
          s.st = reck ? 1.2 : 1.5;
        }
        break;
      case 'read':
        s.st -= game.dt;
        if ((s.spiral -= game.dt) <= 0) {
          s.spiral = reck ? 0.65 : 0.9;
          const a = s.t * 1.4;
          fan(2, 130, 0, a, true);
        }
        const open = game.findAll('tag:hazard').filter((h) => !h.hasTag('rewritten') && !h.hasTag('spent'));
        if (s.st <= 0 || open.length === 0) {
          const all = open.length === 0 && s.st > 0;
          s.mode = all ? 'stagger' : 'roam';
          s.st = reck ? 2.4 : 1.6;
          s.cd = gap;
        }
        break;
      case 'rest':
      case 'stagger':
        if ((s.st -= game.dt) <= 0) { s.mode = 'roam'; s.cd = gap; }
        break;
    }
  },
});
