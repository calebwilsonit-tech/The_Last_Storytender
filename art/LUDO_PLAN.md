# Making the game's art with Ludo.ai (for the next session)

The owner is connecting Ludo.ai to Claude as a claude.ai connector (MCP server `https://mcp.ludo.ai/mcp`, Pro plan).
A session that has the Ludo tools should make the art in `art/ART_GUIDE.pdf` and put it in the game.

## Order
1. The Storytender (directional sprites: idle, walk, strike in 8 directions; or 5 directions and mirror E/SE/NE).
2. Floor textures (flat, seamless, seen from above; `tools/art/sheet_tiles.py` turns them into 64x32 diamonds).
3. Objects with two states (chest, lantern post, forge, oven, plates, gates, signs).
4. The Errors and their friendly looks; then the item icons (69, `tilewright/assets/items.json`); then bosses and villagers.

## Rules
- Style reference: the pictures in `art/training/` (the owner's Gemini sheets). Every result must look like it belongs beside them:
  dark-brown ink outline, flat cel shading, muted warm colours, isometric three-quarter view from above, light from the top left.
- One subject per picture, transparent background, the sizes and file names in `art/ART_GUIDE.pdf`.
- Save results to `art/incoming2/<characters|errors|bosses|objects|tiles|items>/`, then wire them in through the porter
  (`tools/port/run_porter.sh`, picks in `art/picks.json`, cutting tools in `tools/art/`) and run every test in `tools/port/*_test.mjs`.
- Check each asset in the game (screenshots) before moving on; redo what does not match. Keep the credits in mind: try a
  couple of each kind first, show the owner, then do the rest.

## State of the port (when this was written)
Overworld, HUD, menus, Errors and combat, Garrick's, Pip's and Maud's memories are ported and tested.
Still to port: the Weighing Room, the Proof Room, the Cutting Room (Scissor-Man), the intro and the full story run.
