## ContentRegistry.gd (Autoload)
## 数据驱动内容加载与查询（ADR-002）。所有卡牌/敌人/角色定义来自 JSON，
## 脚本中不硬编码任何内容数值。生命周期：整个应用存活期，只读缓存。
extends Node

var cards: Dictionary = {}
var characters: Dictionary = {}
var enemies: Dictionary = {}
var encounters: Dictionary = {}
var iap_products: Dictionary = {}  # sku -> def
var iap_list: Array[Dictionary] = []  # 有序列表


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	var cards_data: Dictionary = _load_json("res://assets/content/cards.json")
	for c: Dictionary in cards_data.get("cards", []):
		cards[String(c["id"])] = c

	var chars_data: Dictionary = _load_json("res://assets/content/characters.json")
	for c: Dictionary in chars_data.get("characters", []):
		characters[String(c["id"])] = c

	var enemies_data: Dictionary = _load_json("res://assets/content/enemies.json")
	for e: Dictionary in enemies_data.get("enemies", []):
		enemies[String(e["id"])] = e
	encounters = enemies_data.get("encounters", {})

	var iap_data: Dictionary = _load_json("res://assets/content/iap_products.json")
	for p: Dictionary in iap_data.get("products", []):
		var sku: String = String(p.get("sku", ""))
		if sku != "":
			iap_products[sku] = p
			iap_list.append(p)


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("ContentRegistry: missing content file: %s" % path)
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("ContentRegistry: cannot open %s (err %d)" % [path, FileAccess.get_open_error()])
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("ContentRegistry: invalid JSON in %s" % path)
	return {}


## ─── 查询接口 ───────────────────────────────────────────────────


func get_card_def(id: String) -> Dictionary:
	return cards.get(id, {})


func get_character(id: String) -> Dictionary:
	return characters.get(id, {})


func get_enemy(id: String) -> Dictionary:
	return enemies.get(id, {})


## 可玩角色列表（未锁定）。
func get_playable_characters() -> Array[String]:
	var result: Array[String] = []
	for id: String in characters.keys():
		if not bool(characters[id].get("locked", false)):
			result.append(id)
	result.sort()
	return result


## ─── IAP 商品查询 ────────────────────────────────────────────────


func get_iap_product(sku: String) -> Dictionary:
	return iap_products.get(sku, {})


func get_all_iap_products() -> Array[Dictionary]:
	return iap_list.duplicate()


## 内部 SKU -> Apple product ID（iOS 平台购买时翻译用）。
func get_apple_id(sku: String) -> String:
	var p: Dictionary = iap_products.get(sku, {})
	return String(p.get("apple_id", ""))


## Apple product ID -> 内部 SKU（iOS 回调翻译用）。
func get_sku_by_apple_id(apple_id: String) -> String:
	for sku: String in iap_products.keys():
		if String(iap_products[sku].get("apple_id", "")) == apple_id:
			return sku
	return ""


## 按 category 过滤商品（character / feature / currency / cosmetic）。
func get_iap_by_category(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for p: Dictionary in iap_list:
		if String(p.get("category", "")) == category:
			result.append(p)
	return result


## 按遭遇类型随机一组敌人 id。
func roll_encounter(kind: String, rng: RandomNumberGenerator) -> Array[String]:
	var pools: Array = encounters.get(kind, [])
	if pools.is_empty():
		return ["jaw_worm"]
	var pool: Array = pools[rng.randi_range(0, pools.size() - 1)]
	var result: Array[String] = []
	for id: Variant in pool:
		result.append(String(id))
	return result


## 掷卡牌奖励：3 张不同稀有度的卡（basic 不入池）。可跳过由 UI 层实现。
func roll_card_rewards(color: String, rng: RandomNumberGenerator, count: int = 3) -> Array[Dictionary]:
	var pool_by_rarity: Dictionary = {"common": [], "uncommon": [], "rare": []}
	for id: String in cards.keys():
		var def: Dictionary = cards[id]
		var card_color: String = String(def.get("color", "colorless"))
		var rarity: String = String(def.get("rarity", "common"))
		if rarity == "basic":
			continue
		if card_color == color or card_color == "colorless":
			if pool_by_rarity.has(rarity):
				pool_by_rarity[rarity].append(def)
	var result: Array[Dictionary] = []
	var used_ids: Dictionary = {}
	while result.size() < count:
		var roll: float = rng.randf()
		var rarity: String = "common"
		if roll > 0.93:
			rarity = "rare"
		elif roll > 0.60:
			rarity = "uncommon"
		var pool: Array = pool_by_rarity[rarity]
		if pool.is_empty():
			pool = pool_by_rarity["common"]
		if pool.is_empty():
			break
		var def: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		if used_ids.has(String(def["id"])):
			continue
		used_ids[String(def["id"])] = true
		result.append(def)
	return result
