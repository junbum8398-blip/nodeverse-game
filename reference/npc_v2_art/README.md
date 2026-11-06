# SD NPC v2

- 2D: npc_assets/sd_v2/NPC*.png — 10 original-resolution transparent PNGs, generated using the built-in image tool. Prompt set: prompts.json. lineup.png is a comparison preview, not a transparent game sprite.
- 3D: models/npc_sd_v2/NPC*.glb — 10 solid, rounded block models with material colors and individual profession props. These simplify the 2D reference details; they are not exact image-to-mesh reconstructions.
- Godot scenes: scenes/npc_sd_v2/NPC*.tscn. Model/Hips/Torso/Head and ArmL/ArmR, plus LegL/LegR are editable pivots. Existing idle animation script is attached. No skeleton, walk animation, dialogue or gameplay collision is included.
- Preview: open_sd_npcs.bat or scenes/NPCSDV2Viewer.tscn. Left/right select; drag rotates; mouse wheel zooms.
- Captures: renders/sd_v2, three views per NPC and lineup.
- Rebuild with Godot: --headless --path . --script res://scripts/tools/build_sd_v2.gd

Existing game scenes and original assets are preserved. The new models are supplied as separate scenes and are not placed into the game world.
