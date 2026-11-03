// The Errors (enemy.gd, enemy_kinds.gd): mistakes in the writing that roam the page. Each wanders near its post, notices the
// Storytender by sight (a cone, longer while the lantern shines, shorter while creeping) or hearing, chases, loses track
// after 2.5 s, searches for 3 s and goes home. The lantern's beam slows them, proofreads some into friends and burns others.
// Distances are in cells (the game's ground pixels / 35.8) and times in seconds, as in the Godot game.
//
// Kinds: 0 Bare, 1 Mite, 2 Run-on, 3 Dangler, 4 Censor, 5 Ellipsis.
const K = 35.8;
const NAMES = ['Bare', 'Mite', 'Run-on', 'Dangler', 'Censor', 'Ellipsis'];
const DROP_NAMES = ['bare', 'mite', 'slug', 'dangler', 'censor', 'ellipsis'];
const FRIENDS = ['Bear', '', 'Run-on Sentence, Corrected', 'Dangler, Tied Up', '', ''];
const RENOWN = [2, 1, 3, 3, 4, 4];
const RANGE = [270, 230, 220, 300, 260, 250].map((p) => p / K);
const HALF_CONE = [0.95, 1.35, 1.1, 1.0, 0.9, 1.2];
const HEARING = [1, 1.35, 0.8, 1, 1, 1.2];
const CHASE = [86, 150, 40, 70, 62, 70].map((p) => p / K);
/** Seconds of lantern light that proofread a kind (0: the light does something else). */
const PROOF = [2.2, 0, 3.0, 1.8, 0, 0];
const BEAM_RANGE = 175 / K;
const BEAM_HALF = 0.63;

