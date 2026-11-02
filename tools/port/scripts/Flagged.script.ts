// An object that changes with the story: it disappears (or appears) when a flag is set, and can take another picture
// once a flag is set (a chest that has been opened, a person who has been restored).
export default defineScript({
  name: 'Flagged',
  description: 'Hidden, shown or redrawn by a story flag.',
  settings: {
    hideWhen: { value: '', label: 'Gone once this flag is set' },
    showWhen: { value: '', label: 'Only there once this flag is set' },
    lookWhen: { value: '', label: 'Change picture once this flag is set' },
    look: { value: '', label: 'The other picture (sprite name)' },
  },
  update(me, game) {
    const v = game.vars;
    const s = me.settings;
    if (s.hideWhen && v[s.hideWhen]) {
      me.destroy();
      return;
    }
    const shown = !s.showWhen || !!v[s.showWhen];
    if (me.visible !== shown) me.visible = shown;
    const col = me.get('collider');
    if (col && col.enabled !== shown) me.set('collider', { ...col, enabled: shown });
    if (s.lookWhen && s.look && v[s.lookWhen]) {
      const spr = me.get('sprite');
      if (spr && spr.asset !== s.look) me.set('sprite', { ...spr, asset: s.look });
    }
  },
});
