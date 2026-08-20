## CharacterSelect.gd — 角色选择画面（设计系统 7.5 v3）。
## 菱形竖向链条（顶点相切）+ 每角色立绘背景层交叉淡入 + 底部随机骰子轮盘。
class_name CharacterSelect
extends Control

const DISPLAY_ORDER: Array[String] = ["ironclad", "silent", "defect", "watcher"]
const DIAMOND: float = 56.0
const CHAIN_SPACING: float = 44.0
const CHAIN_OFFSET: float = 40.0

var _selected_id: String = "ironclad"
var _spinning: bool = false
var _diamonds: Dictionary = {}
var _bg_layers: Dictionary = {}
var _watermark: Label
var _detail_name: Label
var _detail_stats: Label
var _detail_relic: Label
var _start_btn: Button


func _ready() -> void:
	_build_backgrounds()
	_build_foreground()


# ─── 背景：每角色一层渐变 + 大字立绘占位 ──────────────────────────


func _build_backgrounds() -> void:
	for id: String in DISPLAY_ORDER:
		var c: Dictionary = ContentRegistry.get_character(id)
		var layer := Control.new()
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.modulate.a = 0.0
		add_child(layer)
		layer.add_child(UITheme.make_bg(_char_bg_top(id), UITheme.BG_DEEP))
		var glyph := UITheme.label(String(c.get("emoji", "?")), 150, Color(1, 1, 1, 0.14))
		glyph.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		glyph.offset_left = -240.0
		glyph.offset_top = -120.0
		layer.add_child(glyph)
		_bg_layers[id] = layer
	# 竖排角色名水印（碧蓝幻想标志手法）。
	_watermark = UITheme.label("", 34, Color(1, 1, 1, 0.10))
	_watermark.rotation_degrees = 90.0
	_watermark.position = Vector2(660, 420)
	add_child(_watermark)


func _char_bg_top(id: String) -> Color:
	match id:
		"ironclad":
			return Color("3a1515")
		"silent":
			return Color("15301a")
		"defect":
			return Color("15183a")
		"watcher":
			return Color("2a1a30")
	return UITheme.BG_TOP


# ─── 前景：菱形链 + 详情面板 ─────────────────────────────────────


func _build_foreground() -> void:
	var fg := VBoxContainer.new()
	fg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fg.offset_top = 16.0
	fg.offset_bottom = -16.0
	fg.add_theme_constant_override("separation", 6)
	add_child(fg)

	var header := UITheme.label("选择你的角色", 24, UITheme.GOLD)
	fg.add_child(header)
	var hint := UITheme.label("每颗菱形是一位英雄 · 底部骰子随机选择", 12, UITheme.DIM)
	fg.add_child(hint)

	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fg.add_child(top_spacer)

	# 菱形链：角色 + 锁定槽 + 骰子（固定高度容器，居中排布）。
	var chain_area := Control.new()
	chain_area.custom_minimum_size = Vector2(0, 360)
	fg.add_child(chain_area)
	var chain: Array[String] = DISPLAY_ORDER.duplicate()
	chain.append("locked_slot")
	chain.append("random")
	var total_h: float = CHAIN_SPACING * (chain.size() - 1) + DIAMOND
	var top_y: float = (360.0 - total_h) * 0.5
	for i: int in chain.size():
		var id := chain[i]
		var d := _make_diamond(id)
		var cx: float = 360.0 + (CHAIN_OFFSET if i % 2 == 1 else -CHAIN_OFFSET)
		var cy: float = top_y + DIAMOND * 0.5 + CHAIN_SPACING * i
		d.position = Vector2(cx - DIAMOND * 0.5, cy - DIAMOND * 0.5)
		chain_area.add_child(d)
		_diamonds[id] = d

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fg.add_child(bottom_spacer)

	fg.add_child(_build_detail_panel())

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 16)
	fg.add_child(footer)
	var back := UITheme.ghost_button("返回")
	back.pressed.connect(func() -> void: GameManager.change_screen(&"main_menu"))
	footer.add_child(back)
	_start_btn = UITheme.gold_button("启 程", Vector2(200, 52))
	_start_btn.pressed.connect(_on_start)
	footer.add_child(_start_btn)

	_apply_selection("ironclad", true)


func _make_diamond(id: String) -> Panel:
	var wrap := Panel.new()
	wrap.custom_minimum_size = Vector2(DIAMOND, DIAMOND)
	wrap.size = Vector2(DIAMOND, DIAMOND)
	wrap.pivot_offset = Vector2(DIAMOND * 0.5, DIAMOND * 0.5)
	wrap.rotation_degrees = 45.0
	wrap.add_theme_stylebox_override("panel", _diamond_style(id, false))
	var icon := UITheme.label(_diamond_icon(id), 20, Color(1, 1, 1, 0.92))
	icon.rotation_degrees = -45.0
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wrap.add_child(icon)
	wrap.gui_input.connect(_on_diamond_input.bind(id))
	wrap.mouse_entered.connect(_on_diamond_hover.bind(id, true))
	wrap.mouse_exited.connect(_on_diamond_hover.bind(id, false))
	return wrap


