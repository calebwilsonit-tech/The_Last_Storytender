/**
 * Port tool: the overworld's puzzle sites (puzzle_sites.gd, FLOW_SPEC 3.6). Each site guards a chest:
 *   echo     two plates, one pressed by an echo while she stands on the other, open the WEIGHED gate
 *   words    three sentence stones set to the sentence the sign gives bridge a moat of plot holes
 *   arena    stepping on the plate shuts the PROOF gate; two waves of Errors; beaten, it opens
 *   crumble  a causeway of loose pages that crumble a moment after she steps on them
 * The objects of a site (plates, gate, stones, sign) are the ones the game's map already has; overworld.ts gives them their scripts.
 * What is made here is the rest: one invisible controller per site (Site.script.ts), the covers of a bridge, the cracks of a causeway,
 * and the Errors of an arena's waves (hidden until their wave).
 */
import type { EntityData } from '@tilewright/runtime';

export interface SiteData {
  type: string;
  chest: [number, number];
  tier?: number;
  // echo and arena
  gate?: [number, number];
  axis?: [number, number];
  plates?: [number, number][];
  hint?: [number, number];
  hint_id?: string;
  trigger?: [number, number];
  waves?: [number, number, string][][];
  // words
  stones?: { cell: [number, number]; good: number; options: string[]; prefix: string; suffix: string }[];
  sign?: [number, number];
  sign_id?: string;
  bridge?: [number, number][];
  // crumble
  cells?: [number, number][];
  start?: [number, number];
}

export interface SiteLooks {
  hole: string;
  plank: string;
  crack: string;
}

export const ERROR_OF_LETTER: Record<string, number> = { g: 0, x: 1, l: 2, d: 3, n: 4, z: 5 };

/** The cells of every words site's bridge: floor under a cover (not a pit), so the cover can open the way. */
export function bridgeCells(sites: Record<string, SiteData>): Set<string> {
  const out = new Set<string>();
  for (const s of Object.values(sites)) if (s.type === 'words') for (const c of s.bridge ?? []) out.add(`${c[0]},${c[1]}`);
  return out;
}

const COLLIDER = (w: number, d: number, height: number): object => ({ w, d, height, solid: true, trigger: false, layer: 16, mask: 65535, enabled: true, inside: [] });

export function siteExtras(
  sites: Record<string, SiteData>,
  levelOf: (x: number, y: number) => number,
  looks: SiteLooks,
  mkError: (kind: number, x: number, y: number, unlock: string) => EntityData,
  next: () => string,
): EntityData[] {
  const out: EntityData[] = [];
  const flat = (name: string, tags: string[], x: number, y: number, asset: string, visible: boolean, extra: Record<string, unknown> = {}): EntityData => ({
    id: next(),
    name,
    tags,
    components: { transform: { x: x + 0.5, y: y + 0.5, h: levelOf(x, y), facing: 2 }, sprite: { shape: 'box', color: 0x1c1824, w: 1, d: 1, height: 0.02, sortOffset: -1, visible, asset }, ...extra },
  });
  for (const [id, s] of Object.entries(sites)) {
    const data: Record<string, unknown> = { type: s.type };
    if (s.type === 'words') {
      data.good = s.stones!.map((st) => st.options[st.good]!);
      data.goodIndex = s.stones!.map((st) => st.good);
      // the bridge is a cover on each cell: a wall in the shape of a gap until the sentence holds
      for (const c of s.bridge ?? []) out.push(flat(`Bridge ${id} ${c[0]},${c[1]}`, ['bridge', `bridge-${id}`], c[0], c[1], looks.hole, true, { collider: COLLIDER(1, 1, 2), script_PitCover: { flag: `site_${id}`, lookOn: looks.plank, lookOff: looks.hole } }));
    }
    if (s.type === 'echo') data.plates = s.plates!.map((_, i) => `plate_${id}_${i}`);
    if (s.type === 'arena') {
      data.plate = `plate_${id}_t`;
      data.waves = s.waves!.length;
      s.waves!.forEach((wave, n) =>
        wave.forEach(([x, y, letter]) => {
          const e = mkError(ERROR_OF_LETTER[letter!] ?? 0, x, y, `arena_${id}_w${n}`);
          e.tags.push(`arena-${id}`, `arena-${id}-w${n}`);
          out.push(e);
        }),
      );
    }
    if (s.type === 'crumble') {
      data.cells = s.cells;
      data.chest = s.chest;
      data.start = s.start;
      for (const c of s.cells ?? []) out.push(flat(`Crack ${id} ${c[0]},${c[1]}`, ['crack', `crack-${id}`], c[0], c[1], looks.crack, false));
    }
    out.push({
      id: next(),
      name: `Site ${id}`,
      tags: ['site'],
      components: {
        transform: { x: s.chest[0] + 0.5, y: s.chest[1] + 0.5, h: levelOf(s.chest[0], s.chest[1]), facing: 2 },
        sprite: { shape: 'box', color: 0, w: 0.1, d: 0.1, height: 0.1, sortOffset: 0, visible: false },
        script_Site: { id, type: s.type, data: JSON.stringify(data), lookCrack: looks.crack, lookHole: looks.hole },
      },
    });
  }
  return out;
}
