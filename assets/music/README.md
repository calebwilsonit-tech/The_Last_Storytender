# Music

The game's music system is built but this folder ships empty. To add a track, put a file named after
the slot in this folder: `overworld.ogg`, `boss_critic.ogg`, and so on (`.ogg` is best; `.mp3` and
`.wav` also work). Open the project in Godot once so it imports the file. A slot with no file is
silent, so you can add tracks one at a time.

| Slot | Where it plays |
|---|---|
| `title` | Title screen |
| `storybook` | The New Game storybook |
| `overworld` | The Prologue overworld (default everywhere outside dungeons) |
| `region_<id>` | Optional track for one region (for example `region_o`); falls back to `overworld` |
| `index` | The Index hub at a lantern post |
| `memory_forge` | Garrick's memory |
| `memory_pip` | Pip's memory |
| `memory_maud` | Maud's memory |
| `editor_scissor` | The Scissor-Man's arena before the fight |
| `boss_critic`, `boss_critic_reckoning` | The Critic (two halves; the second falls back to the first) |
| `boss_spoiler`, `boss_spoiler_reckoning` | The Spoiler |
| `boss_empty_table`, `boss_cold_shoulder` | Maud's boss (seating, then the Cold Shoulder) |
| `boss_scissor` | The Scissor-Man fight |
| `victory` | A short sting after a boss or a restoration (plays once, no loop) |

Tracks loop and crossfade, dip under dialogue and cutscenes, and follow Settings > Music volume.

## Credits (keep this up to date)

Every track needs its license recorded. CC0 needs no credit but note it anyway; CC-BY **requires**
credit in the game. Add one line per track:

| File | Title | Artist | License | Source link |
|---|---|---|---|---|
| (none yet) | | | | |
