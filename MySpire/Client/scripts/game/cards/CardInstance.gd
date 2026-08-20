## CardInstance.gd — 卡牌运行时实例。
## 逻辑层只认实例，不认定义：同名卡的多张副本通过 uid 区分。
## 升级状态改变的是效果解析结果，定义本身只读（来自 ContentRegistry）。
class_name CardInstance
extends RefCounted

static var _next_uid: int = 1

var uid: int
var definition_id: String
var is_upgraded: bool = false


func _init(id: String, upgraded: bool = false) -> void:
	uid = _next_uid
	_next_uid += 1
	definition_id = id
	is_upgraded = upgraded


func get_definition() -> Dictionary:
	return ContentRegistry.get_card_def(definition_id)


func display_name() -> String:
	var n: String = String(get_definition().get("name", definition_id))
	return n + ("+" if is_upgraded else "")


func cost() -> int:
	var def: Dictionary = get_definition()
	if is_upgraded and def.get("upgrade", {}).has("cost"):
		return int(def["upgrade"]["cost"])
	return int(def.get("cost", 1))


func card_type() -> String:
	return String(get_definition().get("type", "attack"))


func rarity() -> String:
	return String(get_definition().get("rarity", "common"))


func effects() -> Array:
	var def: Dictionary = get_definition()
	if is_upgraded:
		var up: Dictionary = def.get("upgrade", {})
		if up.has("effects"):
			return up["effects"]
	return def.get("effects", [])


func needs_target() -> bool:
	return String(get_definition().get("target", "none")) == "enemy"


func will_exhaust() -> bool:
	return bool(get_definition().get("exhaust", false))
