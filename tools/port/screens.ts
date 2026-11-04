// Port tool: the game's own screens (title, pause, binder, map), rebuilt with the engine's UI designer pieces to look and work like
// the Godot game's (scripts/title.gd, pause_menu.gd, inventory_screen.gd, world_map.gd, menu_column.gd, menu_legend.gd).
// Positions are the Godot game's, on a 1280 x 720 stage kept in the middle of the window.

type Act = { type: string; params: Record<string, unknown> };
type Style = Record<string, unknown>;
interface W {
  id: string;
  name: string;
  type: string;
  children: W[];
  [k: string]: unknown;
}

/** The Godot game's palette (scripts/palette.gd). */
const C = {
  ink: '#1b1722',
  inkBrown: '#3b2a1c',
  paper: '#e8d6ad',
  paperLight: '#f6ecd2',
  gold: '#f2b84b',
  goldDark: '#a97d2f',
  cyanDeep: '#1f6b87',
  red: '#c0405a',
  card: '#fbf3dc',
  leather: '#4a3322',
  leatherEdge: '#1e140c',
  mapPaper: '#efe2c2',
  legend: '#16171fd1',
  legendText: '#f4ecd8',
};

const act = (type: string, params: Record<string, unknown> = {}): Act => ({ type, params });
const open = (screen: string): Act => act('uiScreen', { op: 'open', screen });
const close = (screen: string): Act => act('uiScreen', { op: 'close', screen });
const setVar = (name: string, value: string): Act => act('setVariable', { name, op: 'set', value });

let seq = 0;
function w(type: string, id: string, p: Partial<W> & Style = {}): W {
  return { id: id || `w${++seq}`, name: (p.name as string) ?? id, type, children: [], ...p } as W;
}
/** Something placed at a spot of the 1280 x 720 stage. */
const at = (x: number, y: number, wd: number, h: number): Style => ({ anchor: 'tl', x, y, w: wd, h, wMode: 'fixed', hMode: 'fixed' });
const text = (id: string, t: string, x: number, y: number, size: number, color: string, extra: Style = {}): W =>
  w('text', id, { ...at(x, y, (extra.w as number) ?? 700, (extra.h as number) ?? Math.round(size * 1.35)), text: t, style: { fontSize: size, color, ...((extra.style as Style) ?? {}) }, ...extra, ...{ style: { fontSize: size, color, ...((extra.style as Style) ?? {}) } } });
const box = (id: string, x: number, y: number, wd: number, h: number, style: Style, children: W[] = [], extra: Style = {}): W =>
  w('panel', id, { ...at(x, y, wd, h), layout: 'free', padding: 0, style, children, ...extra });
const rule = (id: string, x: number, y: number, wd: number, color: string, h = 2): W => box(id, x, y, wd, h, { fill: color });

/** The stage: 1280 x 720 in the middle of the window, everything placed on it as in the Godot game. */
function stage(id: string, children: W[], fill?: string): W {
  const inner = w('panel', `${id}.stage`, { name: 'Stage', anchor: 'c', w: 1280, h: 720, wMode: 'fixed', hMode: 'fixed', layout: 'free', padding: 0, style: {}, children });
  return w('panel', `${id}.root`, { name: 'Root', anchor: 'fill', layout: 'free', padding: 0, style: fill ? { fill } : {}, children: [inner] });
}

interface Screen {
  id: string;
  name: string;
  root: W;
  modal: boolean;
  back: string;
  dim: number;
  role?: string;
  priority?: number;
}
const screen = (name: string, root: W, o: Partial<Screen> = {}): Screen => ({ id: o.id ?? name.toLowerCase().replace(/[^a-z0-9]+/g, '-'), name, root, modal: true, back: 'auto', dim: 0, ...o });

/**
 * The button legend along the bottom of every menu (menu_legend.gd): a dark rounded bar, a key cap and a word per entry.
 * The game's own legend swaps keyboard caps for pad buttons; this one names both.
 */
function legend(id: string, entries: [string, string][]): W {
  const kids = entries.flatMap(([cap, label], i) => [
    w('text', `${id}.cap${i}`, { wMode: 'auto', hMode: 'auto', text: cap, style: { fontSize: 17, color: C.ink, fill: C.legendText, radius: 5, bold: true }, padding: 4 }),
    w('text', `${id}.label${i}`, { wMode: 'auto', hMode: 'auto', text: label, style: { fontSize: 20, color: C.legendText } }),
  ]);
  return w('panel', id, { name: 'Legend', anchor: 'b', x: 0, y: 14, wMode: 'auto', hMode: 'fixed', h: 36, layout: 'row', align: 'center', gap: 10, padding: 6, style: { fill: C.legend, radius: 18 }, children: kids });
}

/**
 * A column of parchment buttons (menu_column.gd): light paper, a brown border that thickens on the chosen one, a gold dot beside it,
 * and an optional line of italic description under the label.
 */
interface Item {
  id: string;
  label: string;
  desc?: string;
  click: Act[];
  visible?: string;
  enabled?: string;
}
function column(id: string, x: number, y: number, width: number, h: number, gap: number, size: number, items: Item[]): W {
  const rows = items.map((it) => {
    const hh = it.desc ? 92 : h;
    const label = w('text', `${it.id}.label`, { anchor: 'tl', x: 20, y: it.desc ? 10 : Math.round((hh - size * 1.3) / 2), w: width - 40, h: Math.round(size * 1.35), wMode: 'fixed', hMode: 'fixed', text: it.label, style: { fontSize: size, color: C.ink } });
    const kids = [label];
    if (it.desc) kids.push(w('text', `${it.id}.desc`, { anchor: 'tl', x: 20, y: 50, w: width - 36, h: 40, wMode: 'fixed', hMode: 'fixed', text: it.desc, style: { fontSize: 17, color: C.ink, opacity: 0.65 } }));
    kids.push(box(`${it.id}.dot`, -24, hh / 2 - 6, 12, 12, { fill: C.gold, radius: 6, opacity: 0 }, [], { name: 'Chosen dot' }));
    return w('panel', it.id, {
      name: it.label,
      wMode: 'fill',
      hMode: 'fixed',
      h: hh,
      layout: 'free',
      padding: 0,
      style: { fill: C.paperLight, border: C.inkBrown, borderWidth: 2, radius: 0, shadow: true, color: C.ink },
      states: { hover: { border: C.inkBrown, borderWidth: 4, fill: '#fff6dc' }, focus: { border: C.inkBrown, borderWidth: 4, fill: '#fff6dc' }, disabled: { opacity: 0.55 } },
      on: { click: it.click, hover: [], change: [] },
      visible: it.visible ?? '',
      enabled: it.enabled ?? '',
      children: kids,
    });
  });
  return w('panel', id, { name: 'Menu', ...at(x, y, width, 10), hMode: 'auto', layout: 'column', align: 'stretch', gap, padding: 0, style: {}, children: rows });
}