export default defineScript({
  name: 'Error',
  description: 'An Error: wanders, notices, chases and attacks; the lantern slows, proofreads or burns it.',
  settings: {
    kind: { value: 0, label: 'Kind (0 Bare, 1 Mite, 2 Run-on, 3 Dangler, 4 Censor, 5 Ellipsis)' },
    unlock: { value: '', label: 'Only out once this flag is set (empty: always)' },
    drops: { value: '', label: 'Drop table: item,chance,low,high; ... (rolled when it is beaten)' },
    friendlyLook: { value: '', label: 'Its picture once proofread (sprite name; empty: unchanged)' },
    sleepWhen: { value: '', label: 'Asleep while this flag is set (a sentence put it to sleep)' },
  },
  start(me) {
    const s = me.state;
    s.home = { x: me.x, y: me.y };
    s.mode = 'idle';
    s.t = 0;
    s.cd = 0.8;
    s.alert = 0;
    s.lost = 0;
    s.look = 0;
    s.proof = 0;
    s.face = { x: 1, y: 0 };
    s.wander = { x: 0, y: 0 };
    s.wanderT = 0;
    s.bar = 0; // Censor: seconds its bar stays down
    s.strip = 0;
    s.phase = 'visible'; // Ellipsis: visible / gone
    s.blinkT = 2 + Math.random() * 2;
    s.pinned = 0;
    s.hp = -1;
    s.trail = [];
    s.drip = 0;
  },
  update(me, game) {
    const v = game.vars;
    const s = me.state;
    const kind = Number(me.settings.kind);
    const dt = game.dt;
    // not in the story yet: hidden and harmless
    const p = game.player;
    // resting at a lantern post resets the page: every Error comes back (main.gd _respawn_world)
    if (game.eventsOf('rested').length > 0) s.reset = true;
    // beaten ones also come back after a couple of minutes; either way only once you are well away, so nothing appears on top of you
    if (s.gone && game.time - s.goneAt > 120) s.reset = true;
    if (s.reset && p && Math.hypot(p.x - s.home.x, p.y - s.home.y) > 8 && me.distanceTo(p) > 8) comeBack(me);
    if (s.gone) {
      if (me.visible) me.visible = false;
      return;
    }
    // asleep (a sentence said so): it does nothing, and a hit wakes it (and does double, as it did not see it coming)
    if (me.settings.sleepWhen && !v[String(me.settings.sleepWhen)]) s.woke = false;
    if (me.settings.sleepWhen && v[String(me.settings.sleepWhen)] && !s.woke) {
      s.mode = 'idle';
      s.alert = 0;
      const touch0 = me.get('damageOnTouch');
      if (touch0 && touch0.amount !== 0) me.set('damageOnTouch', { ...touch0, amount: 0 });
      const hs = me.get('state:health');
      if (hs && s.hp !== undefined && hs.hp < s.hp) {
        s.woke = true; // only this one wakes
        me.set('state:health', { ...hs, hp: Math.max(0, hs.hp - (s.hp - hs.hp)) });
      }
      if (hs) s.hp = hs.hp;
      return;
    }
    const out = !me.settings.unlock || !!v[String(me.settings.unlock)];
    if (me.visible !== out) me.visible = out;
    const touch = me.get('damageOnTouch');
    if (!out) return;
    const hp = me.get('state:health') as { hp: number; dead?: boolean } | undefined;

    // ---- beaten: renown, Mnemosynth crystals to pick up (1 from a Mite, 2 from the rest), a drop roll, and gone for now
    if (hp && (hp.dead || hp.hp <= 0)) {
      v.renown = Number(v.renown ?? 0) + RENOWN[kind]!;
      dropCrystals(me, game, kind === 1 ? 1 : 2);
      rollDrops(game, String(me.settings.drops));
      s.gone = true;
      s.goneAt = game.time;
      me.visible = false;
      return;
    }

    // ---- proofread: a friend now, that ambles after you at a polite distance
    if (me.hasTag('friendly')) {
      if (!p) return;
      const d = me.distanceTo(p);
      if (d > 120 / K && d < 420 / K) me.walkTo(p.x, p.y, 52 / K);
      return;
    }

    s.t += dt;
    s.cd = Math.max(0, s.cd - dt);
    if (!p) return;
    const dx = p.x - me.x;
    const dy = p.y - me.y;
    const dist = Math.hypot(dx, dy);
    const dir = dist > 0.01 ? { x: dx / dist, y: dy / dist } : { x: 1, y: 0 };
    const sneaking = game.input.down('sneak');
    const lanternOn = !!v.lantern_on;

    // ---- a hit taken: the Censor's bar takes it from the front; otherwise it is alarmed (and a hit it did not see coming does double)
    if (hp) {
      if (s.hp < 0) s.hp = hp.hp;
      if (hp.hp < s.hp) {
        const lost = s.hp - hp.hp;
        const fromFront = s.face.x * dx + s.face.y * dy > 0.25 * dist;
        if ((kind === 4 && s.bar <= 0 && fromFront) || (kind === 5 && s.phase !== 'visible')) {
          me.set('state:health', { ...hp, hp: s.hp }); // a dull clang: the bar (or the blink) took it
        } else {
          const unaware = (s.mode === 'idle' || s.mode === 'return' || s.mode === 'search') && s.alert < 0.6;
          if (unaware) me.set('state:health', { ...hp, hp: Math.max(0, hp.hp - lost) });
          s.alert = 1;
          alarm(me, game);
          s.mode = 'chase';
          s.lost = 0;
        }
        s.hp = (me.get('state:health') as { hp: number }).hp;
      } else s.hp = hp.hp;
    }

    // ---- the lantern's beam: within reach and in front of the Storytender
    const pf = (p.facing * Math.PI) / 4;
    const toMe = Math.atan2(-dy, -dx);
    let off = Math.abs(toMe - pf);
    if (off > Math.PI) off = 2 * Math.PI - off;
    const beam = lanternOn && dist <= BEAM_RANGE + 0.5 && (dist < 0.6 || off <= BEAM_HALF + Math.atan2(0.5, Math.max(dist, 0.1)));
    const slow = beam ? 0.5 : 1;
    if (beam) {
      if (PROOF[kind]! > 0) {
        s.proof += dt / PROOF[kind]!;
        if (s.proof >= 1) return proofread(me, game, kind);
      } else if (kind === 1) burn(me, 4.5 * dt);
      else if (kind === 4) {
        s.strip += dt;
        if (s.strip >= 1.1) {
          s.strip = 0;
          s.bar = 5;
        }
      } else if (kind === 5) {
        s.pinned = 0.35;
        burn(me, 3 * dt);
      }
    }
    s.bar = Math.max(0, s.bar - dt);
    s.pinned = Math.max(0, s.pinned - dt);

    // ---- noticing: sight in a cone (x1.25 with the lantern, x0.75 creeping), or hearing footsteps
    // (enemy.gd _perceive: footsteps make noise by how fast you go, louder with the lantern, a swing or a dash; it sees in its
    // cone, or anywhere within 90 px)
    const sight = RANGE[kind]! * (lanternOn ? 1.25 : 1) * (sneaking ? 0.75 : 1);
    const ang = Math.acos(Math.max(-1, Math.min(1, s.face.x * dir.x + s.face.y * dir.y)));
    const seen = dist < sight && (dist < 90 / K || ang < HALF_CONE[kind]!);
    const moved = s.pp ? Math.hypot(p.x - s.pp.x, p.y - s.pp.y) / Math.max(dt, 1e-3) : 0;
    s.pp = { x: p.x, y: p.y };
    let noise = (45 + Math.min(1, moved / 4.2) * 105) / K;
    if (game.input.down('attack') || game.input.down('dodge')) noise = 300 / K;
    if (lanternOn) noise += 50 / K;
    if (sneaking) noise *= 0.4;
    noise *= HEARING[kind]!;
    let rate = 0;
    if (dist < noise) rate += (1 - dist / noise) * 1.6;
    if (seen) rate += 0.45 + (1 - dist / sight) * 1.5;
    const heard = dist < noise;
    const sensed = rate > 0;
    if (sensed) s.alert = Math.min(1, s.alert + rate * dt);
    else if (s.mode === 'idle' || s.mode === 'return') s.alert = Math.max(0, s.alert - 0.35 * dt);
    // a sound behind it turns it round to look
    if (heard && !seen && (s.mode === 'idle' || s.mode === 'return')) {
      const r = Math.min(1, dt * 3);
      s.face = { x: s.face.x + (dir.x - s.face.x) * r, y: s.face.y + (dir.y - s.face.y) * r };
      const fl = Math.hypot(s.face.x, s.face.y) || 1;
      s.face = { x: s.face.x / fl, y: s.face.y / fl };
    }

    // ---- the Ellipsis blinks out and back, somewhere 90-140 px away
    if (kind === 5) {
      s.blinkT -= dt;
      if (s.blinkT <= 0 && s.pinned <= 0) {
        if (s.phase === 'visible') {
          s.phase = 'gone';
          s.blinkT = 0.6;
          me.alpha = 0.15;
        } else {
          const a = Math.random() * Math.PI * 2;
          const r = (90 + Math.random() * 50) / K;
          const nx = (s.mode === 'chase' ? p.x : me.x) + Math.cos(a) * r;
          const ny = (s.mode === 'chase' ? p.y : me.y) + Math.sin(a) * r;
          if (game.findPath({ x: me.x, y: me.y }, { x: nx, y: ny })) me.moveTo(nx, ny);
          s.phase = 'visible';
          s.blinkT = 1.6 + Math.random() * 1.6;
          me.alpha = 1;
        }
      }
    }

    // ---- the Run-on leaves a trail of ink that slows the Storytender to 0.55
    if (kind === 2) {
      s.trail = (s.trail as { x: number; y: number; t: number }[]).filter((q) => (q.t -= dt) > 0);
      const inPuddle = (s.trail as { x: number; y: number }[]).some((q) => Math.hypot(q.x - p.x, q.y - p.y) < 26 / K);
      v.puddle_slow = inPuddle ? 0.55 : v.puddle_by === me.id ? 1 : (v.puddle_slow ?? 1);
      if (inPuddle) v.puddle_by = me.id;
    }

    const move = (x: number, y: number, speed: number): void => {
      const len = Math.hypot(x, y);
      if (len < 0.01 || speed <= 0) return;
      me.walkTo(me.x + (x / len) * 0.6, me.y + (y / len) * 0.6, speed);
      s.face = { x: s.face.x + (x / len - s.face.x) * Math.min(1, dt * 6), y: s.face.y + (y / len - s.face.y) * Math.min(1, dt * 6) };
      const fl = Math.hypot(s.face.x, s.face.y) || 1;
      s.face = { x: s.face.x / fl, y: s.face.y / fl };
    };
    const dmgMult = v.difficulty === 'story' ? 0.6 : 1;
    // contact damage only while it is hunting (a wandering Mite does not bite); the part has no switch, so its damage is set to 0
    if (touch) {
      const on = s.mode === 'chase' && (kind === 1 || kind === 2 || kind === 5) && s.phase === 'visible';
      const amount = on ? [12, 6, 7, 6, 10, 7][kind]! * dmgMult : 0;
      if (touch.amount !== amount) me.set('damageOnTouch', { ...touch, amount });
    }
    // the Dangler's word bolts: only while it is hunting and not in the light (off, it aims at nothing)
    const ranged = me.get('rangedAttack');
    if (ranged) {
      const target = s.mode === 'chase' && !beam ? 'player' : 'nothing';
      const damage = 6 * dmgMult;
      if (ranged.target !== target || ranged.damage !== damage) me.set('rangedAttack', { ...ranged, target, damage });
    }

    switch (s.mode) {
      case 'idle': {
        s.wanderT -= dt;
        if (s.wanderT <= 0) {
          s.wanderT = 1 + Math.random() * 1.5;
          const a = Math.random() * Math.PI * 2;
          s.wander = Math.random() > 0.4 ? { x: Math.cos(a), y: Math.sin(a) } : { x: 0, y: 0 };
          const hx = s.home.x - me.x;
          const hy = s.home.y - me.y;
          if (Math.hypot(hx, hy) > 110 / K) s.wander = { x: hx, y: hy };
        }
        move(s.wander.x, s.wander.y, 28 / K);
        if (s.wander.x === 0 && s.wander.y === 0) {
          const r = Math.sin(s.t * 0.8 + me.id) * 0.6 * dt;
          s.face = { x: s.face.x * Math.cos(r) - s.face.y * Math.sin(r), y: s.face.x * Math.sin(r) + s.face.y * Math.cos(r) };
        }
        lure(me, game);
        if (s.alert >= 1 && seen) enterChase(me, game);
        break;
      }
      case 'chase': {
        if (sensed) {
          s.lost = 0;
          s.last = { x: p.x, y: p.y };
        } else if ((s.lost += dt) > 2.5) {
          s.mode = 'search';
          s.look = 3;
          break;
        }
        if (kind === 0 || kind === 4) {
          move(dir.x, dir.y, CHASE[kind]! * slow);
          if (dist < 80 / K && s.cd <= 0 && slow === 1) {
            s.mode = 'windup';
            s.st = 0.45;
            s.lunge = dir;
          }
        } else if (kind === 1) {
          const j = Math.sin(s.t * 9 + me.id) * 0.6;
          move(dir.x - dir.y * j, dir.y + dir.x * j, CHASE[1]! * slow);
        } else if (kind === 2) {
          move(dir.x, dir.y, CHASE[2]! * slow);
          if ((s.drip -= dt) <= 0) {
            s.drip = 0.45;
            (s.trail as object[]).push({ x: me.x, y: me.y, t: 6 });
          }
        } else if (kind === 3) {
          if (dist < 170 / K) move(-dir.x, -dir.y, (78 / K) * slow);
          else if (dist > 290 / K) move(dir.x, dir.y, (64 / K) * slow);
          else {
            const side = Math.sin(me.id * 9) > 0 ? 1 : -1;
            move(-dir.y * side, dir.x * side, (38 / K) * slow);
          }
        } else if (kind === 5 && s.phase === 'visible' && s.pinned <= 0) move(dir.x, dir.y, CHASE[5]! * slow);
        break;
      }
      case 'windup':
        // the telegraph: it rears back before it lunges
        move(-s.lunge.x, -s.lunge.y, 14 / K);
        if ((s.st -= dt) <= 0) {
          s.mode = 'lunge';
          s.st = 0.38;
          s.hit = false;
        }
        break;
      case 'lunge':
        me.walkTo(me.x + s.lunge.x * 0.8, me.y + s.lunge.y * 0.8, 340 / K);
        if (!s.hit && dist < 40 / K) {
          s.hit = true;
          game.damage(p, (kind === 4 ? 10 : 12) * dmgMult);
        }
        if ((s.st -= dt) <= 0) {
          s.mode = 'recover';
          s.st = 0.7;
          s.cd = 1.2;
        }
        break;
      case 'recover':
        if ((s.st -= dt) <= 0) s.mode = 'chase';
        break;
      case 'search': {
        const lx = (s.last?.x ?? me.x) - me.x;
        const ly = (s.last?.y ?? me.y) - me.y;
        if (Math.hypot(lx, ly) > 30 / K) move(lx, ly, 70 / K);
        else {
          s.look -= dt;
          const r = 2.2 * dt;
          s.face = { x: s.face.x * Math.cos(r) - s.face.y * Math.sin(r), y: s.face.x * Math.sin(r) + s.face.y * Math.cos(r) };
          if (s.look <= 0) {
            s.alert = 0.3;
            s.mode = 'return';
          }
        }
        if (s.alert >= 1 && sensed) enterChase(me, game);
        break;
      }
      case 'return': {
        const bx = s.home.x - me.x;
        const by = s.home.y - me.y;
        if (Math.hypot(bx, by) < 14 / K) s.mode = 'idle';
        else move(bx, by, 60 / K);
        lure(me, game);
        if (s.alert >= 1 && sensed) enterChase(me, game);
        break;
      }
    }
    const fa = Math.round((Math.atan2(s.face.y, s.face.x) / Math.PI) * 4);
    me.facing = ((fa % 8) + 8) % 8;
  },
});

