"""Makes the game's missing sprites with a running Forge (Stable Diffusion WebUI Forge started with --api), following
art/SD_PROMPTS.md: the right model and settings, the character reference (IP-Adapter) and the pose (OpenPose) for every
frame. Four tries of every picture are saved in art/generated/, named after what they are; send that folder (or push it)
and Claude picks the best, cuts them out and puts them in the game.

Run it from the repository folder while Forge is open:
    <forge folder>\\system\\python\\python.exe tools\\art\\forge_batch.py [group ...]
Groups: storytender, people, errors, bosses, objects, tiles (default: all). Already-made pictures are skipped, so it can
be stopped and started again."""
import base64, json, os, sys, time, urllib.request

URL = os.environ.get('FORGE_URL', 'http://127.0.0.1:7860')
HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
POSES = os.path.join(REPO, 'art', 'poses')
REF = os.path.join(REPO, 'art', 'reference')
OUT = os.path.join(REPO, 'art', 'generated')

STYLE = ('storybook game sprite, chibi proportions, clean thick dark brown ink outline, flat cel shading, muted warm colours, '
         'hand drawn 2d game art, isometric view from slightly above, full body, centered, plain flat parchment background, simple background')
NEG_CHAR = ('realistic, photo, photorealistic, 3d render, portrait, close-up, bust, face close-up, human face, woman, girl, man, nose, lips, '
            'skin, hair, eyelashes, makeup, frame, border, circle, emblem, text, letters, watermark, signature, logo, busy background, scenery, '
            'landscape, multiple characters, duplicate, cropped, cut off feet, extra limbs, extra arms, blurry')
NEG_PEOPLE = ('realistic, photo, photorealistic, 3d render, portrait, close-up, bust, frame, border, circle, text, letters, watermark, '
              'signature, logo, busy background, scenery, landscape, multiple characters, duplicate, cropped, cut off feet, extra limbs, blurry')
NEG_THING = ('realistic, photo, photorealistic, 3d render, frame, border, circle, emblem, text, letters, watermark, signature, logo, '
             'busy background, scenery, landscape, person, character, people, duplicate, cropped, blurry')

HERO = ('(tiny chibi hooded wanderer:1.3), (faceless, face hidden in deep black shadow inside the hood:1.4), (two small glowing teal dot eyes:1.3), '
        'dark brown cloth cowl, tan stitched tunic, brown leather satchel strap across the chest, dark green trousers, brown boots, '
        'big brown leather backpack with a grey gear emblem and a wrench sticking out, small glass lantern glowing teal at the right hip, about three heads tall')
DIRS = {
    '1_toward': ('facing the viewer, front view', 'storytender_front.png'),
    '2_down_right': ('three-quarter front view, turned toward the right, backpack visible behind left shoulder', 'storytender_front.png'),
    '3_right': ('side view, facing right, profile, backpack on the left side of the body', 'storytender_front.png'),
    '4_up_right': ('three-quarter back view, walking away toward the upper right, backpack visible, no eyes visible', 'storytender_back.png'),
    '5_away': ('back view, facing away from the viewer, backpack with gear emblem, no face, no eyes', 'storytender_away.png'),
}
POSE_WORDS = {'a_stand': 'standing still',
              'b_walk': '(walking, mid stride, one leg stepping forward, legs apart:1.3)',
              'c_walk': '(walking, one knee raised high, one boot lifted off the ground:1.4)',
              'd_walk': '(walking, mid stride, the other leg stepping forward, legs apart:1.3)',
              'e_walk': '(walking, the other knee raised high, one boot lifted off the ground:1.4)',
              'f_strike': '(swinging a long cream feather quill pen overhead, arm raised high:1.3)'}

