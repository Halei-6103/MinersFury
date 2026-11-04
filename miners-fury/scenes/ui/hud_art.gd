extends RefCounted
## Shared look for the HUD: the font, the yellow dashed outlines, and your own
## art when you add it.
##
## Your own HUD art goes in res://assets/sprites/ui/. When a file with one of
## these names is there, the HUD draws it instead of its stand-in shapes:
##   heart_full.png, heart_empty.png   (7 x 6)
##   weapon_<id>.png                   (16 x 16, e.g. weapon_flame_blade.png)
## Draw at 1x; the HUD scales it up with crisp pixels.
##
## Font: JetBrains Mono (assets/fonts, SIL Open Font License, see the OFL file there).

const DIR := "res://assets/sprites/ui/"
const FONT_BOLD := "res://assets/fonts/JetBrainsMono-Bold.ttf"
const FONT_MEDIUM := "res://assets/fonts/JetBrainsMono-Medium.ttf"
## colours from the HUD mockup
const YELLOW := Color(1.0, 0.839, 0.42)       # dashed outlines
const PANEL := Color(0.078, 0.078, 0.075, 0.55) # see-through dark box fill
const TEXT := Color(0.953, 0.933, 0.902)
const RED := Color(0.784, 0.196, 0.235)
const BLUE := Color(0.239, 0.561, 0.839)

static var _cache: Dictionary = {}
static var _fonts: Dictionary = {}


static func get_art(file: String) -> Texture2D:
	if _cache.has(file):
		return _cache[file]
	var path := DIR + file + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
	_cache[file] = tex
	return tex


static func font(bold: bool = true) -> Font:
	var path := FONT_BOLD if bold else FONT_MEDIUM
	if not _fonts.has(path):
		_fonts[path] = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
	return _fonts[path]


## the mockup's box: see-through dark fill with a yellow dashed border
static func panel(ci: CanvasItem, r: Rect2, alpha: float = 1.0) -> void:
	ci.draw_rect(r, Color(PANEL, PANEL.a * alpha))
	dashed_rect(ci, r, Color(YELLOW, alpha))


## text with a soft dark outline, left edge at `at` (baseline)
static func text(ci: CanvasItem, at: Vector2, s: String, size: int, col: Color = TEXT, bold: bool = true) -> void:
	var f := font(bold)
	ci.draw_string_outline(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0.05, 0.03, 0.05, 0.7 * col.a))
	ci.draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## same, centred on x
static func text_c(ci: CanvasItem, at: Vector2, s: String, size: int, col: Color = TEXT, bold: bool = true) -> void:
	var w := font(bold).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text(ci, at - Vector2(w * 0.5, 0), s, size, col, bold)


## a dashed rectangle outline
static func dashed_rect(ci: CanvasItem, r: Rect2, col: Color = YELLOW, width: float = 2.0, dash: float = 6.0) -> void:
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		ci.draw_dashed_line(pts[i], pts[i + 1], col, width, dash, true, true)


## a ring of dashes. The first `fill` (0..1) of them, clockwise from the top,
## use `col`; the rest use `empty_col` (left out when it's fully clear).
static func dashed_ring(ci: CanvasItem, c: Vector2, radius: float, col: Color = YELLOW, width: float = 2.0, segs: int = 24, fill: float = 1.0, empty_col: Color = Color(0, 0, 0, 0)) -> void:
	var slot := TAU / segs
	var on := slot * 0.62
	var lit := clampf(fill, 0.0, 1.0) * segs
	for i in segs:
		var a0 := -PI / 2.0 + i * slot
		var part := clampf(lit - i, 0.0, 1.0)
		if part >= 1.0:
			ci.draw_arc(c, radius, a0, a0 + on, 8, col, width, true)
		else:
			if empty_col.a > 0.0:
				ci.draw_arc(c, radius, a0, a0 + on, 8, empty_col, width, true)
			if part > 0.0:
				ci.draw_arc(c, radius, a0, a0 + on * part, 8, col, width, true)
