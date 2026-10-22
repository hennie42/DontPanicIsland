class_name LeaderboardPanel
extends VBoxContainer
## The shared Top 10 (All-time / This week), built in code. Used on the ending panel and from the Esc menu.
## load_board() fetches through Net; the player's own run (highlight_id) is drawn gold, and its rank is shown
## even when it is outside the top 10.

const GOLD := Color("#ffd23f")
const COLUMNS := ["#", "NAME", "SCORE", "TURNS", "ISLE"]

var period := "all"
var highlight_id := -1
var ranks := {"all": 0, "week": 0}   # the player's rank per period (0: none)

var _font: FontFile
var _tab_all: Button
var _tab_week: Button
var _status: Label
var _grid: GridContainer
var _rank_label: Label
var _loading := false


func _init() -> void:
	name = "Leaderboard"
	_font = load("res://assets/kenney/kenney-fonts/Kenney Future.ttf") as FontFile
	add_theme_constant_override("separation", 8)

	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(tabs)
	_tab_all = _button("All-time", func(): _select("all"))
	_tab_week = _button("This week", func(): _select("week"))
	tabs.add_child(_tab_all)
	tabs.add_child(_tab_week)

	_status = _label("", 24)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_status)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS.size()
	_grid.add_theme_constant_override("h_separation", 28)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_grid)

	_rank_label = _label("", 24)
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_label.add_theme_color_override("font_color", GOLD)
	add_child(_rank_label)


## Fetch and show the current period. Highlights run `id` and shows its ranks (from submit_run) when given.
func load_board(id: int = -1, rank_all: int = 0, rank_week: int = 0) -> void:
	highlight_id = id
	ranks = {"all": rank_all, "week": rank_week}
	await _refresh()


func _select(p: String) -> void:
	if p == period or _loading:
		return
	period = p
	await _refresh()


func _refresh() -> void:
	_loading = true
	_tab_all.disabled = period == "all"
	_tab_week.disabled = period == "week"
	_status.text = "Loading..."
	_status.visible = true
	var res: Dictionary = await Net.top_runs(period)
	_loading = false
	for c in _grid.get_children():
		c.queue_free()
	if not res["ok"] or not res["data"] is Array:
		_status.text = "Leaderboard offline"
		_rank_label.text = ""
		GameEvent.marker("BOARD", "period=%s offline" % period)
		return
	var rows: Array = res["data"]
	_status.text = "No winners yet this week" if rows.is_empty() else ""
	_status.visible = rows.is_empty()
	for h in COLUMNS:
		_cell(h, Color(1, 1, 1, 0.6))
	var mine_shown := false
	for i in rows.size():
		var r: Dictionary = rows[i]
		var mine := int(r["id"]) == highlight_id
		mine_shown = mine_shown or mine
		var col := GOLD if mine else Color.WHITE
		for v in [i + 1, r["nick"], r["score"], r["turns"], r["island"]]:
			_cell(str(v), col)
	var rank: int = ranks[period]
	_rank_label.text = "" if highlight_id < 0 or rank <= 0 else "Your rank: %d" % rank
	GameEvent.marker("BOARD", "period=%s rows=%d mine_shown=%s rank=%d" % [period, rows.size(), mine_shown, rank])


func _cell(text: String, color: Color) -> void:
	var l := _label(text, 28)
	l.add_theme_color_override("font_color", color)
	_grid.add_child(l)


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l


func _button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 28)
	b.custom_minimum_size = Vector2(220, 52)
	b.add_theme_color_override("font_disabled_color", GOLD)   # the selected tab is the disabled one: show it lit, not dimmed
	b.pressed.connect(on_pressed)
	return b