PEOPLE = {
    'garrick': '(chibi:1.3) broad middle-aged blacksmith, short dark beard, rolled up sleeves, brown leather apron, hammer at his belt, kind tired eyes, simple cartoon face',
    'pip': '(chibi:1.3) small curious child, messy hair, big striped scarf, hugging an open storybook to the chest, simple cartoon face',
    'maud': '(chibi:1.3) warm older baker woman, grey hair in a bun, flour on her apron, sleeves pushed up, holding a wooden bread paddle, simple cartoon face',
}
ERRORS = {
    'bare': '(chibi:1.3) grumpy bear missing patches of fur as if erased with an eraser, heavy body, storybook monster',
    'mite': '(tiny:1.3) ink bug made of a single scribble, many thin little legs, dark ink, storybook monster',
    'runon': 'long slow slug made of dark ink and tiny written words, glossy ink trail behind it, storybook monster',
    'dangler': 'small floating creature hanging from a dangling thread, holding loose letters to throw, storybook monster',
    'censor': '(chibi:1.3) stern hooded figure holding a big black redaction bar in front of itself like a shield, storybook monster',
    'ellipsis': 'three floating dark ink dots with a faint shadowy body, blinking, storybook monster',
}
ERROR_STATES = {'stand': 'standing', 'walk': 'walking', 'attack': 'attacking, lunging', 'friendly': 'friendly, gentle smile, softer colours'}
BOSSES = {
    'critic': 'towering figure made of layered red ink and torn review pages, mouth full of sharp words, storybook boss',
    'spoiler': 'floating open book with its last page torn out, glowing letters spilling out of it, storybook boss',
    'cold_shoulder': 'hunched figure of frost and pale blue fabric, one huge frozen shoulder turned toward the viewer, storybook boss',
    'scissor_man': 'tall thin tailor, half coloured and half pencil sketch, enormous shears instead of hands, storybook boss',
}
OBJECTS = {
    'sign_small': 'wooden signpost with a small blank cream paper board, completely blank, no writing',
    'sign_tall': 'tall wooden signpost with a blank cream paper board, no writing',
    'sign_wide': 'wide wooden notice board on two posts, blank cream paper, no writing',
    'chest_closed': 'wooden treasure chest, closed', 'chest_open': 'wooden treasure chest, open, soft glow inside',
    'post_unlit': 'wooden lantern post, unlit', 'post_lit': 'wooden lantern post, lit, warm teal flame',
    'plate_up': 'round stone pressure plate, raised', 'plate_down': 'round stone pressure plate, pressed down flat',
    'echo_plate_dim': 'dark diamond stone plate with a carved eye, dim', 'echo_plate_lit': 'dark diamond stone plate with a carved eye, glowing teal',
    'fence_closed': 'colourful wooden fence gate with a padlock, closed', 'fence_open': 'colourful wooden fence gate swung open',
    'forge_frozen': 'frozen stone forge with a still blue frozen flame', 'forge_warm': 'stone forge with a warm orange fire',
    'oven_cold': 'cold dark brick bread oven', 'oven_warm': 'brick bread oven, warm and glowing',
    'storybook': 'open storybook lying on the ground, its last page torn out', 'memory_shard': 'floating glowing crystal shard, memory',
    'anvil': 'blacksmith anvil', 'first_sword': 'small crooked sword lying on the ground', 'hammer': 'blacksmith hammer',
    'tongs': 'blacksmith tongs', 'bellows': 'leather bellows', 'torn_page': 'torn book page floating', 'chair': 'old wooden chair',
    'table': 'long kitchen table set for six', 'guest': 'shadowy guest sitting on a chair',
    'bread_plain': 'the word BREAD carved as a chunky wooden block', 'bread_underline': 'the word BREAD carved as a chunky wooden block, underlined',
    'bread_bold': 'the word BREAD carved as a chunky wooden block, bold and heavy', 'bread_italic': 'the word BREAD carved as a chunky wooden block, slanted italic',
    'dough': 'lump of rising bread dough', 'redaction_bar': 'floating black redaction bar', 'scissors': 'giant pair of scissors stuck in the floor',
    'patch': 'paper cut-out patch', 'rift': 'swirling portal rift torn in the air', 'bookcase': 'small wooden bookcase',
}
TILES = {'grass': 'meadow grass', 'cobble': 'pale cobblestone town street', 'slate': 'cold blue slate',
         'page': 'printed book page with faint lines of text', 'planks': 'warm wooden kitchen planks', 'mat': 'mossy dark green mat'}


