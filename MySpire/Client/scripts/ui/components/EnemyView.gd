## EnemyView.gd — 敌人视觉组件（200×230）。
## 展示：意图（明牌）、名称、HP 条、格挡徽章、状态层；可点击作为出牌目标。
class_name EnemyView
extends Panel

signal clicked(index: int)

var index: int
var _intent_label: Label
var _name_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _block_label: Label
var _status_label: Label
var _targetable := false


func _init(enemy_index: int) -> void:
	index = enemy_index


func _ready() -> void:
	custom_minimum_size = Vector2(200, 230)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	_intent_label = UITheme.label("…", 15, UITheme.GOLD_L)
	_intent_label.custom_minimum_size = Vector2(0, 30)
	_intent_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.add_child(_intent_label)

	_name_label = UITheme.label("敌人", 18, UITheme.TEXT)
	vbox.add_child(_name_label)

	_hp_bar = UITheme.make_hp_bar(160)
	_hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_hp_bar)

	_hp_label = UITheme.label("0/0", 13, UITheme.TEXT)
	vbox.add_child(_hp_label)

	_block_label = UITheme.label("", 15, UITheme.BLOCK_BLUE)
	vbox.add_child(_block_label)

	_status_label = UITheme.label("", 12, UITheme.DIM)
	_status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vbox.add_child(_status_label)

	gui_input.connect(_on_gui_input)
	_apply_style()


func update_from(enemy: EnemyState) -> void:
	_name_label.text = enemy.display_name
	_hp_bar.max_value = enemy.max_hp
	_hp_bar.value = enemy.hp
	_hp_label.text = "%d / %d" % [enemy.hp, enemy.max_hp]
	_block_label.text = ("⛨ %d" % enemy.block) if enemy.block > 0 else ""
	var statuses: Array[String] = []
	if enemy.strength > 0:
		statuses.append("力量 %d" % enemy.strength)
	if enemy.weak > 0:
		statuses.append("虚弱 %d" % enemy.weak)
	if enemy.vulnerable > 0:
		statuses.append("易伤 %d" % enemy.vulnerable)
	_status_label.text = " · ".join(statuses)
	if enemy.alive:
		var intent := enemy.intent
		var dmg: int = enemy.projected_intent_damage()
		var text := EnemyAI.describe_intent(intent)
		if dmg > 0:
			text = "%s %d" % [text, dmg]
			var hits: int = int(intent.get("hits", 1))
			if hits > 1:
				text += " ×%d" % hits
		_intent_label.text = text
	else:
		_intent_label.text = ""
		_status_label.text = "已阵亡"
	modulate = Color(1, 1, 1) if enemy.alive else Color(0.3, 0.3, 0.3)
	mouse_filter = Control.MOUSE_FILTER_STOP if enemy.alive else Control.MOUSE_FILTER_IGNORE


func set_targetable(value: bool) -> void:
	_targetable = value
	_apply_style()


func _apply_style() -> void:
	var sb := UITheme.panel_style(Color(0.09, 0.07, 0.10, 0.95), Color(0.45, 0.35, 0.35, 0.6), 14, 1)
	if _targetable:
		sb.border_color = UITheme.GOLD_L
		sb.set_border_width_all(3)
		sb.shadow_color = Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.5)
		sb.shadow_size = 16
	add_theme_stylebox_override("panel", sb)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(index)
