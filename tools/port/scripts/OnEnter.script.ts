// Something said as the Storytender arrives somewhere, once (a memory's opening words).
export default defineScript({
  name: 'OnEnter',
  description: 'Starts a conversation the first time the scene is entered.',
  settings: {
    dialogue: { value: '', label: 'Conversation' },
    flag: { value: '', label: 'Remembered as (flag; the conversation should set it)' },
  },
  update(me, game) {
    if (me.state.done) return;
    me.state.t = (me.state.t ?? 0) + game.dt;
    if (me.state.t < 1.2) return;
    me.state.done = true;
    if (!game.vars[me.settings.flag]) game.startDialogue(String(me.settings.dialogue));
  },
});
