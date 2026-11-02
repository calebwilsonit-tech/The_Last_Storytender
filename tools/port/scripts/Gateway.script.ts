// Where a conversation sends the Storytender (into a memory, a side room): the conversation sets a flag, this takes
// the player there and clears it (main.gd: Transition.go after the line).
export default defineScript({
  name: 'Gateway',
  description: 'Travels to a scene when a conversation sets a flag.',
  settings: {
    flag: { value: '', label: 'When this flag is set' },
    scene: { value: '', label: 'Go to scene' },
    spawn: { value: '', label: 'Appear at (object name or x,y)' },
  },
  update(me, game) {
    const f = me.settings.flag;
    if (!f || !game.vars[f]) return;
    game.vars[f] = 0;
    game.travel(me.settings.scene, me.settings.spawn);
  },
});
