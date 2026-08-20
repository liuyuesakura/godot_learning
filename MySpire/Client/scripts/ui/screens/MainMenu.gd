## MainMenu.gd — 主菜单画面。
class_name MainMenu
extends Control


func _ready() -> void:
	add_child(UITheme.make_bg())
	var center := VBoxContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.offset_left = -140.0
	center.offset_right = 140.0
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 18)
	add_child(center)

	var title := UITheme.label("MYSPIRE", 52, UITheme.GOLD)
	center.add_child(title)
	var subtitle := UITheme.label("尖 塔 远 征", 18, UITheme.DIM)
	center.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 28)
	center.add_child(spacer)

	if SaveManager.has_save():
		var run: RunState = SaveManager.load_run()
		var continue_btn := UITheme.gold_button("继续远征 · %s" % run.character_name)
		continue_btn.pressed.connect(_on_continue)
		center.add_child(continue_btn)

	var new_btn := UITheme.gold_button("新的远征")
	new_btn.pressed.connect(func() -> void: GameManager.change_screen(&"character_select"))
	center.add_child(new_btn)

	var shop_btn := UITheme.ghost_button("商店", Vector2(240, 44))
	shop_btn.pressed.connect(func() -> void: GameManager.change_screen(&"shop"))
	center.add_child(shop_btn)

	var quit_btn := UITheme.ghost_button("退出")
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	center.add_child(quit_btn)

	var version := UITheme.label("客户端原型 v0.1 · 离线垂直切片", 11, Color(0.54, 0.58, 0.66, 0.6))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	version.offset_top = -36.0
	version.offset_bottom = -14.0
	add_child(version)


func _on_continue() -> void:
	if not GameManager.resume_run():
		# 存档损坏时直接进入新流程。
		GameManager.change_screen(&"character_select")
