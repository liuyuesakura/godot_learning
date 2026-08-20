## CombatScene.gd — 战斗画面（核心玩法层）。
## 竖屏四区布局：顶栏 → 敌人区 → 状态条 → 手牌区 + 底栏（能量宝石/结回合）。
## 表现层只做两件事：把 CombatState 渲染出来，把玩家输入翻译成 CombatState 调用。
## 敌人回合用 await 分步驱动，插入演出间隔；逻辑本身是同步纯函数式的。
class_name CombatScene
extends Control

const ENEMY_TURN_GAP: float = 0.5

var combat: CombatState
var _selected_card: CardInstance = null
var _busy: bool = false

var _hp_bar: ProgressBar
var _hp_label: Label
var _gold_label: Label
var _floor_label: Label
var _energy_label: Label
var _draw_label: Label
var _discard_label: Label
var _status_label: Label
var _log_label: Label
var _end_turn_btn: Button
var _enemy_box: HBoxContainer
var _hand_box: HBoxContainer
var _enemy_views: Array[EnemyView] = []
var _card_views: Array[CardView] = []


func _ready() -> void:
	var run: RunState = GameManager.run
	var kind: String = GameManager.current_encounter
	var rng := RNGManager.get_rng("combat_%d_%d" % [run.current_floor, run.current_index])
	var enemy_ids := ContentRegistry.roll_encounter(kind, rng)

	combat = CombatState.new(run.max_hp, run.hp, 3)
	combat.setup(run.get_deck_ids(), enemy_ids, rng)
	combat.state_changed.connect(_refresh)
	combat.log_message.connect(_on_log)
	combat.combat_ended.connect(_on_combat_ended)

	_build_ui()
	combat.start()


# ─── UI 构建 ─────────────────────────────────────────────────────


func _build_ui() -> void:
	add_child(UITheme.make_bg())
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	root.add_child(_build_top_bar())

	var enemy_area := CenterContainer.new()
	enemy_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_enemy_box = HBoxContainer.new()
	_enemy_box.add_theme_constant_override("separation", 16)
	enemy_area.add_child(_enemy_box)
	root.add_child(enemy_area)

	_log_label = UITheme.label("", 13, UITheme.DIM)
	_log_label.custom_minimum_size = Vector2(0, 22)
	root.add_child(_log_label)

	_status_label = UITheme.label("", 14, UITheme.TEXT)
	_status_label.custom_minimum_size = Vector2(0, 30)
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root.add_child(_status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var hand_center := CenterContainer.new()
	hand_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hand_box = HBoxContainer.new()
	_hand_box.add_theme_constant_override("separation", 10)
	hand_center.add_child(_hand_box)
	scroll.add_child(hand_center)
	root.add_child(scroll)

	root.add_child(_build_bottom_bar())


func _build_top_bar() -> Panel:
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(0, 56)
	bar.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.04, 0.06, 0.12, 0.92), Color(0, 0, 0, 0.3), 0))
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 12.0
	hbox.offset_right = -12.0
	hbox.add_theme_constant_override("separation", 10)
	bar.add_child(hbox)

	var flee := UITheme.ghost_button("撤退", Vector2(70, 38))
	flee.pressed.connect(func() -> void:
		if flee.text == "撤退":
			flee.text = "确认？"
		else:
			GameManager.end_run())
	hbox.add_child(flee)

	_floor_label = UITheme.label("", 13, UITheme.DIM)
	_floor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(_floor_label)

	_hp_bar = UITheme.make_hp_bar(150.0)
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hp_bar.custom_minimum_size = Vector2(150, 12)
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

	var encounter := UITheme.label(_encounter_name(), 14, Color(1, 1, 1, 0.8))
	encounter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(encounter)
	return bar


func _encounter_name() -> String:
	match GameManager.current_encounter:
		"elite":
			return "精英战 · 第 %d 层" % GameManager.run.current_floor
		"boss":
			return "BOSS · 守卫者"
	return "战斗 · 第 %d 层" % GameManager.run.current_floor


