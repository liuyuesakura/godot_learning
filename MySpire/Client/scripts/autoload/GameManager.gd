## GameManager.gd (Autoload)
## 全局状态机入口 + 画面切换管理（ADR-005：Godot 场景树即状态机）。
## 生命周期：整个应用存活期。持有当前 RunState，不持有任何 UI 节点
## （main 容器由 Main.tscn 注册进来，切换时只做 add/remove child）。
extends Node

signal screen_changed(screen_id: StringName)
signal run_ended

const MainMenuScript: GDScript = preload("res://scripts/ui/screens/MainMenu.gd")
const CharacterSelectScript: GDScript = preload("res://scripts/ui/screens/CharacterSelect.gd")
const MapScreenScript: GDScript = preload("res://scripts/ui/screens/MapScreen.gd")
const CombatSceneScript: GDScript = preload("res://scripts/ui/screens/CombatScene.gd")
const ShopScreenScript: GDScript = preload("res://scripts/ui/screens/ShopScreen.gd")

const SCREENS: Dictionary = {
	&"main_menu": MainMenuScript,
	&"character_select": CharacterSelectScript,
	&"map": MapScreenScript,
	&"combat": CombatSceneScript,
	&"shop": ShopScreenScript,
}

## 当前 run 状态；null 表示不在 run 中。
var run: RunState
## 当前遭遇类型："normal" / "elite" / "boss"。
var current_encounter: String = "normal"

var _main: Control


func register_main(main: Control) -> void:
	_main = main


## 统一画面切换入口 —— 任何代码不得直接调用 change_scene（架构检查清单）。
func change_screen(screen_id: StringName) -> void:
	if _main == null:
		push_error("GameManager: main container not registered yet.")
		return
	if not SCREENS.has(screen_id):
		push_error("GameManager: unknown screen '%s'." % screen_id)
		return
	for child: Control in _main.get_children():
		child.queue_free()
	var screen: Control = (SCREENS[screen_id] as GDScript).new()
	screen.name = String(screen_id)
	_main.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_changed.emit(screen_id)


## ─── Run 生命周期 ───────────────────────────────────────────────


func start_run(character_id: String) -> void:
	RNGManager.new_run_seed()
	run = RunState.new(character_id)
	SaveManager.save_run(run)
	change_screen(&"map")


## 从存档恢复 run（继续远征）。
func resume_run() -> bool:
	var restored: RunState = SaveManager.load_run()
	if restored == null:
		return false
	run = restored
	change_screen(&"map")
	return true


func end_run() -> void:
	run = null
	SaveManager.clear_save()
	run_ended.emit()
	change_screen(&"main_menu")


## 进入地图节点。node: {"floor": int, "index": int, "type": String}
func enter_map_node(node: Dictionary) -> void:
	run.enter_node(int(node["floor"]), int(node["index"]))
	match String(node["type"]):
		"combat", "elite", "boss":
			current_encounter = String(node["type"])
			change_screen(&"combat")
		_:
			# 非战斗节点由 MapScreen 自己弹出处理面板。
			push_warning("GameManager: non-combat node should be handled by MapScreen.")


## 战斗胜利后返回地图（由 CombatScene 调用）。
func finish_encounter() -> void:
	SaveManager.save_run(run)
	change_screen(&"map")


## 当前角色卡池颜色（用于奖励过滤）。
func get_run_color() -> String:
	return String(ContentRegistry.get_character(run.character_id).get("color", "red"))
