class_name TnalakCloth
extends RefCounted
## Strand-by-strand ikat loom. Pure state — no UI, no dialogue, no scoring gate.
##
## The player binds, dyes, and weaves one abaca strand at a time. Each woven
## strand is a permanent row (or column) of the cloth. When the last strand is
## woven, `loom_grid` *is* the finished t'nalak: unique to that playthrough,
## not a match against a hidden target.
##
## Stage loop per strand (tune guards here, not in the view):
##   UNSTARTED --begin--> BINDING
##   BINDING   --commit_binding()--> DYEING     toggle_resist() only here
##   DYEING    --apply_dye(color)--> DYEING     one bath; ties become cream
##   DYEING    --weave()--> WOVEN               then the next strand begins
##
## Renderer: iterate `strands` (or call `display_grid()`). UNSTARTED slots are
## empty; BINDING/DYEING is the working strand in place; WOVEN is settled cloth.
##
## Item handoff: listen to `cloth_completed`, then
##   GameState.add_item("tnalak_cloth")
##   var payload := cloth.to_dictionary()   # persist / thumbnail / codex
## The cloth object is the reward. `harmony()` is flavor only — never a gate.

# --------------------------------------------------------------------------
# Data model
# --------------------------------------------------------------------------

## One segment of fibre.
## RAW is cream: unworked before the vat, and the set color of a resisted
## segment after the dye "takes". RESISTED exists only during BINDING.
## DYED_RED / DYED_BLACK are the two traditional baths. Custom dyes from
## register_dye() store their id (10+) directly in `segments`.
enum SegmentState { RAW, RESISTED, DYED_RED, DYED_BLACK }

## Per-strand stage. The cloth's "phase" is just the active strand's stage.
enum StrandStage { UNSTARTED, BINDING, DYEING, WOVEN }

## ROWS: each strand is a weft row (cloth grows downward).
## COLUMNS: each strand is a warp column (cloth grows sideways).
enum Axis { ROWS, COLUMNS }

const EMPTY := -1
const DYE_NONE := 0
const DYE_RED := SegmentState.DYED_RED
const DYE_BLACK := SegmentState.DYED_BLACK
const DYE_CUSTOM_BASE := 10
const ITEM_ID := "tnalak_cloth"

signal segment_changed(strand_index: int, segment_index: int, state: int)
signal strand_stage_changed(strand_index: int, from_stage: StrandStage, to_stage: StrandStage)
signal strand_woven(strand_index: int)
signal progress_changed(completion: float)
## Fires once, carrying this cloth. Chapters bank it; they do not score it.
signal cloth_completed(cloth: TnalakCloth)

var grid_size := Vector2i(8, 8)
var axis: Axis = Axis.ROWS
## Ordered. Index is the row (ROWS) or column (COLUMNS) the strand will occupy.
var strands: Array = []
var completion := 0.0
var is_complete := false
## Index of the strand currently in BINDING or DYEING. -1 when complete.
var active_index := -1

var _dye_names: Dictionary = {
	DYE_RED: "red",
	DYE_BLACK: "black",
}
var _next_custom_dye := DYE_CUSTOM_BASE


## One abaca strand. `id` is its slot on the cloth. `segments` is 1D, length
## matching the other axis of `grid_size`. `dye_id` is DYE_NONE until apply_dye.
class Strand extends RefCounted:
	var id := 0
	var segments: Array[int] = []
	var stage: int = 0
	var dye_id := 0

	func length() -> int:
		return segments.size()

	func is_woven() -> bool:
		return stage == TnalakCloth.StrandStage.WOVEN

	func dye_is_set() -> bool:
		return dye_id != TnalakCloth.DYE_NONE


# --------------------------------------------------------------------------
# Lifecycle
# --------------------------------------------------------------------------

## Build N empty RAW strands and open strand 0 for binding.
## N = grid_size.y for ROWS, grid_size.x for COLUMNS.
func start_new_cloth(size := Vector2i(8, 8), weave_axis: Axis = Axis.ROWS) -> void:
	grid_size = Vector2i(maxi(size.x, 2), maxi(size.y, 2))
	axis = weave_axis
	is_complete = false
	completion = 0.0
	active_index = -1
	strands.clear()
	var count := strand_count()
	var length := strand_length()
	for i in range(count):
		var strand := Strand.new()
		strand.id = i
		strand.stage = StrandStage.UNSTARTED
		strand.dye_id = DYE_NONE
		strand.segments = _filled_segments(SegmentState.RAW, length)
		strands.append(strand)
	_begin_strand(0)
	progress_changed.emit(completion)


