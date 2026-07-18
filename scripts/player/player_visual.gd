class_name PlayerVisual
extends AnimatedSprite2D

## Presents the authored 32px wanderer sheet. Gameplay code drives the same
## logical states as before (idle/move/dash/melee/relic); this node only maps
## them onto the manifest SpriteFrames clips and never rotates or rescales.
## Logical-state change (idle/move/dash/melee/relic/hurt/death); the native
## animation_changed signal still reports raw clip changes.
signal animation_state_changed(animation_name: StringName)

enum Direction { SOUTH, NORTH, EAST, WEST }

const IDLE_ANIMATION: StringName = &"idle"
const MOVE_ANIMATION: StringName = &"move"
const DASH_ANIMATION: StringName = &"dash"
const MELEE_ANIMATION: StringName = &"melee"
const RELIC_ANIMATION: StringName = &"relic"
const HURT_ANIMATION: StringName = &"hurt"
const DEATH_ANIMATION: StringName = &"death"

## Logical state → manifest clip prefix (visual bible §8); hurt/death clips are
## authored without facing variants.
const DIRECTIONAL_CLIP_PREFIXES: Dictionary[StringName, String] = {
	IDLE_ANIMATION: "idle",
	MOVE_ANIMATION: "walk",
	DASH_ANIMATION: "dash",
	MELEE_ANIMATION: "attack_melee",
	RELIC_ANIMATION: "attack_relic",
}

## Optional HealthComponent hookup: hurt/death presentation listens to the
## existing damage lifecycle (same pattern as CombatFeedback) instead of adding
## new gameplay calls.
@export var health_path: NodePath

var animation_name: StringName:
	get:
		return _animation_name

var facing_label: StringName:
	get:
		match _direction:
			Direction.NORTH:
				return &"north"
			Direction.EAST:
				return &"east"
			Direction.WEST:
				return &"west"
			_:
				return &"south"

var _animation_name: StringName = IDLE_ANIMATION
var _direction: Direction = Direction.SOUTH
# One-shot melee/relic/hurt clips block idle/move updates until they finish.
var _action_locked: bool = false
var _dead: bool = false
var _health: HealthComponent


func _ready() -> void:
	animation_finished.connect(_on_clip_finished)
	if not health_path.is_empty():
		_health = get_node_or_null(health_path) as HealthComponent
	if _health != null:
		_health.damaged.connect(_on_health_damaged)
		_health.died.connect(_on_health_died)
		_health.health_changed.connect(_on_health_changed)
	_play_clip()


func play_idle() -> void:
	if _dead or _action_locked:
		return
	_set_animation(IDLE_ANIMATION)


func play_move() -> void:
	if _dead or _action_locked:
		return
	_set_animation(MOVE_ANIMATION)


func play_dash(direction: Vector2) -> void:
	if _dead:
		return
	set_facing_direction(direction)
	_action_locked = false
	_set_animation(DASH_ANIMATION, true)


func play_melee(direction: Vector2) -> void:
	if _dead:
		return
	set_facing_direction(direction)
	_action_locked = true
	_set_animation(MELEE_ANIMATION, true)


func play_relic(direction: Vector2) -> void:
	if _dead:
		return
	set_facing_direction(direction)
	_action_locked = true
	_set_animation(RELIC_ANIMATION, true)


func set_facing_direction(direction: Vector2) -> void:
	if direction.is_zero_approx():
		return
	var next_direction: Direction
	if absf(direction.x) > absf(direction.y):
		next_direction = Direction.EAST if direction.x > 0.0 else Direction.WEST
	elif direction.y < 0.0:
		next_direction = Direction.NORTH
	else:
		next_direction = Direction.SOUTH
	if next_direction == _direction:
		return
	_direction = next_direction
	# Keep clip progress so mid-clip facing changes don't reset walk cycles.
	_play_clip(frame, frame_progress)


func _set_animation(next_animation: StringName, restart: bool = false) -> void:
	var changed: bool = _animation_name != next_animation
	_animation_name = next_animation
	if changed or restart:
		_play_clip()
	if changed:
		animation_state_changed.emit(_animation_name)


func _play_clip(start_frame: int = 0, start_progress: float = 0.0) -> void:
	var clip: StringName = _resolve_clip()
	flip_h = _direction == Direction.WEST and clip.ends_with("_side")
	if sprite_frames == null or not sprite_frames.has_animation(clip):
		return
	play(clip)
	if start_frame > 0 or start_progress > 0.0:
		var last_frame: int = sprite_frames.get_frame_count(clip) - 1
		set_frame_and_progress(mini(start_frame, last_frame), start_progress)


func _resolve_clip() -> StringName:
	if not DIRECTIONAL_CLIP_PREFIXES.has(_animation_name):
		return _animation_name
	var prefix: String = DIRECTIONAL_CLIP_PREFIXES[_animation_name]
	match _direction:
		Direction.NORTH:
			return StringName(prefix + "_up")
		Direction.EAST, Direction.WEST:
			return StringName(prefix + "_side")
		_:
			return StringName(prefix + "_down")


func _on_clip_finished() -> void:
	# Non-looping clips fall back to idle; death holds its final frame instead.
	if _dead:
		return
	if _animation_name in [DASH_ANIMATION, MELEE_ANIMATION, RELIC_ANIMATION, HURT_ANIMATION]:
		_action_locked = false
		_set_animation(IDLE_ANIMATION)


func _on_health_damaged(_amount: int, _knockback: Vector2, _impact_type: int) -> void:
	if _dead:
		return
	_action_locked = true
	_set_animation(HURT_ANIMATION, true)


func _on_health_died() -> void:
	_dead = true
	_action_locked = false
	_set_animation(DEATH_ANIMATION, true)


func _on_health_changed(current_health: int, _maximum_health: int) -> void:
	# Respawn heals through the same health lifecycle; revive the presentation.
	if _dead and current_health > 0:
		_dead = false
		_action_locked = false
		_set_animation(IDLE_ANIMATION, true)
