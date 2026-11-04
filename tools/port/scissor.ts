/**
 * Port tool: the Cutting Room (editor_scissor.gd). The Scissor-Man and the clippings get what they need to be struck, the exit takes her home,
 * and every cell of the arena gets a flat cover that shows a cut line, a hole, a patch or where a paste would land (Scissor.script.ts).
 */
import type { EntityData } from '@tilewright/runtime';
import { Talk, type World } from './overworld';

export const SCISSOR_RETURN = '88.5,54.5';
const COLLIDER = (w: number, d: number, height: number): object => ({ w, d, height, solid: true, trigger: false, layer: 16, mask: 65535, enabled: true, inside: [] });

export function writeScissorTalk(w: World): void {
  const t = new Talk('leave_scissor');
  w.write('leave_scissor', t.data(t.seq(t.lines([{ who: '', text: 'You step out of the Cutting Room, and the Prologue comes back.', style: 'action' }], w.keyed), t.set('leave_scissor', 1))[0]));
}

/** What one object of the Cutting Room does. */
export function decorateScissor(e: EntityData, cls: string, kind: number, w: World): void {
  const c = e.components;
  if (cls === 'ScissorMan') {
    e.tags.push('boss', 'scissor', 'enemy');
    w.attach(c, 'health', { max: 90, invulnerableSeconds: 0.12, onDeath: 'stay', fallDamage: 0, team: 'enemy', showBar: false });
    c.body = { vx: 0, vy: 0, vz: 0, radius: 0.6, height: 2, state: 'ground', stepUp: 0.35, stepDown: 0.4, ledge: 'stop', pits: 'stop', wade: false, gravity: 1, peakZ: 0, layer: 4, mask: 65535, noclip: true, blockedBy: [], blockedTerrain: false };
    w.attach(c, 'script_Scissor', { minions: 5 });
    return;
  }
  if (cls === 'Clipping') {
    makeClipping(e, w);
    return;
  }
  if (cls === 'Prop' && kind === 8) {
    // the way out
    w.attach(c, 'npcTalk', { dialogue: 'leave_scissor', reach: 70 / 35.8 + 0.4, facePlayer: false, once: false, hint: true });
    w.attach(c, 'script_Gateway', { flag: 'leave_scissor', scene: 'scenes/overworld.scene.json', spawn: SCISSOR_RETURN });
    c.collider = COLLIDER(0.8, 0.8, 1.5);
  }
}

/** A clipping: struck once to be picked up (Scissor.script.ts takes it). */
export function makeClipping(e: EntityData, w: Pick<World, 'attach'>): void {
  e.tags.push('clipping');
  w.attach(e.components, 'health', { max: 1, invulnerableSeconds: 0.05, onDeath: 'stay', fallDamage: 0, team: 'enemy', showBar: false });
}

/** The covers of the arena's cells, and the little copies that wait for the second and third phase. */
export function scissorExtras(cells: [number, number][], levelOf: (x: number, y: number) => number, looks: { hole: string }, mkError: (kind: number, x: number, y: number, unlock: string) => EntityData, next: () => string): EntityData[] {
  const out: EntityData[] = [];
  for (const [x, y] of cells) {
    out.push({
      id: next(),
      name: `Cell ${x},${y}`,
      tags: ['scell'],
      components: { transform: { x: x + 0.5, y: y + 0.5, h: levelOf(x, y), facing: 2 }, sprite: { shape: 'box', color: 0x1c1824, w: 1, d: 1, height: 0.02, sortOffset: -0.9, visible: false, asset: looks.hole } },
    });
  }
  // the little copies (a Mite or a Bare), hidden until he wakes them (scissor_minion_<n>)
  const spots: [number, number, number][] = [[1, 6, 6], [1, 18, 6], [1, 6, 13], [1, 18, 13], [0, 12, 12]];
  spots.forEach(([kind, x, y], i) => {
    const e = mkError(kind, x, y, `scissor_minion_${i}`);
    e.tags.push('scissor-minion');
    out.push(e);
  });
  return out;
}
