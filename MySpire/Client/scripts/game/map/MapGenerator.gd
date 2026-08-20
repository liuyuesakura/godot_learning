## MapGenerator.gd — Act 地图生成（纯逻辑）。
## 结构：16 层（1–15 常规 + 16 Boss），每层 2–4 节点，分支路径。
## 固定规则：第 1 层必为普通战；第 9 层宝箱；第 15 层篝火；第 16 层 Boss。
## 由受管 RNG 驱动 → 同种子必出同一张图（ADR-003，存档不落盘地图）。
class_name MapGenerator
extends RefCounted

const FLOOR_COUNT: int = 15
const BOSS_FLOOR: int = 16
const TREASURE_FLOOR: int = 9
const CAMPFIRE_FLOOR: int = 15


static func generate_act(rng: RandomNumberGenerator) -> Dictionary:
	var floors: Dictionary = {}
	for f: int in range(1, FLOOR_COUNT + 1):
		var count: int = rng.randi_range(2, 4)
		var nodes: Array = []
		for i: int in count:
			nodes.append({
				"floor": f,
				"index": i,
				"x": float(i + 0.5) / float(count),
				"type": _pick_type(f, rng),
				"edges": [],
			})
		floors[f] = nodes
	floors[BOSS_FLOOR] = [{
		"floor": BOSS_FLOOR,
		"index": 0,
		"x": 0.5,
		"type": "boss",
		"edges": [],
	}]
	_connect_floors(floors, rng)
	return floors


static func _pick_type(floor: int, rng: RandomNumberGenerator) -> String:
	if floor == 1:
		return "combat"
	if floor == TREASURE_FLOOR:
		return "treasure"
	if floor == CAMPFIRE_FLOOR:
		return "campfire"
	var elite_allowed: bool = floor >= 5
	var roll: float = rng.randf()
	if elite_allowed and roll < 0.14:
		return "elite"
	if roll < 0.50:
		return "combat"
	if roll < 0.70:
		return "event"
	if roll < 0.86:
		return "campfire"
	return "shop"


## 每个节点连向下一层 1–2 个水平最近的节点；保证下层节点都有父节点。
static func _connect_floors(floors: Dictionary, rng: RandomNumberGenerator) -> void:
	for f: int in range(1, BOSS_FLOOR):
		var current: Array = floors[f]
		var next: Array = floors[f + 1]
		for node: Dictionary in current:
			var cx: float = float(node["x"])
			var order: Array = range(next.size())
			order.sort_custom(func(a: int, b: int) -> bool:
				return absf(float(next[a]["x"]) - cx) < absf(float(next[b]["x"]) - cx))
			var links: int = 1
			if next.size() > 1 and rng.randf() < 0.35:
				links = 2
			for k: int in links:
				var target: int = int(order[k])
				if not (node["edges"] as Array).has(target):
					(node["edges"] as Array).append(target)
		for j: int in next.size():
			var has_parent: bool = false
			for node: Dictionary in current:
				if (node["edges"] as Array).has(j):
					has_parent = true
					break
			if not has_parent:
				var nearest: int = 0
				var best: float = 9.0
				for i: int in current.size():
					var d: float = absf(float(current[i]["x"]) - float(next[j]["x"]))
					if d < best:
						best = d
						nearest = i
				(current[nearest]["edges"] as Array).append(j)