/**
 * The Storytender drawn big (the Godot title shows him at 4.2x, the binder's paper doll at 3.2x). His sprite is a 160 x 150 frame with
 * the feet at (80, 128); the box is placed so the frame, made `zoom` times bigger, has its top left at (x, y) of the stage.
 */
function doll(id: string, x: number, y: number, zoom: number): W {
  return w('image', id, { name: 'The Storytender', anchor: 'tl', x: Math.round(x / zoom), y: Math.round(y / zoom), w: 160, h: 150, wMode: 'fixed', hMode: 'fixed', sprite: 'storytender', style: { scale: zoom } });
}

// ---------------------------------------------------------------- title (title.gd)

const TAGLINE = 'The world is not ending; it is being edited.';
export const BEGIN = 'Title: Begin again';
export const DIFFICULTY = 'Title: Difficulty';

function titleArt(id: string, header: W[]): W[] {
  return [
    text(`${id}.the`, 'The Last', 100, 72, 76, C.ink),
    text(`${id}.name`, 'Storytender', 100, 120, 120, C.ink, { w: 760, h: 162 }),
    rule(`${id}.rule`, 100, 285, 660, '#1b172280', 3),
    text(`${id}.tag`, TAGLINE, 104, 298, 26, C.inkBrown),
    // the Storytender, lantern lit, waiting
    doll(`${id}.doll`, 160, 300, 3),
    ...header,
    legend(`${id}.legend`, [['W A S D', 'Move'], ['E', 'Select']]),
  ];
}

function title(): Screen {
  // "Save and return to title" writes the save a moment after the title opens, so the list of saves the title looked at can be too early:
  // saved_run (set by that button) says there is one now
  const has = '{host.hasSave} + {saved_run} > 0';
  const items: Item[] = [
    { id: 'title.continue', label: 'Continue', click: [act('loadGame', { slot: 'latest' }), close('role:title')], visible: has },
    { id: 'title.new.save', label: 'New Game', click: [open(BEGIN)], visible: has },
    { id: 'title.new', label: 'New Game', click: [open(DIFFICULTY)], visible: '{host.hasSave} + {saved_run} = 0' },
    { id: 'title.settings', label: 'Settings', click: [open('role:settings')] },
    { id: 'title.quit', label: 'Quit', click: [act('quitGame')], visible: '{host.quit}' },
  ];
  return screen('Title', stage('title', [...titleArt('title', []), column('title.menu', 770, 300, 440, 64, 14, 30, items)], C.paper), { id: 'storytender-title', role: 'title', back: 'nothing', dim: 1 });
}

function begin(): Screen {
  const header = [text('begin.head', 'Begin a new story?', 770, 230, 28, C.ink, { w: 460 })];
  const items: Item[] = [
    { id: 'begin.yes', label: 'Yes, begin again', desc: 'Your current save will be erased.', click: [close(BEGIN), open(DIFFICULTY)] },
    { id: 'begin.back', label: 'Cancel', click: [close(BEGIN)] },
  ];
  return screen(BEGIN, stage('begin', [...titleArt('begin', header), column('begin.menu', 770, 300, 440, 64, 14, 30, items)], C.paper), { id: 'storytender-begin', back: 'previous', dim: 1 });
}

function difficulty(): Screen {
  const header = [
    text('diff.head', 'How should the story treat you?', 770, 205, 28, C.ink, { w: 480 }),
    text('diff.sub', 'This is fixed for the save you are about to begin.', 770, 246, 18, C.inkBrown, { w: 480 }),
  ];
  // the engine's own difficulty setting only knows easy / normal / hard and scales the damage she takes; the game's Story and Normal are the variable
  // `difficulty` (the enemy scripts read it), so the engine's stays on normal (a save refuses any other word)
  const pick = (v: string): Act[] => [act('setSetting', { name: 'difficulty', value: 'normal' }), setVar('difficulty', v), setVar('difficulty_locked', '1'), close(DIFFICULTY), close('role:title')];
  const items: Item[] = [
    { id: 'diff.story', label: 'Story', desc: 'Gentler. Enemies hit softer; crumpling costs nothing.', click: pick('story') },
    { id: 'diff.normal', label: 'Normal', desc: 'The intended game. Crumpling costs Mnemosynth and restarts the room.', click: pick('normal') },
    { id: 'diff.back', label: 'Back', click: [close(DIFFICULTY)] },
  ];
  return screen(DIFFICULTY, stage('diff', [...titleArt('diff', header), column('diff.menu', 770, 300, 440, 64, 14, 30, items)], C.paper), { id: 'storytender-difficulty', back: 'previous', dim: 1 });
}

// ---------------------------------------------------------------- pause (pause_menu.gd)

export const RESTART = 'Pause: Start again';

