# Stable Diffusion (Forge) prompts for The Last Storytender

For Forge with an SDXL model (DreamShaper XL), ControlNet OpenPose (xinsir) and IP-Adapter Plus. Stable Diffusion
works best making **one thing per image**: make each frame or object on its own, and the game's tools cut the
background off and put the frames together. Keep everything you like in a folder, named like the pose file
(`1_toward_a_stand.png`), and send them to Claude.

## Settings for everything

Set these once at the top of **Txt2img**:

| Setting | Value |
|---|---|
| UI (top left) | **xl** |
| Checkpoint | **DreamShaper XL** |
| Width x Height | **1024 x 1024** |
| Sampling method | **DPM++ 2M**, Schedule type **Karras** |
| Sampling steps | **30** |
| CFG Scale | **6** |
| Batch count | **4** (four tries at once; keep the best) |

**The Style words** (paste at the end of every prompt below):

```
storybook game sprite, chibi proportions, clean thick dark brown ink outline, flat cel shading, muted warm colours, hand drawn 2d game art, isometric view from slightly above, full body, centered, plain flat parchment background, simple background
```

**The Negative prompt** (paste into Negative prompt every time):

```
realistic, photo, photorealistic, 3d render, portrait, close-up, bust, face close-up, human face, woman, girl, man, nose, lips, skin, hair, eyelashes, makeup, frame, border, circle, emblem, text, letters, watermark, signature, logo, busy background, scenery, landscape, multiple characters, duplicate, cropped, cut off feet, extra limbs, extra arms, blurry
```

For objects, props and tiles, take `human face, woman, girl, man, nose, lips, skin, hair, eyelashes, makeup` out of
the negative prompt and add `person, character, people`.

## ControlNet: two units

Open **ControlNet Integrated** below the prompt.

**Unit 0, the look (IP-Adapter):** keeps the character (or the art style) the same in every image.
1. Tick **Enable**. Click the **IP-Adapter** circle.
2. Drag a reference picture into the image box: for the Storytender, `art/reference/storytender_front.png` (or `storytender_back.png` / `storytender_away.png` for the back views); for
   objects, one of your props (the tree or the house) so the style matches.
3. **Preprocessor:** the CLIP-ViT-H one (its name has **CLIP-H** or **ViT-H** in it).
4. **Model:** `ip-adapter-plus_sdxl_vit-h`.
5. **Control Weight:** **0.6** for characters (higher copies the reference too closely, lower drifts away), **0.4** for
   objects (style only).

**Unit 1, the pose (OpenPose)**, for characters only:
1. Tick **Enable**. Click the **OpenPose** circle.
2. Drag a pose picture from `art/poses/` into the image box.
3. **Preprocessor: None** (the pictures are already stick figures).
4. **Model:** `openpose_sdxl_xinsir` (press the blue refresh button if it is not listed).
5. **Control Weight:** **1**. If the pose is ignored, choose **ControlNet is more important**.

## How to make a walking strip

1. Pick the direction's prompt below, add the Style words, and put the `a_stand` pose of that direction in Unit 1.
2. Generate 4. When one is right, click the **recycle button** beside **Seed** (it keeps that seed).
3. Swap only the pose picture: `b_walk`, `c_walk`, `d_walk`, `e_walk`, `f_strike`. Generate each.
4. Save each frame with the pose file's name. Do the next direction.

If a frame comes out wrong, change the seed for that frame only (dice button), or raise Unit 0 to 0.7.

---

## 1. The Storytender

The character description (start of every Storytender prompt):

```
(tiny chibi hooded wanderer:1.3), (faceless, face hidden in deep black shadow inside the hood:1.4), (two small glowing teal dot eyes:1.3), dark brown cloth cowl, tan stitched tunic, brown leather satchel strap across the chest, dark green trousers, brown boots, big brown leather backpack with a grey gear emblem and a wrench sticking out, small glass lantern glowing teal at the right hip, about three heads tall
```

Then the direction, then the Style words:

| Pose files | Direction words |
|---|---|
| `1_toward_*` | `facing the viewer, front view` |
| `2_down_right_*` | `three-quarter front view, turned toward the right, backpack visible behind left shoulder` |
| `3_right_*` | `side view, facing right, profile, backpack on the left side of the body` |
| `4_up_right_*` | `three-quarter back view, walking away toward the upper right, backpack visible, no eyes visible` |
| `5_away_*` | `back view, facing away from the viewer, backpack with gear emblem, no face, no eyes` |

Add for the poses: `b..e_walk`: `walking`; `f_strike`: `swinging a long cream feather quill pen overhead`.

Example, toward the viewer, standing:
```
(tiny chibi hooded wanderer:1.3), (faceless, face hidden in deep black shadow inside the hood:1.4), (two small glowing teal dot eyes:1.3), dark brown cloth cowl, tan stitched tunic, brown leather satchel strap across the chest, dark green trousers, brown boots, big brown leather backpack with a grey gear emblem and a wrench sticking out, small glass lantern glowing teal at the right hip, about three heads tall, facing the viewer, front view, standing, storybook game sprite, chibi proportions, clean thick dark brown ink outline, flat cel shading, muted warm colours, hand drawn 2d game art, isometric view from slightly above, full body, centered, plain flat parchment background, simple background
```

