# Sprite Asset Licenses

Per `AGENTS.md` §11, every binary sprite asset's source and license is logged
here. Test-only art remains documented separately in `assets/sprites/testing/README.md`.

| Asset | Source / author | License | Notes |
|---|---|---|---|
| `player/player.png` | Hand-authored for hive_mind_rpg by the project team; deterministic source in `assets/sprites/generate_player_art.py`. | CC0-1.0 | 32×32 teal wanderer sheet (idle/walk/dash/attacks × 3 facings, hurt, death) replacing the retired generated wanderer frames. No third-party pixels or generated-image model output. |
| `player/player_frames.tres` | Hand-authored for hive_mind_rpg by the project team; generated deterministically by `assets/sprites/generate_player_art.py`. | CC0-1.0 | Godot `SpriteFrames` regions for the authored player sheet. |
| `enemies/melee_chaser.png` | Hand-authored for hive_mind_rpg by the project team; deterministic source in `assets/sprites/generate_authored_pixel_art.py`. | CC0-1.0 | 32×32 violet relic-hound frames. No third-party pixels or generated-image model output. |
| `enemies/melee_chaser_frames.tres` | Hand-authored for hive_mind_rpg by the project team; generated deterministically by `assets/sprites/generate_authored_pixel_art.py`. | CC0-1.0 | Godot `SpriteFrames` regions for the authored sheet. |
| `world/zone1_forest_tiles.png` | Hand-authored for hive_mind_rpg by the project team; deterministic source in `assets/sprites/generate_authored_pixel_art.py`. | CC0-1.0 | 16×16 corrupted-forest atlas using the canonical visual-bible palette. No third-party pixels or generated-image model output. |
| `enemies/{ranged_harasser,shielded_brute,fast_flanker}.png` | Hand-authored for hive_mind_rpg by the project team; deterministic source in `assets/sprites/generate_enemy_roster_art.py`. | CC0-1.0 | 32×32 original regular-enemy sheets for the Zone 1 roster. No third-party pixels or generated-image model output. |
| `enemies/{ranged_harasser,shielded_brute,fast_flanker}_frames.tres` | Hand-authored for hive_mind_rpg by the project team; generated deterministically by `assets/sprites/generate_enemy_roster_art.py`. | CC0-1.0 | Godot `SpriteFrames` regions for the corresponding authored sheets. |
| `world/zone1_props.png` | Hand-authored for hive_mind_rpg by the project team; deterministic source in `assets/sprites/generate_zone1_props.py`. | CC0-1.0 | 16-bit corrupted-forest trees, root ruins, relic machinery, stumps, and stones. No third-party pixels or generated-image model output. |
| `fx/{combat_fx,energy_bolt}.png` | Hand-authored for hive_mind_rpg by the project team; deterministic source in `assets/sprites/generate_combat_fx.py`. | CC0-1.0 | Production melee, impact, dash, dissolve, and relic-bolt feedback frames. No third-party pixels or generated-image model output. |