function pause(): Screen {
  const items: Item[] = [
    { id: 'pause.resume', label: 'Resume', click: [close('role:pause')] },
    { id: 'pause.travel', label: 'Travel to a lantern', click: [open('role:travel')], visible: '{dungeon_menu}' },
    { id: 'pause.restart', label: 'Restart this dungeon', click: [open(RESTART)], visible: '{dungeon_menu}' },
    { id: 'pause.map', label: 'Map', click: [open('role:travel')] },
    { id: 'pause.settings', label: 'Settings', click: [open('role:settings')] },
    { id: 'pause.title', label: 'Save and return to title', click: [act('saveGame', { slot: 'autosave' }), setVar('saved_run', '1'), close('role:pause'), open('role:title')] },
    { id: 'pause.quit', label: 'Quit game', click: [act('saveGame', { slot: 'autosave' }), act('quitGame')], visible: '{host.quit}' },
  ];
  const kids = [
    text('pause.head', 'Paused', 450, 128, 56, C.paperLight),
    column('pause.menu', 450, 222, 380, 50, 8, 26, items),
    legend('pause.legend', [['W A S D', 'Move'], ['E', 'Select'], ['Esc', 'Resume']]),
  ];
  return screen('Pause', stage('pause', kids), { id: 'storytender-pause', role: 'pause', dim: 0.6 });
}

function restart(): Screen {
  const items: Item[] = [
    { id: 'restart.yes', label: 'Yes, start again', click: [close(RESTART), close('role:pause'), act('restartArea')] },
    { id: 'restart.no', label: 'No, keep going', click: [close(RESTART)] },
  ];
  const note =
    'You go back to the entrance and every puzzle in here resets: gates, plates, echoes and anything you were carrying for the doors. Rewards you already took, and lanterns you lit, are still yours.';
  const kids = [
    text('restart.head', 'Start this place again?', 450, 150, 44, C.paperLight, { w: 780 }),
    text('restart.note', note, 450, 214, 17, C.paperLight, { w: 560, h: 80, style: { opacity: 0.8 } }),
    column('restart.menu', 450, 300, 380, 50, 8, 26, items),
    legend('restart.legend', [['W A S D', 'Move'], ['E', 'Select'], ['Esc', 'Back']]),
  ];
  return screen(RESTART, stage('restart', kids), { id: 'storytender-restart', back: 'previous', dim: 0.6 });
}

// ---------------------------------------------------------------- settings (the engine's menu, in the game's colours)

/**
 * Settings, on a page of parchment: three sections with a colour each (ink-well teal for sound, the Errors' red for play, gold for the
 * screen), a thin rule under each, and rows that alternate a shade so the eye can follow them across. The controls are the engine's own
 * (sliders, tick boxes, the pop-up list), bound to the same settings as the stock menu, so saving and the Controls screen work as before.
 */
function settings(): Screen {
  const X = 330; // the box's left edge on the stage
  const WIDTH = 620;
  const section = (id: string, y: number, label: string, color: string): W[] => [
    box(`${id}.bar`, 24, y + 4, 6, 24, { fill: color, radius: 3 }),
    text(`${id}.head`, label, 42, y, 24, color, { w: 300, style: { bold: true } }),
    rule(`${id}.rule`, 24, y + 33, WIDTH - 48, `${color}59`, 2),
  ];
  const row = (id: string, y: number, label: string, i: number, control: W, extra: Style = {}): W =>
    box(`set.${id}`, 24, y, WIDTH - 48, 40, { fill: i % 2 ? '#3b2a1c0d' : '#3b2a1c00' }, [text(`set.${id}.label`, label, 12, 6, 22, C.ink, { w: 300, h: 28 }), control], extra);
  const slider = (id: string, value: string, min: number, max: number, step: number): W =>
    w('slider', `set.${id}.slider`, { name: `${id} slider`, ...at(300, 6, 260, 28), value, min, max: String(max), step });
  const tick = (id: string, value: string): W => w('toggle', `set.${id}.box`, { name: `${id} tick box`, ...at(520, 4, 40, 32), value, text: '' });
  const controls = box(
    'set.controls',
    24,
    594,
    WIDTH - 48,
    40,
    { fill: '#f2b84b40', border: C.inkBrown, borderWidth: 2 },
    [text('set.controls.label', 'Controls', 12, 6, 22, C.ink, { w: 300, h: 28 }), text('set.controls.go', 'change keys and buttons  ›', 240, 9, 18, C.inkBrown, { w: 310, h: 24, style: { align: 'right', opacity: 0.8 } })],
    { states: { hover: { fill: '#f2b84b99', borderWidth: 4 }, focus: { fill: '#f2b84b99', borderWidth: 4 } }, on: { click: [open('role:controls')], hover: [], change: [] } },
  );
  const panel = box(
    'set.box',
    X,
    36,
    WIDTH,
    648,
    { fill: C.paperLight, border: C.inkBrown, borderWidth: 4, radius: 4, shadow: true },
    [
      text('set.head', 'Settings', 24, 10, 46, C.ink, { w: 400 }),
      rule('set.headrule', 24, 66, WIDTH - 48, C.gold, 4),
      ...section('set.s1', 80, 'SOUND', C.cyanDeep),
      row('master', 120, 'Master volume', 0, slider('master', 'settings.master', 0, 1, 0.1)),
      row('music', 162, 'Music', 1, slider('music', 'settings.music', 0, 1, 0.1)),
      row('sfx', 204, 'Effects', 0, slider('sfx', 'settings.sfx', 0, 1, 0.1)),
      row('voice', 246, 'Voices', 1, slider('voice', 'settings.voice', 0, 1, 0.1)),
      ...section('set.s2', 296, 'PLAY', C.red),
      row('difficulty', 336, 'Difficulty', 0, box('set.difficulty.value', 340, 4, 220, 32, {}, [
        text('set.difficulty.story', 'Story  (fixed for this save)', 0, 4, 20, C.inkBrown, { w: 220, visible: '{difficulty} = story' }),
        text('set.difficulty.normal', 'Normal  (fixed for this save)', 0, 4, 20, C.inkBrown, { w: 220, visible: '{difficulty} != story' }),
      ])),
      row('shake', 378, 'Screen shake and hit freeze', 1, tick('shake', 'settings.screenShake')),
      row('zoom', 420, 'Camera zoom', 0, slider('zoom', 'settings.cameraZoom', 0.75, 1.5, 0.25)),
      ...section('set.s3', 470, 'SCREEN', C.goldDark),
      row('fullscreen', 510, 'Full screen', 0, tick('fullscreen', 'settings.fullscreen'), { visible: '{host.fullscreen}' }),
      row('fps', 552, 'Show frame rate', 1, tick('fps', 'settings.showFps')),
      controls,
    ],
  );
  const kids = [panel, legend('settings.legend', [['W S', 'Choose'], ['A D', 'Change'], ['E', 'Select'], ['Esc', 'Back']])];
  return screen('Settings', stage('settings', kids), { id: 'storytender-settings', role: 'settings', dim: 0.6 });
}

