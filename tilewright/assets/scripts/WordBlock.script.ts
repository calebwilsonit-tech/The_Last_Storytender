// A word with weight (text_block.gd), in Maud's memory. Strike it with the quill after choosing a style (1 underline,
// 2 bold, 3 italic): UNDERLINE makes it walkable and bridges the gap beneath it, BOLD makes it heavy (it presses a plate,
// it shelters from the cold), ITALIC sends it sliding along its slant until something stops it (worked out beforehand,
// or the Storytender standing in the way). Rising dough cannot be rushed: it rises over riseTime seconds (faster in the
// lantern's warmth) and a strike before then collapses it. The engine's textBlock draws the word in its formatting.
const K = 35.8;
export default defineScript({
  name: 'WordBlock',
  description: 'A formattable word: underline bridges, bold weighs, italic slides; dough rises.',
  settings: {
    gapFlag: { value: '', label: 'Underlined (or risen), it bridges the gap: set this flag' },
    leanX: { value: 1, label: 'Slides this way (x)' },
    leanY: { value: 0, label: 'Slides this way (y)' },
    slideTo: { value: '', label: 'Where a slide stops (x,y of its centre), worked out from the map' },
    riseTime: { value: 0, label: 'Rising dough: seconds to rise (0 = not dough)' },
  },
  start(me) {
    const s = me.state;
    s.underline = false;
    s.bold = false;
    s.sliding = false;
    s.rise = Number(me.settings.riseTime) > 0 ? 0 : 1;
    s.hp = undefined;
  },
  update(me, game) {
    const v = game.vars;
    const s = me.state;
    const p = game.player;
    const hp = me.get('state:health');
    const health = me.get('health');
    // struck by the quill (any hit at all): apply the chosen style
    let struck = false;
    if (hp && health) {
      if (s.hp !== undefined && hp.hp < s.hp) struck = true;
      if (hp.hp !== health.max) me.set('state:health', { ...hp, hp: health.max, dead: false });
      s.hp = health.max;
    }
    const rising = Number(me.settings.riseTime) > 0;
    if (rising && s.rise < 1) {
      // dough: rises by itself, faster in the lantern's beam; struck early, it collapses
      let rate = 1 / Number(me.settings.riseTime);
      if (p && v.lantern_on) {
        const d = me.distanceTo(p);
        const bx = me.x - p.x;
        const by = me.y - p.y;
        // her facing is a direction on the screen; the way to this is turned onto the screen first (see Redactor.script.ts)
        let off = Math.abs(Math.atan2((bx + by) / 2, bx - by) - (p.facing * Math.PI) / 4) % (2 * Math.PI);
        if (off > Math.PI) off = 2 * Math.PI - off;
        if (d <= 175 / K + 1 && (d < 0.8 || off <= 0.8)) rate *= 2.5;
      }
      s.rise = Math.min(1, s.rise + game.dt * rate);
      if (struck) {
        s.rise = 0;
        game.say('The dough sighs and collapses. It cannot be rushed.');
      }
      if (s.rise >= 1) game.say('The dough has risen. Now it can take a format.');
      me.alpha = 0.55 + 0.45 * s.rise;
    } else if (struck && !s.sliding) {
      const style = String(v.format_style ?? 'underline');
      if (style === 'underline') s.underline = !s.underline;
      else if (style === 'bold') s.bold = !s.bold;
      else if (style === 'italic' && me.settings.slideTo) s.sliding = true;
      if (me.settings.gapFlag) v[me.settings.gapFlag] = s.underline ? 1 : 0;
    }
    // sliding: a cell every 0.16 s towards where it stops, unless the Storytender is in the way
    if (s.sliding) {
      s.step = (s.step ?? 0) + game.dt;
      const [tx, ty] = String(me.settings.slideTo).split(',').map(Number);
      if (s.step >= 0.16) {
        s.step = 0;
        const lx = Number(me.settings.leanX);
        const ly = Number(me.settings.leanY);
        const nx = me.x + lx;
        const ny = me.y + ly;
        const blocked = p && Math.floor(p.x) === Math.floor(nx) && Math.floor(p.y) === Math.floor(ny);
        if (blocked || Math.abs(me.x - tx!) + Math.abs(me.y - ty!) < 0.1) s.sliding = false;
        else me.moveTo(nx, ny, me.h);
      }
    }
    if (s.bold) me.tags.add('bold');
    else me.tags.delete('bold');
    const fmt = s.underline ? 'underline' : s.bold && !s.sliding ? 'bold' : 'plain';
    const tb = me.get('textBlock');
    if (tb && tb.format !== fmt) me.set('textBlock', { ...tb, format: fmt });
    // the picture already has the word on it: the engine's own copy of it is not shown (V-01); only how it is formatted, in a small tag
    me.set('label', { text: fmt === 'plain' ? '' : fmt, color: 0xfff2c0, size: 11, bold: false, italic: false, underline: false, lift: 0.05 });
  },
});