func strand_count() -> int:
	return grid_size.y if axis == Axis.ROWS else grid_size.x


func strand_length() -> int:
	return grid_size.x if axis == Axis.ROWS else grid_size.y


func active_strand() -> Strand:
	if active_index < 0 or active_index >= strands.size():
		return null
	return strands[active_index] as Strand


func strand_at(index: int) -> Strand:
	if index < 0 or index >= strands.size():
		return null
	return strands[index] as Strand


func woven_count() -> int:
	var n := 0
	for entry in strands:
		if (entry as Strand).is_woven():
			n += 1
	return n


# --------------------------------------------------------------------------
# BIND — toggle ties on the active strand
# --------------------------------------------------------------------------

## Tie or untie one segment. Only legal in BINDING, before the vat.
func toggle_resist(segment_index: int) -> bool:
	var strand := active_strand()
	if strand == null or strand.stage != StrandStage.BINDING:
		return false
	if segment_index < 0 or segment_index >= strand.segments.size():
		return false
	var current: int = strand.segments[segment_index]
	var next_state: int = SegmentState.RAW if current == SegmentState.RESISTED \
		else SegmentState.RESISTED
	strand.segments[segment_index] = next_state
	segment_changed.emit(active_index, segment_index, next_state)
	return true


func resist_count() -> int:
	var strand := active_strand()
	if strand == null:
		return 0
	var n := 0
	for state in strand.segments:
		if int(state) == SegmentState.RESISTED:
			n += 1
	return n


## BINDING -> DYEING. Ties lock; dye is the only legal next input.
func commit_binding() -> bool:
	var strand := active_strand()
	if strand == null or strand.stage != StrandStage.BINDING:
		return false
	_set_stage(strand, StrandStage.DYEING)
	return true


# --------------------------------------------------------------------------
# DYE — one bath on the active strand
# --------------------------------------------------------------------------

## Untied segments take `dye_id`. Tied segments shed their resist and set as
## cream (RAW). One bath per strand — ikat is not undone.
func apply_dye(dye_id: int) -> bool:
	var strand := active_strand()
	if strand == null or strand.stage != StrandStage.DYEING:
		return false
	if strand.dye_is_set():
		return false
	if not is_dye(dye_id):
		return false
	var stored := _stored_dye_state(dye_id)
	for i in range(strand.segments.size()):
		if int(strand.segments[i]) == SegmentState.RESISTED:
			strand.segments[i] = SegmentState.RAW
		else:
			strand.segments[i] = stored
		segment_changed.emit(active_index, i, int(strand.segments[i]))
	strand.dye_id = dye_id
	return true


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
# WEAVE — lock the strand into the cloth and advance
# --------------------------------------------------------------------------

## DYEING (dye set) -> WOVEN. The strand occupies its index on the cloth for
## good. Then the next UNSTARTED strand opens for binding, or the cloth
## completes.
func weave() -> bool:
	var strand := active_strand()
	if strand == null or strand.stage != StrandStage.DYEING:
		return false
	if not strand.dye_is_set():
		return false
	_set_stage(strand, StrandStage.WOVEN)
	_refresh_completion()
	strand_woven.emit(strand.id)
	progress_changed.emit(completion)
	if woven_count() >= strand_count():
		is_complete = true
		active_index = -1
		cloth_completed.emit(self)
		return true
	_begin_strand(strand.id + 1)
	return true


## BINDING or DYEING -> dye this strand and weave it in one step.
## View shortcut so a House can skip the extra buttons.
func dye_and_weave(dye_id: int) -> bool:
	var strand := active_strand()
	if strand == null:
		return false
	if strand.stage == StrandStage.BINDING:
		if not commit_binding():
			return false
	if not strand.dye_is_set() and not apply_dye(dye_id):
		return false
	return weave()


# --------------------------------------------------------------------------
# Renderer / item helpers
# --------------------------------------------------------------------------