// ---------------------------------------------------------------- the binder (inventory_screen.gd)

function card(itemIds: string[]): W {
  const pics = itemIds.map((id) => w('image', `binder.card.icon.${id}`, { name: `Icon ${id}`, ...at(30, 30, 44, 44), sprite: `icon_${id}`, visible: `{item.id} = ${id}`, style: {} }));
  return w('panel', 'binder.card', {
    name: 'Card',
    w: 104,
    h: 104,
    wMode: 'fixed',
    hMode: 'fixed',
    layout: 'free',
    padding: 0,
    style: { fill: C.card, border: C.inkBrown, borderWidth: 2, shadow: true, color: C.ink },
    states: { hover: { border: C.gold, borderWidth: 4 }, focus: { border: C.gold, borderWidth: 4 } },
    on: {
      click: [act('useItem', { item: '{item.id}' })],
      hover: [setVar('binder_name', '{item.name}'), setVar('binder_detail', '{item.description}')],
      change: [act('quickSlot', { item: '{item.id}', step: '{delta}' })],
    },
    children: [
      rule('binder.card.rule', 0, 22, 104, '#d96a6ab3', 2),
      rule('binder.card.line1', 0, 62, 104, '#738cbf33', 1),
      rule('binder.card.line2', 0, 80, 104, '#738cbf33', 1),
      text('binder.card.name', '{item.name}', 5, 3, 12, C.ink, { w: 96, h: 18 }),
      ...pics,
      text('binder.card.count', '×{item.count}', 60, 80, 17, C.ink, { w: 42, h: 22, visible: '{item.count} > 1' }),
      text('binder.card.slot', '{item.slot}', 84, 28, 19, C.inkBrown, { w: 18, h: 24, visible: '{item.slot} > 0', style: { bold: true } }),
    ],
  });
}

function slot(id: string, label: string, x: number, y: number, worn: string): W {
  return box(id, x, y, 150, 98, { fill: '#e6d9b366', border: '#3b2a1c80', borderWidth: 2 }, [
    text(`${id}.label`, label, 8, 4, 17, C.ink, { w: 140, style: { opacity: 0.7 } }),
    text(`${id}.empty`, 'empty', 50, 44, 18, C.ink, { w: 90, visible: `!{${worn}}`, style: { opacity: 0.35 } }),
    text(`${id}.worn`, `{${worn}}`, 8, 72, 14, C.ink, { w: 140, visible: `{${worn}}` }),
  ]);
}

function binder(itemIds: string[]): Screen {
  const pages = [box('binder.page.l', 84, 64, 530, 592, { fill: C.paperLight, border: C.leatherEdge, borderWidth: 2 }), box('binder.page.r', 666, 64, 530, 592, { fill: C.paperLight, border: C.leatherEdge, borderWidth: 2 })];
  for (const p of pages) for (let y = 54, i = 0; y < 584; y += 28, i++) p.children.push(rule(`${p.id}.line${i}`, 12, y, 506, '#738cb221', 1));
  const rings = [150, 360, 570].flatMap((ry, i) => [box(`binder.ring.bar${i}`, 616, ry - 8, 48, 16, { fill: '#2a2a30' }), box(`binder.ring${i}`, 625, ry - 15, 30, 30, { border: '#9aa0ad', borderWidth: 5, radius: 15 })]);
  const weapon = [
    text('binder.tool.quill', 'Quill', 442, 412, 19, C.cyanDeep, { w: 150, visible: '{has_quill}' }),
    text('binder.tool.quill.d', 'Rewrites what it touches.', 442, 436, 15, C.ink, { w: 150, h: 40, visible: '{has_quill}', style: { opacity: 0.8 } }),
    text('binder.tool.sword', 'The First Sword', 442, 412, 19, C.ink, { w: 150, visible: '{has_sword} && !{has_quill}', style: { opacity: 0.45 } }),
    text('binder.tool.pencil', 'Pencil Stub', 442, 412, 19, C.ink, { w: 150, visible: '!{has_sword} && !{has_quill}', style: { opacity: 0.45 } }),
  ];
  const stats = ['Damage taken   no change', 'Move speed    no change', 'Dash cooldown   no change', 'Grace after a hit   0.9s', 'Quill damage   no change     Reach   no change', 'Lantern burn   no change     Ink regen   0.0/s'];
  const left = [
    text('binder.l.head', 'The Storytender', 108, 64, 36, C.ink, { w: 400 }),
    rule('binder.l.rule', 108, 118, 392, '#1b172280'),
    box('binder.plinth', 198, 452, 140, 32, { fill: '#0000001f', radius: 16 }),
    doll('binder.doll', 112, 140, 2.6),
    slot('binder.slot.binding', 'Binding', 442, 150, 'worn_binding'),
    slot('binder.slot.amulet', 'Amulet', 442, 262, 'worn_amulet'),
    text('binder.tools', 'Tools', 442, 368, 22, C.ink, { w: 150 }),
    rule('binder.tools.rule', 442, 398, 150, '#1b172266', 1),
    text('binder.tool.lantern', 'Lantern', 442, 404 - 26, 19, C.cyanDeep, { w: 150, visible: '' }),
    ...weapon,
    ...stats.map((s, i) => text(`binder.stat${i}`, s, 108, 520 + i * 20, 17, C.ink, { w: 420, h: 22, style: { opacity: 0.9 } })),
    text('binder.difficulty.story', 'Difficulty:  Story', 372, 520, 17, C.ink, { w: 230, visible: '{difficulty} = story', style: { opacity: 0.7 } }),
    text('binder.difficulty.normal', 'Difficulty:  Normal', 372, 520, 17, C.ink, { w: 230, visible: '{difficulty} = normal', style: { opacity: 0.7 } }),
  ];
  // the lantern line sits above the weapon, as in the binder
  left.find((x) => x.id === 'binder.tool.lantern')!.y = 404;
  for (const k of weapon) (k as W).y = (k.y as number) + 26;
  const right = [
    text('binder.r.head', 'Card Catalog', 692, 64, 36, C.ink, { w: 380 }),
    rule('binder.r.rule', 692, 118, 388, '#1b172280'),
    text('binder.r.ink', '◆ {mnemosynth}', 1090, 74, 26, C.goldDark, { w: 100, visible: '{mnemosynth}' }),
    w('grid', 'binder.grid', {
      name: 'Cards',
      ...at(684, 150, 448, 340),
      source: 'items',
      layout: 'grid',
      columns: 4,
      gap: 8,
      padding: 0,
      empty: 'Nothing here yet. Cards are filed as you find them: Eraser Crumbs, Ink Vials, Bindings, and stranger things.',
      style: { scroll: true, color: C.ink, fontSize: 20 },
      children: [card(itemIds)],
    }),
    text('binder.d.name', '{binder_name}', 692, 498, 26, C.ink, { w: 450, visible: '{binder_name}' }),
    text('binder.d.text', '{binder_detail}', 692, 534, 17, C.ink, { w: 470, h: 88, visible: '{binder_detail}', style: { opacity: 0.9 } }),
  ];
  const kids = [
    box('binder.cover', 52, 36, 1176, 648, { fill: C.leather, border: C.leatherEdge, borderWidth: 5, radius: 20, shadow: true }),
    ...pages,
    ...rings,
    ...left,
    ...right,
    legend('binder.legend', [['W A S D', 'Move'], ['E', 'Use'], ['A / D', 'Quick slot'], ['Tab', 'Close']]),
  ];
  return screen('Binder', stage('binder', kids), { id: 'storytender-binder', role: 'inventory', dim: 0.62 });
}

