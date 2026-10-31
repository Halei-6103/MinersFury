extends Control
## Pixel hearts in the top-left. The player calls set_health when it changes.

@export var heart_size: int = 3          # pixel size of one "heart pixel"
@export var full_color: Color = Color(0.9, 0.2, 0.25)
@export var empty_color: Color = Color(0.22, 0.18, 0.2, 0.85)
@export var outline_color: Color = Color(0.08, 0.05, 0.06)

var health: int = 5
var max_health: int = 5

# 7x6 heart, 1 = fill
const SHAPE := [
	"0110110",
	"1111111",
	"1111111",
	"0111110",
	"0011100",
	"0001000",
]

func set_health(h: int, m: int) -> void:
	health = h
	max_health = m
	queue_redraw()

func _draw() -> void:
	var s := heart_size
	for i in max_health:
		var origin := Vector2(i * (8 * s + 4), 0)
		var col := full_color if i < health else empty_color
		for y in SHAPE.size():
			for x in SHAPE[y].length():
				if SHAPE[y][x] == "1":
					draw_rect(Rect2(origin + Vector2(x * s - 1, y * s - 1), Vector2(s + 2, s + 2)), outline_color)
		for y in SHAPE.size():
			for x in SHAPE[y].length():
				if SHAPE[y][x] == "1":
					var c := col
					if i < health and y == 1 and x in [1, 2]:
						c = Color(1, 0.65, 0.65)  # little shine
					draw_rect(Rect2(origin + Vector2(x * s, y * s), Vector2(s, s)), c)
