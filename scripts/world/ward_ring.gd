class_name WardRing
extends Sprite2D
## A thin circle of light that turns around S'lang while the ward is up.

const RING := "res://assets/images/vfx/ward_ring.png"


func _ready() -> void:
	centered = true
	texture = Palette.read_texture(RING)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	z_index = 6
	z_as_relative = true
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = glow
	set_process(true)


func _process(delta: float) -> void:
	rotation += delta * 1.7