def call(path, payload=None):
    req = urllib.request.Request(URL + path, data=json.dumps(payload).encode() if payload is not None else None,
                                 headers={'Content-Type': 'application/json'}, method='POST' if payload is not None else 'GET')
    with urllib.request.urlopen(req, timeout=900) as r:
        return json.loads(r.read())


def b64(path):
    with open(path, 'rb') as f:
        return base64.b64encode(f.read()).decode()


def pick(names, *wanted):
    for w in wanted:
        for n in names:
            if w.lower() in n.lower():
                return n
    return None


def setup():
    try:
        models = call('/sdapi/v1/sd-models')
    except Exception as e:
        sys.exit(f'Forge is not answering at {URL}. Is it open, and started with --api (webui-user.bat: set COMMANDLINE_ARGS=--api)?\n{e}')
    ckpt = pick([m['title'] for m in models], 'dreamshaper')
    if not ckpt:
        sys.exit('DreamShaper XL is not in webui\\models\\Stable-diffusion. Put it there and start Forge again.')
    call('/sdapi/v1/options', {'sd_model_checkpoint': ckpt})
    cn = {'models': [], 'modules': []}
    try:
        cn['models'] = call('/controlnet/model_list').get('model_list', [])
        cn['modules'] = call('/controlnet/module_list').get('module_list', [])
    except Exception:
        pass
    pose_model = pick(cn['models'], 'openpose_sdxl', 'xinsir', 'openpose')
    ip_model = pick(cn['models'], 'ip-adapter-plus_sdxl', 'ip-adapter')
    ip_module = pick(cn['modules'], 'ipadapter_clip_h', 'clip_h', 'vit-h', 'ip-adapter_clip')
    print('model:', ckpt)
    print('pose model:', pose_model, '| reference model:', ip_model, '| reference preprocessor:', ip_module)
    if not pose_model or not ip_model:
        print('Warning: a ControlNet model was not found in webui\\models\\ControlNet; pictures will be made without it.')
    return pose_model, ip_model, ip_module


def unit(image, module, model, weight, mode='Balanced', end=1.0):
    return {'enabled': True, 'image': image, 'module': module or 'None', 'model': model, 'weight': weight,
            'resize_mode': 'Crop and Resize', 'control_mode': mode, 'pixel_perfect': False, 'guidance_start': 0.0, 'guidance_end': end}


def make(name, prompt, negative, seed, ref=None, ref_weight=0.6, pose=None, size=(1024, 1024), models=(None, None, None), ref_end=1.0, pose_weight=1.0):
    out_dir = os.path.join(OUT, os.path.dirname(name))
    os.makedirs(out_dir, exist_ok=True)
    first = os.path.join(OUT, f'{name}_s0.png')
    if os.path.exists(first):
        return
    pose_model, ip_model, ip_module = models
    units = []
    if ref and ip_model and os.path.exists(ref):
        units.append(unit(b64(ref), ip_module, ip_model, ref_weight, end=ref_end))
    if pose and pose_model and os.path.exists(pose):
        units.append(unit(b64(pose), 'None', pose_model, pose_weight, 'ControlNet is more important'))
    payload = {'prompt': prompt, 'negative_prompt': negative, 'width': size[0], 'height': size[1], 'steps': 30, 'cfg_scale': 6,
               'sampler_name': 'DPM++ 2M', 'scheduler': 'Karras', 'seed': seed, 'batch_size': 1, 'n_iter': 4,
               'alwayson_scripts': {'ControlNet': {'args': units}} if units else {}}
    t = time.time()
    r = call('/sdapi/v1/txt2img', payload)
    every = r.get('images', [])
    imgs = every[:4]   # extra images (ControlNet's previews) come after the four pictures
    for k, im in enumerate(imgs):
        with open(os.path.join(OUT, f'{name}_s{k}.png'), 'wb') as f:
            f.write(base64.b64decode(im.split(',', 1)[-1]))
    extra = every[4:]
    for k, im in enumerate(extra):   # kept so we can see what ControlNet saw
        os.makedirs(os.path.join(OUT, '_controlnet'), exist_ok=True)
        with open(os.path.join(OUT, '_controlnet', f'{name.replace("/", "_")}_{k}.png'), 'wb') as f:
            f.write(base64.b64decode(im.split(',', 1)[-1]))
    note = f' (+{len(extra)} ControlNet previews)' if extra else (' - WARNING: ControlNet sent nothing back, the pose/reference may be ignored' if units else '')
    print(f'{name}: {len(imgs)} pictures in {time.time() - t:.0f} s{note}')


