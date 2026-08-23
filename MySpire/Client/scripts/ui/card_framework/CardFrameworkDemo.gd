## CardFrameworkDemo.gd — 竖屏卡牌框架演示场景（独立运行：F6 或 godot res://scenes/card_framework_demo.tscn）。
## 全流程：牌库（CardPileView）→ 抽牌（翻面入 FanHand）→ 点击/拖拽打出（BoardGrid）→ 弃牌堆。
## 对应 db0/godot-card-game-framework 的 Main 演示：手牌弧排 + 聚焦让位 + 拖放托管 + 牌堆浏览。
class_name CardFrameworkDemo
extends Control

const DEMO_DECK: Array = [
	{"name": "打击", "cost": 1, "type": "attack", "emoji": "⚔️", "description": "造成 6 点伤害"},
	{"name": "痛击", "cost": 2, "type": "attack", "emoji": "🗡️", "description": "造成 14 点伤害"},
	{"name": "旋风斩", "cost": 3, "type": "attack", "emoji": "🌪️", "description": "对所有敌人造成 8 点伤害"},
	{"name": "防御", "cost": 1, "type": "skill", "emoji": "🛡️", "description": "获得 6 点格挡"},
	{"name": "铁壁", "cost": 2, "type": "skill", "emoji": "🏰", "description": "获得 14 点格挡"},
	{"name": "洞察", "cost": 0, "type": "skill", "emoji": "👁️", "description": "抽 2 张牌"},
	{"name": "力量涌动", "cost": 2, "type": "power", "emoji": "💪", "description": "每回合获得 2 点力量"},
	{"name": "回响", "cost": 1, "type": "power", "emoji": "🌀", "description": "本回合打出的下一张牌复制一次"},
	{"name": "打击", "cost": 1, "type": "attack", "emoji": "⚔️", "description": "造成 6 点伤害"},
	{"name": "防御", "cost": 1, "type": "skill", "emoji": "🛡️", "description": "获得 6 点格挡"},
	{"name": "处决", "cost": 2, "type": "attack", "emoji": "⚡", "description": "对易伤敌人造成双倍伤害"},
	{"name": "聚能", "cost": 1, "type": "skill", "emoji": "🔮", "description": "获得 2 点能量"},
]

var _hand: FanHand
var _board_panel: Panel
var _board: BoardGrid
var _deck_pile: CardPileView
var _discard_pile: CardPileView
var _toast: Label
var _hand_count: Label


func _ready() -> void:
	add_child(UITheme.make_bg())
	_build_top_bar()
	_build_board()
	_build_piles()
	_build_hand()
	_build_toast()
	for i: int in 4:
		_draw_one(false)


# ─── 构建 ──────────────────────────────────────────────────────


func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 16.0
	bar.offset_right = -16.0
	bar.offset_top = 10.0
	bar.offset_bottom = 54.0
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)

	var title := UITheme.label("竖屏卡牌框架 Demo", 18, UITheme.GOLD_L)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(title)

	_hand_count = UITheme.label("手牌 0", 12, UITheme.DIM)
	_hand_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(_hand_count)

	var draw_btn := UITheme.gold_button("抽牌", Vector2(88.0, 42.0))
	draw_btn.pressed.connect(func() -> void: _draw_one(true))
	bar.add_child(draw_btn)

	var discard_btn := UITheme.ghost_button("弃全部", Vector2(88.0, 42.0))
	discard_btn.pressed.connect(_discard_all)
	bar.add_child(discard_btn)

	var clear_btn := UITheme.ghost_button("清棋盘", Vector2(88.0, 42.0))
	clear_btn.pressed.connect(_clear_board)
	bar.add_child(clear_btn)


