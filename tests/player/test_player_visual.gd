extends GutTest
## Behavior coverage for the AnimatedSprite2D player presentation (issue #133):
## logical states map onto the manifest clips, side facings mirror via flip_h,
## one-shot actions gate idle/move updates, and hurt/death ride the existing
## health lifecycle without new gameplay calls.

const PLAYER_FRAMES: SpriteFrames = preload("res://assets/sprites/player/player_frames.tres")
const HEALTH_SCENE: PackedScene = preload("res://scenes/combat/health_component.tscn")

var _visual: PlayerVisual


func before_each() -> void:
	_visual = PlayerVisual.new()
	_visual.sprite_frames = PLAYER_FRAMES
	add_child_autofree(_visual)


func test_defaults_to_the_south_idle_clip() -> void:
	assert_eq(_visual.animation_name, PlayerVisual.IDLE_ANIMATION)
	assert_eq(_visual.facing_label, &"south")
	assert_eq(_visual.animation, &"idle_down")
	assert_false(_visual.flip_h)


func test_movement_selects_directional_walk_clips() -> void:
	_visual.set_facing_direction(Vector2.UP)
	_visual.play_move()

	assert_eq(_visual.animation_name, PlayerVisual.MOVE_ANIMATION)
	assert_eq(_visual.facing_label, &"north")
	assert_eq(_visual.animation, &"walk_up")


func test_west_facing_mirrors_the_right_authored_side_clip() -> void:
	_visual.set_facing_direction(Vector2.LEFT)
	_visual.play_move()

	assert_eq(_visual.facing_label, &"west")
	assert_eq(_visual.animation, &"walk_side")
	assert_true(_visual.flip_h)

	_visual.set_facing_direction(Vector2.RIGHT)
	assert_eq(_visual.facing_label, &"east")
	assert_eq(_visual.animation, &"walk_side")
	assert_false(_visual.flip_h)

	_visual.set_facing_direction(Vector2.DOWN)
	assert_false(_visual.flip_h, "Non-side clips reset a stale left-facing flip.")


func test_melee_attack_plays_the_directional_contact_clip() -> void:
	_visual.play_melee(Vector2.RIGHT)

	assert_eq(_visual.animation_name, PlayerVisual.MELEE_ANIMATION)
	assert_eq(_visual.facing_label, &"east")
	assert_eq(_visual.animation, &"attack_melee_side")
	assert_false(_visual.flip_h)


func test_relic_cast_plays_the_directional_relic_clip() -> void:
	_visual.play_relic(Vector2.DOWN)

	assert_eq(_visual.animation_name, PlayerVisual.RELIC_ANIMATION)
	assert_eq(_visual.animation, &"attack_relic_down")


func test_one_shot_actions_gate_idle_and_move_until_the_clip_finishes() -> void:
	_visual.play_melee(Vector2.DOWN)
	_visual.play_move()
	assert_eq(_visual.animation_name, PlayerVisual.MELEE_ANIMATION)

	_visual._on_clip_finished()
	assert_eq(_visual.animation_name, PlayerVisual.IDLE_ANIMATION)
	_visual.play_move()
	assert_eq(_visual.animation_name, PlayerVisual.MOVE_ANIMATION)


func test_dash_does_not_gate_the_next_movement_update() -> void:
	_visual.play_dash(Vector2.RIGHT)
	assert_eq(_visual.animation_name, PlayerVisual.DASH_ANIMATION)
	assert_eq(_visual.animation, &"dash_side")

	_visual.play_move()
	assert_eq(_visual.animation_name, PlayerVisual.MOVE_ANIMATION)


func test_facing_changes_mid_clip_retarget_the_directional_variant() -> void:
	_visual.play_melee(Vector2.RIGHT)
	_visual.set_facing_direction(Vector2.UP)

	assert_eq(_visual.animation_name, PlayerVisual.MELEE_ANIMATION)
	assert_eq(_visual.animation, &"attack_melee_up")


func test_animation_state_changed_emits_logical_states_once_per_change() -> void:
	watch_signals(_visual)

	_visual.play_move()
	_visual.play_move()

	assert_signal_emit_count(_visual, "animation_state_changed", 1)
	assert_signal_emitted_with_parameters(
		_visual, "animation_state_changed", [PlayerVisual.MOVE_ANIMATION]
	)


func test_hurt_and_death_follow_the_health_lifecycle() -> void:
	var actor: Node2D = Node2D.new()
	var health: HealthComponent = HEALTH_SCENE.instantiate() as HealthComponent
	health.name = "HealthComponent"
	# The lethal follow-up hit must not be swallowed by the post-hit i-frames.
	health.invulnerability_duration = 0.0
	actor.add_child(health)
	var visual: PlayerVisual = PlayerVisual.new()
	visual.sprite_frames = PLAYER_FRAMES
	visual.health_path = NodePath("../HealthComponent")
	actor.add_child(visual)
	add_child_autofree(actor)

	health.take_damage(1)
	assert_eq(visual.animation_name, PlayerVisual.HURT_ANIMATION)
	assert_eq(visual.animation, &"hurt")

	visual._on_clip_finished()
	assert_eq(visual.animation_name, PlayerVisual.IDLE_ANIMATION)

	health.take_damage(health.current_health)
	assert_eq(visual.animation_name, PlayerVisual.DEATH_ANIMATION)
	assert_eq(visual.animation, &"death")

	visual.play_move()
	assert_eq(
		visual.animation_name, PlayerVisual.DEATH_ANIMATION,
		"Death presentation holds until the health lifecycle revives the actor."
	)

	health.restore_full_health()
	assert_eq(visual.animation_name, PlayerVisual.IDLE_ANIMATION)
