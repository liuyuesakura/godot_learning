## MapScreen.gd — 地图画面（Run 战略层）。
## 垂直分支路径：底起第 1 层，顶至第 16 层 Boss；路径连线用 _draw 绘制，
## 节点为圆形按钮。部分可见性：本切片全图可见（后续按层解锁迷雾）。
class_name MapScreen
extends Control

const FLOOR_GAP: float = 68.0
const BASE_Y: float = 1180.0
const MARGIN_X: float = 60.0

var _run: RunState
var _node_buttons: Dictionary = {}
var _pulse_tweens: Array[Tween] = []
var _popup: Control
var _hp_label: Label
var _hp_bar: ProgressBar
var _gold_label: Label
var _floor_label: Label
var _abandon_confirmed: bool = false


func _ready() -> void:
	_run = GameManager.run
	if _run == null:
		GameManager.change_screen(&"main_menu")
		return
	add_child(UITheme.make_bg())
	_build_top_bar()
	_build_nodes()
	if _run.is_boss_defeated():
		call_deferred("_show_run_victory")


func _node_pos(node: Dictionary) -> Vector2:
	return Vector2(
		MARGIN_X + float(node["x"]) * (720.0 - MARGIN_X * 2.0),
		BASE_Y - float(int(node["floor"]) - 1) * FLOOR_GAP
	)


# ─── 顶栏 ────────────────────────────────────────────────────────


func _build_top_bar() -> void:
	var bar := Panel.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 56.0
	bar.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.04, 0.06, 0.12, 0.92), Color(0, 0, 0, 0.3), 0))
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 12.0
	hbox.offset_right = -12.0
	hbox.add_theme_constant_override("separation", 10)
	bar.add_child(hbox)
	add_child(bar)

	var name_label := UITheme.label(_run.character_name, 16, UITheme.GOLD_L)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_label)

	_hp_bar = UITheme.make_hp_bar(140.0)
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hp_bar.custom_minimum_size = Vector2(140, 12)
	hbox.add_child(_hp_bar)
	_hp_label = UITheme.label("", 13, UITheme.TEXT)
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_hp_label)

	_gold_label = UITheme.label("", 14, UITheme.GOLD_L)
	_gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_gold_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	_floor_label = UITheme.label("", 13, UITheme.DIM)
	_floor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_floor_label)

	var deck_btn := UITheme.ghost_button("牌组", Vector2(70, 38))
	deck_btn.pressed.connect(_show_deck)
	hbox.add_child(deck_btn)

	var abandon_btn := UITheme.ghost_button("放弃远征", Vector2(100, 38))
	abandon_btn.pressed.connect(_on_abandon.bind(abandon_btn))
	hbox.add_child(abandon_btn)

	_refresh_top_bar()


func _refresh_top_bar() -> void:
	_hp_bar.max_value = _run.max_hp
	_hp_bar.value = _run.hp
	_hp_label.text = "%d/%d" % [_run.hp, _run.max_hp]
	_gold_label.text = "金 %d" % _run.gold
	_floor_label.text = "层 %d/16" % maxi(1, _run.current_floor)


# ─── 节点 ────────────────────────────────────────────────────────


func _build_nodes() -> void:
	for floor_key: int in _run.map.keys():
		for node: Dictionary in _run.map[floor_key]:
			var key := Vector2i(int(node["floor"]), int(node["index"]))
			var is_boss: bool = String(node["type"]) == "boss"
			var btn := Button.new()
			btn.text = _type_label(String(node["type"]))
			var btn_size: float = 72.0 if is_boss else 54.0
			btn.custom_minimum_size = Vector2(btn_size, btn_size)
			btn.add_theme_font_size_override("font_size", 20 if is_boss else 16)
			btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			btn.pressed.connect(_on_node_pressed.bind(node))
			var pos := _node_pos(node)
			btn.position = pos - Vector2(btn_size, btn_size) * 0.5
			add_child(btn)
			_node_buttons[key] = btn
	_refresh_node_styles()