Extra poses (same character text; use the `a_stand` pose of the direction, or no pose for the crumpled one):
- `holding a small glass lantern up high in the right hand, teal light shining forward`
- `dashing forward, leaning far forward, speed lines`
- `crouched low, sneaking on tiptoe`
- `lying crumpled on the ground like a crumpled paper drawing` (turn Unit 1 off)

## 2. Thistledown's people

Use the pose files of the directions (`1_toward_a_stand`, `2_down_right_a_stand`, `4_up_right_a_stand`,
`5_away_a_stand`). For the **placeholder** versions add `grey graphite pencil sketch, unfinished drawing, rough
hatching, no colour, monochrome` to the prompt and `colour, colorful` to the negative prompt. Take `human face, man,
woman, hair` out of the negative prompt for these three; keep `realistic, photo, portrait, close-up`.

- **Garrick:** `(chibi:1.3) broad middle-aged blacksmith, short dark beard, rolled up sleeves, brown leather apron, hammer at his belt, kind tired eyes, simple cartoon face`
- **Pip:** `(chibi:1.3) small curious child, messy hair, big striped scarf, hugging an open storybook to the chest, simple cartoon face`
- **Maud:** `(chibi:1.3) warm older baker woman, grey hair in a bun, flour on her apron, sleeves pushed up, holding a wooden bread paddle, simple cartoon face`

## 3. The Errors (enemies)

No pose (Unit 1 off); Unit 0 with your Bare (the pig) as the style reference at **0.4**. Make each four times:
`standing`, `walking`, `attacking, lunging`, and `friendly, gentle smile, softer colours` (the proofread one).

- **Bare:** `(chibi:1.3) grumpy bear missing patches of fur as if erased with an eraser, heavy body, storybook monster`
- **Mite:** `(tiny:1.3) ink bug made of a single scribble, many thin little legs, dark ink, storybook monster`
- **Run-on:** `long slow slug made of dark ink and tiny written words, glossy ink trail behind it, storybook monster`
- **Dangler:** `small floating creature hanging from a dangling thread, holding loose letters to throw, storybook monster`
- **Censor:** `(chibi:1.3) stern hooded figure holding a big black redaction bar in front of itself like a shield, storybook monster`
- **Ellipsis:** `three floating dark ink dots with a faint shadowy body, blinking, storybook monster`

## 4. The bosses

No pose; Unit 0 style reference at 0.4. Width x height **1024 x 1024**, add `large, imposing, boss` to the prompt.
Make each twice: `standing` and `attacking`.

- **The Critic:** `towering figure made of layered red ink and torn review pages, mouth full of sharp words, storybook boss`
- **The Spoiler:** `floating open book with its last page torn out, glowing letters spilling out of it, storybook boss`
- **The Cold Shoulder:** `hunched figure of frost and pale blue fabric, one huge frozen shoulder turned toward the viewer, storybook boss`
- **The Scissor-Man:** `tall thin tailor, half coloured and half pencil sketch, enormous shears instead of hands, storybook boss`

## 5. Objects

No pose; Unit 0 with your house or tree at **0.4**. Use the object negative prompt. One object per image.

- **Blank signs** (the game writes the words): `wooden signpost with a small blank cream paper board, completely blank, no writing`;
  `tall wooden signpost with a blank cream paper board, no writing`; `wide wooden notice board on two posts, blank cream paper, no writing`.
- **Two states:** `wooden treasure chest, closed` / `wooden treasure chest, open, soft glow inside`;
  `wooden lantern post, unlit` / `wooden lantern post, lit, warm teal flame`;
  `round stone pressure plate, raised` / `round stone pressure plate, pressed down flat`;
  `dark diamond stone plate with a carved eye, dim` / `the same, glowing teal`;
  `colourful wooden fence gate with a padlock, closed` / `the same gate swung open`;
  `frozen stone forge with a still blue frozen flame` / `the same forge with a warm orange fire`;
  `cold dark brick bread oven` / `the same oven, warm and glowing`.
- **Story things:** `open storybook lying on the ground, its last page torn out`; `floating glowing crystal shard, memory`;
  `blacksmith anvil`; `small crooked sword lying on the ground`; `blacksmith hammer`; `blacksmith tongs`; `leather bellows`;
  `torn book page floating`; `old wooden chair`; `long kitchen table set for six`; `shadowy guest sitting on a chair`;
  `the word BREAD carved as a chunky wooden block` (then `underlined`, `bold and heavy`, `slanted italic`);
  `lump of rising bread dough`; `floating black redaction bar`; `giant pair of scissors stuck in the floor`;
  `paper cut-out patch`; `swirling portal rift torn in the air`; `small wooden bookcase`.

## 6. Floor tiles

No pose; Unit 0 with your tile sheet at 0.4. Size **1024 x 512** (2:1). Add to the prompt:
`seamless isometric floor tile, flat 2:1 diamond seen from above, no sides, no thickness, top surface only` and
add `walls, sides, block, cube, depth` to the negative prompt. Make 6 of each:
`meadow grass`, `pale cobblestone town street`, `cold blue slate`, `printed book page with faint lines of text`,
`warm wooden kitchen planks`, `mossy dark green mat`.
