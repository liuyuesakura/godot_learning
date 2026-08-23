## FanHand.gd — 竖屏弧形手牌容器。
## 移植 db0/godot-card-game-framework 的椭圆手牌数学（CardTemplate._recalculate_position_use_oval）到
## Godot 4 竖屏（720×1280）。核心公式（框架原作者标注为"经验公式，手感调优结果"）：
##   1. 相邻卡张角 = clamp(60 / 手牌数, 6.5°, 15°) —— 手牌越多排得越密
##   2. 每张卡角度 = 90° + (半张数 - 索引) × 张角 —— 以竖直向上为 90° 左右展开
##   3. 椭圆半径：横 = 容器宽 × 0.75，纵 = 卡高 × 1.5 —— 弧线的"弯曲程度"
##   4. 卡牌旋转 = 90° − 椭圆法线角（法线由 atan(−纵半径/横半径/tan θ) 求得）—— 卡面沿弧切线
##   5. 聚焦推邻：邻牌角度按 index_diff 偏移 (1.95 − 0.3·diff²) × min(张角, 5°) —— 近邻多推远邻少推
## 交互：悬停/点击聚焦（卡牌上浮放大 + 邻牌让位），拖拽由 BattleCard 发信号、场景层仲裁。
class_name FanHand
extends Control

## 聚焦的卡被再次点击（打出意图）。场景层监听后决定 move_to 棋盘或弃牌堆。
signal card_activated(card: BattleCard)

## 聚焦时卡牌放大倍率。
const FOCUS_SCALE := 1.3
## 聚焦时卡牌上浮像素。
const FOCUS_LIFT := 30.0
## 布局动画时长。
const LAYOUT_TWEEN := 0.22

var cards: Array[BattleCard] = []
var _focused: BattleCard = null
var _excluded: Array[BattleCard] = []  # 拖拽中的卡，不参与布局


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false


# ─── 增删卡 ────────────────────────────────────────────────────


## 加入手牌（通常在卡牌入场动画完成后调用；先 append 再 relayout）。
func add_card(card: BattleCard) -> void:
	if card.get_parent() != self:
		if card.get_parent() != null:
			card.get_parent().remove_child(card)
		add_child(card)
	cards.append(card)
	card.focused.connect(_on_card_focused)
	card.unfocused.connect(_on_card_unfocused)
	card.activated.connect(_on_card_activated)
	card.drag_started.connect(_on_card_drag_started)
	relayout()


## 从手牌移除（不打 free——去向由场景层决定：棋盘/弃牌堆）。
func remove_card(card: BattleCard) -> void:
	card.focused.disconnect(_on_card_focused)
	card.unfocused.disconnect(_on_card_unfocused)
	card.activated.disconnect(_on_card_activated)
	card.drag_started.disconnect(_on_card_drag_started)
	cards.erase(card)
	_excluded.erase(card)
	if _focused == card:
		_focused = null
	if card.get_parent() == self:
		remove_child(card)
	relayout()


## 拖拽落空后归位手牌。
func snap_back(card: BattleCard) -> void:
	if card in cards:
		_excluded.erase(card)
		card.scale = Vector2.ONE
		relayout()


func get_card_count() -> int:
	return cards.size()


# ─── 椭圆布局数学（框架公式移植） ──────────────────────────────


## 计算第 index 张卡的布局槽位。返回 {pos: Vector2(容器内左上角), rot: float(度)}。
## index_diff：聚焦推邻时的邻牌偏移（±1/±2），0 为常规布局。
func slot_for(index: int, count: int, index_diff: int = 0) -> Dictionary:
	var card_w: float = BattleCard.CARD_SIZE.x
	var card_h: float = BattleCard.CARD_SIZE.y
	# 椭圆半径（经验公式）。
	var hor_rad: float = size.x * 0.5 * 1.5
	var ver_rad: float = card_h * 1.5
	# 卡张角。
	var card_angle: float = clampf(60.0 / float(count), 6.5, 15.0)
	var half: float = (count - 1) / 2.0
	var angle_deg: float = 90.0 + (half - index) * card_angle
	if index_diff != 0:
		angle_deg -= signf(index_diff) * (1.95 - 0.3 * index_diff * index_diff) * minf(card_angle, 5.0)
	var rad: float = deg_to_rad(angle_deg)
	# 椭圆上的点（y 取负 = 弧在椭圆顶部）。
	var oval_pt := Vector2(hor_rad * cos(rad), -ver_rad * sin(rad))
	# 椭圆中心：水平居中；垂直方向使中位卡的底边贴近容器底部。
	var center := Vector2(size.x / 2.0, size.y - 10.0 + 0.5 * card_h)
	# 卡面旋转 = 90° − 法线角。
	var normal_deg: float = 90.0
	if absf(tan(rad)) > 0.0001:
		normal_deg = rad_to_deg(atan(-ver_rad / hor_rad / tan(rad))) + 90.0
	var rot: float = 90.0 - normal_deg
	# 卡顶中点放在椭圆点上 → 换算为左上角坐标（补偿旋转）。
	var left_top := Vector2(-card_w / 2.0, -card_h / 2.0)
	var center_top := Vector2(0.0, -card_h / 2.0)
	var delta := left_top - center_top.rotated(deg_to_rad(rot))
	return {"pos": center + oval_pt + delta, "rot": rot}


## 全量重排（含聚焦推邻）。instant = true 时跳过 Tween（首次入场）。
func relayout(instant: bool = false) -> void:
	var laid: Array[BattleCard] = []
	for c: BattleCard in cards:
		if c not in _excluded:
			laid.append(c)
	var count: int = laid.size()
	for i: int in count:
		var card := laid[i]
		var target_scale := Vector2.ONE
		var target_rot: float = 0.0
		var slot: Dictionary
		if card == _focused:
			slot = slot_for(i, count, 0)
			target_scale = Vector2(FOCUS_SCALE, FOCUS_SCALE)
			target_rot = 0.0
		else:
			var diff: int = _neighbor_diff(card)
			slot = slot_for(i, count, diff)
		var pos: Vector2 = slot["pos"]
		if card == _focused:
			pos.y -= FOCUS_LIFT
		card.z_index = 50 if card == _focused else i
		if instant:
			card.position = pos
			card.rotation = target_rot if card == _focused else float(slot["rot"])
			card.scale = target_scale
		else:
			card.tween_to(pos, target_rot if card == _focused else float(slot["rot"]), target_scale, LAYOUT_TWEEN)


## 聚焦卡的 ±1/±2 邻牌需要让位；返回该卡相对聚焦卡的 index 差，非邻牌返回 0。
func _neighbor_diff(card: BattleCard) -> int:
	if _focused == null or card == _focused:
		return 0
	var laid: Array[BattleCard] = []
	for c: BattleCard in cards:
		if c not in _excluded:
			laid.append(c)
	var focus_index: int = laid.find(_focused)
	var card_index: int = laid.find(card)
	if focus_index < 0 or card_index < 0:
		return 0
	var diff: int = card_index - focus_index
	if diff >= -2 and diff <= 2:
		return diff
	return 0


# ─── 卡牌信号处理 ──────────────────────────────────────────────


func _on_card_focused(card: BattleCard) -> void:
	_focused = card
	relayout()


func _on_card_unfocused(card: BattleCard) -> void:
	if _focused == card:
		_focused = null
	relayout()


func _on_card_activated(card: BattleCard) -> void:
	card_activated.emit(card)


func _on_card_drag_started(card: BattleCard) -> void:
	if _focused == card:
		_focused = null
	_excluded.append(card)
	relayout()
