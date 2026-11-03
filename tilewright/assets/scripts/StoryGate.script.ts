// A gate of the memories (story_gate.gd): a wall of the word FORGOTTEN that opens while its condition holds. It closes
// again once the condition fails, but only when the Storytender is not right beside it (so it never shuts on her).
export default defineScript({
  name: 'StoryGate',
  description: 'A gate that opens while its flags are set.',
  settings: {
    needs: { value: '', label: 'Open when (flags joined by +, or name>=number)' },
    closeFar: { value: 2.5, label: 'Closes again only when the Storytender is this far (cells; 0 = stays open)' },
    said: { value: '', label: 'Said the first time it opens' },
  },
  update(me, game) {
    const v = game.vars;
    const want = String(me.settings.needs).split('+').every((c) => {
      const m = /^(\w+)>=(\d+)$/.exec(c.trim());
      return m ? Number(v[m[1]!] ?? 0) >= Number(m[2]) : !!v[c.trim()];
    });
    const s = me.state;
    if (s.open === undefined) s.open = false;
    const p = game.player;
    if (want && !s.open) {
      s.open = true;
      if (me.settings.said && !s.saidIt) {
        s.saidIt = true;
        game.say(String(me.settings.said));
      }
    } else if (!want && s.open && Number(me.settings.closeFar) > 0 && (!p || me.distanceTo(p) > Number(me.settings.closeFar))) s.open = false;
    const col = me.get('collider');
    if (col && col.enabled === s.open) me.set('collider', { ...col, enabled: !s.open });
    const target = s.open ? 0 : 1;
    me.alpha += (target - me.alpha) * Math.min(1, game.dt * 6);
    me.visible = me.alpha > 0.05;
  },
});
