class_name ResistDyeLoom
extends RefCounted
## Pure ikat logic for a t'nalak-inspired resist-and-dye bath.
##
## T'boli t'nalak is an ikat cloth: sections of abaca are bound so they refuse
## the dye, then the whole warp is lowered into the vat. Bound fibre stays
## cream. Unbound fibre takes the bath. This class is that sequence with no
## UI, no dialogue, and no chapter hooks — only state, guards, and a score.
##
## Consume it from a view or a chapter like this:
##   var loom := ResistDyeLoom.new()
##   loom.weaving_complete.connect(_on_weaving_complete)  # score: float 0..1
##   loom.start_new_cloth(Vector2i(8, 8))                 # or load_target(pattern)
##   loom.toggle_resist(cell)                             # BINDING only
##   loom.commit_binding()                                # BINDING -> DYEING
##   loom.apply_dye(ResistDyeLoom.DYE_BLACK)              # DYEING -> REVEAL
##   # Branch on score (or ResultTier) in the listener — never from this class.
##
## Difficulty knobs: grid_size, generate_target() motif, fail_below, mastery_at.

# --------------------------------------------------------------------------
# Data model
# --------------------------------------------------------------------------

## Working fibre. UNDYED is cream. RESISTED is bound and will refuse the vat.
## DYED_RED / DYED_BLACK are the two sacred t'nalak baths. Extra baths from
## register_dye() store their dye id (10+) directly in the cell.
enum ThreadState { UNDYED, RESISTED, DYED_RED, DYED_BLACK, DYED }

enum Phase { BINDING, DYEING, REVEAL }

## Branching helper for chapters / mini-game shells.
##   score <  FAIL_BELOW  -> FAIL     (cloth is not itself)
##   score <  MASTERY_AT  -> PASS     (the house accepts the work)
##   score >= MASTERY_AT  -> MASTERY  (the dream held)
enum ResultTier { FAIL, PASS, MASTERY }

const FAIL_BELOW := 0.5
const MASTERY_AT := 0.8
## Instance copies so a view can tune a House without forking this file.
var fail_below := FAIL_BELOW
var mastery_at := MASTERY_AT

## Built-in vat ids. Values match ThreadState for red/black so a 2D int grid
## can store the final cloth without a second lookup. Custom dyes use 10+.
const DYE_NONE := 0
const DYE_RED := ThreadState.DYED_RED
const DYE_BLACK := ThreadState.DYED_BLACK
const DYE_CUSTOM_BASE := 10

signal phase_changed(from_phase: Phase, to_phase: Phase)
signal cell_changed(cell: Vector2i, state: ThreadState)
## Fires once when REVEAL is entered. `score` is 0.0..1.0, `tier` is ResultTier.
signal revealed(score: float, tier: ResultTier)
## Quest-facing alias: same moment as `revealed`, score only so chapters can
## gate rewards without importing ResultTier.
signal weaving_complete(score: float)

## Final expected cloth: UNDYED (cream) or a dye id (DYE_BLACK, DYE_RED, …).
var target_pattern: Array = []
## Live warp. During BINDING this holds UNDYED / RESISTED. After the bath it
## holds the same encoding as target_pattern (cream vs dye id).
var loom_grid: Array = []
var grid_size := Vector2i(8, 8)
var phase: Phase = Phase.BINDING

var _dye_names: Dictionary = {
	DYE_RED: "red",
	DYE_BLACK: "black",
}
var _applied_dye := DYE_NONE
var _score := -1.0
var _tier: ResultTier = ResultTier.FAIL
var _next_custom_dye := DYE_CUSTOM_BASE


func start_new_cloth(size := Vector2i(8, 8), dye := DYE_BLACK, motif := "kleng") -> void:
	grid_size = Vector2i(maxi(size.x, 2), maxi(size.y, 2))
	_applied_dye = DYE_NONE
	_score = -1.0
	_set_phase(Phase.BINDING)
	target_pattern = generate_target(grid_size, dye, motif)
	loom_grid = _filled_grid(ThreadState.UNDYED)


## Replace the dream with a caller-authored grid (same encoding as target_pattern).
func load_target(pattern: Array) -> void:
	if pattern.is_empty() or (pattern[0] as Array).is_empty():
		push_warning("ResistDyeLoom.load_target: empty pattern")
		return
	grid_size = Vector2i((pattern[0] as Array).size(), pattern.size())
	target_pattern = _clone_grid(pattern)
	loom_grid = _filled_grid(ThreadState.UNDYED)
	_applied_dye = DYE_NONE
	_score = -1.0
	_set_phase(Phase.BINDING)


## Motif recipes. `kleng` is the lightning zigzag; `lozenge` is diamond chain;
## `bars` is a beginner stripe so early Houses can teach the vat without a maze.
func generate_target(size: Vector2i, dye: int = DYE_BLACK, motif := "kleng") -> Array:
	var dye_id := dye if is_dye(dye) else DYE_BLACK
	var w := maxi(size.x, 2)
	var h := maxi(size.y, 2)
	var grid := _filled_grid(ThreadState.UNDYED, Vector2i(w, h))
	for y in range(h):
		for x in range(w):
			var cream := false
			match motif:
				"bars":
					cream = (x % 2) == 0
				"lozenge":
					var dx := mini(x, w - 1 - x)
					var dy := mini(y, h - 1 - y)
					cream = (dx + dy) % 3 == 0
				_:
					# Kleng: a 45° zigzag band, two cream / two dyed.
					# int() because GDScript `/` on ints is float; pairs of rows must share a shift.
					var shift := 2 if int(y / 2.0) % 2 == 1 else 0
					cream = ((x + shift) % 4) < 2
			grid[y][x] = ThreadState.UNDYED if cream else dye_id
	return grid


