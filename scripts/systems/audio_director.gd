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

## Rendered combat effects (tools/synth_shadow_sfx.py). Mastered to -1 dBFS,
## so they sit lower than the synth voices to land at a similar loudness.
const FX_DIR := "res://assets/audio/sfx/"
const FX_VOLUME_DB := -6.0
const FX_VOICES := 14
## Two skills landing on the same frame should not double the same sample.
const FX_REPEAT_GAP := 0.045
const VOICE_DIR := "res://assets/audio/voice/"
const VOICE_BOOST_DB := 5.0
const VOICE_MUSIC_DUCK_DB := -10.0
## River / waterfall bed and songbird calls (tools/synth_hub_nature.py).
const NATURE_BED_PATH := "res://assets/audio/ambience/hub_river_loop.wav"
const BIRD_PATH := "res://assets/audio/ambience/bird_%d.wav"
const BIRD_COUNT := 10
const NATURE_BED_DB := -7.0
const NATURE_FADE := 1.6

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

var _fx_players: Array[AudioStreamPlayer] = []
var _fx_next := 0
## name -> AudioStream, or null once a load has failed.
var _fx_cache: Dictionary = {}
var _fx_last_played: Dictionary = {}
var _voice_player: AudioStreamPlayer
var _voice_fade: Tween
var _music_duck_db := 0.0

var _nature_player: AudioStreamPlayer
var _nature_tween: Tween
var _nature_on := false
var _bird_players: Array[AudioStreamPlayer] = []
var _bird_timer := 0.0


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

	for i in range(FX_VOICES):
		var fx_player := AudioStreamPlayer.new()
		fx_player.name = "Fx%d" % i
		fx_player.bus = "Master"
		add_child(fx_player)
		_fx_players.append(fx_player)

	_voice_player = AudioStreamPlayer.new()
	_voice_player.name = "Voice"
	_voice_player.bus = "Master"
	add_child(_voice_player)

	_nature_player = AudioStreamPlayer.new()
	_nature_player.name = "NatureBed"
	_nature_player.bus = "Master"
	_nature_player.volume_db = -80.0
	add_child(_nature_player)
	for i in range(3):
		var bird := AudioStreamPlayer.new()
		bird.name = "Bird%d" % i
		bird.bus = "Master"
		add_child(bird)
		_bird_players.append(bird)


## The playback is a reference handed out by the audio server, so drop it before
## the server shuts down.
func _exit_tree() -> void:
	_enabled = false
	_playback = null
	if _player != null:
		_player.stop()
	if _music_player != null:
		_music_player.stop()
	for fx_player in _fx_players:
		fx_player.stop()
	if _voice_player != null:
		_voice_player.stop()
	if _nature_player != null:
		_nature_player.stop()
	for bird in _bird_players:
		bird.stop()


func _process(delta: float) -> void:
	if not _enabled or _playback == null:
		return
	_update_birds(delta)
	_update_gust(delta)
	_update_bell(delta)
	_update_drums(delta)
	_update_voice_duck(delta)
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


## Rushing river, falls, and scattered birdsong for the village. Fades in and out.
func set_nature_ambience(on: bool) -> void:
	if not _enabled or _nature_player == null or on == _nature_on:
		return
	_nature_on = on
	if _nature_tween != null and _nature_tween.is_valid():
		_nature_tween.kill()
	if on:
		if _nature_player.stream == null:
			var bed := _load_music_stream(NATURE_BED_PATH)
			if bed == null:
				_nature_on = false
				return
			_nature_player.stream = bed
		if not _nature_player.playing:
			_nature_player.volume_db = -80.0
			_nature_player.play()
		_bird_timer = randf_range(0.6, 2.0)
		_nature_tween = create_tween()
		_nature_tween.tween_property(_nature_player, "volume_db", _effective_nature_db(), NATURE_FADE) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		return
	var player := _nature_player
	_nature_tween = create_tween()
	_nature_tween.tween_property(player, "volume_db", -80.0, NATURE_FADE * 0.6) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_nature_tween.tween_callback(func() -> void:
		if is_instance_valid(player) and not _nature_on:
			player.stop()
	)


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


## Plays a rendered effect from `assets/audio/sfx/<fx_name>.wav`. `volume_db`
## is relative to the SFX mix; the small random pitch keeps repeated hits from
## sounding stamped out.
func play_fx(fx_name: String, volume_db := 0.0, pitch_jitter := 0.06) -> void:
	if not _enabled or _fx_players.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_fx_last_played.get(fx_name, -10.0)) < FX_REPEAT_GAP:
		return
	var stream := _fx_stream(fx_name)
	if stream == null:
		return
	_fx_last_played[fx_name] = now
	var fx_player := _free_fx_player()
	fx_player.stream = stream
	fx_player.volume_db = _effective_fx_db() + volume_db
	fx_player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	fx_player.play()