// ---------------------------------------------------------------- the map (world_map.gd)

const CHAPTERS = [
  { name: 'The Prologue', sub: 'Prologue Plains · Thistledown', open: true },
  { name: 'Chapter One', sub: 'Plot-Twist Peaks', open: false },
  { name: 'Chapter Two', sub: 'Purple Prose Swamp', open: false },
  { name: 'Chapter Three', sub: 'The Final Chapter', open: false },
];

function lamp(): W {
  return box('lamp', 0, 0, 14, 22, {}, [
    box('lamp.post', 4, 6, 6, 16, { fill: '#8a5a35' }),
    box('lamp.light', 5, 0, 9, 9, { fill: '#e6f7fb', border: C.ink, borderWidth: 1, radius: 5 }),
    box('lamp.ring', -8, -10, 30, 30, { border: '#2b8fb3', borderWidth: 3, radius: 15 }, [], { visible: '{marker.highlight} = 1' }),
    w('text', 'lamp.name', { anchor: 'tl', x: -80, y: -40, w: 174, h: 26, wMode: 'fixed', hMode: 'fixed', text: '{post.name}', visible: '{marker.highlight} = 1', style: { fontSize: 18, color: C.legendText, fill: '#1a1e2be0', align: 'center' } }),
  ]);
}

function here(): W {
  return box('here', 0, 0, 14, 14, {}, [
    box('here.pin', 0, 0, 14, 12, { fill: C.red, border: C.ink, borderWidth: 2, radius: 3 }),
    text('here.you', 'you', -6, -20, 14, C.red, { w: 40, h: 18 }),
  ]);
}

/** An unlit lantern post on the map: the same post, dark. The lit ones (Lamp) are drawn over it. */
function darkPost(): W {
  return box('darkpost', 0, 0, 12, 18, {}, [
    box('darkpost.post', 3, 5, 5, 13, { fill: '#7a6a58' }),
    box('darkpost.lamp', 2, 0, 8, 8, { fill: C.paperLight, border: '#5a4a3a', borderWidth: 1, radius: 4 }),
  ]);
}

/** A door into a memory: a small teal diamond with a dark rim. */
function memoryDoor(): W {
  return box('door', 0, 0, 14, 14, {}, [box('door.mark', 1, 1, 11, 11, { fill: '#7fd0e6', border: C.cyanDeep, borderWidth: 2, radius: 2 })]);
}

/** Nothing to see: a label's marker (the words come from the labels layer). */
function blankMark(): W {
  return box('blank', 0, 0, 1, 1, {});
}

/** The names the map shows over the world (made by the porter from the Godot game's regions, lantern posts and doors). */
export interface MapNames {
  regions: { id: string; x: number; y: number; label: string }[];
  posts: { id: string; x: number; y: number; label: string }[];
  doors: { id: string; x: number; y: number; label: string }[];
}

/** The parts of the Godot game's prologue map (data/prologue_map.gd) the map screen names. */
export interface MapConstants {
  REGION_ROWS: string[];
  REGIONS: Record<string, string>;
  WAYPOINTS: { id: string; name: string; cell: [number, number] }[];
  PORTALS: Record<string, { name: string; cell: [number, number] }>;
}

/** A region's name as the map prints it: short, so neighbours do not run into each other. */
const SHORT: Record<string, string> = { 'Graveyard of Deleted Scenes': 'Graveyard', 'Whispering Orchard': 'Orchard', 'Footnote Hollow': 'Hollow', 'Hushed Glade': 'Glade', 'Dog-Ear Cliffs': 'Dog-Ears', 'Folio Heights': 'Folio', 'Margins Meadow': 'Margins' };
const shortName = (name: string): string => SHORT[name.replace(/^The /, '')] ?? name.replace(/^The /, '');