## 2D grid a view can paint as-is. WOVEN and in-progress strands show their
## segments in slot; UNSTARTED slots are EMPTY (-1) so the cloth reads as
## growing rather than appearing all at once.
func display_grid() -> Array:
	var rows: Array = []
	if axis == Axis.ROWS:
		for y in range(grid_size.y):
			var strand: Strand = strands[y] if y < strands.size() else null
			if strand == null or strand.stage == StrandStage.UNSTARTED:
				rows.append(_filled_segments(EMPTY, grid_size.x))
			else:
				rows.append(strand.segments.duplicate())
		return rows
	for y in range(grid_size.y):
		var row: Array[int] = []
		row.resize(grid_size.x)
		for x in range(grid_size.x):
			var strand: Strand = strands[x] if x < strands.size() else null
			if strand == null or strand.stage == StrandStage.UNSTARTED:
				row[x] = EMPTY
			else:
				row[x] = int(strand.segments[y])
		rows.append(row)
	return rows


## Settled cloth only. Unwoven slots stay EMPTY. Same encoding as display_grid
## once `is_complete` — this *is* the finished textile.
func loom_grid() -> Array:
	var rows: Array = []
	if axis == Axis.ROWS:
		for y in range(grid_size.y):
			var strand: Strand = strands[y] if y < strands.size() else null
			if strand != null and strand.is_woven():
				rows.append(strand.segments.duplicate())
			else:
				rows.append(_filled_segments(EMPTY, grid_size.x))
		return rows
	for y in range(grid_size.y):
		var row: Array[int] = []
		row.resize(grid_size.x)
		for x in range(grid_size.x):
			var strand: Strand = strands[x] if x < strands.size() else null
			row[x] = int(strand.segments[y]) if strand != null and strand.is_woven() else EMPTY
		rows.append(row)
	return rows


## Flavor 0..1: how often neighbouring woven strands share a segment color.
## Identical rows sit high; noisy rows sit low. Never used as pass/fail.
func harmony() -> float:
	var woven: Array = []
	for entry in strands:
		var strand := entry as Strand
		if strand.is_woven():
			woven.append(strand)
	if woven.size() <= 1:
		return 1.0 if not woven.is_empty() else 0.0
	var hits := 0
	var total := 0
	for i in range(1, woven.size()):
		var a: Array[int] = (woven[i - 1] as Strand).segments
		var b: Array[int] = (woven[i] as Strand).segments
		var n := mini(a.size(), b.size())
		total += n
		for s in range(n):
			if int(a[s]) == int(b[s]):
				hits += 1
	return float(hits) / float(total) if total > 0 else 0.0


## JSON-friendly payload for inventory, save, or a later thumbnail.
func to_dictionary() -> Dictionary:
	var packed: Array = []
	for entry in strands:
		var strand := entry as Strand
		packed.append({
			"id": strand.id,
			"stage": strand.stage,
			"dye_id": strand.dye_id,
			"segments": strand.segments.duplicate(),
		})
	return {
		"item_id": ITEM_ID,
		"grid_size": [grid_size.x, grid_size.y],
		"axis": int(axis),
		"completion": completion,
		"is_complete": is_complete,
		"harmony": harmony(),
		"strands": packed,
	}


# --------------------------------------------------------------------------
# Internals
# --------------------------------------------------------------------------

func _begin_strand(index: int) -> void:
	if index < 0 or index >= strands.size():
		return
	var strand := strands[index] as Strand
	if strand.stage != StrandStage.UNSTARTED:
		return
	active_index = index
	_set_stage(strand, StrandStage.BINDING)


func _set_stage(strand: Strand, next: StrandStage) -> void:
	var previous: int = strand.stage
	if previous == next:
		return
	strand.stage = next
	strand_stage_changed.emit(strand.id, previous as StrandStage, next)


func _refresh_completion() -> void:
	var total := strand_count()
	completion = float(woven_count()) / float(total) if total > 0 else 0.0


func _filled_segments(fill: int, length: int) -> Array[int]:
	var row: Array[int] = []
	row.resize(maxi(length, 0))
	row.fill(fill)
	return row


func _stored_dye_state(dye_id: int) -> int:
	if dye_id == DYE_RED:
		return SegmentState.DYED_RED
	if dye_id == DYE_BLACK:
		return SegmentState.DYED_BLACK
	return dye_id
