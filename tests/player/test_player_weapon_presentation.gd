extends GutTest
## Structural, state-mirroring, and provenance coverage for the presentation-only
## HD steel weapon layer (issue #168). PlayerVisual stays the logical facing/action
## driver; the weapon is an authored blade anchored on the hand and rotated to face
## and sweep truthfully for all four directions. Gameplay (melee hitbox, damage,
## timing, input, collision) is untouched.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const WEAPON_PATH: String = "res://assets/sprites/player/hd/player_weapon.png"
const WEAPON_TEXTURE: Texture2D = preload("res://assets/sprites/player/hd/player_weapon.png")
const PNG_SIGNATURE: PackedByteArray = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
## Melee hitbox is a 24×24 rect centered at offset 14 → far edge 26 px from player.
const MELEE_HITBOX_FAR_EDGE_PX: float = 26.0

var _player: PlayerController
var _legacy_visual: PlayerVisual
var _weapon: PlayerWeaponPresentation


func before_each() -> void:
	_player = PLAYER_SCENE.instantiate() as PlayerController
	add_child_autofree(_player)
	_legacy_visual = _player.get_node("Body") as PlayerVisual
	_weapon = _player.get_node("WeaponPresentation") as PlayerWeaponPresentation


func test_weapon_is_presentation_only_and_hd_filtered() -> void:
	assert_not_null(_weapon)
	var blade: Sprite2D = _weapon.get_blade_sprite()
	assert_not_null(blade)
	assert_eq(blade.texture, WEAPON_TEXTURE)
	assert_eq(blade.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
	assert_false(blade.centered, "Blade pivots on the authored grip, not the cell center.")
	assert_eq(blade.offset, -PlayerWeaponPresentation.GRIP_PIVOT)
	assert_almost_eq(
		_weapon.base_scale() * PlayerWeaponPresentation.ART_PIVOT_TO_TIP_PX,
		PlayerWeaponPresentation.DISPLAY_LENGTH_PX,
		0.001,
	)


func test_blade_reach_does_not_overstate_the_melee_hitbox() -> void:
	# Full forward extension = hand offset + on-screen blade length.
	var tip_reach: float = (
		PlayerWeaponPresentation.FORWARD_HAND_PX + PlayerWeaponPresentation.DISPLAY_LENGTH_PX
	)
	assert_lte(
		tip_reach, MELEE_HITBOX_FAR_EDGE_PX,
		"Blade tip must stay inside the melee hitbox envelope so it never lies about reach.",
	)


func test_blade_faces_all_four_directions_truthfully() -> void:
	var blade: Sprite2D = _weapon.get_blade_sprite()
	# MOVE is the sway-free held pose, so rotation is exactly forward + rest.
	var expectations: Array[Array] = [
		[Vector2.UP, Vector2.UP.angle(), -1],
		[Vector2.RIGHT, Vector2.RIGHT.angle(), 1],
		[Vector2.DOWN, Vector2.DOWN.angle(), 1],
		[Vector2.LEFT, Vector2.LEFT.angle(), 1],
	]
	for expectation: Array in expectations:
		var facing: Vector2 = expectation[0] as Vector2
		_legacy_visual.set_facing_direction(facing)
		_legacy_visual.play_move()
		_weapon._process(0.0)
		assert_almost_eq(
			blade.rotation,
			(expectation[1] as float) + PlayerWeaponPresentation.REST_ROTATION_REL,
			0.001,
			"Held blade must point along facing %s." % facing,
		)
		assert_eq(
			blade.position, facing * PlayerWeaponPresentation.FORWARD_HAND_PX + Vector2(0.0, 3.0),
			"Hand anchor follows the facing direction.",
		)
		assert_eq(
			blade.z_index, expectation[2] as int,
			"Facing %s must layer the blade %s the body." % [facing, expectation[2]],
		)


func test_idle_move_and_melee_silhouettes_are_distinct_per_direction() -> void:
	var blade: Sprite2D = _weapon.get_blade_sprite()
	for facing: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		_legacy_visual.set_facing_direction(facing)
		_legacy_visual.play_move()
		_weapon._process(0.0)
		var rest_rotation: float = blade.rotation
		_legacy_visual.play_melee(facing)
		# Advance to the middle of the presentation swing.
		_weapon._process(PlayerWeaponPresentation.SWING_DURATION * 0.5)
		assert_gt(
			absf(blade.rotation - rest_rotation), deg_to_rad(20.0),
			"Melee silhouette for facing %s must read differently from the held guard." % facing,
		)
		_legacy_visual._on_clip_finished()


func test_melee_sweep_progresses_and_flashes_the_edge() -> void:
	_legacy_visual.set_facing_direction(Vector2.RIGHT)
	var blade: Sprite2D = _weapon.get_blade_sprite()
	_legacy_visual.play_melee(Vector2.RIGHT)

	# Near the wind-up the blade is raised back; by follow-through it has chopped
	# forward, so the relative rotation increases monotonically across the swing.
	_weapon._process(0.0)
	var windup_rotation: float = blade.rotation
	_weapon._process(PlayerWeaponPresentation.SWING_DURATION * 0.5)
	var mid_modulate: Color = blade.self_modulate
	_weapon._process(PlayerWeaponPresentation.SWING_DURATION)
	var follow_rotation: float = blade.rotation

	assert_lt(windup_rotation, follow_rotation, "Blade must sweep from wind-up to follow-through.")
	assert_gt(
		mid_modulate.b, 0.9,
		"Mid-swing edge flash brightens the steel for cleaner contact readability.",
	)


func test_weapon_hides_on_death_and_returns_on_respawn() -> void:
	var blade: Sprite2D = _weapon.get_blade_sprite()
	_legacy_visual._on_health_died()
	_weapon._process(0.0)
	assert_false(blade.visible, "A dropped weapon reads as defeated.")

	_legacy_visual._on_health_changed(5, 5)
	_weapon._process(0.0)
	assert_true(blade.visible, "Respawn through the health lifecycle restores the weapon.")


func test_weapon_presentation_does_not_change_player_collision() -> void:
	var collision: CollisionShape2D = _player.get_node("CollisionShape2D") as CollisionShape2D
	var capsule: CapsuleShape2D = collision.shape as CapsuleShape2D
	_legacy_visual.play_melee(Vector2.RIGHT)
	_weapon._process(PlayerWeaponPresentation.SWING_DURATION * 0.5)
	assert_eq(capsule.radius, 7.0)
	assert_eq(capsule.height, 20.0)


func test_weapon_asset_is_a_documented_hd_sprite() -> void:
	var file: FileAccess = FileAccess.open(WEAPON_PATH, FileAccess.READ)
	assert_not_null(file, "Missing HD weapon sprite: %s" % WEAPON_PATH)
	if file == null:
		return
	assert_eq(file.get_buffer(PNG_SIGNATURE.size()), PNG_SIGNATURE)
	assert_eq(Vector2i(WEAPON_TEXTURE.get_width(), WEAPON_TEXTURE.get_height()), Vector2i(256, 128))
	var import_text: String = FileAccess.get_file_as_string(WEAPON_PATH + ".import")
	assert_string_contains(import_text, "compress/mode=0")
	assert_string_contains(import_text, "mipmaps/generate=false")
	assert_string_contains(import_text, "process/premult_alpha=false")
	assert_string_contains(import_text, "process/fix_alpha_border=true")
