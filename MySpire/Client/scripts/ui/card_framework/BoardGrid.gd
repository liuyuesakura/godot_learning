## BoardGrid.gd — 竖屏卡牌框架 · 棋盘打出区（网格托管）。
## 参考 framework BoardPlacementGrid：打出的卡按网格排列，卡牌交出交互权（不可再拖/点）。
class_name BoardGrid
extends Control

## 托管中的卡（按打出顺序）。
var hosted_cards: Array[BattleCard] = []

var _grid: GridContainer
var _hint_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_grid.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_grid.grow_vertical = Control.GROW_DIRECTION_BOTH
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid)

	_hint_label = UITheme.label("（打出或拖拽卡牌到此区域）", 11, UITheme.DIM)
	_hint_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(_hint_label)
	_refresh_hint()


## 托管一张卡（从 FanHand remove 后调用）。
func host_card(card: BattleCard) -> void:
	if card.get_parent() != null:
		card.get_parent().remove_child(card)
	_grid.add_child(card)
	card.place_on_board()
	hosted_cards.append(card)
	_refresh_hint()


## 清空棋盘（卡牌节点由调用方决定去向，这里只摘除）。
func clear() -> Array[BattleCard]:
	var removed: Array[BattleCard] = []
	for card: BattleCard in hosted_cards:
		if card.get_parent() == _grid:
			_grid.remove_child(card)
			removed.append(card)
	hosted_cards.clear()
	_refresh_hint()
	return removed


func get_hosted_count() -> int:
	return hosted_cards.size()


func _refresh_hint() -> void:
	if _hint_label != null:
		_hint_label.visible = hosted_cards.is_empty()
