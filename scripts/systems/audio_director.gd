extends Node
## Autoload that owns ambience, menu music, and synthesised effects.
##
## Procedural wind / brass / stingers still live in an AudioStreamGenerator so
## gameplay never goes silent without shipped SFX. Menu screens play the real
## Dreamweaver login track via `play_menu_music()`; leaving those screens fades
## it out so chapters keep their own ambience.

const MIX_RATE := 22050.0
const BUFFER_SECONDS := 0.2
const MAX_VOICES := 24

const MENU_MUSIC_PATH := "res://assets/audio/music/menu_ambient.mp3"
const MUSIC_FADE_IN := 1.2
const MUSIC_FADE_OUT := 0.7
const MUSIC_VOLUME_DB := -9.0
const SFX_VOLUME_DB := -8.0

enum Sfx { CHIME, HIT, PICKUP, BELL, SUCCESS, FAIL, PARRY, THUD }

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _enabled := true

## Real music bed (login / register / gateway). Separate from the synth player.
var _music_player: AudioStreamPlayer
var _music_path := ""
var _music_tween: Tween
var _music_target_db := MUSIC_VOLUME_DB

## Linear 0..1 gains, applied on top of the authored dB targets.
var _master_linear := 1.0
var _music_linear := 0.85
var _sfx_linear := 1.0
var _muted := false

## Wind bed: a slow gust envelope plus a low-passed noise source.
var _wind_level := 0.0
var _gust := 0.0
var _gust_target := 0.0
var _gust_timer := 0.0
var _noise_lowpass := 0.0

## Distant brass bell scheduling.
var _bell_interval := 0.0
var _bell_timer := 0.0

## Combat drum bed for Chapter 5 (ethnic pulse under the synth brass).
var _drum_level := 0.0
var _drum_period := 0.43
var _drum_timer := 0.0
var _drum_beat := 0

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

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "Music"
	_music_player.bus = "Master"
	_music_player.volume_db = -80.0
	add_child(_music_player)


## The playback is a reference handed out by the audio server, so drop it before
## the server shuts down.
func _exit_tree() -> void:
	_enabled = false
	_playback = null
	if _player != null:
		_player.stop()
	if _music_player != null:
		_music_player.stop()


func _process(delta: float) -> void:
	if not _enabled or _playback == null:
		return
	_update_gust(delta)
	_update_bell(delta)
	_update_drums(delta)
	_fill_buffer()


# --------------------------------------------------------------------------
# Public API
# --------------------------------------------------------------------------

## `level` is 0..1 wind loudness. A positive `bell_interval` (seconds) adds the
## distant brass toll used under quiet menus and in the ancestor hall.
func set_ambience(level: float, bell_interval: float = 0.0) -> void:
	_wind_level = clampf(level, 0.0, 1.0)
	_bell_interval = maxf(0.0, bell_interval)
	if _bell_interval > 0.0:
		_bell_timer = minf(_bell_timer, _bell_interval)


func stop_ambience() -> void:
	set_ambience(0.0, 0.0)


## Loop the Dreamweaver login track across Login, Register, and the Gateway.
## Calling again while the same track is already playing is a no-op so fades
## between those screens do not restart the song.
func play_menu_music() -> void:
	play_music(MENU_MUSIC_PATH, MUSIC_VOLUME_DB)


## Push player prefs from the Settings autoload onto the live buses.
func apply_volumes(master: float, music: float, sfx: float, muted: bool) -> void:
	_master_linear = clampf(master, 0.0, 1.0)
	_music_linear = clampf(music, 0.0, 1.0)
	_sfx_linear = clampf(sfx, 0.0, 1.0)
	_muted = muted
	_apply_live_volumes()


func play_music(path: String, volume_db: float = MUSIC_VOLUME_DB) -> void:
	if not _enabled or path.is_empty() or _music_player == null:
		return
	if _music_path == path and _music_player.playing:
		_music_target_db = volume_db
		_apply_live_volumes()
		return

	var stream := _load_music_stream(path)
	if stream == null:
		push_warning("Audio: could not load music at %s" % path)
		return

	_kill_music_tween()
	_music_path = path
	_music_target_db = volume_db
	_music_player.stream = stream
	_music_player.volume_db = -80.0
	_music_player.play()
	var target := _effective_music_db()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", target, MUSIC_FADE_IN) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


