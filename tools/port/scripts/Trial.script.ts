// A riddle stone's vault trial (main.gd _attempt_trial, vault_trial.gd): "Attempt the trial" sets start_<id>; a word game is played; winning
// settles the stone on its last word, opens the riddle's gate (riddle_<id>, StoryGate.script.ts), pays 4 + 4 x tier renown and says RIDDLE_OPEN;
// losing says "The words slip away. Try again whenever you like." and the stone can be tried again.
//   tier 1  Proofread: find the wrong word in a sentence (the Proofread screen, 3 tries)
//   tier 3+ a game of the engine's (Repeat the pattern), standing in for the Godot game's Typewriter, which needs a clock and raw keys
const SENTENCES: [string, number, string][] = [
  ['She went to the store to buy some milk and bread.', 7, 'bye'],
  ['The knight drew his sword and charged at the dragon.', 3, 'drue'],
  ['It was a bright, cold day in the middle of April.', 7, 'mid-dle'],
  ['They said the old bridge would never hold their weight.', 2, 'sed'],
  ['The baker left warm bread on the table for the guests.', 8, 'gests'],
  ['He didn\'t know weather the story would ever be finished.', 3, 'weather'],
  ['Their was a small door hidden behind the bookshelf.', 0, 'Their'],
  ['The ghost of the forge remembered its first sword.', 2, 'ghoast'],
  ['A page turned slowly in the wind, then the next one followed.', 5, 'wynd'],
  ['Nobody remembered who had writen the last chapter.', 4, 'writen'],
];
const RIDDLE_OPEN = 'The sentence settles into place, and the gate remembers it was always unlatched.';
export default defineScript({
  name: 'Trial',
  description: 'A riddle stone: runs its word trial and opens its gate.',
  settings: {
    id: { value: '', label: 'Riddle id' },
    tier: { value: 1, label: 'Tier (1 to 4)' },
    last: { value: 2, label: 'Number of the last word' },
  },
  start(me, game) {
    me.state.mode = 'idle';
    if (game.vars[`riddle_${me.settings.id}`]) settle(me);
  },
  update(me, game) {
    const v = game.vars;
    const id = String(me.settings.id);
    const s = me.state;
    if (s.mode === 'idle') {
      if (!v[`start_${id}`]) return;
      v[`start_${id}`] = 0;
      if (v[`riddle_${id}`]) return;
      if (Number(me.settings.tier) <= 1) {
        // the Proofread screen: a sentence with one wrong word (the screen counts the tries)
        const [text, bad, wrong] = SENTENCES[game.randomInt(0, SENTENCES.length - 1)]!;
        const words = text.split(' ');
        words[bad] = wrong;
        for (let i = 0; i < 12; i++) {
          v[`pf_has_${i}`] = i < words.length ? 1 : 0;
          v[`pf_w${i}`] = words[i] ?? '';
          v[`pf_x${i}`] = 0;
        }
        v.pf_bad = bad;
        v.pf_tries = 3;
        v.pf_solved = 0;
        v.pf_msg = '';
        v.pf_open = 1;
        s.mode = 'proofread';
        game.do('uiScreen', { op: 'open', screen: 'storytender-proofread' });
      } else {
        s.mode = 'minigame';
        s.played = Number(v[`minigame:Vault Trial ${id}:played`] ?? 0);
        game.do('playMinigame', { minigame: `Vault Trial ${id}` });
      }
      return;
    }
    if (s.mode === 'proofread' && !v.pf_open) {
      s.mode = 'idle';
      end(me, game, !!v.pf_solved);
    } else if (s.mode === 'minigame') {
      const played = Number(v[`minigame:Vault Trial ${id}:played`] ?? 0);
      if (played > s.played) {
        s.mode = 'idle';
        end(me, game, !!v[`minigame:Vault Trial ${id}:won`]);
      }
    }
  },
});

function end(me: ScriptEntity, game: ScriptGame, won: boolean): void {
  if (!won) {
    game.say('The words slip away. Try again whenever you like.');
    return;
  }
  const v = game.vars;
  v[`riddle_${me.settings.id}`] = 1;
  v.renown = Number(v.renown ?? 0) + 4 + 4 * Number(me.settings.tier);
  game.say(RIDDLE_OPEN);
  settle(me);
}

/** The stone shows its last word and can no longer be tried. */
function settle(me: ScriptEntity): void {
  const ss = me.get('sentenceStone');
  if (ss) me.set('sentenceStone', { ...ss, selected: Number(me.settings.last) });
}
