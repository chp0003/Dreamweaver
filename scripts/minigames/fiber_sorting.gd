extends MiniGameBase
## Chapter 1 - "Fiber Sorting".
##
## Ten stripped abaca strands sit on the drying rack. The player drags each one
## into the viable basket or the brittle basket before the timer runs out. The
## strand's description is the only tell, so the player learns what the Spirit of
## the Fiber has forgotten: supple fibre holds a knot, brittle fibre snaps.

const REQUIRED_CORRECT := 8

const VIABLE_DESCRIPTORS := [
	"Long and supple. Holds a knot without slipping.",
	"Combed hair-thin, even sheen along its length.",
	"Bends double and springs back straight.",
	"Cool and slightly damp. Pliant between the fingers.",
	"Unbroken from base to tip. No splits.",
	"Silky, pale cream. Takes the dye evenly.",
]

const BRITTLE_DESCRIPTORS := [
	"Snaps clean in half when bent.",
	"Cracked and sun-dried. Powders at the edge.",
	"Short, with frayed ends that will not knot.",
	"Splits into three the moment it is pulled.",
	"Stiff as straw. Rattles when shaken.",
	"Mottled and rotted through the middle.",
]

var _tray: GridContainer
var _viable_bin: FiberBin
var _brittle_bin: FiberBin
var _cards: Array[FiberCard] = []
var _sorted := 0
var _correct := 0
var _total := 10


func _configure() -> void:
	mini_game_title = "Fiber Sorting"
	mini_game_subtitle = "House of the Black Foundation"
	instructions = "Drag each strand into a basket. Viable fibre bends and holds a knot; brittle fibre snaps, cracks or frays. Sort at least %d of %d correctly." % [
		REQUIRED_CORRECT, _total]


func _build_content(parent: Control) -> void:
	var bins := HBoxContainer.new()
	bins.add_theme_constant_override("separation", 24)
	bins.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(bins)

	_viable_bin = FiberBin.new()
	_viable_bin.bin_title = "Viable Fibre"
	_viable_bin.bin_hint = "For the loom"
	_viable_bin.accepts_brittle = false
	_viable_bin.accent = Color(0.86, 0.76, 0.5)
	_viable_bin.card_dropped.connect(_on_card_dropped)
	bins.add_child(_viable_bin)

	_brittle_bin = FiberBin.new()
	_brittle_bin.bin_title = "Brittle Fibre"
	_brittle_bin.bin_hint = "For the fire"
	_brittle_bin.accepts_brittle = true
	_brittle_bin.accent = Color(0.7, 0.34, 0.28)
	_brittle_bin.card_dropped.connect(_on_card_dropped)
	bins.add_child(_brittle_bin)

	var rack_label := Label.new()
	rack_label.text = "THE DRYING RACK"
	rack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rack_label.theme_type_variation = &"FieldLabel"
	parent.add_child(rack_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	_tray = GridContainer.new()
	_tray.columns = 5
	_tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tray.add_theme_constant_override("h_separation", 12)
	_tray.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_tray)


func _reset_round() -> void:
	for card in _cards:
		if is_instance_valid(card):
			card.queue_free()
	_cards.clear()
	_sorted = 0
	_correct = 0
	_viable_bin.reset_count()
	_brittle_bin.reset_count()

	# Half the strands are usable, dealt from shuffled descriptions so a retry is
	# a genuinely new hand rather than the same layout again.
	var viable := VIABLE_DESCRIPTORS.duplicate()
	var brittle := BRITTLE_DESCRIPTORS.duplicate()
	viable.shuffle()
	brittle.shuffle()

	var deck: Array[Dictionary] = []
	for i in range(floori(float(_total) / 2.0)):
		deck.append({"brittle": false, "text": str(viable[i % viable.size()])})
		deck.append({"brittle": true, "text": str(brittle[i % brittle.size()])})
	deck.shuffle()

	for entry in deck:
		var card := FiberCard.new()
		card.brittle = bool(entry["brittle"])
		card.descriptor = str(entry["text"])
		_tray.add_child(card)
		_cards.append(card)

	_update_status()


func _on_card_dropped(card: FiberCard, bin: FiberBin) -> void:
	if not running or card == null or not is_instance_valid(card):
		return

	var right := card.brittle == bin.accepts_brittle
	if right:
		_correct += 1
		GameState.add_score(15)
	_sorted += 1
	bin.add_count()

	_cards.erase(card)
	card.queue_free()
	_update_status(right)

	if _sorted >= _total:
		_evaluate()


func _evaluate() -> void:
	if _correct >= REQUIRED_CORRECT:
		GameState.unlock_lore("abaca")
		succeed("%d of %d strands sorted true. The Spirit of the Fiber remembers the feel of good abaca." % [_correct, _total])
	else:
		fail("Only %d of %d strands were sorted true. The vat needs at least %d." % [
			_correct, _total, REQUIRED_CORRECT])


func _update_status(last_was_right := true) -> void:
	var remaining := _total - _sorted
	var verdict := ""
	if _sorted > 0:
		verdict = "  -  last strand judged well." if last_was_right \
			else "  -  that one was misjudged."
	set_status("Sorted %d / %d   (correct: %d)%s" % [_sorted, _total, _correct, verdict])
	if remaining == 0:
		set_status("Rack empty. Correct: %d / %d" % [_correct, _total])