/** Mnemosynth crystals scattered where it stood (level_base.gd drop_crystals): +5 Mnemosynth and +12 lantern each, walked into. */
function dropCrystals(me: ScriptEntity, game: ScriptGame, n: number): void {
  for (let i = 0; i < n; i++) game.spawn('DroppedCrystal', me.x + (game.random() - 0.5) * (52 / K), me.y + (game.random() - 0.5) * (24 / K), me.h);
}

/** Back at its post, whole, hostile again (a proofread friend too: the page has been reset). */
function comeBack(me: ScriptEntity): void {
  const s = me.state;
  me.moveTo(s.home.x, s.home.y);
  const max = me.get('health')?.max ?? 1;
  const hs = me.get('state:health');
  if (hs) me.set('state:health', { ...hs, hp: max, dead: false });
  const health = me.get('health');
  if (health) me.set('health', { ...health, team: 'enemy', showBar: false });
  const spr = me.get('sprite');
  if (spr && s.origLook && spr.asset !== s.origLook) me.set('sprite', { ...spr, asset: s.origLook });
  me.tags.delete('friendly');
  me.tags.add('error');
  me.tags.add('enemy');
  Object.assign(s, { gone: false, reset: false, mode: 'idle', alert: 0, proof: 0, hp: max, cd: 0.8, phase: 'visible', bar: 0 });
  me.alpha = 1;
}

