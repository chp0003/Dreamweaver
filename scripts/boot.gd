extends Control
## Startup loading screen — covers autoload init and first-scene preload.

const MIN_DISPLAY := 1.15

const PRELOADS := [
	"res://scenes/Login.tscn",
	"res://assets/images/ui/login_hero_cinematic.png",
]

@onready var emblem: TextureRect = %Emblem
@onready var title_label: Label = %TitleLabel
@onready var status_label: Label = %StatusLabel
@onready var progress_bar: ProgressBar = %ProgressBar


func _ready() -> void:
	var motes := LightMotes.new()
	motes.mote_count = 28
	add_child(motes)

	progress_bar.add_theme_stylebox_override("background", UiStyle.bar_track(8))
	progress_bar.add_theme_stylebox_override("fill", UiStyle.bar_fill(Palette.GOLD_SACRED, 8))
	UiStyle.glow_label(title_label, Palette.DREAM_LANTERN, 18)

	await get_tree().process_frame
	emblem.pivot_offset = emblem.size * 0.5
	UiMotion.bloom(emblem, 0.0, UiMotion.SLOW)
	UiMotion.breathe(emblem, 4.0, 4.0)
	UiMotion.shimmer(status_label, 0.55, 1.0, 2.2)

	await _run_loading()
	if is_inside_tree():
		SceneFader.fade_to_scene(AccountManager.LOGIN_SCENE)


func _run_loading() -> void:
	var started_ms := Time.get_ticks_msec()
	_set_progress(0.04, "Threading the warp…")

	await get_tree().process_frame
	_set_progress(0.18, "Reading the village ledger…")
	await AccountManager.startup_sync()
	GameState.load_from_account()

	_set_progress(0.42, "Gathering lantern light…")
	await _preload_assets()

	var elapsed := (Time.get_ticks_msec() - started_ms) / 1000.0
	if elapsed < MIN_DISPLAY:
		_set_progress(0.92, "The cloth stirs…")
		await get_tree().create_timer(MIN_DISPLAY - elapsed).timeout

	_set_progress(1.0, "Ready.")


func _preload_assets() -> void:
	var pending: Array[String] = []
	for path in PRELOADS:
		if ResourceLoader.has_cached(path):
			continue
		var err := ResourceLoader.load_threaded_request(path)
		if err == OK:
			pending.append(path)

	var total := maxi(pending.size(), 1)
	var done := 0
	while not pending.is_empty():
		var path: String = pending[0]
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(path)
			pending.pop_front()
			done += 1
			var ratio := 0.42 + (float(done) / float(total)) * 0.48
			_set_progress(ratio, "Weaving the entrance…")
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			push_warning("Boot: failed to preload %s" % path)
			pending.pop_front()
			done += 1
		else:
			var progress: Array[float] = []
			ResourceLoader.load_threaded_get_status(path, progress)
			var slice: float = progress[0] if progress.size() > 0 else 0.0
			var ratio: float = 0.42 + ((float(done) + slice) / float(total)) * 0.48
			_set_progress(ratio, "Weaving the entrance…")
		await get_tree().process_frame


func _set_progress(ratio: float, status: String) -> void:
	progress_bar.value = clampf(ratio, 0.0, 1.0) * 100.0
	status_label.text = status
