// Of everything she could use that is close by, only the nearest shows its pop-up prompt (a person, a sign, a chest side by side would
// otherwise pile their prompts on top of each other). Each of them asks "am I the nearest?" and the nearest says so in prompt_focus;
// the prompt (a world UI piece, see prompts.ts) is shown while prompt_focus is its own key.
export default defineScript({
  name: 'Prompt',
  description: 'Says in prompt_focus when it is the nearest thing she could use.',
  settings: {
    key: { value: '', label: 'Its name in prompt_focus' },
    reach: { value: 2, label: 'How close she must be (cells)' },
  },
  update(me, game) {
    const p = game.player;
    if (!p) return;
    const mine = me.distanceTo(p);
    if (mine > Number(me.settings.reach)) return;
    for (const o of game.findAll('tag:prompt')) {
      if (o === me) continue;
      const theirs = o.distanceTo(p);
      if (theirs < mine && theirs <= Number(o.get('script_Prompt')?.reach ?? 2)) return; // somebody else is nearer
    }
    if (game.vars.prompt_focus !== me.settings.key) game.vars.prompt_focus = me.settings.key;
  },
});
