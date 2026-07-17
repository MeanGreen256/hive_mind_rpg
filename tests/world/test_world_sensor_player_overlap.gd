extends GutTest
## Regression coverage for issue #136: every player-proximity world sensor
## (checkpoint shrine, skill-point pickup, hidden-room reveal, encounter
## trigger, flavor NPC) must react to the real PlayerController body
## physically overlapping it through the physics server. Issue #128 moved
## actor bodies onto PLAYER_BODY, which silently blinded any Area2D still
## scanning the inherited default WORLD mask while signal-level tests stayed
## green (issue #135 fixed the hub gate the same way). These tests never emit
## body_entered by hand. Save hygiene mirrors test_skill_point_pickup:
## checkpoints and pickups persist on touch, so SaveManager is redirected at
## a scratch file and progression resets around every test.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const CHECKPOINT_SCENE: PackedScene = preload("res://scenes/world/checkpoint.tscn")
const PICKUP_SCENE: PackedScene = preload("res://scenes/world/skill_point_pickup.tscn")
const NPC_SCENE: PackedScene = preload("res://scenes/world/flavor_npc.tscn")
const ROOM_SCENE: PackedScene = preload("res://scenes/world/encounter_room.tscn")
const CHASER_SCENE: PackedScene = preload("res://scenes/enemies/melee_chaser.tscn")
const REVEAL_SCRIPT: GDScript = preload("res://scripts/world/hidden_room_reveal.gd")
const BARK_SET_SCRIPT: GDScript = preload("res://scripts/resources/npc_bark_set.gd")

const TEST_SAVE_PATH: String = "user://test_world_sensor_overlap_savegame.json"
const SECRET_ID: StringName = &"test_sensor_overlap_secret"
## Far enough that no sensor shape in these tests can reach the player.
const FAR_AWAY: Vector2 = Vector2(500.0, 500.0)


func before_each() -> void:
	GameState.reset_progress()
	SaveManager.save_path = TEST_SAVE_PATH
	_forget_run_state()
	_delete_test_save()


func after_each() -> void:
	_delete_test_save()
	_forget_run_state()
	SaveManager.save_path = SaveManager.DEFAULT_SAVE_PATH
	GameState.reset_progress()


func test_every_world_sensor_scans_only_the_player_body_layer() -> void:
	var pickup: SkillPointPickup = PICKUP_SCENE.instantiate() as SkillPointPickup
	pickup.secret_id = SECRET_ID
	var npc: FlavorNpc = NPC_SCENE.instantiate() as FlavorNpc
	npc.bark_set = _make_bark_set()
	var sensors: Array[Area2D] = [
		CHECKPOINT_SCENE.instantiate() as Area2D,
		pickup,
		_build_reveal(),
		ROOM_SCENE.instantiate() as Area2D,
		npc,
	]
	for sensor: Area2D in sensors:
		add_child_autofree(sensor)
		assert_eq(
			sensor.collision_mask, CollisionLayers.PLAYER_BODY,
			"Actor bodies left the default layer (issue #128); %s must scan "
			% sensor.get_script().resource_path
			+ "PLAYER_BODY or real overlap never fires (issue #136)."
		)
		assert_eq(
			sensor.collision_layer, 0,
			"A pure sensor occupies no physics layer: %s"
			% sensor.get_script().resource_path
		)


func test_player_touch_lights_the_checkpoint_heals_and_saves() -> void:
	var checkpoint: Checkpoint = CHECKPOINT_SCENE.instantiate() as Checkpoint
	add_child_autofree(checkpoint)
	watch_signals(checkpoint)
	var player: PlayerController = _spawn_player()
	# RespawnController owns the heal + save reaction to checkpoint_reached, so
	# the touch is verified through the same composition the zones use.
	var controller: RespawnController = RespawnController.new()
	controller.player_path = player.get_path()
	controller.health_component_path = player.health.get_path()
	add_child_autofree(controller)
	player.health.take_damage(1)
	await wait_physics_frames(2)
	assert_false(checkpoint.is_lit(), "Out of range: the shrine stays dormant.")

	player.global_position = checkpoint.global_position
	await wait_physics_frames(2)

	assert_true(checkpoint.is_lit(), "Real overlap lights the shrine.")
	assert_signal_emit_count(checkpoint, "checkpoint_reached", 1)
	assert_eq(
		controller.get_respawn_position(), checkpoint.get_respawn_position(),
		"The touched shrine becomes the respawn point."
	)
	assert_eq(
		player.health.current_health, player.health.max_health,
		"Reaching the shrine heals the player."
	)
	assert_true(SaveManager.has_save(), "Reaching the shrine persists the run.")
	assert_eq(SaveManager.checkpoint_position, checkpoint.get_respawn_position())


