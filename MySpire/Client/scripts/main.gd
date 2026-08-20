## Main.gd — 场景树根节点。
## 仅负责向 GameManager 注册屏幕容器，然后进入主菜单。
## 所有画面切换由 GameManager 统一管理（ADR-005：场景树即状态机）。
extends Control


func _ready() -> void:
	GameManager.register_main(self)
	GameManager.change_screen(&"main_menu")