func _build_board() -> void:
	_board_panel = Panel.new()
	_board_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_board_panel.offset_left = 16.0
	_board_panel.offset_right = -16.0
	_board_panel.offset_top = 62.0
	_board_panel.offset_bottom = 460.0
	_board_panel.add_theme_stylebox_override("panel", UITheme.panel_style(
		Color(0.05, 0.08, 0.16, 0.85), Color(0.788, 0.659, 0.298, 0.3), 12, 1
	))
	add_child(_board_panel)

	var board_title := UITheme.label("打 出 区", 12, UITheme.DIM)
	board_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	board_title.offset_top = 6.0
	_board_panel.add_child(board_title)

	_board = BoardGrid.new()
	_board.offset_top = 30.0
	_board.offset_bottom = -10.0
	_board_panel.add_child(_board)


func _build_piles() -> void:
	_deck_pile = CardPileView.new()
	_deck_pile.pile_name = "牌库"
	_deck_pile.position = Vector2(48.0, 500.0)
	add_child(_deck_pile)
	_deck_pile.set_cards(DEMO_DECK.duplicate())

	_discard_pile = CardPileView.new()
	_discard_pile.pile_name = "弃牌堆"
	_discard_pile.position = Vector2(592.0, 500.0)
	add_child(_discard_pile)
	_discard_pile.set_cards([])

	var hint := UITheme.label("点击牌堆查看内容", 10, UITheme.DIM)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint.offset_top = 616.0
	add_child(hint)


func _build_hand() -> void:
	_hand = FanHand.new()
	_hand.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hand.offset_top = -300.0  # 容器高度 300px（含弧线下沉空间）
	_hand.card_activated.connect(_on_card_activated)
	add_child(_hand)


func _build_toast() -> void:
	_toast = UITheme.label("", 13, UITheme.GOLD_L)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 648.0
	_toast.modulate.a = 0.0
	add_child(_toast)


# ─── 流程逻辑 ──────────────────────────────────────────────────


func _draw_one(show_toast: bool) -> void:
	var data: Dictionary = _deck_pile.pop_card()
	if data.is_empty():
		_show_toast("牌库已抽空")
		return
	var card := BattleCard.new()
	card.card_data = data
	_connect_card_drag(card)
	# 入场起点：牌库位置，relayout 会把它补间到弧线槽位。
	_hand.add_child(card)
	card.global_position = _deck_pile.global_position + Vector2(40.0, 20.0)
	card.scale = Vector2(0.6, 0.6)
	_hand.add_card(card)
	_refresh_count()
	if show_toast:
		_show_toast("抽到「%s」" % String(data.get("name", "")))


## 点击打出（聚焦后再次点击）。
func _on_card_activated(card: BattleCard) -> void:
	_play_to_board(card)


## 打出到棋盘。
func _play_to_board(card: BattleCard) -> void:
	_hand.remove_card(card)
	_board.host_card(card)
	_refresh_count()
	_show_toast("打出「%s」" % String(card.card_data.get("name", "")))


## 弃掉手牌全部。
func _discard_all() -> void:
	while _hand.get_card_count() > 0:
		var card: BattleCard = _hand.cards.back()
		_hand.remove_card(card)
		_discard_pile.push_card(card.card_data)
		card.queue_free()
	_refresh_count()
	_show_toast("已弃全部手牌")


## 棋盘上的卡全部进弃牌堆。
func _clear_board() -> void:
	var removed: Array[BattleCard] = _board.clear()
	if removed.is_empty():
		return
	for card: BattleCard in removed:
		_discard_pile.push_card(card.card_data)
		card.queue_free()
	_show_toast("棋盘已清空 → 弃牌堆")


func _refresh_count() -> void:
	_hand_count.text = "手牌 %d" % _hand.get_card_count()


func _show_toast(msg: String) -> void:
	_toast.text = msg
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.4)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.3)


# ─── 拖拽落点仲裁 ──────────────────────────────────────────────


## 给新建卡牌接上拖拽结束处理（区分打出/归位）。
func _connect_card_drag(card: BattleCard) -> void:
	card.drag_ended.connect(_on_card_drag_ended)


func _on_card_drag_ended(card: BattleCard, global_pos: Vector2) -> void:
	if _board_panel.get_global_rect().has_point(global_pos):
		_play_to_board(card)
	else:
		_hand.snap_back(card)
		_show_toast("已放回手牌")
