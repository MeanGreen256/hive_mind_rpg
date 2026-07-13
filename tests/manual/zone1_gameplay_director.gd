extends Node2D

enum AgentMode { EXPLORE, ENGAGE, EVADE, COMPLETE }

const CAPTURE_DIR_ENV: String = "HIVE_MIND_CAPTURE_DIR"
const DEFAULT_CAPTURE_DIR: String = "user://zone1_gameplay"
const MAX_CAPTURE_FRAMES: int = 2100
const SHOWCASE_DEFEATS: int = 2
const ENEMY_NOTICE_DISTANCE: float = 165.0
const MELEE_DISTANCE: float = 38.0
const RELIC_MIN_DISTANCE: float = 62.0
const WAYPOINT_REACHED_DISTANCE: float = 25.0
const STUCK_SAMPLE_INTERVAL: float = 0.75
const STUCK_DISTANCE: float = 8.0

const WAYPOINTS: Array[Vector2] = [
	Vector2(136, 200), Vector2(152, 248), Vector2(220, 248),
	Vector2(390, 248), Vector2(392, 336), Vector2(392, 382),
	Vector2(408, 248), Vector2(510, 248), Vector2(570, 248),
	Vector2(760, 248), Vector2(900, 248), Vector2(990, 248),
	Vector2(1048, 184), Vector2(1128, 144), Vector2(1128, 72),
	Vector2(1128, 200), Vector2(1248, 248), Vector2(1490, 248),
]

const WAYPOINT_TITLES: Array[String] = [
	"Light the entrance shrine",
	"Align with the narrow western corridor",
	"Dash through the corridor mouth",
	"Scout encounter room A",
	"Line up with the southern hidden path",
	"Check the southern secret alcove",
	"Return to the main route",
	"Line up with the middle corridor",
	"Cross into encounter room B",
	"Clear the split encounter",
	"Line up with the east corridor",
	"Cross into encounter room C",
	"Secure the forward checkpoint",
	"Line up with the northern hidden path",
	"Explore the northern secret alcove",
	"Return from the hidden northern path",
	"Approach the sealed boss corridor",
	"Enter the boss-arena stub",
]

@onready var _zone: Zone1Graybox = $Zone1Graybox
@onready var _player: PlayerController = $Zone1Graybox/Player
@onready var _phase_label: Label = $CaptureUI/Panel/Margin/VBox/Phase
@onready var _intent_label: Label = $CaptureUI/Panel/Margin/VBox/Intent
@onready var _status_label: Label = $CaptureUI/Panel/Margin/VBox/Status

var _mode: AgentMode = AgentMode.EXPLORE
var _waypoint_index: int = 0
var _frame_count: int = 0
var _phase_elapsed: float = 0.0
var _attack_cooldown: float = 0.0
var _dash_cooldown: float = 0.0
var _strafe_clock: float = 0.0
var _stuck_clock: float = 0.0
var _last_sample_position: Vector2
var _stuck_recovery_frames: int = 0
var _tap_action: StringName = &""
var _tap_frames_remaining: int = 0
var _opened_with_relic: Dictionary[int, bool] = {}
var _current_target_id: int = 0
var _defeated_count: int = 0
var _showcase_complete: bool = false
var _captured_first_fight: bool = false
var _captured_dodge: bool = false
var _captured_secret: bool = false
var _captured_gate: bool = false
var _capture_dir: String = DEFAULT_CAPTURE_DIR


func _ready() -> void:
	var configured_capture_dir: String = OS.get_environment(CAPTURE_DIR_ENV)
	if not configured_capture_dir.is_empty():
		_capture_dir = configured_capture_dir
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_capture_dir))
	_last_sample_position = _player.global_position
	var respawn_controller: RespawnController = $Zone1Graybox/RespawnController
	respawn_controller.save_on_checkpoint = false
	for enemy: EnemyBase in _zone.get_zone_enemies():
		enemy.enemy_died.connect(_on_enemy_died)
	_set_copy("ZONE 1 AUTONOMOUS PLAYTEST", "Reading the route, encounters, and optional spaces")
	print("Zone 1 gameplay director started")


