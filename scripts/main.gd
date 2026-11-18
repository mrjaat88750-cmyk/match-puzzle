extends Control

# Original 2D arrow-escape puzzle. All board coordinates are on a 6x6 grid.
const BG := Color("#F7F9FD")
const NAVY := Color("#111B4D")
const BLUE := Color("#168BEA")
const LIGHT_BLUE := Color("#EAF5FF")
const MUTED := Color("#8C96A9")
const RED := Color("#F04455")
const GRID := 6
const BOARD_SIZE := 540.0
const BOARD_ORIGIN := Vector2(90, 390)

var level := 1
var lives := 3
var hints := 2
var removed := 0
var arrows: Array[Dictionary] = []
var history: Array = []
var selected := -1
var hint_index := -1
var state := "playing"
var message := ""
var message_timer := 0.0
var sound_on := true
var music_on := false

# Each arrow is a polyline. Its final segment determines its exit direction.
# The levels are intentionally authored as original layouts, not copied boards.
var level_templates: Array = [
    [
        [[0,0],[2,0],[2,2]], [[4,0],[4,2],[6,2]],
        [[0,3],[2,3],[2,5]], [[4,6],[4,4],[6,4]],
        [[0,6],[1,6],[1,4]], [[3,3],[5,3],[5,5]]
    ],
    [
        [[0,1],[2,1],[2,3]], [[3,0],[3,2],[5,2]],
        [[0,4],[2,4],[2,6]], [[4,6],[4,4],[6,4]],
        [[6,0],[5,0],[5,1]], [[3,6],[3,5],[1,5]]
    ],
    [
        [[0,0],[0,2],[2,2]], [[2,0],[4,0],[4,2]],
        [[6,1],[4,1],[4,3]], [[0,4],[2,4],[2,6]],
        [[6,5],[4,5],[4,3]], [[1,6],[1,5],[3,5]],
        [[3,3],[3,4],[5,4]]
    ],
    [
        [[0,2],[2,2],[2,0]], [[3,0],[3,2],[5,2]],
        [[6,3],[4,3],[4,5]], [[3,6],[3,4],[1,4]],
        [[0,5],[2,5],[2,3]], [[5,6],[5,5],[6,5]],
        [[1,0],[1,1],[0,1]]
    ]
]

func _ready() -> void:
    set_process(true)
    _load_progress()
    _make_level()
    queue_redraw()

func _process(delta: float) -> void:
    if message_timer > 0.0:
        message_timer -= delta
        if message_timer <= 0.0:
            message = ""
            queue_redraw()

