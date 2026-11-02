# Art prompts for Gemini: what the game still needs

Each section is one image to generate. Paste the **Style block** first, then the section's prompt. Generate each sheet
on its own (one sheet per request) so the style and the layout stay clean.

## Style block (paste before every prompt)

> Hand-drawn 2D game art in the same style as my previous sheets: a warm storybook look, clean dark-brown ink
> outlines of even weight, soft cel shading with one shadow tone and a gentle highlight, muted warm colours (parchment,
> moss green, worn wood, slate), slightly chunky cute proportions. Camera: **isometric game view from above at about 30
> degrees** (2:1 isometric, the way objects look on a 64x32 diamond floor tile). **Plain flat background of exactly one
> colour, #EADBB4 (warm parchment), no texture, no gradient, no vignette.** Every drawing stands on its own with
> **wide empty margins** (at least 40 pixels of plain background between drawings, nothing touching or overlapping).
> **No text, labels, names, numbers or captions anywhere** unless the prompt asks for words. A small soft oval shadow
> under each standing thing is fine. Keep every drawing at the **same scale** across the sheet; standing figures
> stand on the **same invisible baseline** in each row. Arrange drawings in a **strict grid** exactly as described.

## 1. The Storytender, walking (five strips, one direction each)

Image models lose track of directions when one picture holds many of them, so this is **five separate requests**,
one per direction. The game mirrors the right-facing strips to make the left-facing ones, so five are enough.
For every request: paste the Style block, **attach one good picture of the Storytender as a reference**, paste the
prompt below, and replace `[DIRECTION]` with one of the five direction texts. If a strip comes back with a frame that
turns, regenerate only that strip.

> **Reference:** the attached character. Draw exactly this character and nothing else: a small hooded wanderer about
> 3 heads tall, dark brown cowl hiding a dark face with two glowing teal eyes, tan tunic with stitched seams, a brown
> leather satchel strap across the chest, dark green trousers, brown boots, a big brown leather backpack with a grey
> gear emblem and a wrench sticking out of it, and a small glass lantern glowing teal hanging at the right hip. Same
> colours, same proportions and same details in every frame.
>
> A sprite strip of **exactly 6 frames in one single row**, every frame the same width, the character the same size
> in every frame, the feet on the same invisible baseline, at least 60 pixels of plain background between frames.
>
> **Every frame faces exactly the same way: [DIRECTION]. The character must not turn, rotate or change viewing angle
> between frames; only the arms and legs move.**
>
> Frame 1: standing still, relaxed. Frames 2 to 5: a 4-frame walk cycle **in place** (not moving across the strip):
> 2 right foot forward and left arm forward, 3 feet together passing with a slight bob up, 4 left foot forward and
> right arm forward, 5 feet together passing with a slight bob up. Frame 6: an overhead strike with a long cream
> feather quill pen held in the right hand, swinging forward in the facing direction.

The five `[DIRECTION]` texts:

1. **toward the viewer**: the whole face and the front of the tunic are visible, looking straight out of the image;
   the backpack only peeks out above both shoulders; the lantern hangs at the left side of the image.
2. **diagonally down and to the right, a three-quarter front view**: the face and the front of the body are visible
   and turned toward the lower right corner of the image; the backpack shows behind the left shoulder.
3. **to the right, a side view**: the right side of the body; the hood in profile, looking at the right edge of the
   image, one glowing eye visible; the backpack fully visible on the left side of the body.
4. **diagonally up and to the right, a three-quarter back view**: mostly the back and the backpack, the hood turned
   toward the upper right corner of the image; no eyes visible; the right shoulder nearer to the viewer.
5. **away from the viewer**: the full back, the backpack in the middle with the gear emblem facing the viewer; no face
   and no eyes visible; the lantern hangs at the right side of the image.

## 2. The Storytender, extra poses (four strips, the same way)

The same method: one request per strip, the reference picture attached, the reference text from prompt 1, and the
same rules (one row, same size, same baseline, same facing in every frame). Make each strip twice: facing **toward
the viewer** and facing **away from the viewer** (8 requests in all).

> A strip of **exactly 4 frames in one row**, all facing [toward the viewer / away from the viewer], not turning
> between frames.
> - Strip A, **lantern up**: holding the lantern up high in the right hand, its teal light shining forward; frames
>   1 to 4 the light gently flickering brighter and dimmer.
> - Strip B, **dash**: a quick dash forward: 1 crouch, 2 leaning far forward with speed lines behind, 3 the same
>   further, 4 straightening up.
> - Strip C, **creeping**: crouched low and sneaking on tiptoe, a 4-frame slow sneaking walk in place.
> - Strip D, **crumpled**: 1 hit and stumbling, 2 falling, 3 lying crumpled flat like a crumpled paper drawing,
>   4 getting back up.

## 3. Thistledown's people, as placeholders and restored