func stop_music(immediate: bool = false) -> void:
	if _music_player == null:
		return
	_music_path = ""
	_kill_music_tween()
	if immediate or not _music_player.playing:
		_music_player.stop()
		_music_player.volume_db = -80.0
		return
	var player := _music_player
	_music_tween = create_tween()
	_music_tween.tween_property(player, "volume_db", -80.0, MUSIC_FADE_OUT) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_music_tween.tween_callback(func() -> void:
		if is_instance_valid(player):
			player.stop()
	)


func is_music_playing() -> bool:
	return _music_player != null and _music_player.playing and not _music_path.is_empty()


## 0 = silent. Positive `bpm` drives a four-on-the-floor ethnic drum pulse.
func set_combat_drums(level: float, bpm: float = 140.0) -> void:
	_drum_level = clampf(level, 0.0, 1.0)
	_drum_period = 60.0 / maxf(60.0, bpm)
	if _drum_level <= 0.001:
		_drum_timer = 0.0
		_drum_beat = 0


## Sharp wind whistle that telegraphs a Bleach Attack.
func play_wind_whistle() -> void:
	if not _enabled:
		return
	_add_voice(1480.0, 0.22, 9.0)
	_add_voice(2100.0, 0.12, 14.0)
	_add_voice(920.0, 0.10, 7.5)


## Loud brass shockwave layered on staff strikes and the sonic chime.
func play_brass_shock() -> void:
	if not _enabled:
		return
	_add_voice(98.0, 0.40, 8.0)
	_add_voice(196.0, 0.32, 10.0)
	_add_voice(311.0, 0.18, 14.0)
	_add_voice(523.0, 0.10, 18.0)


func play_note(freq: float) -> void:
	if not _enabled:
		return
	_add_voice(freq, 0.15, 7.0)


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
# Music loading
# --------------------------------------------------------------------------

func _load_music_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var loaded := load(path)
		if loaded is AudioStream:
			_configure_loop(loaded)
			return loaded as AudioStream

	# Editor import may not have run yet (fresh clone / headless). Fall back to
	# reading the MP3 bytes so the menu still sings.
	if not path.ends_with(".mp3"):
		return null
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var stream := AudioStreamMP3.new()
	stream.data = file.get_buffer(file.get_length())
	stream.loop = true
	return stream


func _configure_loop(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD


func _kill_music_tween() -> void:
	if _music_tween != null and is_instance_valid(_music_tween):
		_music_tween.kill()
	_music_tween = null


func _effective_music_db() -> float:
	if _muted or _master_linear <= 0.001 or _music_linear <= 0.001:
		return -80.0
	return _music_target_db + linear_to_db(_master_linear * _music_linear)


func _effective_sfx_db() -> float:
	if _muted or _master_linear <= 0.001 or _sfx_linear <= 0.001:
		return -80.0
	return SFX_VOLUME_DB + linear_to_db(_master_linear * _sfx_linear)


func _apply_live_volumes() -> void:
	if _player != null:
		_player.volume_db = _effective_sfx_db()
	if _music_player == null:
		return
	# Don't fight an in-progress fade-in/out.
	if _music_tween != null and is_instance_valid(_music_tween) and _music_tween.is_running():
		return
	if _music_player.playing and not _music_path.is_empty():
		_music_player.volume_db = _effective_music_db()


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


func _update_drums(delta: float) -> void:
	if _drum_level <= 0.001:
		return
	_drum_timer -= delta
	if _drum_timer > 0.0:
		return
	_drum_timer = _drum_period
	_drum_beat = (_drum_beat + 1) % 4
	var amp := 0.26 * _drum_level
	if _drum_beat == 0:
		_add_voice(64.0, amp * 1.5, 12.0)
		_add_voice(110.0, amp * 0.7, 16.0)
	elif _drum_beat == 2:
		_add_voice(78.0, amp * 1.1, 14.0)
		_add_voice(156.0, amp * 0.45, 18.0)
	else:
		_add_voice(90.0, amp * 0.55, 20.0)


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
