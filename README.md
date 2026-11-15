# Rebound — "Reach The Glow"

Godot 4.7 project. Flow: `homepage` → START → `level_select` → `level1`…`level10`.

- Mirrors: hover + `Q`/`E` to rotate. `R` restarts the level. `Esc` returns to level select (menu: back to home).
- Lighting the bulb advances to the next level (after level 10 → level select).
- Each level has a 30 s countdown (top of screen). When it hits zero the level restarts. Change the limit per level via `time_limit` on the `Emitter` node.
- Scene flow and the timer HUD live in `game_flow.gd` (autoload).