func _refresh_node_styles() -> void:
	for t: Tween in _pulse_tweens:
		t.kill()
	_pulse_tweens.clear()
	var reachable: Array[Vector2i] = _run.get_reachable()
	var current := Vector2i(_run.current_floor, _run.current_index)
	for key: Vector2i in _node_buttons.keys():
		var btn: Button = _node_buttons[key]
		var node: Dictionary = _run.get_node_at(key.x, key.y)
		var node_type := String(node["type"])
		var is_reachable: bool = reachable.has(key)
		var is_current: bool = key == current and current != Vector2i.ZERO and _run.current_index >= 0
		var passed: bool = _run.current_index >= 0 and key.x <= _run.current_floor
		var border: Color = UITheme.GOLD if is_reachable else Color(0.5, 0.55, 0.62, 0.35)
		var bg: Color = _type_bg(node_type)
		if is_current:
			bg = UITheme.GOLD
		elif passed and not is_reachable:
			bg = Color(bg.r * 0.35 + 0.03, bg.g * 0.35 + 0.03, bg.b * 0.35 + 0.03, 0.85)
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_color = border
		sb.set_corner_radius_all(32)
		sb.set_border_width_all(2 if is_reachable else 1)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.modulate = Color(0.65, 0.65, 0.7) if passed and not is_current and not is_reachable else Color.WHITE
		if is_reachable:
			var tween := create_tween()
			tween.set_loops()
			tween.tween_property(btn, "modulate:a", 0.7, 0.7)
			tween.tween_property(btn, "modulate:a", 1.0, 0.7)
			_pulse_tweens.append(tween)


func _type_label(node_type: String) -> String:
	match node_type:
		"combat":
			return "战"
		"elite":
			return "精"
		"shop":
			return "店"
		"campfire":
			return "火"
		"event":
			return "事"
		"treasure":
			return "宝"
		"boss":
			return "王"
	return "?"


func _type_bg(node_type: String) -> Color:
	match node_type:
		"combat":
			return Color(0.12, 0.18, 0.34, 0.95)
		"elite":
			return Color(0.34, 0.12, 0.12, 0.95)
		"shop":
			return Color(0.30, 0.24, 0.08, 0.95)
		"campfire":
			return Color(0.32, 0.18, 0.06, 0.95)
		"event":
			return Color(0.22, 0.14, 0.34, 0.95)
		"treasure":
			return Color(0.28, 0.24, 0.10, 0.95)
		"boss":
			return Color(0.40, 0.06, 0.06, 0.98)
	return Color(0.15, 0.15, 0.2, 0.9)


func _draw() -> void:
	if _run == null:
		return
	for f: int in range(1, MapGenerator.BOSS_FLOOR):
		var current_floor_nodes: Array = _run.map.get(f, [])
		var next_floor_nodes: Array = _run.map.get(f + 1, [])
		for node: Dictionary in current_floor_nodes:
			for j: Variant in node["edges"]:
				draw_line(
					_node_pos(node),
					_node_pos(next_floor_nodes[int(j)]),
					Color(0.55, 0.60, 0.70, 0.28),
					2.0
				)


func _on_node_pressed(node: Dictionary) -> void:
	var f := int(node["floor"])
	var i := int(node["index"])
	if not _run.is_reachable(f, i):
		return
	match String(node["type"]):
		"combat", "elite", "boss":
			GameManager.enter_map_node(node)
		"campfire":
			_enter_and_popup(f, i, "篝火", "火焰噼啪作响，你有机会休整。", [
				{
					"text": "休息（回复 %d 生命）" % int(_run.max_hp * 0.3),
					"action": func() -> void:
						_run.heal(int(_run.max_hp * 0.3))
						_close_and_refresh(),
				},
			])
		"treasure":
			_enter_and_popup(f, i, "宝箱", "箱中有些许补给。", [
				{
					"text": "开启（+30 金币，获得遗物）",
					"action": func() -> void:
						_run.add_gold(30)
						_run.add_relic("treasure_relic")
						_close_and_refresh(),
				},
			])
		"event":
			_show_event(f, i)
		"shop":
			_enter_and_popup(f, i, "流浪商队", "商队还在赶来的路上……（商店建设中）", [
				{"text": "继续赶路", "action": func() -> void: _close_and_refresh()},
			])