func _physics_process(delta: float) -> void:
	_frame_count += 1
	_phase_elapsed += delta
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	_strafe_clock += delta
	_stuck_clock += delta
	_update_tap_release()
	_update_status()
	if _frame_count >= MAX_CAPTURE_FRAMES:
		_shutdown("Safety timeout")
		return
	if _player.health.is_dead:
		_clear_movement()
		_set_copy("RECOVER", "Waiting for the checkpoint respawn flow")
		return
	if _showcase_complete:
		_clear_movement()
		_set_copy("PLAYTEST COMPLETE", "Explored a secret route and cleared two varied encounters")
		if _phase_elapsed >= 2.0:
			_shutdown("Capture complete")
		return
	if _defeated_count >= SHOWCASE_DEFEATS and _waypoint_index >= 8:
		_showcase_complete = true
		_phase_elapsed = 0.0
		return

	var target: EnemyBase = _nearest_living_enemy()
	if target != null and _player.global_position.distance_to(target.global_position) <= ENEMY_NOTICE_DISTANCE:
		_run_combat(target)
	else:
		_run_exploration()
	_update_stuck_recovery()


func _run_exploration() -> void:
	_mode = AgentMode.EXPLORE
	if _waypoint_index >= WAYPOINTS.size():
		_mode = AgentMode.COMPLETE
		_clear_movement()
		_set_copy("ROUTE COMPLETE", "Rooms cleared, shrines visited, secrets checked, gate opened")
		if _phase_elapsed >= 2.0:
			_shutdown("Capture complete")
		return
	var goal: Vector2 = WAYPOINTS[_waypoint_index]
	var distance: float = _player.global_position.distance_to(goal)
	_set_copy("EXPLORE · %d/%d" % [_waypoint_index + 1, WAYPOINTS.size()], WAYPOINT_TITLES[_waypoint_index])
	if distance <= _waypoint_reached_distance():
		_on_waypoint_reached()
		return
	_move_toward(goal)
	if distance > 150.0 and _dash_cooldown <= 0.0:
		_tap(&"dash")
		_dash_cooldown = 0.8


func _run_combat(target: EnemyBase) -> void:
	var target_id: int = target.get_instance_id()
	if target_id != _current_target_id:
		_current_target_id = target_id
		_phase_elapsed = 0.0
	_mode = AgentMode.ENGAGE
	var offset: Vector2 = target.global_position - _player.global_position
	var distance: float = offset.length()
	var direction: Vector2 = offset.normalized()
	_set_copy("COMBAT · ENEMY %d/4" % mini(_defeated_count + 1, 4), "Read the tell · vary range · preserve health · finish decisively")

	if target.state == EnemyBase.State.WIND_UP and distance < 72.0:
		_mode = AgentMode.EVADE
		var rotation: float = 0.35 if sin(_strafe_clock * 4.0) > 0.0 else -0.35
		_set_movement(-direction.rotated(rotation))
		if _dash_cooldown <= 0.0:
			_tap(&"dash")
			_dash_cooldown = 0.55
			if not _captured_dodge:
				_captured_dodge = true
				_capture_after_draw("02_reactive_dodge.png")
		return

	if not _opened_with_relic.has(target_id) and distance >= RELIC_MIN_DISTANCE:
		_set_movement(direction)
		if _attack_cooldown <= 0.0 and _player.energy.can_spend(_player.energy_bolt_cost):
			_tap(&"ability_relic")
			_opened_with_relic[target_id] = true
			_attack_cooldown = 0.65
		return

	if distance <= MELEE_DISTANCE:
		_set_movement(direction)
		if _attack_cooldown <= 0.0:
			_tap(&"attack_melee")
			_attack_cooldown = 0.28
			if not _captured_first_fight:
				_captured_first_fight = true
				_capture_after_draw("01_mixed_combat.png")
		return

	if distance < 95.0 and _player.energy.can_spend(_player.energy_bolt_cost) and _attack_cooldown <= 0.0:
		_set_movement(direction)
		_tap(&"ability_relic")
		_attack_cooldown = 0.75
		return

	var approach_direction: Vector2 = direction
	if distance < 58.0:
		var strafe_sign: float = 1.0 if fmod(_strafe_clock, 1.6) < 0.8 else -1.0
		approach_direction = direction.rotated(strafe_sign * 0.7)
	_set_movement(approach_direction)
	if distance > 125.0 and _dash_cooldown <= 0.0:
		_tap(&"dash")
		_dash_cooldown = 0.75


