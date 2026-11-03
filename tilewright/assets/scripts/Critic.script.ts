// The Critic (critic.gd, memory_forge.gd): Garrick's own doubt. It wakes when the Storytender steps into the forge hall,
// hovers and throws its words (9 damage; some slow you). While it still has layers it cannot be hurt: each memory shard
// held up strips one (shard_1..3). With none left comes the reckoning: it can be hit (110 HP, 77 in Story) and fights
// with fans of words, pools of red ink and a lunge. Beaten, it sets critic_down.
const K = 35.8;
const WORDS = [
  ['DERIVATIVE', 'slow'], ['CLUMSY', 'slow'], ['HACK', ''], ['AMATEUR', 'slow'], ['PREDICTABLE', ''], ['FORGETTABLE', ''], ['TIRED', 'slow'], ['BORING', ''],
];
export default defineScript({
  name: 'Critic',
  description: 'The boss of the forge memory.',
  settings: {
    arenaX: { value: 42, label: 'The forge hall starts at this x (cells)' },
  },
  start(me) {
    const s = me.state;
    s.home = { x: me.x, y: me.y };
    s.t = 0;
    s.cd = 2;
    s.tele = 0;
    s.mode = '';
    s.atk = 0;
    s.bolts = [];
  },
  update(me, game) {
    const v = game.vars;
    const s = me.state;
    const p = game.player;
    if (!p) return;
    const mult = v.difficulty === 'story' ? 0.6 : 1;
    s.t += game.dt;
    if (v.critic_down) {
      me.alpha = Math.max(0, me.alpha - game.dt * 0.6);
      if (me.alpha <= 0.02) me.destroy();
      return;
    }
    const inside = p.x >= Number(me.settings.arenaX);
    // stepping into the hall wakes it: its words first (critic_intro sets critic_awake at the end)
    if (inside && !v.critic_seen) {
      v.critic_seen = 1;
      game.startDialogue('critic_intro');
      return;
    }
    const layers = 3 - (Number(v.shard_1 ?? 0) + Number(v.shard_2 ?? 0) + Number(v.shard_3 ?? 0));
    v.boss_name = v.critic_awake ? 'The Critic' : '';
    let health = me.get('health');
    // 110 health, 77 in Story (critic.gd)
    const want = v.difficulty === 'story' ? 77 : 110;
    if (health && health.max !== want) {
      me.set('health', { ...health, max: want });
      health = me.get('health');
    }
    const hp = me.get('state:health');
    if (hp && health) {
      v.boss_hp = hp.hp;
      v.boss_max = health.max;
    }
    if (!v.critic_awake || !inside) return;
    // a word that hit: the slowing ones slow the Storytender for 3 s
    for (const e of game.eventsOf('damaged')) {
      const b = (s.bolts as { id: number; fx: string }[]).find((x) => x.id === e.source);
      if (b && b.fx === 'slow' && e.entity === p.id) v.slow_until = game.time + 3;
    }
    s.bolts = (s.bolts as { id: number; at: number }[]).filter((b) => game.time - b.at < 4);
    const fire = (dx: number, dy: number): void => {
      const w = WORDS[Math.floor(game.random() * WORDS.length)]!;
      const b = game.spawn('WordBolt', me.x, me.y, me.h + 0.6);
      if (!b) return;
      const len = Math.hypot(dx, dy) || 1;
      const speed = (190 - (3 - layers) * 10) / K;
      b.set('projectile', { ...b.get('projectile'), useFacing: false, dirX: dx / len, dirY: dy / len, speed, damage: 9 * mult, hurts: 'player', lifetime: 3.5 });
      b.name = w[0]!;
      (s.bolts as object[]).push({ id: b.id, fx: w[1], at: game.time });
    };
    if (layers > 0) {
      // armoured: cannot be hurt, hovers, and throws one word at a time, quieter with every memory held up
      if (hp && health && hp.hp !== health.max) me.set('state:health', { ...hp, hp: health.max });
      me.walkTo(s.home.x + Math.cos(s.t * 0.5) * (90 / K), s.home.y + Math.sin(s.t * 0.8) * (68 / K), 2.2);
      if (s.layersSeen !== undefined && layers < s.layersSeen) s.cd = 2.5; // it recoils when a layer goes
      s.layersSeen = layers;
      if (s.tele > 0) {
        if ((s.tele -= game.dt) <= 0) fire(p.x - me.x, p.y - me.y);
      } else if ((s.cd -= game.dt) <= 0) {
        s.tele = 0.85;
        s.cd = 1.7 + (3 - layers) * 0.6;
      }
      return;
    }
    if (!v.critic_reckoning) {
      if (!s.reckonAsked) {
        s.reckonAsked = true;
        game.startDialogue('critic_reckon');
      }
      return;
    }
    // the reckoning: fans of words, pools of red ink, a lunge; faster below half health
    const fury = hp && health && hp.hp < health.max * 0.5 ? 0.65 : 1;
    if (hp && (hp.dead || hp.hp <= 0)) {
      if (!s.endAsked) {
        s.endAsked = true;
        v.boss_name = '';
        game.startDialogue('critic_end');
      }
      return;
    }
    switch (s.mode) {
      case '':
        me.walkTo(s.home.x + Math.cos(s.t * 0.6) * (110 / K), s.home.y + Math.sin(s.t * 0.9) * (92 / K), 2.6);
        if ((s.cd -= game.dt) <= 0) {
          s.mode = ['fan', 'pools', 'lunge_tele'][s.atk % 3];
          s.atk++;
          s.st = (s.mode === 'lunge_tele' ? 0.9 : 0.8) * fury;
          s.lungeTo = { x: p.x, y: p.y };
        }
        break;
      case 'fan':
      case 'pools':
        if ((s.st -= game.dt) <= 0) {
          if (s.mode === 'fan') {
            const n = fury < 1 ? 7 : 5;
            const base = Math.atan2(p.y - me.y, p.x - me.x);
            for (let k = 0; k < n; k++) {
              const a = base + (k - (n - 1) / 2) * 0.26;
              fire(Math.cos(a), Math.sin(a));
            }
          } else {
            game.spawn('InkPool', Math.floor(p.x) + 0.5, Math.floor(p.y) + 0.5, p.h);
            for (let k = 0; k < 2; k++) {
              const a = game.random() * Math.PI * 2;
              const r = (60 + game.random() * 50) / K;
              game.spawn('InkPool', Math.floor(p.x + Math.cos(a) * r) + 0.5, Math.floor(p.y + Math.sin(a) * r) + 0.5, p.h);
            }
          }
          s.mode = '';
          s.cd = 1.5 * fury;
        }
        break;
      case 'lunge_tele':
        if ((s.st -= game.dt) <= 0) {
          s.mode = 'lunge';
          s.st = 0;
          s.hit = false;
        }
        break;
      case 'lunge':
        s.st += game.dt;
        me.walkTo(s.lungeTo.x, s.lungeTo.y, 9);
        if (!s.hit && me.distanceTo(p) < 42 / K + 0.4) {
          s.hit = true;
          game.damage(p, 12 * mult);
        }
        if (s.st > 0.6) {
          s.mode = 'rest';
          s.st = 1.6;
        }
        break;
      case 'rest':
        if ((s.st -= game.dt) <= 0) {
          s.mode = '';
          s.cd = 1.2 * fury;
        }
        break;
    }
  },
});