func _enter_and_popup(f: int, i: int, title: String, body: String, actions: Array) -> void:
	_run.enter_node(f, i)
	_show_popup(title, body, actions)


func _show_event(f: int, i: int) -> void:
	var rng := RNGManager.get_rng("event_%d_%d" % [f, i])
	var roll := rng.randi_range(0, 2)
	var title := "奇遇"
	var body := ""
	var apply := func() -> void: _close_and_refresh()
	match roll:
		0:
			body = "你帮助了一位迷路的商人，获赠 60 金币。"
			apply = func() -> void:
				_run.add_gold(60)
				_close_and_refresh()
		1:
			body = "路边的草药让你恢复了 10 点生命。"
			apply = func() -> void:
				_run.heal(10)
				_close_and_refresh()
		2:
			body = "一片宁静，什么都没有发生。"
	_enter_and_popup(f, i, title, body, [{"text": "继续", "action": apply}])


func _close_and_refresh() -> void:
	_close_popup()
	SaveManager.save_run(_run)
	_refresh_top_bar()
	_refresh_node_styles()
	queue_redraw()
	if _run.is_boss_defeated():
		_show_run_victory()


# ─── 弹层 ────────────────────────────────────────────────────────


func _show_popup(title: String, body: String, actions: Array) -> void:
	_close_popup()
	_popup = Control.new()
	_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup.add_child(dim)
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -260.0
	panel.offset_right = 260.0
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20.0
	vbox.offset_right = -20.0
	vbox.offset_top = 16.0
	vbox.offset_bottom = -16.0
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	_popup.add_child(panel)
	add_child(_popup)

	vbox.add_child(UITheme.label(title, 24, UITheme.GOLD))
	var body_label := UITheme.label(body, 15, UITheme.TEXT)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body_label)
	for action: Dictionary in actions:
		var btn := UITheme.gold_button(String(action["text"]))
		btn.pressed.connect(action["action"] as Callable)
		vbox.add_child(btn)


func _close_popup() -> void:
	if _popup != null:
		_popup.queue_free()
		_popup = null


func _show_deck() -> void:
	var counts := {}
	for c: CardInstance in _run.deck:
		var key := c.display_name()
		counts[key] = int(counts.get(key, 0)) + 1
	var entries: Array[String] = []
	for key: String in counts.keys():
		entries.append("%s ×%d" % [key, int(counts[key])])
	entries.sort()
	_show_popup("牌组（%d 张）" % _run.deck.size(), "", [
		{"text": "关闭", "action": func() -> void: _close_and_refresh()},
	])
	# 内容多时替换 body 为可滚动列表。
	if _popup != null:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(440, 320)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 24)
		grid.add_theme_constant_override("v_separation", 6)
		scroll.add_child(grid)
		for e: String in entries:
			grid.add_child(UITheme.label(e, 14, UITheme.TEXT))
		# 内容挂到面板的 VBox 里，保持布局（panel 不是容器，直接挂会错位）。
		_popup.get_child(1).get_child(0).add_child(scroll)


func _on_abandon(btn: Button) -> void:
	if _abandon_confirmed:
		GameManager.end_run()
		return
	_abandon_confirmed = true
	btn.text = "确认放弃？"
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		_abandon_confirmed = false
		if is_instance_valid(btn):
			btn.text = "放弃远征")


func _show_run_victory() -> void:
	_show_popup(
		"尖塔之巅",
		"守卫者已被击败，%s 的远征完成！\n最终金币：%d" % [_run.character_name, _run.gold],
		[{"text": "回到主菜单", "action": func() -> void: GameManager.end_run()}]
	)