func test_player_touch_collects_the_pickup_awards_points_and_persists() -> void:
	var pickup: SkillPointPickup = PICKUP_SCENE.instantiate() as SkillPointPickup
	pickup.secret_id = SECRET_ID
	pickup.points = 2
	add_child_autofree(pickup)
	# The collected pickup frees itself before control returns to the test, so
	# the emission is captured into locals instead of GUT's signal watcher.
	var collected_payloads: Array[Array] = []
	pickup.collected.connect(
		func(secret_id: StringName, points: int) -> void:
			collected_payloads.append([secret_id, points])
	)
	var player: PlayerController = _spawn_player()
	await wait_physics_frames(2)
	assert_false(pickup.is_collected(), "Out of range: nothing is awarded yet.")

	player.global_position = pickup.global_position
	await wait_physics_frames(2)

	assert_eq(GameState.get_skill_points(), 2, "Real overlap awards the points.")
	assert_true(SaveManager.is_secret_collected(SECRET_ID))
	assert_true(SaveManager.has_save(), "Collection saves immediately.")
	assert_eq(collected_payloads, [[SECRET_ID, 2]] as Array[Array])
	assert_false(is_instance_valid(pickup), "The collected pickup frees itself.")


func test_player_entry_reveals_the_hidden_room() -> void:
	var reveal: HiddenRoomReveal = _build_reveal()
	add_child_autofree(reveal)
	watch_signals(reveal)
	var cover: CanvasItem = reveal.get_node("Cover") as CanvasItem
	var player: PlayerController = _spawn_player()
	await wait_physics_frames(2)
	assert_false(reveal.is_revealed(), "Out of range: the room stays covered.")
	assert_true(cover.visible)

	player.global_position = reveal.global_position
	await wait_physics_frames(2)

	assert_true(reveal.is_revealed(), "Real overlap reveals the room.")
	assert_false(cover.visible, "The cover hides on reveal.")
	assert_signal_emit_count(reveal, "room_revealed", 1)


func test_player_body_physically_entering_activates_the_encounter() -> void:
	var room: EncounterRoom = ROOM_SCENE.instantiate() as EncounterRoom
	var chaser: EnemyBase = CHASER_SCENE.instantiate() as EnemyBase
	room.get_node("Enemies").add_child(chaser)
	add_child_autofree(room)
	watch_signals(room)
	var player: PlayerController = _spawn_player()
	await wait_physics_frames(2)
	assert_eq(room.state, EncounterRoom.State.DORMANT, "Out of range: dormant.")

	player.global_position = room.global_position
	await wait_physics_frames(2)

	assert_true(room.is_active(), "Real overlap starts the encounter.")
	assert_eq(chaser.target, player, "The live enemy targets the real player.")
	assert_signal_emit_count(room, "encounter_started", 1)


