extends RefCounted
## Shared look for menus (telecom, crafting, inventory, pause).
##   const UI = preload("res://scenes/ui/ui_kit.gd")
##   var panel := UI.panel()            dark navy box with a cyan edge
##   UI.label("TEXT", 20, UI.GOLD)
##   UI.button("CRAFT", enabled, UI.EDGE)
##   UI.icon(path, frames, scale)

const BG := Color(0.07, 0.09, 0.16, 0.96)
const EDGE := Color(0.35, 0.7, 1.0)
const DIM := Color(0.6, 0.68, 0.8)
const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.45, 0.4)
const GOLD := Color(1.0, 0.85, 0.3)
const CARD := Color(0.1, 0.14, 0.24)
const CARD_EDGE := Color(0.25, 0.45, 0.75)


static func style(bg: Color, edge: Color, w: int = 3, margin: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(w)
	s.set_content_margin_all(margin)
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 6
	return s


static func panel(edge: Color = EDGE, min_w: float = 0.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(BG, edge, 3, 16))
	p.custom_minimum_size = Vector2(min_w, 0)
	return p


static func card(edge: Color = CARD_EDGE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(CARD, edge, 2, 10))
	return p


static func label(text: String, size: int, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0.05))
	return l


static func icon(path: String, frames: int, k: float = 2.0) -> TextureRect:
	var tex: Texture2D = load(path)
	var a := AtlasTexture.new()
	a.atlas = tex
	var fw := tex.get_width() / frames
	a.region = Rect2(0, 0, fw, tex.get_height())
	var r := TextureRect.new()
	r.texture = a
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.custom_minimum_size = Vector2(fw, tex.get_height()) * k
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return r


static func button(text: String, enabled: bool, color: Color, size: int = 16) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", style(color.darkened(0.6), color, 2, 8))
	b.add_theme_stylebox_override("hover", style(color.darkened(0.4), color.lightened(0.3), 2, 8))
	b.add_theme_stylebox_override("pressed", style(color.darkened(0.2), Color.WHITE, 2, 8))
	b.add_theme_stylebox_override("disabled", style(Color(0.12, 0.12, 0.16), Color(0.3, 0.3, 0.35), 2, 8))
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.5))
	return b


static func section(title: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(label(title, 15, EDGE))
	return v


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


## full-screen layer that centers one panel and dims the game behind it
static func overlay(parent: Node, dim: float = 0.45) -> CenterContainer:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, dim)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	return c


## little "item x3" row
static func item_row(id: String, n: int, info: Dictionary, k: float = -1.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var frames: int = info.get("frames", 1)
	if k < 0.0:
		k = 1.6 if frames == 1 else 1.0
	row.add_child(icon(info.icon, frames, k))
	row.add_child(label("%s  x%d" % [info.name, n] if n >= 0 else info.name, 15))
	return row