func _build_bottom_bar() -> Panel:
	var bar := Panel.new()
	bar.custom_minimum_size = Vector2(0, 96)
	bar.add_theme_stylebox_override("panel", UITheme.panel_style(Color(0.04, 0.06, 0.12, 0.92), Color(UITheme.GOLD.r, UITheme.GOLD.g, UITheme.GOLD.b, 0.25), 0))
	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 16.0
	hbox.offset_right = -16.0
	hbox.add_theme_constant_override("separation", 12)
	bar.add_child(hbox)

	# 能量宝石。
	var gem := Panel.new()
	gem.custom_minimum_size = Vector2(72, 72)
	gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var gem_style := StyleBoxFlat.new()
	gem_style.bg_color = Color(0.10, 0.25, 0.60, 0.95)
	gem_style.border_color = UITheme.GOLD_L
	gem_style.set_corner_radius_all(36)
	gem_style.set_border_width_all(2)
	gem_style.shadow_color = Color(0.3, 0.55, 1.0, 0.5)
	gem_style.shadow_size = 16
	gem.add_theme_stylebox_override("panel", gem_style)
	var gem_v := VBoxContainer.new()
	gem_v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gem_v.alignment = BoxContainer.ALIGNMENT_CENTER
	gem.add_child(gem_v)
	var gem_caption := UITheme.label("能量", 11, Color(1, 1, 1, 0.75))
	gem_v.add_child(gem_caption)
	_energy_label = UITheme.label("3/3", 20, Color.WHITE)
	gem_v.add_child(_energy_label)
	hbox.add_child(gem)

	var mid_spacer := Control.new()
	mid_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(mid_spacer)

	_end_turn_btn = UITheme.gold_button("结束回合", Vector2(190, 60))
	_end_turn_btn.pressed.connect(_on_end_turn)
	hbox.add_child(_end_turn_btn)

	var right_spacer := Control.new()
	right_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(right_spacer)

	var piles := VBoxContainer.new()
	piles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	piles.add_theme_constant_override("separation", 4)
	hbox.add_child(piles)
	_draw_label = UITheme.label("抽 0", 13, UITheme.DIM)
	piles.add_child(_draw_label)
	_discard_label = UITheme.label("弃 0", 13, UITheme.DIM)
	piles.add_child(_discard_label)
	return bar


# ─── 刷新 ────────────────────────────────────────────────────────


func _refresh() -> void:
	var run: RunState = GameManager.run
	_hp_bar.max_value = combat.player_max_hp
	_hp_bar.value = combat.player_hp
	_hp_label.text = "%d/%d" % [combat.player_hp, combat.player_max_hp]
	_gold_label.text = "金 %d" % run.gold
	_floor_label.text = "回合 %d" % combat.turn
	_energy_label.text = "%d/%d" % [combat.energy, combat.max_energy]
	_draw_label.text = "抽 %d" % combat.deck.draw_pile.size()
	_discard_label.text = "弃 %d" % combat.deck.discard_pile.size()

	var statuses: Array[String] = []
	if combat.player_block > 0:
		statuses.append("格挡 %d" % combat.player_block)
	if combat.player_strength > 0:
		statuses.append("力量 %d" % combat.player_strength)
	if combat.player_weak > 0:
		statuses.append("虚弱 %d" % combat.player_weak)
	if combat.player_vulnerable > 0:
		statuses.append("易伤 %d" % combat.player_vulnerable)
	_status_label.text = " · ".join(statuses) if not statuses.is_empty() else "—"

	_end_turn_btn.disabled = not combat.is_player_turn or combat.is_over or _busy
	_rebuild_enemies()
	_rebuild_hand()


func _rebuild_enemies() -> void:
	for v: EnemyView in _enemy_views:
		v.queue_free()
	_enemy_views.clear()
	var targeting: bool = _selected_card != null and _selected_card.needs_target()
	for i: int in combat.enemies.size():
		var view := EnemyView.new(i)
		view.clicked.connect(_on_enemy_clicked)
		_enemy_box.add_child(view)
		view.update_from(combat.enemies[i])
		view.set_targetable(targeting and combat.enemies[i].alive)
		_enemy_views.append(view)


func _rebuild_hand() -> void:
	for v: CardView in _card_views:
		v.queue_free()
	_card_views.clear()
	for card: CardInstance in combat.deck.hand:
		var view := CardView.new(card)
		view.clicked.connect(_on_card_clicked)
		_hand_box.add_child(view)
		view.refresh()
		view.set_selected(card == _selected_card)
		view.set_playable(combat.can_play_card(card))
		_card_views.append(view)


# ─── 玩家输入 ────────────────────────────────────────────────────


func _on_card_clicked(card: CardInstance) -> void:
	if _busy or not combat.is_player_turn or combat.is_over:
		return
	if not combat.can_play_card(card):
		return
	if _selected_card == card:
		_selected_card = null
		_refresh()
		return
	if not card.needs_target():
		_play_card(card, _first_alive_index())
		return
	_selected_card = card
	_log_label.text = "选择一个目标…"
	_refresh()


