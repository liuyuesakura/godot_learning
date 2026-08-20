## RunState.gd — Run 全局状态（纯逻辑）。
## 持有角色、HP、金币、牌组、遗物与地图进度。
## 地图不入存档：由 seed 确定性重建；玩家状态与位置入存档。
class_name RunState
extends RefCounted

var character_id: String
var character_name: String
var hp: int
var max_hp: int
var gold: int = 99
var deck: Array[CardInstance] = []
var relics: Array[String] = []
var map: Dictionary = {}
var current_floor: int = 0
var current_index: int = -1


func _init(id: String) -> void:
	character_id = id
	var c: Dictionary = ContentRegistry.get_character(id)
	character_name = String(c.get("name", id))
	max_hp = int(c.get("hp", 75))
	hp = max_hp
	for card_id: Variant in c.get("deck", []):
		deck.append(CardInstance.new(String(card_id)))
	map = MapGenerator.generate_act(RNGManager.get_rng("map"))


## ─── 进度查询 ───────────────────────────────────────────────────


## 可达节点：开局 = 第 1 层全部；否则 = 当前节点的 edges。
func get_reachable() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if current_index < 0:
		for node: Dictionary in map.get(1, []):
			result.append(Vector2i(1, int(node["index"])))
	else:
		var node: Dictionary = get_node_at(current_floor, current_index)
		for j: Variant in node.get("edges", []):
			result.append(Vector2i(current_floor + 1, int(j)))
	return result


func get_node_at(floor: int, index: int) -> Dictionary:
	var nodes: Array = map.get(floor, [])
	if index < 0 or index >= nodes.size():
		return {}
	return nodes[index]


func is_reachable(floor: int, index: int) -> bool:
	return get_reachable().has(Vector2i(floor, index))


func is_boss_defeated() -> bool:
	return current_floor >= MapGenerator.BOSS_FLOOR and current_index >= 0


## ─── 状态变更 ───────────────────────────────────────────────────


func enter_node(floor: int, index: int) -> void:
	current_floor = floor
	current_index = index


func add_card(card_id: String) -> void:
	deck.append(CardInstance.new(card_id))


func heal(n: int) -> void:
	hp = mini(hp + n, max_hp)


func add_gold(n: int) -> void:
	gold += n


func add_relic(relic_id: String) -> void:
	relics.append(relic_id)


func get_deck_ids() -> Array:
	var ids: Array = []
	for c: CardInstance in deck:
		ids.append(c.definition_id)
	return ids


## ─── 序列化 ─────────────────────────────────────────────────────


func to_dict() -> Dictionary:
	var deck_data: Array = []
	for c: CardInstance in deck:
		deck_data.append([c.definition_id, c.is_upgraded])
	return {
		"v": 1,
		"seed": RNGManager.master_seed,
		"character_id": character_id,
		"hp": hp,
		"max_hp": max_hp,
		"gold": gold,
		"deck": deck_data,
		"relics": relics.duplicate(),
		"current_floor": current_floor,
		"current_index": current_index,
	}


static func from_dict(d: Dictionary) -> RunState:
	# 必须先恢复种子：_init 里的地图生成依赖它。
	RNGManager.restore_seed(int(d.get("seed", 0)))
	var run: RunState = RunState.new(String(d.get("character_id", "ironclad")))
	run.hp = int(d.get("hp", run.max_hp))
	run.max_hp = int(d.get("max_hp", run.max_hp))
	run.gold = int(d.get("gold", 99))
	run.current_floor = int(d.get("current_floor", 0))
	run.current_index = int(d.get("current_index", -1))
	run.relics.clear()
	for r: Variant in d.get("relics", []):
		run.relics.append(String(r))
	run.deck.clear()
	for entry: Variant in d.get("deck", []):
		var pair: Array = entry
		run.deck.append(CardInstance.new(String(pair[0]), bool(pair[1])))
	return run
