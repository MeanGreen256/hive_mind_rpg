extends GutTest
## Coverage for the AudioManager autoload (issues #25 and #181): the Zone 1
## registry, deterministic stream metadata, unknown-id handling, and ambient
## loop state control. Actual audible output is not assertable headless, so
## these tests pin the API contract and the authored source durations.

const REQUIRED_SFX_IDS: Array[StringName] = [
	&"melee_swing", &"relic_cast", &"dash", &"hit", &"death",
]
const EXPECTED_STREAM_LENGTHS: Dictionary[StringName, float] = {
	&"forest_drone": 8.0,
	&"melee_swing": 0.22,
	&"relic_cast": 0.34,
	&"dash": 0.16,
	&"hit": 0.15,
	&"death": 0.78,
}
const STREAM_LENGTH_TOLERANCE_SECONDS: float = 0.01


func after_each() -> void:
	# Leave the autoload the way gameplay expects it: default drone running.
	AudioManager.play_ambient()


func test_registry_covers_the_zone1_combat_set() -> void:
	for sfx_id: StringName in REQUIRED_SFX_IDS:
		assert_true(
			AudioManager.SFX_STREAM_PATHS.has(sfx_id),
			"Missing required Zone 1 SFX '%s'." % sfx_id
		)


func test_zone1_streams_match_the_documented_deterministic_durations() -> void:
	var stream_paths: Dictionary[StringName, String] = AudioManager.SFX_STREAM_PATHS.duplicate()
	stream_paths.merge(AudioManager.AMBIENT_STREAM_PATHS)
	for stream_id: StringName in EXPECTED_STREAM_LENGTHS:
		assert_true(stream_paths.has(stream_id), "Missing authored stream '%s'." % stream_id)
		if not stream_paths.has(stream_id):
			continue
		var stream: AudioStreamWAV = load(stream_paths[stream_id]) as AudioStreamWAV
		assert_not_null(stream, "%s must import as AudioStreamWAV." % stream_id)
		if stream == null:
			continue
		assert_eq(stream.mix_rate, 22050, "%s must retain the authored 22.05 kHz rate." % stream_id)
		assert_almost_eq(
			stream.get_length(), EXPECTED_STREAM_LENGTHS[stream_id],
			STREAM_LENGTH_TOLERANCE_SECONDS,
			"%s duration must match the deterministic source contract." % stream_id
		)


func test_known_sfx_ids_are_accepted() -> void:
	for sfx_id: StringName in AudioManager.SFX_STREAM_PATHS:
		assert_true(AudioManager.play_sfx(sfx_id), "SFX '%s' should be playable." % sfx_id)


func test_unknown_sfx_id_warns_and_is_rejected() -> void:
	assert_false(AudioManager.play_sfx(&"kazoo_solo"))
	assert_push_warning("no SFX named")


func test_unknown_ambient_id_warns_and_keeps_the_current_loop() -> void:
	var previous_ambient_id: StringName = AudioManager.get_current_ambient_id()

	assert_false(AudioManager.play_ambient(&"elevator_jazz"))

	assert_push_warning("no ambient loop named")
	assert_eq(AudioManager.get_current_ambient_id(), previous_ambient_id)


func test_ambient_loop_stops_and_restarts() -> void:
	AudioManager.stop_ambient()
	assert_false(AudioManager.is_ambient_playing())
	assert_eq(AudioManager.get_current_ambient_id(), StringName())

	assert_true(AudioManager.play_ambient())
	assert_true(AudioManager.is_ambient_playing())
	assert_eq(AudioManager.get_current_ambient_id(), AudioManager.DEFAULT_AMBIENT)
