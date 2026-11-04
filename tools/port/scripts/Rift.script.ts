// The tear in the square (main.gd _check_rift, _enter_rift, _publish_scene): once Garrick, Pip and Maud are restored a seam opens at (88,53) and
// leads to the Cutting Room. When she comes back with the Scissor-Man beaten, the Prologue is published: the town is written in.
const RIFT_NARRATION = 'With the last of them remembered, something in the sky begins to cut. A seam opens in the middle of the square.';
const PUBLISHED = 'The Prologue is written. Whatever comes next, it has somewhere to begin.';
export default defineScript({
  name: 'Rift',
  description: 'The rift into the Cutting Room, and publishing the town afterwards.',
  settings: {
    reach: { value: 3.5, label: 'How close to step into it (cells)' },
  },
  start(me) {
    me.state.t = 0;
  },
  update(me, game) {
    const v = game.vars;
    const s = me.state;
    const open = !!v.restored_garrick && !!v.restored_pip && !!v.restored_maud && !v.scissor_done;
    const talk = me.get('npcTalk');
    if (me.visible !== open) me.visible = open;
    const col = me.get('collider');
    if (col && col.enabled !== open) me.set('collider', { ...col, enabled: open });
    if (talk) {
      const reach = open ? Number(me.settings.reach) : 0.01;
      if (talk.reach !== reach) me.set('npcTalk', { ...talk, reach });
    }
    if (open && !v.rift_seen) {
      v.rift_seen = 1;
      game.say(RIFT_NARRATION);
    }
    // the Margin Gate has opened (a conversation sets ending_go): the end card of the Prologue
    if (v.ending_go) {
      v.ending_go = 0;
      s.endAt = game.time + 1.2;
    }
    if (s.endAt && game.time >= s.endAt) {
      s.endAt = 0;
      v.prologue_complete = 1;
      game.do('saveGame', { slot: 'autosave' });
      game.do('uiScreen', { op: 'open', screen: 'storytender-ending' });
    }
    // back from the Cutting Room: the town is published, a moment after she arrives
    if (v.scissor_done && !v.town_published) {
      s.t += game.dt;
      if (s.t > 1.5 && !s.said) {
        s.said = true;
        game.say(PUBLISHED);
      }
      if (s.t > 1.5 + 5.5 * 0.8) {
        v.restored_town = 1;
        v.town_published = 1;
        game.do('saveGame', { slot: 'autosave' });
      }
    }
  },
});
