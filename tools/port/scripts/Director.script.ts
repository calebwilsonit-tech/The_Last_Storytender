// Plays the game's cutscenes (main.gd cinematic(), the boss and restoration scenes) and finishes what each one is about.
// A conversation, a boss script or the rift sets play_<cutscene>; this plays it. While one plays the screen has black bars (letterbox), everyone
// else stands still (cutscene_on), and P skips it. What a scene changes in the story (flags, rewards) is applied when it ENDS, whether it was
// watched or skipped, so a skip never loses anything.
interface Outcome {
  set?: Record<string, number>;
  add?: Record<string, number>;
  give?: [string, number][];
  say?: string;
  save?: boolean;
  open?: string;
}
const OUTCOMES: Record<string, Outcome> = {
  k_garrick: { set: { restored_garrick: 1 }, add: { mnemosynth: 25, renown: 35 }, say: 'Restored: Garrick' },
  k_pip: { set: { restored_pip: 1 }, add: { mnemosynth: 30, renown: 35 }, say: 'Restored: Pip' },
  k_maud: { set: { restored_maud: 1 }, add: { mnemosynth: 30, renown: 35 }, give: [['warm_loaf', 3]], say: 'Restored: Maud' },
  k_rift: { set: { go_scissor: 1 } },
  k_publish: { set: { restored_town: 1, town_published: 1 }, save: true },
  k_ending: { set: { gate_opened: 1, prologue_complete: 1 }, save: true, open: 'storytender-ending' },
  k_critic_intro: { set: { critic_awake: 1 } },
  k_critic_reckon: { set: { critic_reckoning: 1 } },
  k_critic_end: { set: { critic_down: 1 } },
  k_spoiler_intro: { set: { spoiler_awake: 1 } },
  k_spoiler_reckon: { set: { spoiler_reckoning: 1 } },
  k_spoiler_end: { set: { spoiler_down: 1 } },
  k_maud_table: { set: { table_awake: 1 } },
  k_maud_reckon: { set: { cold_spawn: 1 } },
  k_maud_end: { set: { maud_finale: 1, cold_down: 1 } },
  k_scissor_intro: {},
  k_scissor_finale: { set: { scissor_finale_done: 1 } },
  k_wake: { set: { woke_up: 1 } },
};
/** Scenes with no black bars (the waking up is just the page, and some words). */
const NO_BARS = new Set(['k_wake']);
/** The music of each boss while it is awake (its name is what the boss scripts put in boss_name). */
const BOSS_MUSIC: Record<string, string> = { 'The Critic': 'music_boss_critic', 'The Spoiler': 'music_boss_spoiler', 'The Cold Shoulder': 'music_boss_cold', 'The Scissor-Man': 'music_boss_scissor' };
export default defineScript({
  name: 'Director',
  description: 'Plays cutscenes when play_<name> is set, and applies what they change when they end.',
  settings: {
    music: { value: '', label: 'The music of this place' },
    step: { value: 'step_grass', label: 'The sound of her steps here' },
  },
  start(me, game) {
    me.state.now = '';
    me.state.cur = '';
    me.state.walked = 0;
    me.state.last = null;
    game.vars.cutscene_on = 0;
    game.vars.letterbox = 0;
    // a game not begun yet shows the title, with its own music
    if (!game.vars.difficulty_locked && !game.vars.book_seen) {
      me.state.cur = 'music_title';
      game.do('music', { name: 'music_title' });
    }
  },
  update(me, game) {
    const v = game.vars;
    const s = me.state;
    // a scene that has ended (its last step sets ended_<name>): what it changes is applied now
    for (const [name, o] of Object.entries(OUTCOMES)) {
      if (!v[`ended_${name}`]) continue;
      v[`ended_${name}`] = 0;
      s.now = '';
      v.cutscene_on = 0;
      v.letterbox = 0;
      for (const [k, x] of Object.entries(o.set ?? {})) v[k] = x;
      for (const [k, x] of Object.entries(o.add ?? {})) v[k] = Number(v[k] ?? 0) + x;
      for (const [item, n] of o.give ?? []) game.giveItem(item, n);
      if (o.say) game.say(o.say);
      if (o.save) game.do('saveGame', { slot: 'autosave' });
      if (o.open) game.do('uiScreen', { op: 'open', screen: o.open });
    }
    // ---- the sounds of what happens
    const p = game.player;
    const play = (name: string): void => game.do('sound', { name, volume: 1 });
    if (p) {
      for (const e of game.eventsOf('damaged')) play(e.entity === p.id ? 'hurt' : 'quill_hit');
      for (const e of game.eventsOf('attack')) if (e.entity === p.id) play('quill_swing');
      for (const e of game.eventsOf('dodge')) if (e.entity === p.id) play('dash');
      for (const e of game.eventsOf('healed')) if (e.entity === p.id) play('heal');
      for (const e of game.eventsOf('died')) if (((e.tags as string[]) ?? []).includes('player')) play('crumple');
      // footsteps: one for every step and a half she walks
      const last = s.last as { x: number; y: number } | null;
      if (last && !v.cutscene_on) {
        const d = Math.hypot(p.x - last.x, p.y - last.y);
        if (d > 0.05 && d < 1.5) s.moved = true; // a game is on once she walks (the title does not let her)
        if (d < 1.5) s.walked += d;
        if (s.walked > 1.5) {
          s.walked = 0;
          play(String(me.settings.step));
        }
      }
      s.last = { x: p.x, y: p.y };
    }
    for (const e of game.eventsOf('item-given')) if (Number(e.amount) > 0) play('pickup');
    if (game.eventsOf('item-used').length > 0) play('item_use');
    if (game.eventsOf('lantern-lit').length > 0) play('post_light');
    else if (game.eventsOf('rested').length > 0) play('rest');
    if (game.eventsOf('sentence-changed').length > 0) play('stone_rewrite');
    if (v.lantern_on && !s.lamp) play('lantern_on');
    s.lamp = !!v.lantern_on;
    // the title's music is asked for again every second until a game is begun (the sound files may still have been loading when the scene started)
    if (!(v.difficulty_locked || v.book_seen || s.moved)) {
      s.again = (s.again ?? 0) + game.dt;
      if (s.again > 1) {
        s.again = 0;
        game.do('music', { name: 'music_title' });
      }
    }
    // ---- the music: the place's, and a boss's while it fights, once a game is begun
    if (v.difficulty_locked || v.book_seen || s.moved) {
      const want = BOSS_MUSIC[String(v.boss_name ?? '')] ?? String(me.settings.music);
      if (want && want !== s.cur) {
        s.cur = want;
        game.do('music', { name: want });
      }
    }
    // a scene asked for: only when none is playing
    if (!s.now) {
      for (const name of Object.keys(OUTCOMES)) {
        if (!v[`play_${name}`]) continue;
        v[`play_${name}`] = 0;
        if (game.playCutscene(name)) {
          // (its 'started' event is this very tick's, which this script has already passed)
          s.now = name;
          v.cutscene_on = 1;
          v.letterbox = NO_BARS.has(name) ? 0 : 1;
          break;
        }
        v[`play_${name}`] = 1; // busy: try again next tick
      }
    }
  },
});
