/**
 * Port tool: the game's cutscenes as the engine's timelines (assets/cutscenes/*.cutscene.json). The Godot game's cinematic() glides the camera to
 * a person or place, zooms, plays the words, and glides back. Black bars come with every cutscene (Director.script.ts), and P skips.
 * What each scene changes in the story is applied by the Director when it ends (so a skip loses nothing).
 */
import { writeFileSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import type { World } from './overworld';

type Step = Record<string, unknown>;

export function writeCutscenes(out: string, schemaVersion: number, w: World): number {
  const dir = join(out, 'assets/cutscenes');
  mkdirSync(dir, { recursive: true });
  const k = (name: string): string => String(w.story.constants[name] ?? '');
  const intro = (w.story.constants.INTRO as string[]) ?? [];
  const list: Record<string, Step[]> = {};
  /** The camera glides to `who` (zoom, seconds), the dialogue plays, the camera comes back. */
  const at = (who: string, dialogue: string, zoom = 1.3, pan = 1.2): Step[] => [
    { type: 'cameraTo', target: who, seconds: pan, zoom },
    { type: 'wait', seconds: 0.3 },
    { type: 'dialogue', dialogue },
    { type: 'wait', seconds: 0.3 },
    { type: 'cameraReset', seconds: 0.9 },
  ];
  // waking up: the page, the first words, the first hints
  list.k_wake = [
    { type: 'message', text: k('INTRO_WAKE') },
    { type: 'wait', seconds: 3 },
    { type: 'message', text: 'Walk with W A S D. Speak or take with E.' },
    { type: 'wait', seconds: 3 },
    { type: 'message', text: 'Strike with J, dash with Shift, shine the lantern by holding Q.' },
    { type: 'wait', seconds: 3 },
    ...intro.flatMap((line) => [{ type: 'message', text: line }, { type: 'wait', seconds: 3.4 }] as Step[]),
  ];
  // the three restorations: the camera to the person, the words, the ink flowing back
  list.k_garrick = [...at('tag:garrick', 'garrick_restoration', 1.45), { type: 'shake', amount: 3, seconds: 0.5 }];
  list.k_pip = [...at('tag:pip', 'pip_restoration', 1.45), { type: 'shake', amount: 3, seconds: 0.5 }];
  list.k_maud = [...at('tag:maud', 'maud_restoration', 1.45), { type: 'shake', amount: 3, seconds: 0.5 }];
  // the rift opens, and she steps in
  list.k_rift = [
    { type: 'sound', name: 'rift' },
    { type: 'cameraTo', target: 'tag:rift', seconds: 1.2, zoom: 1.3 },
    { type: 'wait', seconds: 0.4 },
    { type: 'dialogue', dialogue: 'scissor_rift_enter' },
    { type: 'fade', to: 1, seconds: 0.8, color: 0xf6f3ea },
    { type: 'cameraReset', seconds: 0.1 },
  ];
  // the town is written in
  list.k_publish = [
    { type: 'sound', name: 'publish' },
    { type: 'cameraTo', target: 'tag:rift', seconds: 1.4, zoom: 1.2 },
    { type: 'message', text: k('PUBLISHED') },
    { type: 'wait', seconds: 1.5 },
    { type: 'shake', amount: 4, seconds: 1.2 },
    { type: 'fade', to: 0.85, seconds: 1.4, color: 0xffffff },
    { type: 'wait', seconds: 0.5 },
    { type: 'fade', to: 0, seconds: 1.6, color: 0xffffff },
    { type: 'cameraReset', seconds: 1.2 },
  ];
  // the Margin Gate opens, and the Prologue ends
  list.k_ending = [
    { type: 'sound', name: 'gate_open' },
    { type: 'cameraTo', target: 'tag:margin-gate', seconds: 1.2, zoom: 1.3 },
    { type: 'dialogue', dialogue: 'gate_open' },
    { type: 'shake', amount: 3, seconds: 0.8 },
    { type: 'fade', to: 1, seconds: 1.6, color: 0xf6f3ea },
    { type: 'wait', seconds: 0.4 },
    { type: 'cameraReset', seconds: 0.1 },
  ];
  // after the end card is closed the world comes back out of the white (a fade lasts until the scene changes, and the card does not change it)
  list.k_unfade = [{ type: 'fade', to: 0, seconds: 1.2, color: 0xf6f3ea }];
  // a scene that does nothing: the Director plays it to find out whether any scene is really playing (it is refused while one is)
  list.k_probe = [];
  // the bosses: the camera to them for their words
  for (const [name, dialogue, zoom] of [
    ['k_critic_intro', 'critic_intro', 1.3],
    ['k_critic_reckon', 'critic_reckon', 1.3],
    ['k_critic_end', 'critic_end', 1.3],
    ['k_spoiler_intro', 'spoiler_intro', 1.3],
    ['k_spoiler_reckon', 'spoiler_reckon', 1.3],
    ['k_spoiler_end', 'spoiler_end', 1.3],
    ['k_maud_table', 'maud_table', 1.25],
    ['k_maud_reckon', 'maud_reckon', 1.25],
    ['k_maud_end', 'maud_end', 1.3],
    ['k_scissor_intro', 'scissor_boss_intro', 1.2],
    ['k_scissor_finale', 'scissor_finale', 1.25],
  ] as const) list[name] = at(name === 'k_maud_table' || name === 'k_maud_reckon' ? '36.5,7.5' : 'tag:boss', dialogue, zoom, 1.4);
  for (const [name, steps] of Object.entries(list)) {
    // the first steps put the black bars up and everyone still; the last take them away and say it is over. A skip runs the steps that are left,
    // so this is how the Director finds out a scene has ended even when it ended in a tick the scripts did not run (a conversation open).
    const bars = name === 'k_wake' || name === 'k_unfade' || name === 'k_probe' ? [] : [{ type: 'setVariable', name: 'letterbox', value: 1 }];
    const framed = [...bars, { type: 'setVariable', name: 'cutscene_on', value: 1 }, ...steps, { type: 'setVariable', name: 'letterbox', value: 0 }, { type: 'setVariable', name: 'cutscene_on', value: 0 }, { type: 'setVariable', name: `ended_${name}`, value: 1 }];
    const data = { schemaVersion, name, skippable: true, steps: framed.map((s, i) => ({ id: `s${i + 1}`, async: false, ...s })) };
    writeFileSync(join(dir, `${name}.cutscene.json`), JSON.stringify(data, null, 2) + '\n');
  }
  return Object.keys(list).length;
}