/** Each region (named at a cell inside it, nearest its middle), every lantern post and the memory doors. */
export function mapNamesFrom(c: MapConstants): MapNames {
  const cells = new Map<string, [number, number][]>();
  c.REGION_ROWS.forEach((row, y) => [...row].forEach((ch, x) => ch !== ' ' && (cells.get(ch) ?? cells.set(ch, []).get(ch)!).push([x, y])));
  const regions = [...cells.entries()]
    .filter(([ch, list]) => c.REGIONS[ch] && list.length >= 12)
    .map(([ch, list]) => {
      const mx = list.reduce((s, p) => s + p[0], 0) / list.length;
      const my = list.reduce((s, p) => s + p[1], 0) / list.length;
      const [x, y] = list.reduce((best, p) => (Math.hypot(p[0] - mx, p[1] - my) < Math.hypot(best[0] - mx, best[1] - my) ? p : best));
      return { id: `region_${ch}`, x, y, label: shortName(c.REGIONS[ch]!) };
    });
  return {
    regions,
    posts: c.WAYPOINTS.map((p) => ({ id: p.id, x: p.cell[0], y: p.cell[1], label: p.name })),
    doors: Object.entries(c.PORTALS).map(([id, p]) => ({ id, x: p.cell[0], y: p.cell[1], label: p.name })),
  };
}

/** What the little pictures on the map mean, under the map. */
function mapKey(): W[] {
  const item = (id: string, x: number, mark: W, label: string, wd: number): W[] => [mark, text(`${id}.t`, label, x + 22, 584, 17, C.ink, { w: wd, h: 24, style: { opacity: 0.8 } })];
  const dot = (id: string, x: number, style: Style): W => box(id, x, 587, 14, 14, style);
  return [
    ...item('key.you', 480, dot('key.you.m', 480, { fill: C.red, border: C.ink, borderWidth: 2, radius: 3 }), 'You', 60),
    ...item('key.lit', 570, dot('key.lit.m', 570, { fill: '#e6f7fb', border: C.cyanDeep, borderWidth: 2, radius: 7 }), 'Lit lantern', 130),
    ...item('key.dark', 730, dot('key.dark.m', 730, { fill: C.paperLight, border: '#5a4a3a', borderWidth: 2, radius: 7 }), 'Unlit lantern', 150),
    ...item('key.door', 910, dot('key.door.m', 910, { fill: '#7fd0e6', border: C.cyanDeep, borderWidth: 2, radius: 2 }), 'Memory door', 150),
  ];
}

function map(paperTile: number, names: MapNames): Screen {
  const hand = (list: MapNames['regions']): object[] => list.map((p) => ({ id: p.id, x: p.x, y: p.y, label: p.label, state: '' }));
  const chapters = CHAPTERS.flatMap((c, i) => {
    const y = 170 + i * 92;
    const fill = i === 0 ? '#f2b84b59' : '#0000000f';
    const kids = [
      text(`map.ch${i}.name`, c.name, 16, 6, 30, C.ink, { w: 330, style: c.open ? {} : { opacity: 0.45 } }),
      ...(i === 0
        ? [text(`map.ch${i}.sub.draft`, `${c.sub}  ·  Draft`, 16, 48, 16, C.ink, { w: 330, visible: '!{town_published}', style: { opacity: 0.65 } }), text(`map.ch${i}.sub.done`, `${c.sub}  ·  Complete`, 16, 48, 16, C.ink, { w: 330, visible: '{town_published}', style: { opacity: 0.65 } })]
        : [text(`map.ch${i}.sub`, 'Unwritten', 16, 48, 16, C.ink, { w: 330, visible: '!{town_published}', style: { opacity: 0.4 } }), text(`map.ch${i}.sub.pub`, c.sub, 16, 48, 16, C.ink, { w: 330, visible: '{town_published}', style: { opacity: 0.4 } })]),
    ];
    return [box(`map.ch${i}`, 60, y, 360, 80, { fill, border: c.open ? C.inkBrown : '#1b172259', borderWidth: 2 }, kids)];
  });
  const travel = act('travelToPost', { scene: '{post.scene}', id: '{post.id}', name: '{post.name}', x: '{post.x}', y: '{post.y}', h: '{post.h}' });
  const spec = {
    source: { kind: 'scene', scene: 'scenes/overworld.scene.json', scenes: [], table: '', width: 137, height: 106 },
    projection: { kind: 'iso', rotation: 'fixed', angle: 0, picture: '' },
    layers: [
      // the ground in its own colours, shaded by height, with a thin brown line where one kind of ground meets another (paths, cliffs, water)
      { id: 'terrain', name: 'Terrain', kind: 'terrain', settings: { colourBy: 'tile', palette: `${paperTile}:#00000000`, fallback: '#a9c78a', outline: 'edges', outlineColour: '#3b2a1c4d', shade: true } },
      { id: 'grid', name: 'Page grid', kind: 'grid', settings: { every: 10, colour: '#3b2a1c18', lineWidth: 1 } },
      { id: 'names', name: 'Region names', kind: 'labels', settings: { from: 'markers', kind: 'regions', colour: '#3b2a1c', size: 13 } },
      { id: 'marks', name: 'Markers', kind: 'markers', settings: {} },
    ],
    markers: [
      { id: 'regions', name: 'Region names', from: 'hand', hand: hand(names.regions), prefab: 'Blank', choosable: false, scaleWithZoom: false },
      { id: 'doors', name: 'Memory doors', from: 'hand', hand: hand(names.doors), prefab: 'Door', choosable: false },
      { id: 'darkposts', name: 'Lantern posts', from: 'hand', hand: hand(names.posts), prefab: 'DarkPost', choosable: false },
      { id: 'posts', name: 'Lit lanterns', from: 'list', source: 'lit-posts', x: 'post.x', y: 'post.y', prefab: 'Lamp', show: '{map.distance} >= 40', choosable: true },
      { id: 'you', name: 'You are here', from: 'tags', source: 'player', prefab: 'Here', choosable: false },
    ],
    view: { zoom: 1, zoomMin: 0.5, zoomMax: 6, centre: 'auto', turn: 'none', turnAngle: 0, cell: 8, fit: true },
    nav: { mode: 'direction', wrap: true, start: 'here', click: true, drag: true, wheel: true, pinch: true, keys: 'highlight' },
    on: { highlight: [], choose: [travel, close('role:travel')], reveal: [] },
    bind: 'wm',
  };
  const kids = [
    box('map.sheet', 30, 30, 1220, 660, { fill: C.mapPaper, border: C.inkBrown, borderWidth: 5, radius: 10, shadow: true }),
    text('map.head', 'The Map', 70, 40, 54, C.ink, { w: 400 }),
    rule('map.rule', 70, 114, 1140, '#1b172280'),
    ...chapters,
    // the map sits in a frame of darker paper, like a plate in an atlas
    box('map.frame', 462, 126, 776, 450, { fill: '#e5d4a7', border: C.inkBrown, borderWidth: 3, radius: 4 }),
    w('map', 'map.world', { name: 'World', ...at(470, 130, 760, 442), map: spec, style: { fill: '#00000000', border: '#00000000' } }),
    ...mapKey(),
    text('map.none', 'Light a lantern post out in the world, and you can travel to it from here.', 470, 626, 22, C.ink, { w: 760, visible: '!{wm.marker}', style: { opacity: 0.8 } }),
    text('map.foot', 'E   Travel (far posts only)          M   Close', 70, 640, 20, C.ink, { w: 700, style: { opacity: 0.8 } }),
    legend('map.legend', [['W A S D', 'Move'], ['E', 'Travel'], ['M', 'Close']]),
  ];
  return screen('Map', stage('map', kids), { id: 'storytender-map', role: 'travel', dim: 0.78 });
}