func _diamond_icon(id: String) -> String:
	match id:
		"ironclad":
			return "战"
		"silent":
			return "猎"
		"defect":
			return "法"
		"watcher":
			return "锁"
		"locked_slot":
			return "锁"
		"random":
			return "骰"
	return "?"


func _build_detail_panel() -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(0, 132)
	panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20.0
	vbox.offset_right = -20.0
	vbox.offset_top = 10.0
	vbox.offset_bottom = -10.0
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	_detail_name = UITheme.label("", 18, UITheme.GOLD_L)
	vbox.add_child(_detail_name)
	_detail_stats = UITheme.label("", 13, UITheme.TEXT)
	vbox.add_child(_detail_stats)
	_detail_relic = UITheme.label("", 11, UITheme.DIM)
	_detail_relic.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_detail_relic)
	return panel


func _diamond_style(id: String, selected: bool) -> StyleBoxFlat:
	var border: Color = UITheme.GOLD if selected else Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.4)
	var bg := Color(0.10, 0.14, 0.28, 0.94)
	if id == "random":
		bg = Color(0.18, 0.10, 0.28, 0.94)
		border = Color("9a6cd0") if not selected else UITheme.GOLD
	if id == "locked_slot" or id == "watcher":
		bg = Color(0.10, 0.10, 0.12, 0.9)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_corner_radius_all(6)
	sb.set_border_width_all(2 if selected else 1)
	if selected:
		sb.shadow_color = Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.6)
		sb.shadow_size = 20
	return sb


func _on_diamond_input(event: InputEvent, id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if id == "locked_slot" or id == "watcher":
			_shake(_diamonds[id])
			return
		if id == "random":
			_roll_random()
			return
		if not _spinning:
			_apply_selection(id)


func _on_diamond_hover(id: String, entering: bool) -> void:
	if id == "locked_slot" or id == "watcher" or _spinning:
		return
	var d: Panel = _diamonds[id]
	var target: Vector2 = Vector2(1.12, 1.12) if entering and id != _selected_id else (Vector2(1.18, 1.18) if id == _selected_id else Vector2.ONE)
	var tween := create_tween()
	tween.tween_property(d, "scale", target, 0.15)


func _shake(panel: Panel) -> void:
	var tween := create_tween()
	var base: Vector2 = panel.position
	tween.tween_property(panel, "position:x", base.x - 5.0, 0.05)
	tween.tween_property(panel, "position:x", base.x + 5.0, 0.05)
	tween.tween_property(panel, "position:x", base.x, 0.05)


# ─── 选择与轮盘 ──────────────────────────────────────────────────


func _apply_selection(id: String, instant: bool = false) -> void:
	_selected_id = id
	for key: String in _diamonds.keys():
		var d: Panel = _diamonds[key]
		var is_sel: bool = key == id
		d.add_theme_stylebox_override("panel", _diamond_style(key, is_sel))
		var target: Vector2 = Vector2(1.18, 1.18) if is_sel else Vector2.ONE
		if instant:
			d.scale = target
		else:
			var tween := create_tween()
			tween.tween_property(d, "scale", target, 0.18)
	# 背景交叉淡入。
	for key: String in _bg_layers.keys():
		var layer: Control = _bg_layers[key]
		var target_a: float = 1.0 if key == id else 0.0
		var tween := create_tween()
		tween.tween_property(layer, "modulate:a", target_a, 0.55 if not instant else 0.0)
	var c: Dictionary = ContentRegistry.get_character(id)
	_watermark.text = String(c.get("name", ""))
	_refresh_detail(c)
	_start_btn.disabled = false


func _refresh_detail(c: Dictionary) -> void:
	_detail_name.text = "%s · %s" % [String(c.get("name", "?")), String(c.get("title", ""))]
	_detail_stats.text = "生命 %d    能量 3    起始牌组 %d 张    机制：%s" % [
		int(c.get("hp", 75)), int(c.get("deck", []).size()), String(c.get("mechanic", "")),
	]
	_detail_relic.text = "起始遗物 · %s：%s" % [String(c.get("relic", "")), String(c.get("relic_desc", ""))]


func _roll_random() -> void:
	if _spinning:
		return
	_spinning = true
	_start_btn.disabled = true
	var playable: Array[String] = ContentRegistry.get_playable_characters()
	var rng: RandomNumberGenerator = RNGManager.get_rng("menu")
	var steps: int = rng.randi_range(10, 14)
	var cursor: int = maxi(0, playable.find(_selected_id))
	for i: int in steps:
		cursor = (cursor + 1) % playable.size()
		_apply_selection(playable[cursor])
		await get_tree().create_timer(0.09).timeout
	_spinning = false
	_start_btn.disabled = false


func _on_start() -> void:
	if _spinning:
		return
	GameManager.start_run(_selected_id)
