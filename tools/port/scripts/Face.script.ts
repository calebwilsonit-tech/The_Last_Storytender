// A villager turns to face the Storytender while she is near, so the picture of them that fits is the one shown (they have views from every direction).
export default defineScript({
  name: 'Face',
  description: 'Turns to face the Storytender when she is within reach.',
  settings: {
    radius: { value: 7, label: 'Notices her within (cells)' },
  },
  update(me, game) {
    const p = game.player;
    if (!p || me.distanceTo(p) > Number(me.settings.radius)) return;
    // a screen direction: 0 right, 2 down; a grid step (dx, dy) moves the screen by (dx - dy, (dx + dy) / 2)
    me.facing = (Math.round(Math.atan2((p.x - me.x + (p.y - me.y)) / 2, p.x - me.x - (p.y - me.y)) / (Math.PI / 4)) % 8 + 8) % 8;
  },
});