## Extra baths (gold, a second black, etc.) so later Houses do not fork this file.
func register_dye(dye_name: String) -> int:
	var id := _next_custom_dye
	_next_custom_dye += 1
	_dye_names[id] = dye_name
	return id


func is_dye(dye_id: int) -> bool:
	return dye_id == DYE_RED or dye_id == DYE_BLACK or dye_id >= DYE_CUSTOM_BASE


func dye_name(dye_id: int) -> String:
	return str(_dye_names.get(dye_id, "dye"))


# --------------------------------------------------------------------------
# Binding phase
# --------------------------------------------------------------------------

## Tie or untie one cell. Only legal before the fibre enters the vat.
func toggle_resist(cell: Vector2i) -> bool:
	if phase != Phase.BINDING:
		return false
	if not _in_bounds(cell):
		return false
	var current: int = loom_grid[cell.y][cell.x]
	var next_state: int = ThreadState.UNDYED if current == ThreadState.RESISTED \
		else ThreadState.RESISTED
	loom_grid[cell.y][cell.x] = next_state
	cell_changed.emit(cell, next_state as ThreadState)
	return true


func is_resisted(cell: Vector2i) -> bool:
	return _in_bounds(cell) and int(loom_grid[cell.y][cell.x]) == ThreadState.RESISTED


func resist_count() -> int:
	var n := 0
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if int(loom_grid[y][x]) == ThreadState.RESISTED:
				n += 1
	return n


## BINDING -> DYEING. The ties are set; the vat is allowed to speak.
func commit_binding() -> bool:
	if phase != Phase.BINDING:
		return false
	_set_phase(Phase.DYEING)
	return true


# --------------------------------------------------------------------------
# Dye phase
# --------------------------------------------------------------------------

## Lower the warp into a bath. Unresisted cells take `dye_id`. Resisted cells
## shed their ties and set as cream (UNDYED). One bath per cloth — ikat is not
## undone.
##
## On success the dye "sets" immediately and the loom enters REVEAL. Pass
## auto_reveal = false if a view wants a beat of vat animation first, then
## call reveal() itself.
func apply_dye(dye_id: int, auto_reveal := true) -> bool:
	if phase != Phase.DYEING:
		return false
	if not is_dye(dye_id):
		return false
	if _applied_dye != DYE_NONE:
		return false
	var stored := _stored_dye_state(dye_id)
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var cell := Vector2i(x, y)
			if int(loom_grid[y][x]) == ThreadState.RESISTED:
				loom_grid[y][x] = ThreadState.UNDYED
			else:
				loom_grid[y][x] = stored
			cell_changed.emit(cell, int(loom_grid[y][x]) as ThreadState)
	_applied_dye = dye_id
	if auto_reveal:
		return reveal()
	return true


func applied_dye() -> int:
	return _applied_dye


# --------------------------------------------------------------------------
# Reveal phase + scoring
# --------------------------------------------------------------------------

## DYEING -> REVEAL. Scores the set cloth against the dream. Emits `revealed`.
func reveal() -> bool:
	if phase != Phase.DYEING:
		return false
	if _applied_dye == DYE_NONE:
		return false
	_score = compute_match()
	_tier = tier_for_score(_score, fail_below, mastery_at)
	_set_phase(Phase.REVEAL)
	revealed.emit(_score, _tier)
	weaving_complete.emit(_score)
	return true


## Cell-by-cell ratio in 0.0..1.0. Cream must stay cream; dyed cells must
## carry the same bath as the target. Tune FAIL_BELOW / MASTERY_AT rather
## than this function if a House needs to be kinder or stricter.
func compute_match() -> float:
	var total := grid_size.x * grid_size.y
	if total <= 0:
		return 0.0
	var hits := 0
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if int(loom_grid[y][x]) == int(target_pattern[y][x]):
				hits += 1
	return float(hits) / float(total)


func last_score() -> float:
	return _score


func last_tier() -> ResultTier:
	return _tier


static func tier_for_score(score: float, fail_at := FAIL_BELOW, mastery := MASTERY_AT) -> ResultTier:
	if score < fail_at:
		return ResultTier.FAIL
	if score < mastery:
		return ResultTier.PASS
	return ResultTier.MASTERY


func passed() -> bool:
	return _tier == ResultTier.PASS or _tier == ResultTier.MASTERY


# --------------------------------------------------------------------------
# Internals
# --------------------------------------------------------------------------

func _set_phase(next: Phase) -> void:
	var previous := phase
	if previous == next:
		return
	phase = next
	phase_changed.emit(previous, next)


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y


func _filled_grid(fill: int, size := Vector2i.ZERO) -> Array:
	var dim := grid_size if size == Vector2i.ZERO else size
	var rows: Array = []
	for _y in range(dim.y):
		var row: Array[int] = []
		row.resize(dim.x)
		row.fill(fill)
		rows.append(row)
	return rows


func _clone_grid(source: Array) -> Array:
	var rows: Array = []
	for y in range(source.size()):
		var src_row: Array = source[y]
		var row: Array[int] = []
		for x in range(src_row.size()):
			row.append(int(src_row[x]))
		rows.append(row)
	return rows


func _stored_dye_state(dye_id: int) -> int:
	if dye_id == DYE_RED:
		return ThreadState.DYED_RED
	if dye_id == DYE_BLACK:
		return ThreadState.DYED_BLACK
	return dye_id
