"""Writes the Ludo.ai job lists (art/ludo_manifests/<name>.json) for tools/art/ludo_batch.py from the tables in art/ART_GUIDE.pdf.

    python ludo_make_manifests.py
Outputs go to art/incoming2/<tiles|objects|errors|items|bosses|characters>/ as <name>_s0.png ... (the tries; the chosen one is
copied to <name>.png by the picking step)."""
import json, os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
OUT = os.path.join(ROOT, 'art', 'ludo_manifests')
os.makedirs(OUT, exist_ok=True)

STYLE = ('storybook game art, hand-drawn, simple flat cel shading, thick clean dark-brown ink outline, cute chunky proportions, '
         'muted warm colours, isometric three-quarter view from above, light from the top left, single subject, centered, full view, '
         'plain parchment background')
PROP = 'art/training/props_11.png'      # the chest: the look of an object
ICON = 'art/training/props_14.png'      # the potion bottle: the look of an item
HERO = 'art/training/hero_01.png'       # the Storytender: the look of a creature
TREE = 'art/training/props_10.png'


def style(out, ref, prompt, n=3, image_type='sprite', **kw):
    return dict(out=f'art/incoming2/{out}', kind='style', style_image=ref, prompt=prompt, n=n, image_type=image_type, **kw)


def save(name, jobs):
    json.dump(jobs, open(os.path.join(OUT, name + '.json'), 'w'), indent=1)
    print(name, len(jobs), 'jobs')


# ---------------------------------------------------------------- floors
FLOOR_STYLE = ('seamless texture, seen from directly above, flat, even lighting, no shadows, no objects, hand-drawn, '
               'clean dark-brown ink details, flat cel shading, muted warm colours')
floors = {
    'floor_meadow_1': 'meadow grass with tiny tufts', 'floor_meadow_2': 'meadow grass with a few small clover leaves',
    'floor_meadow_3': 'meadow grass with a few tiny daisies', 'floor_dirt': 'packed dirt path with small pebbles',
    'floor_cobble': 'pale cobblestones with moss between them', 'floor_flagstone': 'large flat grey paving stones',
    'floor_slate': 'cold dark blue-grey slate tiles with a little frost', 'floor_parchment': 'an old printed book page with faint lines of text',
    'floor_planks': 'warm wooden kitchen floorboards', 'floor_moss': 'dark green moss with tiny glowing teal specks',
}
jobs = [dict(out=f'art/incoming2/tiles/{k}', kind='image', prompt=f'{v}, {FLOOR_STYLE}', image_type='texture', n=3,
             extra={'art_style': 'Cel-Shaded', 'perspective': 'Top-Down'}) for k, v in floors.items()]
for k, v in {'side_earth': 'the side face of a raised block of earth with roots and small stones', 'side_stone': 'the side face of a raised block of grey stone bricks',
             'side_wood': 'the side face of a raised wooden platform of vertical planks'}.items():
    jobs.append(dict(out=f'art/incoming2/tiles/{k}', kind='image', image_type='texture', n=2, extra={'art_style': 'Cel-Shaded', 'aspect_ratio': 'ar_16_9'},
                     prompt=f'{v}, flat front view, seamless left to right, hand-drawn, clean dark-brown ink outline, flat cel shading, muted warm colours'))
save('tiles', jobs)

