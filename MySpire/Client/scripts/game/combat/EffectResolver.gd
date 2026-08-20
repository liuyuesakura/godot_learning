## EffectResolver.gd — 卡牌效果解析（纯逻辑，不知道 UI 存在）。
## 每种 effect 是一个最小语义单元；卡牌定义用 effects 数组组合它们。
## 新增卡牌效果 = 在 match 中加一个分支，不改卡牌系统。
class_name EffectResolver
extends RefCounted

var combat: CombatState


func _init(c: CombatState) -> void:
	combat = c


func resolve(effect: Dictionary, target_index: int) -> void:
	match String(effect.get("effect", "")):
		"damage":
			combat.deal_damage_to_enemy(target_index, int(effect.get("amount", 0)))
		"damage_all":
			# 快照索引：遍历中可能有敌人死亡，不能直接迭代活动列表。
			for i: int in combat.enemies.size():
				if combat.enemies[i].alive:
					combat.deal_damage_to_enemy(i, int(effect.get("amount", 0)))
		"block":
			combat.gain_player_block(int(effect.get("amount", 0)))
		"strength":
			combat.player_strength += int(effect.get("amount", 0))
		"weak":
			combat.apply_status_to_enemy(target_index, "weak", int(effect.get("amount", 0)))
		"vulnerable":
			combat.apply_status_to_enemy(target_index, "vulnerable", int(effect.get("amount", 0)))
		"draw":
			combat.draw(int(effect.get("amount", 0)))
		"energy":
			combat.energy += int(effect.get("amount", 0))
		_:
			push_warning("EffectResolver: unknown effect '%s'" % String(effect.get("effect", "")))