func _on_enemy_clicked(index: int) -> void:
	if _busy or not combat.is_player_turn or combat.is_over:
		return
	if _selected_card != null and _selected_card.needs_target():
		_play_card(_selected_card, index)


func _play_card(card: CardInstance, target: int) -> void:
	_selected_card = null
	if not combat.play_card(card, target):
		_refresh()


func _first_alive_index() -> int:
	for i: int in combat.enemies.size():
		if combat.enemies[i].alive:
			return i
	return -1


func _on_end_turn() -> void:
	if _busy or not combat.is_player_turn or combat.is_over:
		return
	_busy = true
	_selected_card = null
	combat.begin_enemy_phase()
	_refresh()
	await get_tree().create_timer(0.45).timeout
	for i: int in combat.enemies.size():
		if combat.is_over:
			break
		if combat.enemies[i].alive:
			combat.execute_enemy_action(i)
			await get_tree().create_timer(ENEMY_TURN_GAP).timeout
	if not combat.is_over:
		await get_tree().create_timer(0.35).timeout
		combat.begin_player_turn()
	_busy = false
	_refresh()


func _on_log(text: String) -> void:
	_log_label.text = text


# ─── 结算 ────────────────────────────────────────────────────────


func _on_combat_ended(victory: bool) -> void:
	var run: RunState = GameManager.run
	if not victory:
		_show_end_overlay(false)
		return
	run.hp = maxi(1, combat.player_hp)
	var reward_gold := _reward_gold()
	run.add_gold(reward_gold)
	SaveManager.save_run(run)
	_show_reward_overlay(reward_gold)


func _reward_gold() -> int:
	var rng := RNGManager.get_rng("loot_%d_%d" % [GameManager.run.current_floor, GameManager.run.current_index])
	match GameManager.current_encounter:
		"elite":
			return rng.randi_range(25, 35)
		"boss":
			return 60
	return rng.randi_range(10, 20)


func _show_reward_overlay(reward_gold: int) -> void:
	var run: RunState = GameManager.run
	var rewards := ContentRegistry.roll_card_rewards(
		GameManager.get_run_color(),
		RNGManager.get_rng("reward_%d_%d" % [run.current_floor, run.current_index])
	)
	var overlay := _make_overlay_panel("战斗胜利", "获得 %d 金币\n选择一张卡牌加入牌组，或跳过保持精简。" % reward_gold)
	var vbox: VBoxContainer = overlay.get_child(1).get_child(0)
	var cards_row := HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", 12)
	vbox.add_child(cards_row)
	for def: Dictionary in rewards:
		var view := CardView.new(CardInstance.new(String(def["id"])))
		view.clicked.connect(func(card: CardInstance) -> void:
			run.add_card(card.definition_id)
			SaveManager.save_run(run)
			_after_reward())
		cards_row.add_child(view)
		view.refresh()
		view.set_playable(true)
	var skip := UITheme.ghost_button("跳过", Vector2(160, 44))
	skip.pressed.connect(_after_reward)
	vbox.add_child(skip)


func _show_end_overlay(victory: bool) -> void:
	var run: RunState = GameManager.run
	var overlay: Control
	if victory:
		overlay = _make_overlay_panel("远征完成", "%s 登上了尖塔之巅！\n最终金币：%d" % [run.character_name, run.gold])
	else:
		overlay = _make_overlay_panel("远征失败", "%s 倒在了第 %d 层。\n每次失败都是下一次远征的经验。" % [run.character_name, run.current_floor])
	var vbox: VBoxContainer = overlay.get_child(1).get_child(0)
	var btn := UITheme.gold_button("回到主菜单")
	btn.pressed.connect(func() -> void: GameManager.end_run())
	vbox.add_child(btn)


func _make_overlay_panel(title: String, body: String) -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(640, 0)
	panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -320.0
	panel.offset_right = 320.0
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 24.0
	vbox.offset_right = -24.0
	vbox.offset_top = 20.0
	vbox.offset_bottom = -20.0
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	overlay.add_child(panel)
	add_child(overlay)
	vbox.add_child(UITheme.label(title, 26, UITheme.GOLD))
	var body_label := UITheme.label(body, 15, UITheme.TEXT)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(body_label)
	return overlay


func _after_reward() -> void:
	if GameManager.current_encounter == "boss":
		SaveManager.save_run(GameManager.run)
		_show_end_overlay(true)
		return
	GameManager.finish_encounter()
