extends Node
## Autoload that synthesises the game's ambience and effects at runtime.
##
## The project ships no audio files yet, so rather than leave every scene silent
## this generates the wind bed and the brass bell of the Main Menu, plus short
## gameplay stingers, into a single AudioStreamGenerator buffer. Replacing this
## with real recordings later means rewriting the bodies of `play_sfx()` and
## `set_ambience()` - callers do not change.

const MIX_RATE := 22050.0
const BUFFER_SECONDS := 0.2
const MAX_VOICES := 24

enum Sfx { CHIME, HIT, PICKUP, BELL, SUCCESS, FAIL, PARRY, THUD }

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _enabled := true

## Wind bed: a slow gust envelope plus a low-passed noise source.
var _wind_level := 0.0
var _gust := 0.0
var _gust_target := 0.0
var _gust_timer := 0.0
var _noise_lowpass := 0.0

## Distant brass bell scheduling.
var _bell_interval := 0.0
var _bell_timer := 0.0

## Decaying sine voices: { freq, phase, amp, decay }
var _voices: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Headless runs (the build checks in tools/) get the Dummy driver, which can
	# never play anything. Skip the generator there so the checks stay quiet and
	# do not burn a frame's worth of synthesis on silence.
	if AudioServer.get_driver_name() == "Dummy":
		_enabled = false
		return

	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = BUFFER_SECONDS

	_player = AudioStreamPlayer.new()
	_player.name = "Generator"
	_player.stream = stream
	_player.volume_db = -8.0
	add_child(_player)
	_player.play()

	var playback := _player.get_stream_playback()
	if playback is AudioStreamGeneratorPlayback:
		_playback = playback
	else:
		# Headless or no audio device: stay quiet rather than error every frame.
		_enabled = false


## The playback is a reference handed out by the audio server, so drop it before
## the server shuts down.
func _exit_tree() -> void:
	_enabled = false
	_playback = null
	if _player != null:
		_player.stop()


func _process(delta: float) -> void:
	if not _enabled or _playback == null:
		return
	_update_gust(delta)
	_update_bell(delta)
	_fill_buffer()


# --------------------------------------------------------------------------
# Public API
# --------------------------------------------------------------------------

## `level` is 0..1 wind loudness. A positive `bell_interval` (seconds) adds the
## distant brass toll used on the Main Menu and in the ancestor hall.
func set_ambience(level: float, bell_interval: float = 0.0) -> void:
	_wind_level = clampf(level, 0.0, 1.0)
	_bell_interval = maxf(0.0, bell_interval)
	if _bell_interval > 0.0:
		_bell_timer = minf(_bell_timer, _bell_interval)


func stop_ambience() -> void:
	set_ambience(0.0, 0.0)


func play_sfx(kind: Sfx) -> void:
	if not _enabled:
		return
	match kind:
		Sfx.CHIME:
			_add_voice(1180.0, 0.30, 3.2)
			_add_voice(1770.0, 0.16, 4.0)
			_add_voice(2360.0, 0.08, 5.5)
		Sfx.BELL:
			_add_voice(196.0, 0.26, 1.1)
			_add_voice(392.0, 0.13, 1.6)
			_add_voice(587.0, 0.06, 2.4)
		Sfx.HIT:
			_add_voice(150.0, 0.34, 16.0)
			_add_voice(96.0, 0.22, 11.0)
		Sfx.THUD:
			_add_voice(72.0, 0.40, 8.0)
		Sfx.PICKUP:
			_add_voice(880.0, 0.16, 12.0)
			_add_voice(1320.0, 0.10, 14.0)
		Sfx.PARRY:
			_add_voice(1560.0, 0.22, 18.0)
			_add_voice(2340.0, 0.12, 22.0)
		Sfx.SUCCESS:
			_add_voice(523.0, 0.18, 3.0)
			_add_voice(659.0, 0.16, 3.4)
			_add_voice(784.0, 0.14, 3.8)
		Sfx.FAIL:
			_add_voice(196.0, 0.24, 5.0)
			_add_voice(185.0, 0.20, 6.0)


# --------------------------------------------------------------------------
# Synthesis
# --------------------------------------------------------------------------

func _update_gust(delta: float) -> void:
	_gust_timer -= delta
	if _gust_timer <= 0.0:
		_gust_timer = randf_range(1.4, 4.2)
		_gust_target = randf_range(0.35, 1.0)
	_gust = lerpf(_gust, _gust_target, minf(1.0, delta * 0.8))


func _update_bell(delta: float) -> void:
	if _bell_interval <= 0.0:
		return
	_bell_timer -= delta
	if _bell_timer <= 0.0:
		_bell_timer = _bell_interval * randf_range(0.8, 1.3)
		play_sfx(Sfx.BELL)


func _add_voice(freq: float, amp: float, decay: float) -> void:
	if _voices.size() >= MAX_VOICES:
		_voices.remove_at(0)
	_voices.append({"freq": freq, "phase": 0.0, "amp": amp, "decay": decay})


func _fill_buffer() -> void:
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return

	var wind_gain := _wind_level * _gust * 0.35
	var step := 1.0 / MIX_RATE

	for _frame in range(frames):
		var sample := 0.0

		if wind_gain > 0.0:
			var noise := randf() * 2.0 - 1.0
			_noise_lowpass = lerpf(_noise_lowpass, noise, 0.06)
			sample += _noise_lowpass * wind_gain

		for voice in _voices:
			var amp := float(voice["amp"])
			if amp <= 0.0005:
				continue
			sample += sin(float(voice["phase"]) * TAU) * amp
			voice["phase"] = fmod(float(voice["phase"]) + float(voice["freq"]) * step, 1.0)
			voice["amp"] = amp * (1.0 - float(voice["decay"]) * step)

		_playback.push_frame(Vector2(sample, sample).clampf(-1.0, 1.0))

	for i in range(_voices.size() - 1, -1, -1):
		if float(_voices[i]["amp"]) <= 0.0005:
			_voices.remove_at(i)