def main():
    groups = sys.argv[1:] or ['storytender', 'people', 'errors', 'bosses', 'objects', 'tiles']
    models = setup()
    ref_style = os.path.join(REF, 'style_props.png')
    if 'storytender' in groups:
        for d, (words, ref) in DIRS.items():
            seed = 1000 + list(DIRS).index(d) * 10   # the same seeds for every pose of a direction, so the frames match
            for p, pw in POSE_WORDS.items():
                moving = p != 'a_stand'   # in moving frames the pose must win over the reference picture
                make(f'storytender/{d}_{p}', f'{HERO}, {words}, {pw}, {STYLE}', NEG_CHAR + (', standing still, feet together' if moving else ''),
                     seed, os.path.join(REF, ref), 0.45 if moving else 0.6, os.path.join(POSES, f'{d}_{p}.png'), models=models,
                     ref_end=0.7 if moving else 1.0, pose_weight=1.3 if moving else 1.0)
    if 'people' in groups:
        for who, desc in PEOPLE.items():
            for d in ('1_toward', '2_down_right', '4_up_right', '5_away'):
                for look, extra, neg in (('restored', '', NEG_PEOPLE), ('placeholder', ', grey graphite pencil sketch, unfinished drawing, rough hatching, no colour, monochrome', NEG_PEOPLE + ', colour, colorful')):
                    make(f'people/{who}_{look}_{d}', f'{desc}, {DIRS[d][0]}, standing{extra}, {STYLE}', neg, 2000 + len(who),
                         ref_style, 0.4, os.path.join(POSES, f'{d}_a_stand.png'), models=models)
    if 'errors' in groups:
        for who, desc in ERRORS.items():
            for st, sw in ERROR_STATES.items():
                make(f'errors/{who}_{st}', f'{desc}, {sw}, {STYLE}', NEG_THING, 3000 + len(who), ref_style, 0.4, models=models)
    if 'bosses' in groups:
        for who, desc in BOSSES.items():
            for st in ('standing', 'attacking'):
                make(f'bosses/{who}_{st}', f'{desc}, large, imposing, boss, {st}, {STYLE}', NEG_THING, 4000 + len(who), ref_style, 0.4, models=models)
    if 'objects' in groups:
        for what, desc in OBJECTS.items():
            make(f'objects/{what}', f'{desc}, single object, {STYLE}', NEG_THING, 5000 + len(what), ref_style, 0.4, models=models)
    if 'tiles' in groups:
        for what, desc in TILES.items():
            make(f'tiles/{what}', f'{desc}, seamless isometric floor tile, flat 2:1 diamond seen from above, no sides, no thickness, top surface only, {STYLE}',
                 NEG_THING + ', walls, sides, block, cube, depth', 6000 + len(what), os.path.join(REF, 'style_tiles.png'), 0.4, size=(1024, 512), models=models)
    print('Done. The pictures are in', OUT)


main()
