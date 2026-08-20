## EnemyState.gd — 敌人运行时状态。
## 意图（intent）在敌人行动前展示（核心机制①：敌方行动明牌）。
class_name EnemyState
extends RefCounted

var def_id: String
var display_name: String
var hp: int
var max_hp: int
var block: int = 0
var strength: int = 0
var weak: int = 0
var vulnerable: int = 0
var alive: bool = true
var intent: Dictionary = {}
var move_history: Array[int] = []


func _init(def: Dictionary, rng: RandomNumberGenerator) -> void:
	def_id = String(def.get("id", ""))
	display_name = String(def.get("name", def_id))
	var hp_range: Array = def.get("hp", [30, 30])
	max_hp = rng.randi_range(int(hp_range[0]), int(hp_range[1]))
	hp = max_hp


func gain_block(n: int) -> void:
	block += n


## 伤害先由格挡吸收，再扣血。
func take_damage(n: int) -> void:
	if not alive:
		return
	var absorbed: int = mini(block, n)
	block -= absorbed
	hp -= (n - absorbed)
	if hp <= 0:
		hp = 0
		alive = false


func tick_debuffs() -> void:
	if weak > 0:
		weak -= 1
	if vulnerable > 0:
		vulnerable -= 1


## UI 展示用：意图预计伤害（含力量/虚弱修正）。
func projected_intent_damage() -> int:
	var base: int = int(intent.get("damage", 0))
	if base <= 0:
		return 0
	var dmg: int = base + strength
	if weak > 0:
		dmg = int(float(dmg) * 0.75)
	return dmg