func _nearest_living_enemy() -> EnemyBase:
	var nearest: EnemyBase = null
	var nearest_distance: float = INF
	for enemy: EnemyBase in _zone.get_zone_enemies():
		if enemy.state == EnemyBase.State.DEAD:
			continue
		var distance: float = _player.global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


func _move_toward(goal: Vector2) -> void:
	var direction: Vector2 = _player.global_position.direction_to(goal)
	if _stuck_recovery_frames > 0:
		direction = direction.rotated(PI / 2.0)
		_stuck_recovery_frames -= 1
	_set_movement(direction)


func _set_movement(direction: Vector2) -> void:
	_clear_movement()
	if direction.x < -0.04:
		Input.action_press(&"move_left")
	elif direction.x > 0.04:
		Input.action_press(&"move_right")
	if direction.y < -0.04:
		Input.action_press(&"move_up")
	elif direction.y > 0.04:
		Input.action_press(&"move_down")


func _clear_movement() -> void:
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	Input.action_release(&"move_up")
	Input.action_release(&"move_down")


func _tap(action: StringName) -> void:
	if not _tap_action.is_empty():
		return
	_tap_action = action
	_tap_frames_remaining = 1
	Input.action_press(action)


func _update_tap_release() -> void:
	if _tap_action.is_empty():
		return
	_tap_frames_remaining -= 1
	if _tap_frames_remaining > 0:
		return
	Input.action_release(_tap_action)
	_tap_action = &""


func _on_waypoint_reached() -> void:
	_clear_movement()
	if _waypoint_index == 5 and not _captured_secret:
		_captured_secret = true
		_capture_after_draw("03_secret_alcove.png")
	if _waypoint_index == 16 and _zone.is_boss_door_open() and not _captured_gate:
		_captured_gate = true
		_capture_after_draw("04_open_boss_gate.png")
	_waypoint_index += 1
	_phase_elapsed = 0.0


func _on_enemy_died() -> void:
	_defeated_count += 1
	_current_target_id = 0
	_attack_cooldown = 0.3


func _waypoint_reached_distance() -> float:
	if _waypoint_index in [1, 4, 7, 10, 13]:
		return 5.0
	return WAYPOINT_REACHED_DISTANCE


func _update_stuck_recovery() -> void:
	if _stuck_clock < STUCK_SAMPLE_INTERVAL:
		return
	var traveled: float = _player.global_position.distance_to(_last_sample_position)
	if traveled < STUCK_DISTANCE and _mode == AgentMode.EXPLORE:
		_stuck_recovery_frames = 12
		if _dash_cooldown <= 0.0:
			_tap(&"dash")
			_dash_cooldown = 0.6
	_last_sample_position = _player.global_position
	_stuck_clock = 0.0


func _update_status() -> void:
	var target: EnemyBase = _nearest_living_enemy()
	var enemy_status: String = "none"
	if target != null:
		enemy_status = "%d HP · %.0f px" % [target.health.current_health, _player.global_position.distance_to(target.global_position)]
	_status_label.text = "HP %d/%d  ·  Energy %.0f/%.0f  ·  Defeated %d/4  ·  Nearest %s" % [
		_player.health.current_health, _player.health.max_health,
		_player.energy.current_energy, _player.energy.max_energy,
		_defeated_count, enemy_status,
	]


func _set_copy(phase: String, intent: String) -> void:
	_phase_label.text = phase
	_intent_label.text = intent


func _capture_after_draw(file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var capture_path: String = ProjectSettings.globalize_path(_capture_dir.path_join(file_name))
	var error: Error = image.save_png(capture_path)
	if error != OK:
		push_error("Could not save capture frame '%s': %s" % [file_name, error_string(error)])


func _shutdown(reason: String) -> void:
	_clear_movement()
	if not _tap_action.is_empty():
		Input.action_release(_tap_action)
	print("Zone 1 gameplay director finished: %s; defeated=%d; waypoint=%d/%d; position=%s" % [
		reason, _defeated_count, _waypoint_index, WAYPOINTS.size(), _player.global_position,
	])
	get_tree().quit()