func test_player_proximity_drives_the_npc_prompt_and_real_interact_barks() -> void:
	var npc: FlavorNpc = NPC_SCENE.instantiate() as FlavorNpc
	npc.bark_set = _make_bark_set()
	add_child_autofree(npc)
	watch_signals(npc)
	var prompt: Label = npc.get_node("%PromptLabel") as Label
	var player: PlayerController = _spawn_player()
	await wait_physics_frames(2)
	assert_false(npc.is_player_nearby(), "Out of range: no proximity yet.")
	assert_false(prompt.visible)

	player.global_position = npc.global_position + Vector2(16.0, 0.0)
	await wait_physics_frames(2)

	assert_true(npc.is_player_nearby(), "Real overlap registers proximity.")
	assert_true(prompt.visible, "The nearby player sees the talk prompt.")

	# The real keyboard binding, not a direct interact() call, must bark for
	# the physically-nearby player.
	var input_sender: GutInputSender = GutInputSender.new(Input)
	await _press_and_release_key(input_sender, KEY_E)
	input_sender.clear()

	assert_true(npc.is_barking(), "Pressing E while overlapping barks.")
	assert_eq(npc.get_current_bark(), "First line.")
	assert_signal_emit_count(npc, "barked", 1)

	player.global_position = FAR_AWAY
	await wait_physics_frames(2)

	assert_false(npc.is_player_nearby(), "Leaving the overlap drops proximity.")
	assert_false(prompt.visible)


func test_enemy_body_physically_overlapping_triggers_nothing() -> void:
	var checkpoint: Checkpoint = CHECKPOINT_SCENE.instantiate() as Checkpoint
	add_child_autofree(checkpoint)
	var pickup: SkillPointPickup = PICKUP_SCENE.instantiate() as SkillPointPickup
	pickup.secret_id = SECRET_ID
	add_child_autofree(pickup)
	watch_signals(checkpoint)
	watch_signals(pickup)
	# A real enemy body on ENEMY_BODY: outside the sensors' scanned mask, so
	# physics itself must reject it — not just the player-group check.
	var chaser: EnemyBase = CHASER_SCENE.instantiate() as EnemyBase
	add_child_autofree(chaser)
	chaser.global_position = checkpoint.global_position

	await wait_physics_frames(3)

	assert_false(checkpoint.is_lit(), "ENEMY_BODY overlap must not light the shrine.")
	assert_signal_emit_count(checkpoint, "checkpoint_reached", 0)
	assert_false(pickup.is_collected(), "ENEMY_BODY overlap must not collect.")
	assert_eq(GameState.get_skill_points(), 0)
	assert_signal_emit_count(pickup, "collected", 0)


## The real player scene, far from every sensor. The "player" group is
## assigned at the placement site (hub/zone scenes), so the test does too.
func _spawn_player() -> PlayerController:
	var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
	player.add_to_group(&"player")
	# Positioned before entering the tree: the physics server registers the
	# body at its spawn transform, so placing it afterwards would still clip
	# every origin-parked sensor for one frame.
	player.position = FAR_AWAY
	add_child_autofree(player)
	return player


## HiddenRoomReveal ships without a scene: levels author the trigger shape and
## cover in place, so the test composes the same subtree.
func _build_reveal() -> HiddenRoomReveal:
	var reveal: HiddenRoomReveal = REVEAL_SCRIPT.new()
	var cover: Polygon2D = Polygon2D.new()
	cover.name = "Cover"
	reveal.add_child(cover)
	var collision: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(48.0, 48.0)
	collision.shape = shape
	reveal.add_child(collision)
	return reveal


func _make_bark_set() -> NpcBarkSet:
	var bark_set: NpcBarkSet = BARK_SET_SCRIPT.new()
	bark_set.npc_name = "Test NPC"
	var barks: Array[String] = ["First line.", "Second line."]
	bark_set.barks = barks
	return bark_set


func _press_and_release_key(input_sender: GutInputSender, keycode: Key) -> void:
	var press: InputEventKey = InputEventKey.new()
	press.physical_keycode = keycode
	press.pressed = true
	input_sender.send_event(press)
	Input.flush_buffered_events()
	await wait_process_frames(2)
	var release: InputEventKey = press.duplicate() as InputEventKey
	release.pressed = false
	input_sender.send_event(release)
	Input.flush_buffered_events()
	await wait_process_frames(1)


func _delete_test_save() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


func _forget_run_state() -> void:
	SaveManager.checkpoint_scene_path = ""
	SaveManager.checkpoint_position = Vector2.ZERO
	SaveManager.collected_secret_ids.clear()
	SaveManager.completed_milestone_ids.clear()
