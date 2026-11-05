// Port tool: the pop-up that tells the player what the buttons do next to something they can use. The engine's own hint ("E: talk")
// is a line of text drawn on the object; this hangs a small prompt (a UI prefab, see screens.ts) over it instead, shown while she is
// close enough, not in the middle of a conversation with it, and the nearest thing she could use (Prompt.script.ts).
import { promptPrefab } from './screens';

interface Ent {
  name: string;
  tags?: string[];
  components: Record<string, unknown>;
}

/** What the button does, from the conversation the object has. */
export function verbOf(dialogue: string): string {
  if (/^(lore_|plaque_|forge_look_|shard_)|sign$/.test(dialogue)) return 'Read';
  if (/^chest_/.test(dialogue)) return 'Open';
  if (/^take_/.test(dialogue)) return 'Take';
  if (/^leave_/.test(dialogue)) return 'Leave';
  if (/^(forge|pip_book|maud_oven|margin_gate|rift_enter|pip_door|portal_)/.test(dialogue)) return 'Enter';
  if (/^maud_sit$/.test(dialogue)) return 'Sit';
  if (/^(garrick|pip|maud|pip_turn)$/.test(dialogue)) return 'Talk';
  return 'Use';
}

/** Turns the engine's text hint off and hangs the prompt over every object that is talked to. */
export function promptify(entities: Ent[]): number {
  let n = 0;
  for (const e of entities) {
    // a lantern post: its own text hint off, "Light" / "Rest" over it instead
    const post = e.components.checkpoint as { reach: number; hint: boolean } | undefined;
    if (post) {
      post.hint = false;
      const key = `p${++n}`;
      e.components.script_Prompt = { key, reach: post.reach };
      e.tags = [...(e.tags ?? []), 'prompt'];
      e.components.worldUi = { prefab: promptPrefab('Light'), height: 2.9, showWhen: `{prompt_focus} = ${key}`, maxDistance: Math.max(1.5, post.reach) };
      continue;
    }
    const t = e.components.npcTalk as { dialogue: string; reach: number; hint: boolean } | undefined;
    if (!t || !t.hint || !t.dialogue) continue;
    t.hint = false;
    const spr = e.components.sprite as { height?: number } | undefined;
    const key = `p${++n}`;
    e.components.script_Prompt = { key, reach: t.reach };
    e.tags = [...(e.tags ?? []), 'prompt'];
    e.components.worldUi = {
      prefab: promptPrefab(verbOf(t.dialogue)),
      height: Math.max(1.4, (spr?.height ?? 1.2) + 0.8),
      // shown while it is visible, she is not in the middle of talking to it, and it is the nearest thing she could use
      showWhen: `{self.sprite.visible} != 0 && {self.npcTalk.talking} != 1 && {prompt_focus} = ${key}`,
      maxDistance: Math.max(1.5, t.reach),
    };
  }
  return n;
}