// ---------------------------------------------------------------- the heads-up display (hud.gd, ink_bottle.gd, lantern_gauge.gd)

const HP = '{@Player.state:health.hp}';
const HP_MAX = '{@Player.health.max}';

/** The ink bottle: the ink level drops as health drains; the glass cracks below 50% and leaks below 25%. */
function inkBottle(): W {
  const outline = '#261a14';
  const glass = '#bfd9e640';
  const ink = '#1d2466';
  const slices = 17; // the ink is drawn as 17 rows of 4 px, each shown while health is above its share
  const rows = Array.from({ length: slices }, (_, i) =>
    box(`hud.ink.row${i}`, 8, 102 - (i + 1) * 4, 54, 4, { fill: ink }, [], { name: 'Ink', visible: `${HP} / ${HP_MAX} > ${(i / slices).toFixed(3)}` }),
  );
  const crack = (id: string, x: number, y: number, visible: string): W => text(id, '⟋', x, y, 22, outline, { w: 20, h: 26, visible });
  return box('hud.bottle', 20, 14, 70, 110, {}, [
    ...rows,
    box('hud.glass', 8, 38, 54, 68, { fill: glass, border: outline, borderWidth: 3 }),
    box('hud.neck', 24, 16, 22, 24, { fill: glass, border: outline, borderWidth: 3 }),
    box('hud.cork', 22, 6, 26, 12, { fill: '#8c6133', border: outline, borderWidth: 2 }),
    crack('hud.crack1', 18, 44, `${HP} / ${HP_MAX} < 0.5`),
    crack('hud.crack2', 18, 70, `${HP} / ${HP_MAX} < 0.5`),
    crack('hud.crack3', 40, 52, `${HP} / ${HP_MAX} < 0.25`),
    crack('hud.crack4', 36, 80, `${HP} / ${HP_MAX} < 0.25`),
    box('hud.leak', 37, 104, 6, 6, { fill: ink, radius: 3 }, [], { visible: `${HP} / ${HP_MAX} < 0.25`, anim: [{ on: 'show', kind: 'pulse', ms: 800, dir: 'down' }] }),
  ], { name: 'Ink bottle' });
}

/** The lantern gauge: a small lantern and a cyan bar that drains while the beam is on (red and flickering when low). */
function lanternGauge(): W {
  const low = '{light} < 20';
  const high = '{light} >= 20';
  const bar = (id: string, color: string, visible: string): W =>
    w('bar', id, { name: 'Lantern fuel', ...at(34, 10, 140, 10), value: 'light', max: '100', visible, style: { fill: '#00000073', color, border: '#14111a', borderWidth: 2 } });
  return box('hud.gauge', 104, 22, 190, 30, {}, [
    box('hud.lamp.top', 8, 4, 12, 3, { fill: '#3a3f4a' }),
    box('hud.lamp.glass', 5, 7, 18, 16, { fill: '#6fe3ffb0', border: '#14111a', borderWidth: 2 }, [], { visible: high }),
    box('hud.lamp.glass.low', 5, 7, 18, 16, { fill: '#ff8a6a80', border: '#14111a', borderWidth: 2 }, [], { visible: low, anim: [{ on: 'show', kind: 'pulse', ms: 400, dir: 'up' }] }),
    box('hud.lamp.base', 3, 23, 22, 4, { fill: '#3a3f4a' }),
    bar('hud.fuel', '#6fe3ff', high),
    bar('hud.fuel.low', '#ff8a6a', low),
  ], { name: 'Lantern gauge' });
}

/** The quick slots, bottom right: the active one big with its key and count, the other small and dimmed, and the swap key. */
function quickSlots(usable: string[]): W {
  const icons = (slot: string, prefix: string, x: number, y: number, size: number): W[] =>
    usable.map((id) => w('image', `${prefix}.${id}`, { name: `Icon ${id}`, ...at(x, y, size, size), sprite: `icon_${id}`, visible: `{${slot}} = ${id}`, style: {} }));
  const active = '{quick_active}';
  // slot 1 is active unless quick_active is 1
  const kids: W[] = [];
  for (const [n, other] of [[1, 2], [2, 1]] as const) {
    const on = n === 1 ? `!${active}` : `${active} = 1`;
    const group = box(`hud.quick${n}`, 0, 0, 180, 110, {}, [
      box(`hud.quick${n}.plate`, 0, 0, 180, 110, { fill: '#f6ecd2e6', border: C.inkBrown, borderWidth: 3, radius: 10 }, [], { name: 'Plate' }),
      ...icons(`slot:${n}`, `hud.quick${n}.big`, 104, 10, 64),
      text(`hud.quick${n}.label`, `F   ×{item:{slot:${n}}}`, 84, 76, 22, C.inkBrown, { w: 94, style: { bold: true, align: 'center' } }),
      ...icons(`slot:${other}`, `hud.quick${n}.small`, 16, 38, 44).map((x) => ({ ...x, style: { opacity: 0.6 } })),
      text(`hud.quick${n}.count2`, `×{item:{slot:${other}}}`, 14, 84, 17, C.inkBrown, { w: 56, style: { align: 'center' }, visible: `{slot:${other}}` }),
      text(`hud.quick${n}.hint`, 'G  swap', 14, 10, 16, C.inkBrown, { w: 70, visible: `{slot:${other}}` }),
    ], { name: `Quick slot ${n} active`, visible: on });
    kids.push(group);
  }
  return w('panel', 'hud.quick', { name: 'Quick slots', anchor: 'br', x: 0, y: 0, w: 180, h: 110, wMode: 'fixed', hMode: 'fixed', layout: 'free', padding: 0, style: {}, children: kids });
}

