class_name UiMotion
extends RefCounted
## The one place motion is defined, so every screen moves like the same game.
##
## Before this existed each screen hand-rolled its own tween with whatever
## duration and easing was typed at the time, which is why the interface felt
## snappy in one place and sluggish in the next. Everything here shares two
## rules, both borrowed from Child of Light's storybook feel:
##
##   1. Nothing appears instantly and nothing lands hard. Entrances ease OUT of
##      a fast start; exits ease IN to a slow stop.
##   2. Anything alive breathes. Idle elements drift on a long sine so a still
##      screen is never a dead screen.
##
## Durations are deliberately short. "Dreamy" comes from the easing curve and
## the stagger, not from making the player wait.

# Every duration in the interface is one of these four.
const FAST := 0.18
const BASE := 0.32
const SLOW := 0.55
const DRIFT := 0.9

## Gap between successive items in a staggered entrance.
const STAGGER := 0.06

## How far an entering element travels. Small on purpose - a long slide reads as
## lag, a short one reads as weight.
const RISE := 18.0


# --------------------------------------------------------------------------
# Entrances
# --------------------------------------------------------------------------

## Fades `node` in while it rises into place. The workhorse entrance.
static func fade_in(node: CanvasItem, delay := 0.0, duration := BASE,
		rise := RISE) -> Tween:
	if node == null or not node.is_inside_tree():
		return null
	var start_position := _position_of(node)
	var in_container := node.get_parent() is Container
	if not in_container:
		_set_position(node, start_position + Vector2(0.0, rise))
	node.modulate.a = 0.0

	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(node, "modulate:a", 1.0, duration).set_delay(delay)
	if not in_container:
		tween.tween_property(node, "position", start_position,
			duration).set_delay(delay)
	return tween


## Fades a whole column/row in one item at a time. Give it the container and it
## walks the visible children. This single call is what makes menus feel
## authored rather than dumped on screen.
static func cascade(container: Node, delay := 0.0, duration := BASE,
		rise := RISE, gap := STAGGER) -> void:
	if container == null:
		return
	var index := 0
	for child in container.get_children():
		if child is CanvasItem and (child as CanvasItem).visible:
			fade_in(child as CanvasItem, delay + float(index) * gap, duration, rise)
			index += 1


## Grows a node out from its own centre. For badges, medals and pickups.
static func bloom(node: Control, delay := 0.0, duration := SLOW) -> Tween:
	if node == null or not node.is_inside_tree():
		return null
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(0.82, 0.82)
	node.modulate.a = 0.0

	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "modulate:a", 1.0, duration * 0.6).set_delay(delay)
	tween.tween_property(node, "scale", Vector2.ONE, duration) \
		.set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return tween


# --------------------------------------------------------------------------
# Exits
# --------------------------------------------------------------------------

## Fades out and sinks. Mirror image of `fade_in`, so open/close feel related.
static func fade_out(node: CanvasItem, duration := FAST, fall := 10.0) -> Tween:
	if node == null or not node.is_inside_tree():
		return null
	var tween := node.create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(node, "modulate:a", 0.0, duration)
	tween.tween_property(node, "position",
		_position_of(node) + Vector2(0.0, fall), duration)
	return tween


# --------------------------------------------------------------------------
# Idle life
# --------------------------------------------------------------------------

## An endless slow rise and fall. Put this on emblems, floating props and
## anything that would otherwise sit perfectly still.
static func breathe(node: CanvasItem, distance := 6.0, period := 3.4,
		phase := 0.0) -> Tween:
	if node == null or not node.is_inside_tree():
		return null
	var tween := node.create_tween().set_loops()
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	if phase > 0.0:
		tween.tween_interval(phase)
	if node is Control and node.get_parent() is Container:
		var ctrl := node as Control
		ctrl.pivot_offset = ctrl.size * 0.5
		tween.tween_property(ctrl, "scale", Vector2(1.03, 1.03), period * 0.5)
		tween.tween_property(ctrl, "scale", Vector2.ONE, period * 0.5)
		return tween
	var home := _position_of(node)
	tween.tween_property(node, "position",
		home - Vector2(0.0, distance), period * 0.5)
	tween.tween_property(node, "position", home, period * 0.5)
	return tween


## An endless soft brightening, for anything meant to look lit from within.
static func shimmer(node: CanvasItem, low := 0.72, high := 1.0,
		period := 2.6) -> Tween:
	if node == null or not node.is_inside_tree():
		return null
	var tween := node.create_tween().set_loops()
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "modulate:a", high, period * 0.5)
	tween.tween_property(node, "modulate:a", low, period * 0.5)
	return tween


# --------------------------------------------------------------------------
# Reactions
# --------------------------------------------------------------------------

## A quick squash-and-recover. Confirms a press without moving the layout.
static func press(node: Control, depth := 0.96) -> Tween:
	if node == null or not node.is_inside_tree():
		return null
	node.pivot_offset = node.size * 0.5
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector2(depth, depth), 0.06) \
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, 0.18) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	return tween


## A gentle lift, for hover. Paired with `settle` on mouse exit.
static func hover(node: Control, amount := 1.03) -> Tween:
	if node == null or not node.is_inside_tree():
		return null
	node.pivot_offset = node.size * 0.5
	var tween := node.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(node, "scale", Vector2(amount, amount), FAST)
	return tween


static func settle(node: Control) -> Tween:
	if node == null or not node.is_inside_tree():
		return null
	var tween := node.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(node, "scale", Vector2.ONE, BASE)
	return tween


## Horizontal shake for rejected input. Decays so it never feels like a glitch.
static func refuse(node: CanvasItem, distance := 12.0) -> Tween:
	if node == null or not node.is_inside_tree():
		return null
	var home := _position_of(node)
	var property := "position"
	var tween := node.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	var swing := distance
	for _i in range(4):
		tween.tween_property(node, property, home + Vector2(swing, 0.0), 0.055)
		swing *= -0.55
	tween.tween_property(node, property, home, 0.075)
	return tween


## Counts a label from its current number to `to`, so scores tick up instead of
## teleporting. `format` receives the rounded value.
static func count_to(label: Label, from: int, to: int, duration := SLOW,
		format := "%d") -> Tween:
	if label == null or not label.is_inside_tree():
		return null
	if from == to:
		label.text = format % to
		return null
	var tween := label.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(func(value: float) -> void:
		if is_instance_valid(label):
			label.text = format % roundi(value)
	, float(from), float(to), duration)
	return tween


## Eases a bar to a new value rather than snapping it. Damage still needs to
## read as sudden, so drops move at roughly twice the speed of gains.
static func slide_bar(bar: Range, to: float, duration := BASE) -> Tween:
	if bar == null or not bar.is_inside_tree():
		return null
	var span := duration if to > bar.value else duration * 0.55
	var tween := bar.create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(bar, "value", to, span)
	return tween


# --------------------------------------------------------------------------
# Internals. Control and Node2D both expose `position`, but not through a
# shared base, so reading it needs a cast either way.
# --------------------------------------------------------------------------

static func _position_of(node: CanvasItem) -> Vector2:
	if node is Control:
		return (node as Control).position
	if node is Node2D:
		return (node as Node2D).position
	return Vector2.ZERO


static func _set_position(node: CanvasItem, value: Vector2) -> void:
	if node is Control:
		(node as Control).position = value
	elif node is Node2D:
		(node as Node2D).position = value
