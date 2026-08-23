## CardPileView.gd — 竖屏卡牌框架 · 牌堆视图（牌库/弃牌堆通用）。
## 参考 framework Pile：叠放卡背呈现厚度 + 数量角标 + 点击弹出浏览面板（网格平铺堆内卡牌）。
## 弹窗为全屏遮罩（加挂到场景根，避免被父容器裁剪），点击遮罩关闭。
class_name CardPileView
extends Control

signal pile_pressed(pile: CardPileView)

const PILE_CARD_SIZE := Vector2(56.0, 80.0)
## 呈现"厚度"的卡背层数。
const STACK_LAYERS := 3

## 堆内卡牌数据（Dictionary 数组，字段同 BattleCard.card_data）。
var pile_cards: Array = []
var pile_name: String = "牌堆"

var _count_label: Label
var _name_label: Label
var _viewer: Control = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(80.0, 110.0)
	_build_stack()
	gui_input.connect(_on_gui_input)


func _build_stack() -> void:
	for i: int in STACK_LAYERS:
		var back := Panel.new()
		var depth: float = float(i)
		back.position = Vector2(12.0 - depth * 3.0, 16.0 - depth * 3.0)
		back.size = PILE_CARD_SIZE
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.13, 0.25).darkened(0.1 * depth)
		sb.border_color = UITheme.GOLD if i == STACK_LAYERS - 1 else UITheme.DIM
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(6)
		sb.shadow_color = Color(0, 0, 0, 0.5)
		sb.shadow_size = 4
		back.add_theme_stylebox_override("panel", sb)
		add_child(back)

	_count_label = UITheme.label("0", 16, UITheme.GOLD_L)
	_count_label.position = Vector2(4.0, 44.0)
	_count_label.size = PILE_CARD_SIZE
	add_child(_count_label)

	_name_label = UITheme.label(pile_name, 10, UITheme.DIM)
	_name_label.position = Vector2(4.0, 92.0)
	_name_label.size = Vector2(72.0, 14.0)
	add_child(_name_label)


func _on_gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		pile_pressed.emit(self)
		if _viewer == null:
			open_viewer()


# ─── 数据 ──────────────────────────────────────────────────────


## 整堆替换。
func set_cards(cards: Array) -> void:
	pile_cards = cards.duplicate()
	_refresh()


## 顶部压入一张（卡牌数据）。
func push_card(card: Dictionary) -> void:
	pile_cards.append(card)
	_refresh()


## 从顶部弹出一张；堆空返回空 Dictionary。
func pop_card() -> Dictionary:
	if pile_cards.is_empty():
		return {}
	var top: Dictionary = pile_cards.back()
	pile_cards.pop_back()
	_refresh()
	return top


func _refresh() -> void:
	if _count_label != null:
		_count_label.text = str(pile_cards.size())
		_count_label.add_theme_color_override("font_color", UITheme.GOLD_L if not pile_cards.is_empty() else UITheme.DIM)


# ─── 浏览弹窗 ──────────────────────────────────────────────────


## 全屏弹窗平铺堆内卡牌（只读浏览）。
func open_viewer() -> void:
	if _viewer != null:
		return
	_viewer = Control.new()
	_viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewer.mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().root.add_child.call_deferred(_viewer)
	_viewer.ready.connect(func() -> void: _build_viewer_content())


func _build_viewer_content() -> void:
	# 半透明遮罩。
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewer.add_child(dim)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 24.0
	vb.offset_right = -24.0
	vb.offset_top = 60.0
	vb.offset_bottom = -40.0
	vb.add_theme_constant_override("separation", 12)
	_viewer.add_child(vb)

	var title := UITheme.label("%s（%d 张）" % [pile_name, pile_cards.size()], 18, UITheme.GOLD)
	vb.add_child(title)

	# 卡牌网格（可滚动）。
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)

	for entry: Variant in pile_cards:
		var data: Dictionary = entry as Dictionary
		var mini := Panel.new()
		mini.custom_minimum_size = Vector2(150.0, 64.0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.09, 0.09, 0.16)
		sb.border_color = UITheme.type_color(String(data.get("type", "")))
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(6)
		mini.add_theme_stylebox_override("panel", sb)
		grid.add_child(mini)

		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 8.0
		row.offset_right = -8.0
		row.add_theme_constant_override("separation", 6)
		mini.add_child(row)

		var emoji := UITheme.label(String(data.get("emoji", "✦")), 20, UITheme.TEXT)
		emoji.custom_minimum_size = Vector2(24.0, 0.0)
		emoji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(emoji)

		var name_label := UITheme.label(
			"%s · %d费" % [String(data.get("name", "?")), int(data.get("cost", 1))],
			12, UITheme.GOLD_L
		)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_label)

	if pile_cards.is_empty():
		var empty := UITheme.label("（空）", 13, UITheme.DIM)
		vb.add_child(empty)

	var hint := UITheme.label("点击任意位置关闭", 10, UITheme.DIM)
	vb.add_child(hint)

	# 点遮罩/弹窗任意处关闭。
	_viewer.gui_input.connect(func(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			close_viewer()
	)


func close_viewer() -> void:
	if _viewer != null:
		_viewer.queue_free()
		_viewer = null


func _exit_tree() -> void:
	close_viewer()
