## PaymentManager.gd (Autoload)
## 跨平台支付封装层 —— 唯一的支付入口（架构检查：UI 不得直接调插件/StoreKit）。
## 三轨：
##   - Android: GodotGooglePlayBilling 插件（StoreKit 不适用）
##   - iOS: Godot InAppStore 单例（StoreKit 1，内置于 iOS 导出模板，无需插件）
##   - 桌面/编辑器: 内置模拟器（90% 成功率 + 延迟，UI 离线可测）
## 平台检测在 _ready() 中完成，运行期间不变。购买记录通过 SaveManager 持久化（跨 run）。
extends Node

## Billing/StoreKit 连接成功（Android 真机 / iOS / 桌面模拟器均会触发）。
signal billing_connected
## Billing/StoreKit 断开。
signal billing_disconnected
## 商品详情查询完成。参数为 sku -> details 的 Dictionary。
signal sku_details_received(details: Dictionary)
## 单笔购买成功。参数为 purchase: Dictionary + product_id。
signal purchase_succeeded(purchase: Dictionary, product_id: String)
## 单笔购买失败。参数为 error: Dictionary + product_id。
signal purchase_failed(error: Dictionary, product_id: String)
## 消费成功（消耗品）。参数为 purchase_token。
signal purchase_consumed(purchase_token: String)
## 恢复购买完成。参数为已恢复的 purchase 数组。
signal restore_completed(purchases: Array)
## 所有异步操作结束的错误兜底。
signal billing_error(error: Dictionary)

## 购买状态枚举（与 Google Play BillingClient.PurchaseState 对齐；iOS 映射到 PURCHASED）。
enum PurchaseState {
	UNSPECIFIED = 0,
	PURCHASED = 1,
	PENDING = 2,
}

## Billing/StoreKit 连接状态。
var is_connected: bool = false
## 是否运行在 Android 真机。
var is_android: bool = false
## 是否运行在 iOS 真机。
var is_ios: bool = false

var _billing: Object = null       # Android: GodotGooglePlayBilling
var _ios_store: Object = null     # iOS: InAppStore singleton
var _sku_cache: Dictionary = {}   # sku -> details Dictionary
var _pending_sku: String = ""    # 正在购买的 sku（单次购买流程）
var _pending_consume_sku: String = ""  # 正在消费的 sku（消耗品流程）
var _is_simulator: bool = false

const SIM_CONSUMABLE_COUNT: int = 3  # 模拟器初始消耗品库存


func _ready() -> void:
	is_android = OS.get_name() == "Android"
	is_ios = OS.get_name() == "iOS"

	if is_android:
		_billing = Engine.get_singleton("GodotGooglePlayBilling")
		if _billing == null:
			push_error("PaymentManager: GodotGooglePlayBilling singleton not found. Plugin installed?")
			_is_simulator = true
		else:
			_connect_billing_signals()
			_billing.startConnection()
	elif is_ios:
		if Engine.has_singleton("InAppStore"):
			_ios_store = Engine.get_singleton("InAppStore")
			_connect_ios_signals()
			# iOS 不需要显式连接——InAppStore 初始化后立即可用。
			is_connected = true
			billing_connected.emit()
			# Apple 最佳实践：启动时恢复已购买项。
			restore_purchases()
		else:
			push_error("PaymentManager: InAppStore singleton not found. iOS export template missing?")
			_is_simulator = true
	else:
		_is_simulator = true
		# 桌面端延迟模拟连接，让 UI 有机会注册信号。
		call_deferred("_sim_connect")


# ─── 公开 API ──────────────────────────────────────────────────


## 查询商品详情。sku_list 为内部 SKU ID 数组（iOS 会自动翻译为 Apple product ID）。
func query_sku_details(sku_list: Array[String]) -> void:
	if _is_simulator:
		_sim_query(sku_list)
		return
	if is_android:
		if not is_connected:
			push_warning("PaymentManager: billing not connected, deferring query.")
			await billing_connected
		if _billing:
			_billing.querySkuDetails(PackedStringArray(sku_list), "inapp")
	elif is_ios:
		var apple_ids := PackedStringArray()
		for sku: String in sku_list:
			var aid: String = ContentRegistry.get_apple_id(sku)
			if aid != "":
				apple_ids.append(aid)
		if _ios_store and apple_ids.size() > 0:
			_ios_store.request_product_info({"product_ids": apple_ids})


