// The tear in the square (main.gd _check_rift, _enter_rift, _publish_scene): once Garrick, Pip and Maud are restored a seam opens at (88,53) and
// leads to the Cutting Room. When she comes back with the Scissor-Man beaten, the Prologue is published: the town is written in.
const RIFT_NARRATION = 'With the last of them remembered, something in the sky begins to cut. A seam opens in the middle of the square.';
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
    // back from the Cutting Room: the town is published, a moment after she arrives
    if (v.scissor_done && !v.town_published) {
      s.t += game.dt;
      if (s.t > 1.5 && !s.said) {
        s.said = true;
        v.play_k_publish = 1; // the cutscene says PUBLISHED, and the Director publishes the town when it ends
      }
    }
  },
});
