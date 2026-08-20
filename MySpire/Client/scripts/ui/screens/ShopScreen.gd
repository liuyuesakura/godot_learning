## ShopScreen.gd — IAP 商店画面。支付系统 UI 入口。
## 展示所有内购商品，处理购买流程，应用即时效果（金币包等）。
class_name ShopScreen
extends Control

const CATEGORY_ORDER: Array[String] = ["character", "feature", "currency", "consumable", "cosmetic"]
const CATEGORY_LABELS: Dictionary = {
	"character": "角色解锁",
	"feature": "功能",
	"currency": "金币包",
	"consumable": "道具",
	"cosmetic": "装饰",
}

var _sku_details: Dictionary = {}
var _card_widgets: Dictionary = {}  # sku -> {"btn": Button, "price": Label}
var _toast: Label = null


func _ready() -> void:
	add_child(UITheme.make_bg())
	_build_ui()
	PaymentManager.billing_connected.connect(_query_all)
	PaymentManager.sku_details_received.connect(_on_sku_details)
	PaymentManager.purchase_succeeded.connect(_on_purchase_succeeded)
	PaymentManager.purchase_failed.connect(_on_purchase_failed)
	PaymentManager.restore_completed.connect(_on_restore_completed)
	if PaymentManager.is_connected:
		_query_all()


func _exit_tree() -> void:
	for pair: Array in [
		[PaymentManager.billing_connected, _query_all],
		[PaymentManager.sku_details_received, _on_sku_details],
		[PaymentManager.purchase_succeeded, _on_purchase_succeeded],
		[PaymentManager.purchase_failed, _on_purchase_failed],
		[PaymentManager.restore_completed, _on_restore_completed],
	]:
		var sig: Signal = pair[0]
		var cb: Callable = pair[1]
		if sig.is_connected(cb):
			sig.disconnect(cb)


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_top = 8.0
	vbox.offset_bottom = -8.0
	add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 52)
	header.add_theme_constant_override("separation", 12)
	vbox.add_child(header)
	var back := UITheme.ghost_button("← 返回", Vector2(90, 40))
	back.pressed.connect(func() -> void: GameManager.change_screen(&"main_menu"))
	header.add_child(back)
	var title := UITheme.label("商店", 22, UITheme.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(Control.new())  # 右侧占位

	# Scroll area
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 6)
	scroll.add_child(content)

	for cat: String in CATEGORY_ORDER:
		var products: Array[Dictionary] = ContentRegistry.get_iap_by_category(cat)
		if products.is_empty():
			continue
		var cat_label := Label.new()
		cat_label.text = String(CATEGORY_LABELS.get(cat, cat))
		cat_label.add_theme_font_size_override("font_size", 14)
		cat_label.add_theme_color_override("font_color", UITheme.DIM)
		content.add_child(cat_label)
		for p: Dictionary in products:
			content.add_child(_make_product_card(p))

	# Footer
	var footer := HBoxContainer.new()
	footer.custom_minimum_size = Vector2(0, 48)
	footer.add_theme_constant_override("separation", 12)
	vbox.add_child(footer)
	var restore := UITheme.ghost_button("恢复购买", Vector2(120, 38))
	restore.pressed.connect(func() -> void:
		PaymentManager.restore_purchases()
		_show_toast("正在恢复购买...")
	)
	footer.add_child(restore)
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 13)
	_toast.add_theme_color_override("font_color", UITheme.DIM)
	_toast.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(_toast)


func _make_product_card(p: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 72)
	card.add_theme_stylebox_override("panel", UITheme.panel_style())
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	var icon := Label.new()
	icon.text = String(p.get("icon", "🎁"))
	icon.add_theme_font_size_override("font_size", 32)
	icon.custom_minimum_size = Vector2(48, 48)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	hbox.add_child(info)
	var name := Label.new()
	name.text = String(p.get("display_name", ""))
	name.add_theme_font_size_override("font_size", 16)
	name.add_theme_color_override("font_color", UITheme.GOLD_L)
	info.add_child(name)
	var desc := Label.new()
	desc.text = String(p.get("description", ""))
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", UITheme.DIM)
	info.add_child(desc)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(100, 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 4)
	hbox.add_child(right)

	var price_label := Label.new()
	price_label.add_theme_font_size_override("font_size", 14)
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(price_label)

	var buy_btn := Button.new()
	buy_btn.custom_minimum_size = Vector2(100, 34)
	buy_btn.add_theme_font_size_override("font_size", 13)
	right.add_child(buy_btn)

	var sku := String(p.get("sku", ""))
	var ptype := String(p.get("type", ""))
	_card_widgets[sku] = {"btn": buy_btn, "price": price_label}
	_update_card(sku, ptype)
	buy_btn.pressed.connect(_on_buy.bind(sku))
	return card


