extends GutTest
## Structural regression coverage for the issue #133 player presentation. These
## checks pin the authored sheet dimensions, the manifest SpriteFrames contract,
## nearest filtering, and the scene integration without judging the art itself.

const SHEET_PATH: String = "res://assets/sprites/player/player.png"
const SHEET_TEXTURE: Texture2D = preload("res://assets/sprites/player/player.png")
const PLAYER_FRAMES: SpriteFrames = preload("res://assets/sprites/player/player_frames.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

const FRAME_SIZE: Vector2 = Vector2(32.0, 32.0)
## name → [frame count, loops, fps] from docs/asset_manifest_v1.md §2.1 and
## docs/visual_bible.md §8.
const ANIMATION_CONTRACT: Dictionary[StringName, Array] = {
	&"idle_down": [4, true, 6.0], &"idle_up": [4, true, 6.0], &"idle_side": [4, true, 6.0],
	&"walk_down": [6, true, 10.0], &"walk_up": [6, true, 10.0], &"walk_side": [6, true, 10.0],
	&"dash_down": [4, false, 12.0], &"dash_up": [4, false, 12.0], &"dash_side": [4, false, 12.0],
	&"attack_melee_down": [4, false, 12.0], &"attack_melee_up": [4, false, 12.0],
	&"attack_melee_side": [4, false, 12.0],
	&"attack_relic_down": [3, false, 12.0], &"attack_relic_up": [3, false, 12.0],
	&"attack_relic_side": [3, false, 12.0],
	&"hurt": [2, false, 12.0], &"death": [6, false, 10.0],
}

var _png_signature: PackedByteArray = PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10])


func test_player_sheet_is_a_real_png_with_manifest_dimensions() -> void:
	var file: FileAccess = FileAccess.open(SHEET_PATH, FileAccess.READ)
	assert_not_null(file, "Player sheet should exist: %s" % SHEET_PATH)
	if file == null:
		return
	assert_eq(file.get_buffer(_png_signature.size()), _png_signature, "%s must be a real PNG" % SHEET_PATH)
	file.close()
	assert_eq(SHEET_TEXTURE.get_size(), Vector2(192.0, 544.0), "6 columns x 17 authored rows of 32px frames")


func test_sprite_frames_match_the_manifest_animation_contract() -> void:
	assert_eq(PLAYER_FRAMES.get_animation_names().size(), ANIMATION_CONTRACT.size())
	for animation_name: StringName in ANIMATION_CONTRACT:
		var contract: Array = ANIMATION_CONTRACT[animation_name]
		assert_true(PLAYER_FRAMES.has_animation(animation_name), "%s animation must exist." % animation_name)
		if not PLAYER_FRAMES.has_animation(animation_name):
			continue
		assert_eq(PLAYER_FRAMES.get_frame_count(animation_name), int(contract[0]), "%s frame count" % animation_name)
		assert_eq(PLAYER_FRAMES.get_animation_loop(animation_name), bool(contract[1]), "%s loop flag" % animation_name)
		assert_eq(PLAYER_FRAMES.get_animation_speed(animation_name), float(contract[2]), "%s fps" % animation_name)


func test_every_frame_is_an_authored_32px_region_of_the_player_sheet() -> void:
	var sheet_image: Image = SHEET_TEXTURE.get_image()
	for animation_name: StringName in ANIMATION_CONTRACT:
		for frame_index: int in PLAYER_FRAMES.get_frame_count(animation_name):
			var frame_texture: AtlasTexture = (
				PLAYER_FRAMES.get_frame_texture(animation_name, frame_index) as AtlasTexture
			)
			assert_not_null(frame_texture, "%s frame %d should be an AtlasTexture" % [animation_name, frame_index])
			if frame_texture == null:
				continue
			assert_eq(frame_texture.atlas.resource_path, SHEET_PATH)
			assert_eq(frame_texture.region.size, FRAME_SIZE)
			_assert_region_has_pixels(sheet_image, frame_texture.region, animation_name, frame_index)


func test_player_scene_integrates_the_animated_visual_on_the_collision_center() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	add_child_autofree(player)

	var visual: PlayerVisual = player.get_node("Body") as PlayerVisual
	assert_not_null(visual)
	assert_eq(visual.sprite_frames, PLAYER_FRAMES)
	assert_eq(visual.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_true(visual.centered)
	assert_eq(visual.offset, Vector2.ZERO)
	assert_eq(visual.scale, Vector2.ONE, "Pixel sprites render at scale = 1 only (visual bible §5).")
	var collision: CollisionShape2D = player.get_node("CollisionShape2D") as CollisionShape2D
	assert_eq(visual.position, collision.position, "Frame center aligns with the collision-shape center.")
	assert_eq(visual.animation, &"idle_down")


func test_controller_calls_produce_directional_presentation_states() -> void:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	add_child_autofree(player)
	var visual: PlayerVisual = player.get_node("Body") as PlayerVisual

	visual.set_facing_direction(Vector2.LEFT)
	visual.play_move()
	assert_eq(visual.animation, &"walk_side")
	assert_true(visual.flip_h)

	visual.play_dash(Vector2.UP)
	assert_eq(visual.animation, &"dash_up")
	assert_false(visual.flip_h)

	visual.play_melee(Vector2.RIGHT)
	assert_eq(visual.animation, &"attack_melee_side")
	assert_false(visual.flip_h)

	visual._on_clip_finished()
	visual.play_relic(Vector2.DOWN)
	assert_eq(visual.animation, &"attack_relic_down")


func _assert_region_has_pixels(
	sheet_image: Image, region: Rect2, animation_name: StringName, frame_index: int
) -> void:
	var origin: Vector2i = Vector2i(region.position)
	for y: int in int(region.size.y):
		for x: int in int(region.size.x):
			if sheet_image.get_pixelv(origin + Vector2i(x, y)).a > 0.0:
				return
	fail_test("%s frame %d should contain authored pixels" % [animation_name, frame_index])