## 发起购买。sku 为内部商品 ID（iOS 会自动翻译为 Apple product ID）。
func purchase(sku: String) -> void:
	_pending_sku = sku
	if _is_simulator:
		_sim_purchase(sku)
		return
	if is_android:
		if not is_connected:
			billing_error.emit({"code": -1, "message": "Billing not connected"})
			purchase_failed.emit({"response_code": -1, "debug_message": "not connected"}, sku)
			_pending_sku = ""
			return
		if _billing:
			_billing.purchase(sku)
	elif is_ios:
		var apple_id: String = ContentRegistry.get_apple_id(sku)
		if apple_id == "":
			billing_error.emit({"code": -4, "message": "No Apple product ID mapped for sku: %s" % sku})
			purchase_failed.emit({"response_code": -4, "debug_message": "missing apple_id mapping"}, sku)
			_pending_sku = ""
			return
		if _ios_store:
			_ios_store.purchase({"product_id": apple_id})


## 消费购买（消耗品）。
## Android: consumePurchase（异步，回调 _on_purchase_consumed）。
## iOS: finish_transaction（同步，call_deferred 触发 _on_purchase_consumed）。
func consume(purchase_token: String) -> void:
	if _is_simulator:
		_sim_consume(purchase_token)
		return
	if is_android and _billing:
		_billing.consumePurchase(purchase_token)
	elif is_ios and _ios_store:
		var sku: String = _pending_consume_sku
		var apple_id: String = ""
		if sku != "":
			apple_id = ContentRegistry.get_apple_id(sku)
		if apple_id != "":
			_ios_store.finish_transaction({"product_id": apple_id, "transaction_id": purchase_token})
		# iOS finish_transaction 无回调信号——延迟触发后续逻辑保持异步一致性。
		_on_purchase_consumed.call_deferred(purchase_token)


## 恢复购买（非消耗品 / 未消费的消耗品）。
func restore_purchases() -> void:
	if _is_simulator:
		_sim_restore()
		return
	if is_android and _billing:
		_billing.queryPurchases("inapp")
	elif is_ios and _ios_store:
		_ios_store.restore_purchases()


## 判断某非消耗品是否已拥有（跨 run 持久）。
func owns(sku: String) -> bool:
	return SaveManager.has_iap(sku)


## 获取已缓存的商品详情。返回空 Dictionary 如果未查询过。
func get_sku_detail(sku: String) -> Dictionary:
	return _sku_cache.get(sku, {})


# ─── Android 插件信号回调 ───────────────────────────────────────


func _connect_billing_signals() -> void:
	_billing.connected.connect(_on_connected)
	_billing.disconnected.connect(_on_disconnected)
	_billing.purchases_updated.connect(_on_purchases_updated)
	_billing.purchase_error.connect(_on_purchase_error)
	_billing.sku_details_query_completed.connect(_on_sku_details_completed)
	_billing.sku_details_query_error.connect(_on_sku_details_error)
	_billing.purchase_consumed.connect(_on_purchase_consumed)
	_billing.purchase_consumption_error.connect(_on_purchase_consumption_error)
	_billing.purchase_acknowledged.connect(_on_purchase_acknowledged)
	_billing.purchase_acknowledgement_error.connect(_on_purchase_acknowledgement_error)


func _on_connected() -> void:
	is_connected = true
	billing_connected.emit()
	restore_purchases()


func _on_disconnected() -> void:
	is_connected = false
	billing_disconnected.emit()


func _on_purchases_updated(purchases: Array) -> void:
	for raw: Variant in purchases:
		var p: Dictionary = raw as Dictionary
		var sku: String = String(p.get("product_id", ""))
		var state: int = int(p.get("purchase_state", 0))
		if state == PurchaseState.PURCHASED:
			_handle_successful_purchase(p, sku)
		elif state == PurchaseState.PENDING:
			billing_error.emit({"code": 2, "message": "Purchase pending (awaiting approval)", "sku": sku})


func _on_purchase_error(error: Dictionary) -> void:
	var sku: String = _pending_sku
	_pending_sku = ""
	var code: int = int(error.get("response_code", -1))
	if code == 6:
		purchase_failed.emit(error, sku)
	else:
		billing_error.emit({"code": code, "message": String(error.get("debug_message", "unknown")), "sku": sku})
		purchase_failed.emit(error, sku)


func _on_sku_details_completed(skus: Array) -> void:
	_sku_cache.clear()
	for raw: Variant in skus:
		var d: Dictionary = raw as Dictionary
		var sku: String = String(d.get("sku", ""))
		if sku != "":
			_sku_cache[sku] = d
	sku_details_received.emit(_sku_cache.duplicate())


func _on_sku_details_error(error: Dictionary) -> void:
	billing_error.emit({"code": int(error.get("response_code", -1)), "message": "SKU query failed"})


