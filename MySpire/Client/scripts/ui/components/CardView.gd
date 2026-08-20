## CardView.gd — 卡牌视觉组件（200×280，对应设计系统卡牌规范）。
## 纯表现层：从 CardInstance 读数据渲染；点击向上发射 clicked 信号。
class_name CardView
extends Panel

signal clicked(card: CardInstance)

const CARD_SIZE := Vector2(200, 280)

var card: CardInstance
var _selected := false
var _playable := true
var _name_label: Label
var _desc_label: Label
var _cost_label: Label
var _type_label: Label


func _init(card_instance: CardInstance) -> void:
	card = card_instance


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE * 0.5
	_build()
	_apply_style()
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))


func _build() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 8.0
	vbox.offset_right = -8.0
	vbox.offset_top = 6.0
	vbox.offset_bottom = -6.0
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_child(top)

	var cost_panel := Panel.new()
	cost_panel.custom_minimum_size = Vector2(38, 38)
	cost_panel.add_theme_stylebox_override("panel", UITheme.panel_style(Color("1c2a4a"), UITheme.GOLD_L, 19, 1))
	_cost_label = UITheme.label("0", 18, UITheme.GOLD_L)
	_cost_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_panel.add_child(_cost_label)
	top.add_child(cost_panel)

	_name_label = UITheme.label("???", 17, UITheme.TEXT)
	_name_label.custom_minimum_size = Vector2(0, 42)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_name_label)

	_type_label = UITheme.label("攻击", 12, UITheme.DIM)
	vbox.add_child(_type_label)

	_desc_label = UITheme.label("", 14, UITheme.TEXT)
	_desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_desc_label)


func refresh() -> void:
	if card == null:
		return
	_cost_label.text = str(card.cost())
	_name_label.text = card.display_name()
	_type_label.text = UITheme.type_name(card.card_type())
	var desc := UITheme.describe_effects(card.effects())
	if card.will_exhaust():
		desc += "\n· 消耗"
	_desc_label.text = desc
	_apply_style()


func _apply_style() -> void:
	var tc: Color = UITheme.type_color(card.card_type())
	var rc: Color = UITheme.rarity_color(card.rarity())
	var sb := UITheme.panel_style(Color(tc.r * 0.22 + 0.03, tc.g * 0.22 + 0.03, tc.b * 0.22 + 0.04, 0.96), tc, 14, 2)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	if _selected:
		sb.border_color = UITheme.GOLD_L
		sb.set_border_width_all(3)
		sb.shadow_color = Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.55)
		sb.shadow_size = 18
	else:
		sb.shadow_color = Color(rc.r, rc.g, rc.b, 0.25)
		sb.shadow_size = 8
	add_theme_stylebox_override("panel", sb)
	modulate = Color(1, 1, 1) if _playable or _selected else Color(0.55, 0.55, 0.55)


func set_selected(value: bool) -> void:
	_selected = value
	_apply_style()


func set_playable(value: bool) -> void:
	_playable = value
	_apply_style()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(card)


func _on_hover(entering: bool) -> void:
	if _selected or not _playable:
		return
	var target := Vector2(1.05, 1.05) if entering else Vector2.ONE
	var tween := create_tween()
	tween.tween_property(self, "scale", target, 0.12)
