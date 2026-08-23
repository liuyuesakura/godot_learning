## Main.gd — 场景树根节点。
## 仅负责向 GameManager 注册屏幕容器，然后按登录态分流：
## 已有会话 → 主菜单；无会话 → 登录画面（ADR-005：场景树即状态机）。
extends Control


func _ready() -> void:
	GameManager.register_main(self)
	if AuthManager.restore_session():
		GameManager.change_screen(&"main_menu")
	else:
		GameManager.change_screen(&"login")
