# Manual gameplay directors

These scenes drive the game through authored input actions and public gameplay APIs. They are intended for repeatable Movie Maker evidence, not unit-test coverage.

## Combat feedback capture

`combat_feedback_gameplay_director.tscn` runs a goal-driven combat sequence: approach and dash, melee, reposition, relic attack, allow an enemy hit, show invulnerability feedback, and finish the enemy. The overlay identifies each phase and reports live health and distance.

Set `HIVE_MIND_CAPTURE_DIR` to choose where the four evidence screenshots are written. If it is unset, captures go to `user://combat_feedback_gameplay`.

From PowerShell:

```powershell
$env:HIVE_MIND_CAPTURE_DIR = "C:\path\to\capture"
godot --path . --fixed-fps 60 --write-movie "$env:HIVE_MIND_CAPTURE_DIR\combat_feedback.avi" --quit-after 1200 res://tests/manual/combat_feedback_gameplay_director.tscn
```

The director quits after the victory hold or after its safety frame limit. Run it with a normal renderer because screenshot capture waits for `RenderingServer.frame_post_draw`.

## Zone 1 normal gameplay capture

`zone1_gameplay_director.tscn` runs a player-like showcase through the real Zone 1 graybox. It lights the entrance checkpoint, follows authored corridor geometry, detours into the southern secret, mixes relic and melee attacks, reacts to enemy wind-ups with evasive dashes, and ends after two encounters. A stuck detector adds a short corrective nudge if navigation stops making progress.

The director uses the same `HIVE_MIND_CAPTURE_DIR` variable and defaults to `user://zone1_gameplay`. From PowerShell:

```powershell
$env:HIVE_MIND_CAPTURE_DIR = "C:\path\to\capture"
godot --disable-vsync --path . --fixed-fps 30 --write-movie "$env:HIVE_MIND_CAPTURE_DIR\zone1_gameplay.avi" --quit-after 2100 res://tests/manual/zone1_gameplay_director.tscn
```

The overlay shows the current route or combat intent plus live health, energy, enemy distance, and defeat count. The director writes representative dodge, mixed-combat, and secret-route screenshots alongside the movie.