# ---------------------------------------------------------------- objects (first states; the second state is made from the chosen first)
objs = {
    'chest_closed': 'a wooden treasure chest, closed, with brass corners and a lock', 'post_unlit': 'a wooden lantern post with an unlit glass lantern on top',
    'forge_warm': 'a stone blacksmith forge with a chimney, roaring orange fire glowing in its opening', 'oven_warm': 'a brick bread oven with an arched opening, warm glow inside',
    'sign_small': 'a small wooden signpost with a completely blank cream paper board, no writing', 'sign_wide': 'a wide wooden notice board on two posts with a completely blank cream paper board, no writing',
    'sign_tall': 'a tall wooden signpost with a completely blank cream paper board, no writing', 'plate_up': 'a round stone pressure plate, raised slightly above the ground',
    'echo_plate_dim': 'a dark diamond-shaped floor stone with a carved eye, dim', 'gate_closed': 'a colourful painted wooden fence gate with a brass padlock, closed',
    'storygate': 'a wall of pale paper strips hanging side by side, three cells wide', 'redaction_bar': 'a thick floating black bar with ragged torn edges',
    'block_stone': 'a plain cube of grey slate stone', 'block_wood': 'a plain cube of wooden planks', 'anvil': 'a blacksmith anvil', 'hammer': 'a blacksmith hammer',
    'tongs': 'blacksmith tongs', 'bellows': 'a leather blacksmith bellows with a wooden handle', 'shard': 'a floating glowing teal crystal splinter',
    'first_sword': 'a small crooked wooden-hilted sword lying on its side', 'torn_page': 'a torn storybook page, floating in the air',
    'storybook': 'an open storybook lying on the ground', 'word_bread': 'the word BREAD carved as chunky wooden letter blocks',
    'dough_1': 'a small lump of bread dough', 'dough_2': 'a half-risen lump of bread dough', 'dough_3': 'a full risen round loaf of bread dough',
    'table_long': 'a long wooden kitchen table set for six with plates and cups', 'chair': 'a simple wooden chair', 'portal': 'a swirling teal rift torn in the air with a glowing edge',
    'crystal': 'a small glowing teal crystal on the ground', 'dummy': 'a straw training dummy on a wooden post', 'scissors': 'a pair of giant scissors stuck blade-down in the floor',
    'patch': 'a paper cut-out patch with torn edges', 'tree_1': 'a round leafy storybook tree', 'tree_2': 'a tall slim leafy storybook tree',
    'tree_3': 'a wide bushy leafy storybook tree', 'house_1': 'a small timber cottage with a steep roof and chimney', 'house_2': 'a two-storey timber house with a chimney',
    'house_3': 'a small timber workshop with a lean-to roof',
}
jobs = []
for k, v in objs.items():
    ref = TREE if k.startswith('tree') else PROP
    jobs.append(style(f'objects/{k}', ref, f'{v}, {STYLE}', n=3))
save('objects', jobs)

# ---------------------------------------------------------------- Errors (idle, facing down-right) and bosses
errs = {
    'err_bare_idle': 'a grumpy heavy storybook bear missing patches of fur, as if letters were erased from it, standing',
    'err_mite_idle': 'a tiny ink bug made of one scribble with many thin legs',
    'err_runon_idle': 'a long slow slug of dark glossy ink made of tiny words, with a wet ink trail',
    'err_dangler_idle': 'a small floating creature hanging from a dangling thread, holding loose letters',
    'err_censor_idle': 'a stern hooded figure holding a thick black redaction bar across its front like a shield',
    'err_ellipsis_idle': 'three floating dark ink dots in a row with a faint shadowy body',
}
jobs = [style(f'errors/{k}', HERO, f'{v}, {STYLE}', n=3) for k, v in errs.items()]
save('errors', jobs)
bosses = {
    'boss_critic_idle': 'a towering figure made of layered red ink and torn review pages, a mouth full of sharp words',
    'boss_spoiler_idle': 'a floating open book with its last page torn out, glowing letters spilling out',
    'boss_cold_idle': 'a hunched figure of frost and pale blue cloth turning one huge frozen shoulder toward the viewer',
    'boss_scissor_idle': 'a tall thin tailor, half coloured and half pencil sketch, enormous shears for hands',
}
save('bosses', [style(f'bosses/{k}', HERO, f'{v}, {STYLE}', n=3) for k, v in bosses.items()])

# ---------------------------------------------------------------- villagers and the memory figures (the front view; the rest by rotation)
people = {
    'garrick_S': 'a broad middle-aged blacksmith with a short dark beard, rolled sleeves, a leather apron and a hammer at his belt, kind tired face, standing',
    'pip_S': 'a small curious child with messy hair, a big striped scarf and an open storybook hugged to the chest, standing',
    'maud_S': 'a warm older baker with a grey hair bun, flour on her apron, sleeves pushed up, holding a wooden bread paddle, standing',
    'figure_memory': 'a pale glowing cyan silhouette of a person, translucent, standing',
    'guest_standing': 'a pale shadowy dinner guest made of shadow, standing',
}
save('people', [style(f'characters/{k}', HERO, f'{v}, facing the viewer, {STYLE}', n=3) for k, v in people.items()])

