// A gap a sentence can fill (memory_pip.gd: the bridge, the frozen river, the floor written solid): while its flag is
// set the cell can be walked on and shows the bridge's look; otherwise it is a dark gap that cannot be crossed.
export default defineScript({
  name: 'PitCover',
  description: 'A gap that is walkable only while its flag is set.',
  settings: {
    flag: { value: '', label: 'Walkable while this flag is set' },
    lookOn: { value: '', label: 'Picture while walkable' },
    lookOff: { value: '', label: 'Picture of the gap' },
  },
  update(me, game) {
    const on = !!game.vars[me.settings.flag];
    const col = me.get('collider');
    if (col && col.enabled === on) me.set('collider', { ...col, enabled: !on });
    const look = on ? me.settings.lookOn : me.settings.lookOff;
    const spr = me.get('sprite');
    if (look && spr && spr.asset !== look) me.set('sprite', { ...spr, asset: look });
  },
});
