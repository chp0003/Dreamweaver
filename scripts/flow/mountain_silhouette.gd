extends Control
## Draws the Lake Sebu highland skyline behind the Gateway and the Ending.
##
## This is placeholder art that is meant to look deliberate rather than blank:
## a graded sky, aerial-perspective ridges that get hazier with distance, a
## stilted Guno Bong with two smaller houses flanking it, and a band of T'nalak
## zigzag in the clouds. Drop a PNG at `art_path` and it takes over wholesale.
##
## Both screens share it with different sky colours - night for the Gateway,
## dawn for the Ending - which is why every colour here is exported.

## Set to "" to force the drawn version even if the PNG exists.
@export var art_path := "res://assets/images/ui/gateway_backdrop.png"
@export var sky_top := Palette.DREAM_ABYSS
@export var sky_horizon := Palette.DREAM_VIOLET.lerp(Palette.RED_DEEP, 0.45)
@export var moon_color := Palette.GOLD_SUN
@export var ridge_color := Palette.DREAM_ABYSS
## Distant ridges are lifted toward this to fake aerial haze. Kept muted on
## purpose: pushing it all the way to the horizon hue turns the ridges into
## bright maroon shapes that fight the menu buttons for attention.
@export var haze_color := Color("#2a2438")
## Moonlight along the roof ridges, so the village reads as a silhouette against
## the hill behind it instead of vanishing into it.
@export var rim_color := Palette.CREAM_STONE
@export var window_color := Palette.GOLD_SACRED
## Horizontal placement of the moon, 0..1 across the frame.
@export var moon_x := 0.76
@export var draw_stars := true

## Back ridge first. `haze` blends that ridge toward the horizon colour, so the
## furthest ridge is barely darker than the sky and the nearest is almost black.
## Kept in the lower 40% of the frame so the title and buttons sit against sky.
const RIDGES := [
	{"base": 0.70, "peak": 0.155, "steps": 3, "jag": 0.028, "haze": 0.42},
	{"base": 0.79, "peak": 0.115, "steps": 4, "jag": 0.024, "haze": 0.26},
	{"base": 0.88, "peak": 0.085, "steps": 6, "jag": 0.018, "haze": 0.12},
	{"base": 0.99, "peak": 0.055, "steps": 9, "jag": 0.012, "haze": 0.0},
]

## Stilt positions as a fraction of the house's half-width.
const STILT_OFFSETS: Array[float] = [-0.72, -0.24, 0.24, 0.72]

const SKY_BANDS := 48
const STAR_COUNT := 110
## Fixed seed so the sky does not reshuffle on every resize or scene entry.
const STAR_SEED := 20240824


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not art_path.is_empty() and ResourceLoader.exists(art_path):
		var texture := load(art_path)
		if texture is Texture2D:
			var art := TextureRect.new()
			art.texture = texture
			art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(art)
			return
	resized.connect(queue_redraw)
	var motes := LightMotes.new()
	motes.mote_count = 36
	motes.warm = true
	add_child(motes)


func _draw() -> void:
	# A texture child means real art took over and there is nothing to draw.
	for child in get_children():
		if child is TextureRect:
			return

	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return

	_draw_sky(w, h)
	if draw_stars:
		_draw_stars(w, h)
	_draw_aurora(w, h)
	_draw_moon(w, h)
	_draw_cloud_weave(w, h)

	# The village is drawn after the second ridge, so its roofs break the crest
	# into open sky (dark thatch on a lit sky reads at any size) while the two
	# nearer ridges draw over its stilts and settle it into the hillside.
	for i in range(RIDGES.size()):
		_draw_ridge(w, h, RIDGES[i])
		if i == 1:
			_draw_village(w, h)


## Vertical gradient in bands. Eased so the warm horizon stays low and the top
## of the frame holds the deep night the title needs to sit against.
func _draw_sky(w: float, h: float) -> void:
	for i in range(SKY_BANDS):
		var t := float(i) / float(SKY_BANDS - 1)
		var eased := pow(t, 2.4)
		draw_rect(
			Rect2(0.0, h * t, w, h / float(SKY_BANDS) + 1.0),
			sky_top.lerp(sky_horizon, eased)
		)