> Three villagers of a storybook town, each drawn **twice**: once as an unfinished **placeholder** (a faceless grey
> graphite pencil sketch of the same silhouette, rough hatching, no colour) and once **restored** (full colour,
> finished). A strict grid of **6 rows x 4 columns**; columns are facing down, down-right, up-right and up.
> Row 1 Garrick placeholder, row 2 Garrick restored: a broad middle-aged blacksmith with a short beard, rolled
> sleeves, a leather apron and a hammer at his belt. Row 3 Pip placeholder, row 4 Pip restored: a small curious child
> with messy hair, a big scarf and an open storybook hugged to the chest. Row 5 Maud placeholder, row 6 Maud restored:
> a warm older baker with a bun of grey hair, flour on her apron, sleeves pushed up, holding a wooden bread paddle.

## 4. The Errors (enemies)

> Six small storybook monsters made of mistakes in writing, each with **3 frames in one row** (idle, moving, attacking)
> and a 4th frame **"proofread"** (corrected: the same creature turned friendly, softer colours, a gentle smile).
> A strict grid of **6 rows x 4 columns**, all facing down-right.
> Row 1 the Bare: a bear that is missing patches of its fur, as if letters were erased from it, looking grumpy, heavy.
> Row 2 the Mite: a tiny fast ink bug made of a single crawling typo, many little legs.
> Row 3 the Run-on: a long slow slug made of one endless sentence of ink, leaving a wet ink trail.
> Row 4 the Dangler: a floating creature hanging from a dangling thread like a misplaced phrase, throws words.
> Row 5 the Censor: a stern figure holding a big black redaction bar in front of itself like a shield.
> Row 6 the Ellipsis: three floating dark dots that blink in and out, with a faint shadowy body.

## 5. The bosses

> Four large storybook bosses, each in its own cell of a strict grid of **2 rows x 4 columns**; row 1 is each boss
> standing, row 2 the same boss attacking. Column 1 the Critic: a towering figure made of layered red ink and torn
> review pages, a mouth full of sharp words. Column 2 the Spoiler: a floating open book with its last page torn out,
> glowing letters spilling out. Column 3 the Cold Shoulder: a hunched figure of frost and blue fabric that always
> turns one big frozen shoulder toward the viewer. Column 4 the Scissor-Man: a tall thin tailor, half coloured and half
> pencil sketch, with a pair of enormous shears instead of hands.

## 6. Blank signs (so the game can write the words on them)

> Wooden signs with **completely blank cream paper boards, no writing at all**. A strict grid of **2 rows x 4
> columns**. Row 1: a signpost with a small blank board (two lines tall), a tall signpost with the same board, a wide
> notice board on two posts, a small hanging plaque on a short stand. Row 2: the same four, slightly weathered with a
> torn corner. Same wood and same cream paper as my earlier "The bridge is BROKEN" signs.

## 7. Things that change state

> A strict grid of **4 rows x 4 columns**, each object drawn in two states side by side (2 pairs per row).
> Row 1: a wooden treasure chest closed / the same chest open with a soft glow inside; a lantern post unlit / the same
> post lit with a warm teal flame. Row 2: a stone pressure plate up / pressed down; a glowing echo plate (a dark
> diamond stone with a carved eye) dim / glowing teal. Row 3: a colourful wooden fence gate with a padlock closed /
> the same gate swung open; a tall arched stained-glass gate closed / open. Row 4: a frozen forge with a still blue
> frozen flame / the same forge with a warm orange fire; a cold dark brick bread oven / the same oven warm and glowing.

## 8. Thistledown's buildings, as ghosts and restored

> Isometric storybook village buildings, each twice: a grey graphite **pencil-sketch placeholder** version and a full
> colour **restored** version. A strict grid of **3 rows x 4 columns** (sketch, colour, sketch, colour). Row 1: a small
> cottage; a larger two-storey house. Row 2: a blacksmith's forge building with a chimney and anvil; a bakery with a
> brick oven chimney. Row 3: a town notice sign; a small market stall.

## 9. Memory and dungeon props

> A strict grid of **4 rows x 5 columns**. Row 1: a glowing memory shard (a floating crystal splinter), an anvil, a
> crooked first sword lying on the ground, a hammer, blacksmith tongs. Row 2: a bellows, a torn book page floating, an
> old wooden chair, a long kitchen table set for six, a guest made of shadow sitting on a chair. Row 3: a big word
> "BREAD" carved as a 3D wooden block, the same block underlined, the same block bold and heavy, the same block
> slanted italic, a lump of rising bread dough. Row 4: a black redaction bar floating, a pair of giant scissors stuck
> in the floor, a paper cut-out patch, a swirling portal rift torn in the air, a small bookcase.

## 10. Floor tiles (top-down diamonds)

> Floor tiles for an isometric game, each one a **flat 2:1 diamond seen from above with no sides and no thickness**,
> exactly 128 pixels wide and 64 pixels tall each, a strict grid of **6 rows x 6 columns**, 40 px of plain background
> between tiles. Rows: 1 meadow grass (6 slightly different variations), 2 pale cobblestone town street, 3 cold blue
> slate (a frozen memory), 4 printed book page with faint lines of text, 5 warm wooden kitchen planks, 6 mossy dark
> green mat. Each row's six tiles must join seamlessly when placed edge to edge.