func _on_purchase_consumed(purchase_token: String) -> void:
	var sku: String = _pending_consume_sku
	_pending_consume_sku = ""
	if sku != "":
		var product: Dictionary = ContentRegistry.get_iap_product(sku)
		if not product.has("reward_gold"):
			SaveManager.add_consumable(sku, 1)
		purchase_succeeded.emit({"purchase_token": purchase_token, "product_id": sku}, sku)
	purchase_consumed.emit(purchase_token)


func _on_purchase_consumption_error(error: Dictionary) -> void:
	billing_error.emit({"code": int(error.get("response_code", -1)), "message": "Consume failed"})


func _on_purchase_acknowledged(_purchase_token: String) -> void:
	pass


func _on_purchase_acknowledgement_error(error: Dictionary) -> void:
	billing_error.emit({"code": int(error.get("response_code", -1)), "message": "Acknowledge failed"})


# ─── iOS InAppStore 信号回调 ────────────────────────────────────


func _connect_ios_signals() -> void:
	_ios_store.product_info_received.connect(_on_ios_product_info)
	_ios_store.purchase_success.connect(_on_ios_purchase_success)
	_ios_store.purchase_failed.connect(_on_ios_purchase_failed)
	_ios_store.purchase_cancel.connect(_on_ios_purchase_cancel)
	_ios_store.restore_purchases_finished.connect(_on_ios_restore_finished)


## iOS 商品信息回调：Apple product ID -> 内部 SKU 翻译后写入缓存。
func _on_ios_product_info(info: Dictionary) -> void:
	_sku_cache.clear()
	for raw: Variant in info.get("product_ids", []):
		var d: Dictionary = raw as Dictionary
		var apple_id: String = String(d.get("product_id", ""))
		var sku: String = ContentRegistry.get_sku_by_apple_id(apple_id)
		if sku != "":
			_sku_cache[sku] = {
				"sku": sku,
				"title": String(d.get("title", "")),
				"description": String(d.get("description", "")),
				"price": String(d.get("price", "")),
				"price_currency_code": String(d.get("currency_code", "USD")),
				"type": "inapp",
			}
	sku_details_received.emit(_sku_cache.duplicate())


## iOS 购买成功：归一化为标准 purchase Dictionary 后走统一处理流程。
func _on_ios_purchase_success(purchase: Dictionary) -> void:
	var apple_id: String = String(purchase.get("product_id", ""))
	var sku: String = ContentRegistry.get_sku_by_apple_id(apple_id)
	if sku == "":
		# 未知商品——finish 防止队列阻塞，然后报错。
		var tid: String = String(purchase.get("transaction_id", ""))
		if _ios_store and tid != "":
			_ios_store.finish_transaction({"product_id": apple_id, "transaction_id": tid})
		billing_error.emit({"code": -3, "message": "Unknown Apple product ID: %s" % apple_id})
		_pending_sku = ""
		return
	# 归一化为与 Android 相同的格式，_handle_successful_purchase 无需感知平台。
	var normalized: Dictionary = {
		"product_id": sku,
		"purchase_token": String(purchase.get("transaction_id", "")),
		"purchase_state": PurchaseState.PURCHASED,
		"is_acknowledged": false,
		"receipt": String(purchase.get("receipt", "")),
		"platform": "ios",
		"original_json": JSON.stringify(purchase),
	}
	_handle_successful_purchase(normalized, sku)


## iOS 购买失败。
func _on_ios_purchase_failed(purchase: Dictionary) -> void:
	var sku: String = _pending_sku
	_pending_sku = ""
	purchase_failed.emit({"response_code": 1, "debug_message": String(purchase.get("error", "purchase failed"))}, sku)


## iOS 用户取消购买（与 Android response_code 6 对齐）。
func _on_ios_purchase_cancel(_purchase: Dictionary) -> void:
	var sku: String = _pending_sku
	_pending_sku = ""
	purchase_failed.emit({"response_code": 6, "debug_message": "user cancelled"}, sku)


## iOS 恢复购买完成：归一化所有已恢复的购买并重新应用非消耗品所有权。
func _on_ios_restore_finished(purchases: Array) -> void:
	var restored: Array = []
	for raw: Variant in purchases:
		var p: Dictionary = raw as Dictionary
		var apple_id: String = String(p.get("product_id", ""))
		var sku: String = ContentRegistry.get_sku_by_apple_id(apple_id)
		if sku != "":
			var normalized: Dictionary = {
				"product_id": sku,
				"purchase_token": String(p.get("transaction_id", "")),
				"purchase_state": PurchaseState.PURCHASED,
				"is_acknowledged": false,
				"receipt": String(p.get("receipt", "")),
				"platform": "ios",
			}
			SaveManager.save_iap(sku, normalized)
			restored.append(normalized)
	restore_completed.emit(restored)


