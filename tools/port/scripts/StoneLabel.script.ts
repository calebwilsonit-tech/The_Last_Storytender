// A sentence stone's words, readable (V-02): the engine writes the sentence small and pale over the board; here it is written big, dark and
// bold on the board's paper, with the word that can change in brackets.
export default defineScript({
  name: 'StoneLabel',
  description: 'Writes a sentence stone\'s sentence large and dark on its board.',
  settings: {},
  phase: 'actuator', // after the stone has written its own label
  update(me) {
    const ss = me.get('sentenceStone') as { before: string; words: string; after: string; selected: number } | undefined;
    if (!ss) return;
    const words = ss.words.split(',').map((w) => w.trim()).filter(Boolean);
    const word = words.length ? words[((ss.selected % words.length) + words.length) % words.length]!.toUpperCase() : '...';
    const text = [ss.before.trim(), `[ ${word} ]`, ss.after.trim()].filter(Boolean).join(' ');
    me.set('label', { text, color: 0x2b1d12, size: 19, bold: true, italic: false, underline: false, lift: -1.55 + 0.35 * (Math.floor(me.x) % 3) }); // on the board, not above it (the label sits that far above the board's top); stones stand two cells apart, so their lines are stepped
  },
});