## Spoken line from `assets/audio/voice/<line_name>.wav`. Only one line plays
## at a time; a new line cuts the previous one off.
func play_voice(line_name: String, volume_db := 0.0) -> float:
	if not _enabled or _voice_player == null:
		return 0.0
	var stream := _wav_stream(VOICE_DIR + line_name + ".wav")
	if stream == null:
		return 0.0
	_kill_voice_fade()
	_voice_player.stream = stream
	_voice_player.volume_db = _effective_fx_db() + VOICE_BOOST_DB + volume_db
	_voice_player.play()
	return stream.get_length()


func stop_voice() -> void:
	if _voice_player == null or not _voice_player.playing:
		return
	_kill_voice_fade()
	_voice_fade = create_tween()
	_voice_fade.tween_property(_voice_player, "volume_db", _voice_player.volume_db - 24.0, 0.18)
	_voice_fade.tween_callback(_voice_player.stop)


## Music dips under a spoken line so the words stay readable over the drums.
func _update_voice_duck(delta: float) -> void:
	var target := VOICE_MUSIC_DUCK_DB if is_voice_playing() else 0.0
	if is_equal_approx(_music_duck_db, target):
		return
	_music_duck_db = move_toward(_music_duck_db, target, delta * 36.0)
	if _music_tween != null and is_instance_valid(_music_tween) and _music_tween.is_running():
		return
	if _music_player != null and _music_player.playing and not _music_path.is_empty():
		_music_player.volume_db = _effective_music_db()


func _kill_voice_fade() -> void:
	if _voice_fade != null and _voice_fade.is_valid():
		_voice_fade.kill()
	_voice_fade = null


func is_voice_playing() -> bool:
	return _voice_player != null and _voice_player.playing


func _fx_stream(fx_name: String) -> AudioStream:
	return _wav_stream(FX_DIR + fx_name + ".wav")


func _wav_stream(path: String) -> AudioStream:
	if _fx_cache.has(path):
		return _fx_cache[path]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	# Fresh clones may not have imported the WAVs yet.
	if stream == null and FileAccess.file_exists(path):
		stream = AudioStreamWAV.load_from_file(path)
	if stream == null:
		push_warning("Audio: missing effect %s" % path)
	_fx_cache[path] = stream
	return stream


## Oldest voice is stolen when every player is busy.
func _free_fx_player() -> AudioStreamPlayer:
	for i in range(_fx_players.size()):
		var index := (_fx_next + i) % _fx_players.size()
		if not _fx_players[index].playing:
			_fx_next = (index + 1) % _fx_players.size()
			return _fx_players[index]
	var stolen := _fx_players[_fx_next]
	_fx_next = (_fx_next + 1) % _fx_players.size()
	return stolen


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
	# reading the raw file so the music still plays.
	if not FileAccess.file_exists(path):
		return null
	if path.ends_with(".wav"):
		var wav := AudioStreamWAV.load_from_file(path)
		if wav != null:
			_configure_loop(wav)
		return wav
	if not path.ends_with(".mp3"):
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
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)


func _kill_music_tween() -> void:
	if _music_tween != null and is_instance_valid(_music_tween):
		_music_tween.kill()
	_music_tween = null


func _effective_music_db() -> float:
	if _muted or _master_linear <= 0.001 or _music_linear <= 0.001:
		return -80.0
	return _music_target_db + _music_duck_db + linear_to_db(_master_linear * _music_linear)


func _effective_sfx_db() -> float:
	if _muted or _master_linear <= 0.001 or _sfx_linear <= 0.001:
		return -80.0
	return SFX_VOLUME_DB + linear_to_db(_master_linear * _sfx_linear)


func _effective_fx_db() -> float:
	if _muted or _master_linear <= 0.001 or _sfx_linear <= 0.001:
		return -80.0
	return FX_VOLUME_DB + linear_to_db(_master_linear * _sfx_linear)


func _effective_nature_db() -> float:
	if _muted or _master_linear <= 0.001 or _music_linear <= 0.001:
		return -80.0
	return NATURE_BED_DB + linear_to_db(_master_linear * _music_linear)


## Calls overlap a little and come from different birds, so the canopy never
## sounds like one looped recording.
func _update_birds(delta: float) -> void:
	if not _nature_on or _bird_players.is_empty():
		return
	_bird_timer -= delta
	if _bird_timer > 0.0:
		return
	_bird_timer = randf_range(1.2, 4.8)
	var stream := _wav_stream(BIRD_PATH % randi_range(1, BIRD_COUNT))
	if stream == null:
		return
	var bird: AudioStreamPlayer = null
	for candidate in _bird_players:
		if not candidate.playing:
			bird = candidate
			break
	if bird == null:
		return
	bird.stream = stream
	bird.pitch_scale = randf_range(0.9, 1.12)
	bird.volume_db = _effective_nature_db() + randf_range(-14.0, -4.0)
	bird.play()


func _apply_live_volumes() -> void:
	if _player != null:
		_player.volume_db = _effective_sfx_db()
	if _nature_on and _nature_player != null and _nature_player.playing:
		if _nature_tween == null or not _nature_tween.is_running():
			_nature_player.volume_db = _effective_nature_db()
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