func _draw() -> void:
    var size := get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, size), BG)
    # Header
    draw_string(ThemeDB.fallback_font, Vector2(42, 64), "ARROW ESCAPE", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, NAVY)
    draw_string(ThemeDB.fallback_font, Vector2(44, 96), "Tap the arrows. Clear the board.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, MUTED)
    _draw_round_rect(Rect2(42, 124, 636, 96), Color.WHITE, 24)
    draw_string(ThemeDB.fallback_font, Vector2(70, 164), "LEVEL %03d" % level, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, NAVY)
    draw_string(ThemeDB.fallback_font, Vector2(70, 194), _difficulty_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, MUTED)
    for i in range(3):
        draw_string(ThemeDB.fallback_font, Vector2(410 + i * 54, 184), "♥", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, RED if i < lives else Color("#DDE2EA"))
    # Board card and grid
    _draw_round_rect(Rect2(42, 252, 636, 690), Color.WHITE, 28)
    var cell := BOARD_SIZE / float(GRID)
    for x in range(GRID + 1):
        for y in range(GRID + 1):
            var p := BOARD_ORIGIN + Vector2(x * cell, y * cell)
            draw_circle(p, 3.3, Color("#D8DEE9"))
    for i in range(arrows.size()):
        var a: Dictionary = arrows[i]
        if a.get("removed", false):
            continue
        var pts: Array = a["points"]
        var points := PackedVector2Array()
        for p in pts:
            points.append(_grid_to_screen(Vector2(p[0], p[1])))
        var col := BLUE if i == selected or i == hint_index else NAVY
        var width := 10.0 if i == selected or i == hint_index else 8.0
        if points.size() >= 2:
            draw_polyline(points, col, width, true)
            _draw_arrow_head(points[points.size()-2], points[points.size()-1], col)
    # Footer actions
    _draw_round_rect(Rect2(52, 986, 180, 104), LIGHT_BLUE, 24)
    draw_string(ThemeDB.fallback_font, Vector2(85, 1030), "↶  UNDO", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, BLUE)
    draw_string(ThemeDB.fallback_font, Vector2(85, 1062), "Previous move", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MUTED)
    _draw_round_rect(Rect2(270, 986, 180, 104), LIGHT_BLUE, 24)
    draw_string(ThemeDB.fallback_font, Vector2(304, 1030), "✦  HINT", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, BLUE)
    draw_string(ThemeDB.fallback_font, Vector2(304, 1062), "%d hints left" % hints, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MUTED)
    _draw_round_rect(Rect2(488, 986, 180, 104), LIGHT_BLUE, 24)
    draw_string(ThemeDB.fallback_font, Vector2(519, 1030), "⟳  RESTART", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, BLUE)
    draw_string(ThemeDB.fallback_font, Vector2(519, 1062), "Try this level", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, MUTED)
    draw_string(ThemeDB.fallback_font, Vector2(42, 1150), "ARROWS LEFT: %d" % (arrows.size() - removed), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, NAVY)
    draw_string(ThemeDB.fallback_font, Vector2(678, 1150), "%d%%" % int(float(removed) / max(1, arrows.size()) * 100.0), HORIZONTAL_ALIGNMENT_RIGHT, -1, 19, BLUE)
    _draw_round_rect(Rect2(42, 1170, 636, 12), Color("#E5EAF2"), 6)
    _draw_round_rect(Rect2(42, 1170, 636.0 * float(removed) / max(1, arrows.size()), 12), BLUE, 6)
    if message != "":
        _draw_round_rect(Rect2(95, 880, 530, 58), Color("#17234F"), 18)
        draw_string(ThemeDB.fallback_font, Vector2(360, 917), message, HORIZONTAL_ALIGNMENT_CENTER, 480, 20, Color.WHITE)
    if state != "playing":
        _draw_overlay()

func _draw_overlay() -> void:
    draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0.03, 0.06, 0.16, 0.72))
    _draw_round_rect(Rect2(72, 420, 576, 390), Color.WHITE, 32)
    var title := "LEVEL COMPLETED!" if state == "won" else "NO LIVES LEFT"
    draw_string(ThemeDB.fallback_font, Vector2(360, 510), title, HORIZONTAL_ALIGNMENT_CENTER, 520, 34, NAVY)
    var sub := "Great focus! Ready for the next puzzle?" if state == "won" else "Take a breath and try this puzzle again."
    draw_string(ThemeDB.fallback_font, Vector2(360, 560), sub, HORIZONTAL_ALIGNMENT_CENTER, 500, 18, MUTED)
    _draw_round_rect(Rect2(150, 630, 420, 74), BLUE, 24)
    draw_string(ThemeDB.fallback_font, Vector2(360, 678), "CONTINUE" if state == "won" else "TRY AGAIN", HORIZONTAL_ALIGNMENT_CENTER, 380, 25, Color.WHITE)

func _draw_round_rect(rect: Rect2, color: Color, radius: float) -> void:
    draw_rect(rect, color)
    # Soft rounded-looking corner circles; keeps the project dependency-free.
    draw_circle(rect.position + Vector2(radius, radius), radius, color)
    draw_circle(rect.position + Vector2(rect.size.x-radius, radius), radius, color)
    draw_circle(rect.position + Vector2(radius, rect.size.y-radius), radius, color)
    draw_circle(rect.position + rect.size - Vector2(radius, radius), radius, color)
    draw_rect(Rect2(rect.position.x, rect.position.y + radius, rect.size.x, rect.size.y - 2*radius), color)
    draw_rect(Rect2(rect.position.x + radius, rect.position.y, rect.size.x - 2*radius, rect.size.y), color)

func _grid_to_screen(p: Vector2) -> Vector2:
    return BOARD_ORIGIN + p * (BOARD_SIZE / float(GRID))

func _draw_arrow_head(from: Vector2, tip: Vector2, color: Color) -> void:
    var d := (tip - from).normalized()
    var side := Vector2(-d.y, d.x)
    var base := tip - d * 24.0
    var tri := PackedVector2Array([tip + d * 2.0, base + side * 13.0, base - side * 13.0])
    draw_colored_polygon(tri, color)

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        _handle_tap(event.position)
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _handle_tap(event.position)

func _handle_tap(pos: Vector2) -> void:
    if state != "playing":
        if Rect2(120, 600, 480, 110).has_point(pos):
            if state == "won":
                level += 1
                _save_progress()
                _make_level()
            else:
                _restart_level()
        queue_redraw()
        return
    if Rect2(52, 986, 180, 104).has_point(pos):
        _undo()
        return
    if Rect2(270, 986, 180, 104).has_point(pos):
        _use_hint()
        return
    if Rect2(488, 986, 180, 104).has_point(pos):
        _restart_level()
        return
    if Rect2(BOARD_ORIGIN, Vector2(BOARD_SIZE, BOARD_SIZE)).has_point(pos):
        var idx := _find_arrow_at(pos)
        if idx >= 0:
            _try_remove(idx)

