# Arrow Escape — Android 2D Puzzle (Godot 4)

An original, playable starter project inspired by the arrow-escape puzzle genre and the user-provided reference screenshots/video. It does not include copied assets, branding, or source code from another game.

## Included
- Portrait 720×1280 2D interface
- Tap arrows to attempt escape
- Forward-path obstruction checks against remaining arrow paths
- Three lives; blocked tap consumes one life
- Hint highlights an arrow that can currently escape
- Undo, restart, win/loss overlays
- Progress saved locally in `user://progress.cfg`
- Four authored layouts, with deterministic variations for later level numbers

## Open and run
1. Install Godot 4.x on a computer or supported Android workflow.
2. Import this folder by selecting `project.godot`.
3. Press Play (F6/F5; main scene is already configured).
4. For Android export, install export templates and configure an Android export preset in Godot.

## Controls
- Tap/click an arrow line on the board.
- UNDO restores the previous board state.
- HINT highlights a currently free arrow (two hints per level).
- RESTART resets the current board.
- Tap CONTINUE after winning to load the next level.

## Important scope / testing
This is a complete playable prototype foundation, not a finished commercial release. The arrow-path collision and touch logic are implemented, but the authored layouts should be play-tested and tuned in Godot on a real phone. It does not yet include ads, in-app purchases, cloud saves, daily challenges, localization, analytics, or a large professionally balanced level catalogue. Do not publish before testing the exported APK, reviewing privacy/data disclosures, and adding your own original store assets.

## Project files
- `project.godot` — project settings
- `scenes/main.tscn` — main scene
- `scripts/main.gd` — gameplay, drawing, input, UI, and save logic