# ---------------------------------------------------------------- the 69 item icons
items = {
    'authors_pen': 'a long cream feather quill pen with a gold nib', 'blank_page': 'a perfect blank white paper page, slightly glowing',
    'bookworm_charm': 'a small charm of a cute green bookworm curled on a ring', 'cartographer_compass': 'a brass compass with a glowing needle',
    'censors_monocle': 'a monocle with a black lens and a gold chain', 'clarity_tonic': 'a small glass bottle of clear blue tonic with a cork',
    'cloth_binding': 'a book spine bound in plain woven cloth', 'clover_press': 'a pressed four-leaf clover between two small paper sheets',
    'dust_jacket': 'a paper book dust jacket folded', 'eternal_bookmark': 'an ornate golden bookmark with a tassel',
    'ghost_pepper_ink': 'a small bottle of fiery red-orange ink with a pepper on the label', 'ghostwriter_glove': 'a pale translucent ghostly glove holding a pen',
    'glue_stub': 'a stubby glue stick, nearly used up', 'gold_leaf': 'a sheet of shimmering gold leaf', 'golden_ratio': 'a golden spiral drawn on a small gold disc',
    'herbal_tea': 'a steaming cup of herbal tea with a leaf', 'honey_biscuit': 'a round honey biscuit with a drizzle of honey',
    'hourglass_of_drafts': 'an hourglass with sand and tiny paper scraps', 'illuminated_binding': 'a book spine decorated with gold illuminated patterns',
    'ink_blot': 'a glossy black ink blot', 'lamplighter_match': 'a long wooden match with a small teal flame', 'library_binding': 'a library book spine with a small label',
    'loose_thread': 'a loose silver-grey thread curling', 'lucky_clover': 'a bright green four-leaf clover', 'margin_doodle': 'a small cute doodle of a star and a swirl sketched on paper',
    'marginalia_dust': 'a small pile of glittering pencil dust in a little pouch', 'memory_jar': 'a glass jar holding a glowing teal wisp', 'midnight_inkwell': 'a dark blue inkwell with tiny stars',
    'paper_clip': 'a shiny metal paper clip', 'paper_scrap': 'a small torn scrap of paper with scribbles', 'pencil_shaving': 'a curl of pencil shaving',
    'phoenix_draught': 'a glass bottle of glowing orange-red potion with a small flame', 'phoenix_ember': 'a glowing orange ember with a tiny feather',
    'pocket_workbench': 'a tiny folding toolbox with small tools', 'quill_feather': 'a single cream feather with a sharp tip', 'reader_digest': 'a small thick digest book with a ribbon',
    'reading_glasses': 'a pair of round reading glasses', 'rubber_band': 'a stretchy red rubber band', 'silver_ribbon': 'a curled silver ribbon', 'silver_thread': 'a spool of shining silver thread',
    'time_in_a_bottle': 'a corked glass bottle with swirling golden sand and a tiny clock', 'tin_bell': 'a small tin hand bell', 'unwritten_word': 'a glowing teal word floating, letters faint and unfinished',
    'vellum_binding': 'a book spine bound in pale vellum', 'void_pearl': 'a black pearl with a purple shimmer', 'wax_seal': 'a red wax seal stamp',
    'bookmark': 'a simple ribbon bookmark', 'bookmark_charm': 'a small charm shaped like a bookmark on a ring', 'eraser_crumbs': 'a small pile of pink eraser crumbs',
    'first_edition': 'a worn leather book with a gold star', 'footnote': 'a tiny paper note with a small number one', 'gilded_binding': 'a book spine bound in gold-edged leather',
    'hardcover_binding': 'a sturdy hardcover book spine', 'highlighter': 'a yellow highlighter pen', 'index_tab': 'a small coloured index tab', 'ink_flask': 'a round flask of dark ink with a cork',
    'ink_vial': 'a small thin vial of ink', 'lantern_oil': 'a small bottle of golden lantern oil', 'leatherbound_binding': 'a leather-bound book spine', 'margin_note': 'a small paper note with a handwritten arrow',
    'oxford_comma': 'a big comma symbol carved of cream stone', 'paperback_binding': 'a paperback book spine, soft and bendy', 'red_pen': 'a red pen with a cap', 'softcover_binding': 'a softcover book spine',
    'sticky_note': 'a yellow sticky note', 'thimble': 'a silver sewing thimble', 'torn_page': 'a torn page from a storybook', 'void_ink': 'a bottle of black glittering ink', 'warm_loaf': 'a warm round loaf of bread with steam',
}
assert len(items) == 69, len(items)
save('items', [style(f'items/icon_{k}', ICON, f'{v}, game item icon, single object, filling most of the picture, {STYLE}', n=2, image_type='item-icon') for k, v in items.items()])