func _draw_stars(w: float, h: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	for _i in range(STAR_COUNT):
		var x := rng.randf() * w
		# Stars only in the upper half; lower sky is washed out by the horizon.
		var y := rng.randf() * h * 0.45
		var fade := 1.0 - (y / (h * 0.45))
		var alpha := rng.randf_range(0.22, 0.7) * fade
		var star_size := 1.0 if rng.randf() > 0.18 else 2.0
		var tint := Palette.CREAM_WARP if rng.randf() > 0.18 else Palette.DREAM_AURORA
		draw_rect(Rect2(x, y, star_size, star_size), Color(tint, alpha))
		if rng.randf() < 0.12:
			draw_circle(Vector2(x + 0.5, y + 0.5), 3.2, Color(tint, alpha * 0.18))


## A faint aurora band under the moon, so the sky has a second colour besides
## gold. Kept very thin: it is atmosphere, not a logo.
func _draw_aurora(w: float, h: float) -> void:
	var y := h * 0.28
	var amp := h * 0.035
	var step := w / 20.0
	for row in range(3):
		var points := PackedVector2Array()
		var yy := y + float(row) * amp * 1.25
		for i in range(21):
			var lift := sin(float(i) * 0.55 + float(row) * 0.8) * amp
			points.append(Vector2(float(i) * step, yy + lift))
		var ink := Palette.DREAM_AURORA if row == 1 else Palette.DREAM_COBALT
		draw_polyline(points, Color(ink, 0.09 + float(row) * 0.03), 2.4, true)


## A low moon with a soft halo, built from concentric rings because a pixel-art
## sky should not use a real blur.
func _draw_moon(w: float, h: float) -> void:
	var centre := Vector2(w * moon_x, h * 0.235)
	var radius := h * 0.052

	for i in range(6, 0, -1):
		var ring := radius * (1.0 + float(i) * 0.42)
		draw_circle(centre, ring, Color(moon_color, 0.035))
	draw_circle(centre, radius, Color(moon_color, 0.9))
	# Offset darker disc reads as a waning moon without needing a mask.
	draw_circle(centre + Vector2(radius * 0.42, -radius * 0.2), radius * 0.92,
		Color(sky_top.lerp(sky_horizon, 0.35), 0.55))


## A band of T'nalak zigzag (kleng) worked into the cloud layer - the motif that
## ties the sky to the cloth, used at very low opacity so it reads as texture.
func _draw_cloud_weave(w: float, h: float) -> void:
	var band_y := h * 0.40
	var amplitude := h * 0.022
	var step := w / 26.0
	var ink := Color(Palette.GOLD_BRASS, 0.10)

	for row in range(3):
		var y := band_y + float(row) * amplitude * 1.7
		var points := PackedVector2Array()
		for i in range(27):
			var up := i % 2 == 0
			points.append(Vector2(float(i) * step, y + (0.0 if up else amplitude)))
		draw_polyline(points, ink, 2.0)


func _draw_ridge(w: float, h: float, ridge: Dictionary) -> void:
	var base := h * float(ridge["base"])
	var peak := h * float(ridge["peak"])
	var jag := h * float(ridge["jag"])
	var steps := int(ridge["steps"])
	var colour := ridge_color.lerp(haze_color, float(ridge["haze"]))

	var points := PackedVector2Array()
	points.append(Vector2(0.0, h))

	var samples := steps * 6
	for i in range(samples + 1):
		var t := float(i) / float(samples)
		# One broad massif plus a jagged high-frequency crest, which reads as
		# rock far better than a single sine wave.
		var massif := sin(t * PI) * peak
		var crest := sin(t * PI * float(steps) * 2.0) * jag
		var teeth := sin(t * PI * float(steps) * 7.0) * jag * 0.35
		points.append(Vector2(w * t, base - massif - crest - teeth))

	points.append(Vector2(w, h))
	draw_colored_polygon(points, colour)


## A cluster of three Guno Bong, the largest one lit. Anchored mid-left so the
## Gateway's brand and menu panel keep open sky behind their type.
func _draw_village(w: float, h: float) -> void:
	var ground := h * 0.80
	_draw_guno_bong(Vector2(w * 0.36, ground), h * 0.095, true)
	_draw_guno_bong(Vector2(w * 0.18, ground + h * 0.014), h * 0.056, false)
	_draw_guno_bong(Vector2(w * 0.52, ground + h * 0.02), h * 0.05, false)


## A T'boli longhouse in silhouette: stilts, a low wall band, and the steep
## thatched roof that overhangs it on both sides.
func _draw_guno_bong(base: Vector2, house_height: float, lit: bool) -> void:
	var half := house_height * 0.95
	var wall_top := base.y - house_height * 0.52
	var ridge_peak := base.y - house_height * 1.55
	var ink := ridge_color

	# Stilts.
	var stilt_w := maxf(2.0, house_height * 0.055)
	for offset in STILT_OFFSETS:
		draw_rect(Rect2(
			Vector2(base.x + half * offset - stilt_w * 0.5, base.y - house_height * 0.1),
			Vector2(stilt_w, house_height * 0.34)
		), ink)

	# Wall band.
	draw_colored_polygon(PackedVector2Array([
		Vector2(base.x - half, base.y - house_height * 0.08),
		Vector2(base.x + half, base.y - house_height * 0.08),
		Vector2(base.x + half, wall_top),
		Vector2(base.x - half, wall_top),
	]), ink)

	# Steep overhanging roof.
	var eave_left := Vector2(base.x - half * 1.32, wall_top + house_height * 0.06)
	var eave_right := Vector2(base.x + half * 1.32, wall_top + house_height * 0.06)
	var apex := Vector2(base.x, ridge_peak)
	draw_colored_polygon(PackedVector2Array([
		eave_left,
		Vector2(base.x - half * 1.06, wall_top - house_height * 0.02),
		apex,
		Vector2(base.x + half * 1.06, wall_top - house_height * 0.02),
		eave_right,
	]), ink)

	# Moonlight catching the thatch. Without this the house is a black shape on
	# a black hill and the whole village disappears.
	var rim_width := maxf(1.5, house_height * 0.03)
	draw_line(eave_left, apex, Color(rim_color, 0.3), rim_width)
	draw_line(apex, eave_right, Color(rim_color, 0.13), rim_width)

	# The only warm light on the screen: one open doorway.
	if lit:
		var door := Vector2(house_height * 0.2, house_height * 0.34)
		var door_pos := Vector2(base.x - door.x * 0.5, wall_top + house_height * 0.14)
		draw_rect(Rect2(door_pos - Vector2(2.0, 2.0), door + Vector2(4.0, 4.0)),
			Color(window_color, 0.18))
		draw_rect(Rect2(door_pos, door), Color(window_color, 0.8))
