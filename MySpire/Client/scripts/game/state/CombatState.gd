## CombatState.gd — 战斗状态机（纯逻辑层，可独立于场景测试）。
## 回合流由 CombatScene 分步驱动以插入演出间隔：
##   begin_enemy_phase() → execute_enemy_action(i)… → begin_player_turn()
## 伤害公式：base + 力量 → 攻击方虚弱 ×0.75 → 受击方易伤 ×1.5（均向下取整）。
class_name CombatState
extends RefCounted

signal state_changed
signal combat_ended(victory: bool)
signal log_message(text: String)

const MAX_HAND: int = 10
const DRAW_PER_TURN: int = 5

var turn: int = 1
var is_player_turn: bool = true
var is_over: bool = false
var victory: bool = false

var energy: int = 3
var max_energy: int = 3
var player_max_hp: int = 80
var player_hp: int = 80
var player_block: int = 0
var player_strength: int = 0
var player_weak: int = 0
var player_vulnerable: int = 0

var deck: DeckManager
var enemies: Array[EnemyState] = []
var rng: RandomNumberGenerator
var resolver: EffectResolver


func _init(p_max_hp: int, p_hp: int, p_energy: int = 3) -> void:
	player_max_hp = p_max_hp
	player_hp = p_hp
	max_energy = p_energy
	energy = p_energy


func setup(deck_ids: Array, enemy_ids: Array, p_rng: RandomNumberGenerator) -> void:
	rng = p_rng
	deck = DeckManager.new(deck_ids)
	resolver = EffectResolver.new(self)
	enemies.clear()
	for id: Variant in enemy_ids:
		var def: Dictionary = ContentRegistry.get_enemy(String(id))
		enemies.append(EnemyState.new(def, rng))


func start() -> void:
	deck.shuffle(rng)
	draw(DRAW_PER_TURN)
	_roll_all_intents()
	state_changed.emit()


## ─── 玩家行动 ───────────────────────────────────────────────────


func can_play_card(card: CardInstance) -> bool:
	return is_player_turn and not is_over and energy >= card.cost()


func play_card(card: CardInstance, target_index: int) -> bool:
	if not can_play_card(card):
		return false
	if card.needs_target() and not is_valid_target(target_index):
		return false
	energy -= card.cost()
	deck.remove_from_hand(card)
	log_message.emit("打出 " + card.display_name())
	for effect: Dictionary in card.effects():
		resolver.resolve(effect, target_index)
	if card.will_exhaust():
		deck.move_to_exhaust(card)
	else:
		deck.move_to_discard(card)
	state_changed.emit()
	return true


func is_valid_target(index: int) -> bool:
	return index >= 0 and index < enemies.size() and enemies[index].alive


func draw(n: int) -> void:
	var drawn: Array[CardInstance] = deck.draw_cards(n, rng)
	for c: CardInstance in drawn:
		if deck.hand.size() < MAX_HAND:
			deck.hand.append(c)
		else:
			deck.move_to_discard(c)
	state_changed.emit()


## ─── 回合相位（由表现层分步调用） ───────────────────────────────


func begin_enemy_phase() -> void:
	if not is_player_turn or is_over:
		return
	is_player_turn = false
	if player_weak > 0:
		player_weak -= 1
	if player_vulnerable > 0:
		player_vulnerable -= 1
	deck.discard_hand()
	state_changed.emit()


func execute_enemy_action(index: int) -> void:
	if is_over or index < 0 or index >= enemies.size():
		return
	var enemy: EnemyState = enemies[index]
	if not enemy.alive:
		return
	enemy.block = 0
	var intent: Dictionary = enemy.intent
	log_message.emit("%s 使用 %s" % [enemy.display_name, String(intent.get("name", ""))])
	if int(intent.get("block", 0)) > 0:
		enemy.gain_block(int(intent["block"]))
	if int(intent.get("strength", 0)) > 0:
		enemy.strength += int(intent["strength"])
	var hits: int = maxi(1, int(intent.get("hits", 1)))
	for h: int in hits:
		if is_over:
			break
		if int(intent.get("damage", 0)) > 0:
			_enemy_attack(enemy, int(intent["damage"]))
	if not is_over:
		if int(intent.get("weak", 0)) > 0:
			player_weak += int(intent["weak"])
			log_message.emit("你获得了虚弱")
		if int(intent.get("vulnerable", 0)) > 0:
			player_vulnerable += int(intent["vulnerable"])
			log_message.emit("你获得了易伤")
	enemy.tick_debuffs()
	state_changed.emit()


func begin_player_turn() -> void:
	if is_over:
		return
	turn += 1
	is_player_turn = true
	player_block = 0
	energy = max_energy
	draw(DRAW_PER_TURN)
	_roll_all_intents()
	state_changed.emit()


## ─── 伤害与状态 ─────────────────────────────────────────────────


func deal_damage_to_enemy(index: int, base: int) -> void:
	if not is_valid_target(index):
		return
	var enemy: EnemyState = enemies[index]
	var dmg: int = base + player_strength
	if player_weak > 0:
		dmg = int(float(dmg) * 0.75)
	if enemy.vulnerable > 0:
		dmg = int(float(dmg) * 1.5)
	enemy.take_damage(dmg)
	if not enemy.alive:
		log_message.emit("%s 被击败！" % enemy.display_name)
		_check_victory()


func gain_player_block(n: int) -> void:
	player_block += n


func apply_status_to_enemy(index: int, kind: String, n: int) -> void:
	if not is_valid_target(index):
		return
	var enemy: EnemyState = enemies[index]
	match kind:
		"weak":
			enemy.weak += n
		"vulnerable":
			enemy.vulnerable += n
		_:
			push_warning("CombatState: unknown status '%s'" % kind)


func get_deck_ids() -> Array:
	var ids: Array = []
	for c: CardInstance in deck.draw_pile + deck.hand + deck.discard_pile + deck.exhaust_pile:
		ids.append(c.definition_id)
	return ids


## ─── 内部 ───────────────────────────────────────────────────────


func _enemy_attack(enemy: EnemyState, base: int) -> void:
	var dmg: int = base + enemy.strength
	if enemy.weak > 0:
		dmg = int(float(dmg) * 0.75)
	if player_vulnerable > 0:
		dmg = int(float(dmg) * 1.5)
	var absorbed: int = mini(player_block, dmg)
	player_block -= absorbed
	dmg -= absorbed
	player_hp -= dmg
	if player_hp <= 0:
		player_hp = 0
		_end_combat(false)


func _roll_all_intents() -> void:
	for enemy: EnemyState in enemies:
		if enemy.alive:
			enemy.intent = EnemyAI.roll_intent(enemy, rng)


func _check_victory() -> void:
	for enemy: EnemyState in enemies:
		if enemy.alive:
			return
	_end_combat(true)


func _end_combat(v: bool) -> void:
	if is_over:
		return
	is_over = true
	victory = v
	state_changed.emit()
	combat_ended.emit(v)