# ─── 购买成功内部处理（跨平台统一） ──────────────────────────────


## 购买成功后的标准流程：服务端验证 → 消费/确认 → 持久化 → 应用效果。
func _handle_successful_purchase(purchase: Dictionary, sku: String) -> void:
	# 1. 服务端验证（桩：离线时本地信任，在线时按平台上报 receipt）。
	var verified: bool = NetworkClient.verify_purchase_receipt(purchase)
	if not verified:
		billing_error.emit({"code": -2, "message": "Server verification failed", "sku": sku})
		_pending_sku = ""
		return

	# 2. 查商品类型，决定消费还是确认。
	var product: Dictionary = ContentRegistry.get_iap_product(sku)
	var ptype: String = String(product.get("type", "consumable"))
	var token: String = String(purchase.get("purchase_token", ""))
	var platform: String = String(purchase.get("platform", "android"))

	if ptype == "consumable":
		_pending_consume_sku = sku
		consume(token)
	else:
		# 非消耗品：Android 需 acknowledge；iOS 需 finish_transaction（确认已处理）。
		if platform == "ios":
			if _ios_store:
				var apple_id: String = ContentRegistry.get_apple_id(sku)
				if apple_id != "":
					_ios_store.finish_transaction({"product_id": apple_id, "transaction_id": token})
		else:
			if _billing and not bool(purchase.get("is_acknowledged", false)):
				_billing.acknowledgePurchase(token)
		SaveManager.save_iap(sku, purchase)
		purchase_succeeded.emit(purchase, sku)

	_pending_sku = ""


# ─── 桌面模拟器 ────────────────────────────────────────────────


func _sim_connect() -> void:
	await get_tree().create_timer(0.3).timeout
	is_connected = true
	billing_connected.emit()


func _sim_query(sku_list: Array[String]) -> void:
	await get_tree().create_timer(0.2).timeout
	_sku_cache.clear()
	var products: Array = ContentRegistry.get_all_iap_products()
	for p: Variant in products:
		var d: Dictionary = p as Dictionary
		var sku: String = String(d.get("sku", ""))
		if sku in sku_list:
			_sku_cache[sku] = {
				"sku": sku,
				"title": String(d.get("display_name", sku)),
				"description": String(d.get("description", "")),
				"price": "$%.2f" % float(d.get("price_usd", 0.99)),
				"price_currency_code": "USD",
				"price_amount_micros": int(float(d.get("price_usd", 0.99)) * 1000000),
				"type": "inapp",
			}
	sku_details_received.emit(_sku_cache.duplicate())


func _sim_purchase(sku: String) -> void:
	await get_tree().create_timer(0.5).timeout
	var product: Dictionary = ContentRegistry.get_iap_product(sku)
	var ptype: String = String(product.get("type", "consumable"))
	# 模拟 90% 成功率。
	if randf() < 0.1:
		purchase_failed.emit({"response_code": 1, "debug_message": "Simulated failure"}, sku)
		_pending_sku = ""
		return
	var fake_purchase: Dictionary = {
		"purchase_token": "sim_%s_%d" % [sku, Time.get_ticks_msec()],
		"product_id": sku,
		"quantity": 1,
		"purchase_state": PurchaseState.PURCHASED,
		"is_acknowledged": false,
		"order_id": "sim_order_%d" % randi(),
		"purchase_time": Time.get_unix_time_from_system() * 1000,
		"signature": "",
		"original_json": "{}",
		"platform": "simulator",
	}
	if ptype == "consumable":
		_pending_consume_sku = sku
		consume(fake_purchase["purchase_token"])
	else:
		SaveManager.save_iap(sku, fake_purchase)
		purchase_succeeded.emit(fake_purchase, sku)
	_pending_sku = ""


func _sim_consume(purchase_token: String) -> void:
	await get_tree().create_timer(0.3).timeout
	var sku: String = _pending_consume_sku
	_pending_consume_sku = ""
	if sku != "":
		var product: Dictionary = ContentRegistry.get_iap_product(sku)
		if not product.has("reward_gold"):
			SaveManager.add_consumable(sku, 1)
		purchase_consumed.emit(purchase_token)
		purchase_succeeded.emit({"purchase_token": purchase_token, "product_id": sku}, sku)
	else:
		purchase_consumed.emit(purchase_token)


func _sim_restore() -> void:
	await get_tree().create_timer(0.3).timeout
	var restored: Array = []
	var owned: Array = SaveManager.get_all_iaps()
	for entry: Variant in owned:
		restored.append(entry as Dictionary)
	restore_completed.emit(restored)