/** The Margin Gate: two posts and an arch, small, beside the renown count (it opens at 220). */
function gateIcon(id: string, x: number, y: number): W {
  const ink = C.inkBrown;
  return box(id, x, y, 22, 24, {}, [
    box(`${id}.l`, 1, 8, 5, 16, { fill: ink }),
    box(`${id}.r`, 16, 8, 5, 16, { fill: ink }),
    box(`${id}.top`, 0, 3, 22, 6, { fill: ink, radius: 3 }),
    box(`${id}.in`, 6, 10, 10, 14, { fill: C.gold, opacity: 0.8 }),
  ], { name: 'Margin Gate' });
}

/** The renown needed for the Margin Gate (main.gd: the gate opens at 220). */
const GATE_RENOWN = 220;

/** The bar across the top while a boss is awake: its name and what is left of it (the boss scripts set boss_name, boss_hp and boss_max). */
function bossBar(): W {
  const shown = '{boss_name} != ""';
  const bar = w('bar', 'hud.boss.bar', { name: 'Boss health', ...at(20, 40, 380, 16), value: 'boss_hp', max: '{boss_max}', style: { fill: '#2a1418', color: C.red, border: C.leatherEdge, borderWidth: 3 } });
  return w('panel', 'hud.boss', {
    name: 'Boss',
    anchor: 'b',
    x: 0,
    y: -22,
    w: 420,
    h: 74,
    wMode: 'fixed',
    hMode: 'fixed',
    layout: 'free',
    padding: 0,
    visible: shown,
    style: { fill: C.paperLight, border: C.inkBrown, borderWidth: 3, radius: 8 },
    anim: [{ on: 'show', kind: 'fade', ms: 400, dir: 'down' }],
    children: [text('hud.boss.name', '{boss_name}', 20, 6, 24, C.inkBrown, { w: 380, style: { bold: true, align: 'center' } }), bar],
  });
}

function hud(usable: string[]): Screen {
  // pinned to the corners of the window, as the Godot HUD is: the bottle and gauges top left, the place top right, the quick slots bottom right.
  // Everything sits on a parchment plate, so it reads against the dark page edge as well as the grass.
  const plate = box('hud.plate', 6, 6, 316, 134, { fill: '#f6ecd2f0', border: C.inkBrown, borderWidth: 3, radius: 10 }, [], { name: 'Plate' });
  const topLeft = box('hud.tl', 0, 0, 340, 146, {}, [
    plate,
    inkBottle(),
    lanternGauge(),
    text('hud.mnemo', '◆ {mnemosynth}', 104, 54, 28, '#7a5410', { w: 200, style: { bold: true } }),
    gateIcon('hud.gate', 104, 92),
    text('hud.renown', `Renown {renown} / ${GATE_RENOWN}`, 134, 92, 18, C.inkBrown, { w: 180, style: { bold: true } }),
    w('bar', 'hud.renown.bar', { name: 'Renown', ...at(134, 116, 176, 9), value: 'renown', max: String(GATE_RENOWN), style: { fill: '#3b2a1c40', color: C.gold, border: C.inkBrown, borderWidth: 2 } }),
  ], { name: 'Top left' });
  const region = box('hud.region', 0, 0, 360, 46, { fill: '#f6ecd2f0', border: C.inkBrown, borderWidth: 3, radius: 10 }, [
    text('hud.region.text', '{region_name}', 12, 6, 26, C.inkBrown, { w: 336, style: { align: 'center', bold: true } }),
  ], { name: 'Region', anchor: 'tr', x: -16, y: 14, visible: '{region_show}', anim: [{ on: 'show', kind: 'fade', ms: 600, dir: 'down' }, { on: 'hide', kind: 'fade', ms: 900, dir: 'up' }] });
  const root = w('panel', 'hud.root', { name: 'Root', anchor: 'fill', layout: 'free', padding: 0, style: {}, children: [topLeft, region, bossBar(), quickSlots(usable)] });
  return { ...screen('HUD', root, { id: 'storytender-hud', role: 'hud', modal: false, back: 'pass' }), opensOnStart: true } as Screen;
}

// ---------------------------------------------------------------- the file

/** The engine's own menus (settings, controls, saves, the conversation box...) wear the game's colours: parchment, ink, gold, ink-well teal. */
export function uiTheme(schemaVersion: number): object {
  return {
    schemaVersion,
    theme: { font: 'serif', text: C.ink, accent: C.cyanDeep, panel: C.paperLight, border: C.inkBrown, highlight: C.gold, radius: 4, scale: 1 },
    widgets: [],
  };
}

export function buildScreens(itemIds: string[], schemaVersion: number, paperTile: number, usable: string[] = itemIds, names: MapNames = { regions: [], posts: [], doors: [] }): object {
  return {
    schemaVersion,
    screens: [hud(usable), title(), begin(), difficulty(), pause(), restart(), settings(), binder(itemIds), map(paperTile, names)],
    prefabs: [
      { name: 'Lamp', widget: lamp() },
      { name: 'Here', widget: here() },
      { name: 'DarkPost', widget: darkPost() },
      { name: 'Door', widget: memoryDoor() },
      { name: 'Blank', widget: blankMark() },
    ],
    safeArea: 0,
  };
}
