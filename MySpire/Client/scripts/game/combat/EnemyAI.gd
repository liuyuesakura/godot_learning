## EnemyAI.gd — 敌人意图选择（纯逻辑）。
## 规则：首回合可用 def.first 指定开场招；随机模式下同一招最多连出 2 次。
class_name EnemyAI
extends RefCounted

const MAX_REPEAT: int = 2


static func roll_intent(enemy: EnemyState, rng: RandomNumberGenerator) -> Dictionary:
	var def: Dictionary = ContentRegistry.get_enemy(enemy.def_id)
	var moves: Array = def.get("moves", [])
	if moves.is_empty():
		return {}
	var idx: int = 0
	var first: int = int(def.get("first", -1))
	if enemy.move_history.is_empty() and first >= 0 and first < moves.size():
		idx = first
	else:
		var candidates: Array[int] = []
		for i: int in moves.size():
			candidates.append(i)
		if _tail_all_same(enemy.move_history, MAX_REPEAT):
			candidates.erase(enemy.move_history[enemy.move_history.size() - 1])
		if candidates.is_empty():
			candidates = [0]
		idx = candidates[rng.randi_range(0, candidates.size() - 1)]
	enemy.move_history.append(idx)
	var move: Dictionary = moves[idx]
	var intent: Dictionary = {
		"move_index": idx,
		"name": String(move.get("name", "")),
		"type": String(move.get("type", "attack")),
	}
	for key: String in ["damage", "hits", "block", "strength", "weak", "vulnerable"]:
		if move.has(key):
			intent[key] = move[key]
	return intent


static func _tail_all_same(history: Array[int], n: int) -> bool:
	if history.size() < n:
		return false
	var last: int = history[history.size() - 1]
	for i: int in range(history.size() - n, history.size()):
		if history[i] != last:
			return false
	return true


## 意图文案（UI 用中文短描述）。
static func describe_intent(intent: Dictionary) -> String:
	match String(intent.get("type", "attack")):
		"attack", "attack_defend":
			var text: String = "攻击"
			if intent.get("block", 0):
				text += "·防御"
			return text
		"block":
			return "防御"
		"buff":
			return "强化"
		"debuff":
			return "削弱"
		"attack_debuff":
			return "攻击·削弱"
	return "…"
