## BattleCard.gd — 竖屏卡牌框架 · 卡牌视图。
## 参考 db0/godot-card-game-framework 的 CardTemplate（Godot 3）移植到 Godot 4 竖屏。
## 状态机：IN_HAND → FOCUSED → (DRAGGING → 归位 | ACTIVATED 打出) → ON_BOARD。
## 交互（触屏优先，兼顾鼠标）：
##   - 鼠标悬停 → focus（邻牌让位由 FanHand 处理）
##   - 单击 → 聚焦；聚焦后再点 → activated（打出）
##   - 按住拖动超阈值 → 拖拽（drag_started/drag_ended 由场景层决定去留）
## 本节点只管视觉与输入，不持有牌局规则——布局由 FanHand 驱动。
class_name BattleCard
extends Control

## 卡牌获得焦点（悬停或首次点击）。
signal focused(card: BattleCard)
## 卡牌失去焦点。
signal unfocused(card: BattleCard)
## 聚焦状态下再次点击（打出意图，由场景层决定去向）。
signal activated(card: BattleCard)
## 开始拖拽（FanHand 会将其移出布局）。
signal drag_started(card: BattleCard)
## 拖拽结束（场景层判断落点：打出到棋盘 / 归位手牌）。
signal drag_ended(card: BattleCard, global_pos: Vector2)

enum State { IN_HAND, FOCUSED, DRAGGING, ON_BOARD }

const CARD_SIZE := Vector2(96.0, 138.0)
## 按下后位移超过该值判定为拖拽（触屏防误触）。
const DRAG_THRESHOLD := 24.0

## 卡牌数据：{name, cost, type, emoji, description}（与 ContentRegistry 卡牌字段同构）。
var card_data: Dictionary = {}
var state: State = State.IN_HAND

var _panel: Panel
var _cost_label: Label
var _name_label: Label
var _art_label: Label
var _desc_label: Label
var _type_label: Label
var _pressing: bool = false
var _press_origin: Vector2 = Vector2.ZERO
var _hovering: bool = false


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_visuals()


# ─── 构建 ──────────────────────────────────────────────────────


func _build_visuals() -> void:
	_panel = Panel.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _frame_style(_type_border_color(), 2))
	add_child(_panel)

	# 费用宝石（蓝色圆形，对应设计系统能量宝石）。
	var gem := Panel.new()
	gem.position = Vector2(5.0, 5.0)
	gem.size = Vector2(26.0, 26.0)
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gem_style := StyleBoxFlat.new()
	gem_style.bg_color = Color(0.29, 0.56, 0.88)
	gem_style.set_corner_radius_all(13)
	gem_style.set_border_width_all(2)
	gem_style.border_color = UITheme.BLOCK_BLUE
	gem_style.shadow_color = Color(0.29, 0.56, 0.88, 0.45)
	gem_style.shadow_size = 6
	gem.add_theme_stylebox_override("panel", gem_style)
	_panel.add_child(gem)

	_cost_label = UITheme.label(str(int(card_data.get("cost", 1))), 15, Color.WHITE)
	_cost_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gem.add_child(_cost_label)

	_name_label = UITheme.label(String(card_data.get("name", "?")), 11, UITheme.GOLD)
	_name_label.position = Vector2(4.0, 6.0)
	_name_label.size = Vector2(CARD_SIZE.x - 8.0, 16.0)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_name_label)

	_art_label = UITheme.label(String(card_data.get("emoji", "✦")), 30, UITheme.TEXT)
	_art_label.position = Vector2(4.0, 34.0)
	_art_label.size = Vector2(CARD_SIZE.x - 8.0, 48.0)
	_art_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_art_label)

	_desc_label = UITheme.label(String(card_data.get("description", "")), 9, Color(0.82, 0.82, 0.82))
	_desc_label.position = Vector2(5.0, 84.0)
	_desc_label.size = Vector2(CARD_SIZE.x - 10.0, 44.0)
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_desc_label)

	_type_label = UITheme.label(UITheme.type_name(String(card_data.get("type", ""))).to_upper(), 7, UITheme.DIM)
	_type_label.position = Vector2(4.0, CARD_SIZE.y - 16.0)
	_type_label.size = Vector2(CARD_SIZE.x - 8.0, 12.0)
	_type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_type_label)


func _frame_style(border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.09, 0.16)
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 4
	return sb


func _type_border_color() -> Color:
	return UITheme.type_color(String(card_data.get("type", "")))


# ─── 输入（触屏 + 鼠标统一走 _gui_input） ──────────────────────


func _gui_input(event: InputEvent) -> void:
	if state == State.ON_BOARD:
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_pressing = true
			_press_origin = mb.global_position
		else:
			if _pressing:
				_pressing = false
				if state == State.DRAGGING:
					_end_drag(mb.global_position)
				elif state == State.FOCUSED:
					activated.emit(self)
				else:
					_set_focus(true)
	var mm := event as InputEventMouseMotion
	if mm != null and _pressing and state != State.DRAGGING:
		if mm.global_position.distance_to(_press_origin) > DRAG_THRESHOLD:
			_start_drag()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hovering = true
		if state == State.IN_HAND:
			_set_focus(true)
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hovering = false
		if state == State.FOCUSED:
			_set_focus(false)


# ─── 状态切换 ──────────────────────────────────────────────────


func _set_focus(on: bool) -> void:
	if on and state == State.IN_HAND:
		state = State.FOCUSED
		z_index = 50
		focused.emit(self)
	elif not on and state == State.FOCUSED:
		state = State.IN_HAND
		z_index = 0
		unfocused.emit(self)


func _start_drag() -> void:
	state = State.DRAGGING
	z_index = 100
	rotation = 0.0
	drag_started.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.1, 1.1), 0.12)


func _end_drag(global_pos: Vector2) -> void:
	_pressing = false
	state = State.IN_HAND
	z_index = 0
	drag_ended.emit(self, global_pos)


## 拖拽中跟随指针（由 _process 驱动，避免依赖 motion 事件频率）。
func _process(_delta: float) -> void:
	if state == State.DRAGGING:
		global_position = get_global_mouse_position() - CARD_SIZE / 2.0


# ─── 对外方法 ──────────────────────────────────────────────────


## 打出到棋盘：禁用交互并标记状态。
func place_on_board() -> void:
	state = State.ON_BOARD
	z_index = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.15)


## 抽牌翻面入场动画（从牌堆位置飞入由场景层控制起点，这里做翻面）。
func flip_in() -> void:
	scale = Vector2(0.05, 1.0)
	var tw := create_tween()
	tw.tween_property(self, "scale:x", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 平滑移动到指定布局位（FanHand 调用）。
func tween_to(target_pos: Vector2, target_rot: float, target_scale: Vector2, duration: float) -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "position", target_pos, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation", target_rot, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", target_scale, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