func _update_card(sku: String, ptype: String) -> void:
	var widgets: Dictionary = _card_widgets.get(sku, {})
	var btn: Button = widgets.get("btn")
	var price_label: Label = widgets.get("price")
	if btn == null or price_label == null:
		return
	var p: Dictionary = ContentRegistry.get_iap_product(sku)
	if _sku_details.has(sku):
		price_label.text = String(_sku_details[sku].get("price", "..."))
		price_label.add_theme_color_override("font_color", UITheme.GOLD_L)
	elif p.has("price_usd"):
		price_label.text = "$%.2f" % float(p["price_usd"])
		price_label.add_theme_color_override("font_color", UITheme.DIM)
	else:
		price_label.text = "..."
	if ptype == "non_consumable":
		if PaymentManager.owns(sku):
			btn.text = "已拥有"
			btn.disabled = true
		else:
			btn.text = "购买"
			btn.disabled = false
	else:
		var count := SaveManager.get_consumable_count(sku)
		btn.text = "购买" if count == 0 else "购买 · 持有×%d" % count
		btn.disabled = false


func _on_buy(sku: String) -> void:
	var widgets: Dictionary = _card_widgets.get(sku, {})
	var btn: Button = widgets.get("btn")
	if btn:
		btn.text = "处理中..."
		btn.disabled = true
	PaymentManager.purchase(sku)
	_show_toast("正在处理购买...")


func _on_purchase_succeeded(_purchase: Dictionary, sku: String) -> void:
	var p: Dictionary = ContentRegistry.get_iap_product(sku)
	var ptype := String(p.get("type", ""))
	if p.has("reward_gold"):
		var gold := int(p["reward_gold"])
		if GameManager.run != null:
			GameManager.run.gold += gold
			SaveManager.save_run(GameManager.run)
			_show_toast("获得 %d 金币！" % gold)
		else:
			_show_toast("购买成功！金币将在下次远征中发放。")
	elif ptype == "non_consumable":
		_show_toast("购买成功：%s" % String(p.get("display_name", "")))
	else:
		_show_toast("购买成功！")
	_update_card(sku, ptype)


func _on_purchase_failed(error: Dictionary, sku: String) -> void:
	var code: int = int(error.get("response_code", -1))
	if code == 6:
		_show_toast("购买已取消")
	else:
		_show_toast("购买失败，请重试")
	_update_card(sku, String(ContentRegistry.get_iap_product(sku).get("type", "")))


func _on_sku_details(details: Dictionary) -> void:
	_sku_details = details
	for sku: String in _card_widgets.keys():
		_update_card(sku, String(ContentRegistry.get_iap_product(sku).get("type", "")))
	_show_toast("商品信息已加载")


func _on_restore_completed(purchases: Array) -> void:
	if purchases.is_empty():
		_show_toast("没有可恢复的购买")
	else:
		_show_toast("已恢复 %d 项购买" % purchases.size())
	for sku: String in _card_widgets.keys():
		_update_card(sku, String(ContentRegistry.get_iap_product(sku).get("type", "")))


func _query_all() -> void:
	var skus: Array[String] = []
	for p: Dictionary in ContentRegistry.get_all_iap_products():
		skus.append(String(p.get("sku", "")))
	PaymentManager.query_sku_details(skus)


func _show_toast(msg: String) -> void:
	if _toast == null:
		return
	_toast.text = msg
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_callback(func() -> void:
		if _toast:
			_toast.text = ""
	)