func _find_arrow_at(pos: Vector2) -> int:
    var best := 28.0
    var found := -1
    for i in range(arrows.size()):
        var a: Dictionary = arrows[i]
        if a.get("removed", false):
            continue
        var pts: Array = a["points"]
        for j in range(pts.size()-1):
            var p1 := _grid_to_screen(Vector2(pts[j][0], pts[j][1]))
            var p2 := _grid_to_screen(Vector2(pts[j+1][0], pts[j+1][1]))
            var dist := _distance_to_segment(pos, p1, p2)
            if dist < best:
                best = dist
                found = i
    return found

func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
    var ab := b - a
    var t := clampf((p-a).dot(ab) / max(0.001, ab.length_squared()), 0.0, 1.0)
    return p.distance_to(a + t * ab)

func _try_remove(index: int) -> void:
    if _can_exit(index):
        history.append({"arrows": arrows.duplicate(true), "lives": lives, "removed": removed})
        arrows[index]["removed"] = true
        removed += 1
        selected = -1
        hint_index = -1
        message = "Nice! Arrow escaped."
        message_timer = 1.0
        if removed >= arrows.size():
            state = "won"
            _save_progress()
    else:
        lives -= 1
        selected = index
        message = "Blocked! Find another free arrow."
        message_timer = 1.2
        if lives <= 0:
            state = "lost"
    queue_redraw()

func _can_exit(index: int) -> bool:
    var pts: Array = arrows[index]["points"]
    var head := Vector2(pts[pts.size()-1][0], pts[pts.size()-1][1])
    var prev := Vector2(pts[pts.size()-2][0], pts[pts.size()-2][1])
    var direction := (head - prev).normalized()
    # Sample the arrow's forward ray. Any other arrow segment within the ray blocks it.
    var t := 0.08
    while t <= 8.0:
        var sample := head + direction * t
        if sample.x < -0.01 or sample.x > GRID+0.01 or sample.y < -0.01 or sample.y > GRID+0.01:
            return true
        for j in range(arrows.size()):
            if j == index or arrows[j].get("removed", false):
                continue
            var other: Array = arrows[j]["points"]
            for k in range(other.size()-1):
                var a := Vector2(other[k][0], other[k][1])
                var b := Vector2(other[k+1][0], other[k+1][1])
                if _distance_to_segment(sample, a, b) < 0.20:
                    return false
        t += 0.12
    return true

func _use_hint() -> void:
    if hints <= 0:
        message = "No hints left. You can still solve it!"
        message_timer = 1.5
        queue_redraw()
        return
    for i in range(arrows.size()):
        if not arrows[i].get("removed", false) and _can_exit(i):
            hints -= 1
            hint_index = i
            message = "Hint: this arrow can escape safely."
            message_timer = 2.0
            queue_redraw()
            return
    message = "No free arrow found. Try Undo or Restart."
    message_timer = 1.6
    queue_redraw()

func _undo() -> void:
    if history.is_empty():
        message = "Nothing to undo yet."
        message_timer = 1.2
    else:
        var previous: Dictionary = history.pop_back()
        arrows = previous["arrows"]
        lives = previous["lives"]
        removed = previous["removed"]
        state = "playing"
        hint_index = -1
        message = "Last move undone."
        message_timer = 1.0
    queue_redraw()

func _make_level() -> void:
    lives = 3
    hints = 2
    removed = 0
    history.clear()
    selected = -1
    hint_index = -1
    state = "playing"
    message = ""
    var template: Array = level_templates[(level - 1) % level_templates.size()]
    arrows.clear()
    for path in template:
        arrows.append({"points": path.duplicate(true), "removed": false})
    # Later levels add a few deterministic extra paths for variety.
    if level > level_templates.size():
        var shift := (level - 1) % 3
        if shift == 1:
            arrows.append({"points": [[0,2],[1,2],[1,3]], "removed": false})
        elif shift == 2:
            arrows.append({"points": [[6,0],[6,1],[5,1]], "removed": false})
    queue_redraw()

func _restart_level() -> void:
    _make_level()

func _difficulty_name() -> String:
    if level < 4:
        return "EASY  •  Find the free path"
    if level < 10:
        return "NORMAL  •  Plan your moves"
    return "HARD  •  Clear the board"

func _save_progress() -> void:
    var cfg := ConfigFile.new()
    cfg.set_value("progress", "unlocked_level", max(level + (1 if state == "won" else 0), 1))
    cfg.save("user://progress.cfg")

func _load_progress() -> void:
    var cfg := ConfigFile.new()
    if cfg.load("user://progress.cfg") == OK:
        level = max(1, int(cfg.get_value("progress", "unlocked_level", 1)))

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        _save_progress()