function burn(me: ScriptEntity, amount: number): void {
  const hp = me.get('state:health') as { hp: number } | undefined;
  if (hp) me.set('state:health', { ...hp, hp: Math.max(0, hp.hp - amount) });
}

/** Seen it: chase, and raise the alarm for the Errors within 170 px. */
function enterChase(me: ScriptEntity, game: ScriptGame): void {
  me.state.mode = 'chase';
  me.state.lost = 0;
  alarm(me, game);
}

function alarm(me: ScriptEntity, game: ScriptGame): void {
  for (const o of game.findAll('tag:error')) {
    if (o.id === me.id || o.hasTag('friendly') || !o.visible) continue;
    if (me.distanceTo(o) < 170 / K && (o.state.mode === 'idle' || o.state.mode === 'return' || o.state.mode === 'search')) {
      o.state.alert = 1;
      o.state.mode = 'chase';
      o.state.lost = 0;
    }
  }
}

/** An echo nearby draws an idle Error to it (it stares at the echo). */
function lure(me: ScriptEntity, game: ScriptGame): void {
  for (const e of game.findAll('tag:echo')) {
    if (me.distanceTo(e) < 6) {
      me.walkTo(e.x, e.y, 60 / K);
      return;
    }
  }
}

/** The lantern corrected it: a friend now. 6 Mnemosynth and an Ink Vial (always in Story, 60% in Normal). */
function proofread(me: ScriptEntity, game: ScriptGame, kind: number): void {
  me.tags.add('friendly');
  me.tags.delete('error');
  me.tags.delete('enemy');
  const touch = me.get('damageOnTouch');
  if (touch) me.set('damageOnTouch', { ...touch, amount: 0 });
  const ranged = me.get('rangedAttack');
  if (ranged) me.set('rangedAttack', { ...ranged, target: 'nothing' });
  const health = me.get('health');
  if (health) me.set('health', { ...health, team: 'player', showBar: false });
  me.alpha = 1;
  const spr = me.get('sprite');
  if (spr && me.settings.friendlyLook) {
    me.state.origLook = spr.asset;
    me.set('sprite', { ...spr, asset: me.settings.friendlyLook });
  }
  const v = game.vars;
  dropCrystals(me, game, 6);
  if (v.difficulty === 'story' || game.random() < 0.6) game.giveItem('ink_vial', 1);
  game.say(`Proofread: ${NAMES[kind]} -> ${FRIENDS[kind] || NAMES[kind]}`);
}

/** Each entry is rolled on its own (drop_tables.gd): "item,chance,low,high; ...". */
function rollDrops(game: ScriptGame, table: string): void {
  for (const part of table.split(';')) {
    const [item, chance, lo, hi] = part.split(',').map((x) => x.trim());
    if (!item) continue;
    if (game.random() * 100 < Number(chance)) {
      const a = Number(lo);
      const b = Number(hi);
      game.giveItem(item, b <= a ? a : game.randomInt(a, b));
    }
  }
}
