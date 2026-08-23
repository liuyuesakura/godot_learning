## NetworkClient.gd (Autoload) — 占位桩。
## 垂直切片完全离线可玩（架构检查清单：客户端可完全离线运行一局完整 run）。
## 服务端（C#/.NET 8）接入时，在此实现 JWT 管理 / REST 调用 / 重试队列。
## 生命周期：整个应用存活期。
extends Node


func is_online() -> bool:
	return false


## 未来：向服务端上报命令日志（ADR-004），供 run 合法性重放验证。
func submit_command_log(_commands: Array) -> bool:
	return false


## ─── IAP 验证 ──────────────────────────────────────────────────


## 验证购买收据（跨平台统一入口，按 purchase.platform 路由）。
## 离线桩：本地信任（仅适用于原型；生产环境必须用服务端在线验证）。
## Android: original_json + signature → 服务端调 Google Play Developer API 验签。
## iOS: receipt (base64) + transaction_id → 服务端调 App Store Server API 验证。
func verify_purchase_receipt(purchase: Dictionary) -> bool:
	if not is_online():
		# 离线信任 —— 原型阶段。生产环境改为 return false 强制在线验证。
		return true

	var platform: String = String(purchase.get("platform", "android"))
	if platform == "ios":
		# iOS: POST /api/iap/verify/apple { receipt, transaction_id, product_id }
		var _ios_receipt: Dictionary = {
			"receipt": String(purchase.get("receipt", "")),
			"transaction_id": String(purchase.get("purchase_token", "")),
			"product_id": String(purchase.get("product_id", "")),
		}
		# var resp = await _post("/api/iap/verify/apple", _ios_receipt)
		# return resp.code == 200 and bool(resp.data.get("valid", false))
	else:
		# Android: POST /api/iap/verify/google { original_json, signature, purchase_token }
		var _android_receipt: Dictionary = {
			"original_json": String(purchase.get("original_json", "")),
			"signature": String(purchase.get("signature", "")),
			"product_id": String(purchase.get("product_id", "")),
			"purchase_token": String(purchase.get("purchase_token", "")),
		}
		# var resp = await _post("/api/iap/verify/google", _android_receipt)
		# return resp.code == 200 and bool(resp.data.get("valid", false))
	return false  # 在线验证未实装时拒绝（避免误以为已验证）


## 上报消费确认（服务端记账，防止退款欺诈）。
func report_consumption(purchase_token: String) -> bool:
	if not is_online():
		return false
	# 未来：POST /api/iap/consume { purchase_token }
	return false


## ─── 认证（登录令牌交换） ──────────────────────────────────────────


## 用平台 identity token 向服务端换取应用 JWT（跨平台统一入口）。
## 离线桩：本地信任（仅原型；生产必须在线换取，否则 server_token 无签名无法验真）。
## provider: "google" | "apple"。id_token: 平台返回的 identity token（JWT）。
## 返回服务端 JWT 字符串；失败返回空串。
func exchange_auth_token(provider: String, id_token: String) -> String:
	if not is_online():
		# 离线信任 —— 原型阶段。生产环境改为 return "" 强制在线换取。
		return "sim_jwt_%s_%d" % [provider, Time.get_ticks_msec()]
	# 在线换取（Phase 2/3 实装）：
	#   var payload := {"provider": provider, "id_token": id_token}
	#   var resp = await _post("/api/auth/exchange", payload)
	#   if resp.code == 200:
	#       return String(resp.data.get("jwt", ""))
	return ""  # 在线换取未实装时拒绝（避免误以为已验证）


## 发送短信验证码（Phase 2 实装：POST /api/auth/sms { phone } → 服务端接短信通道）。
## 离线桩：AuthManager.send_sms_code 直接走模拟延迟，不经过此函数。
func send_sms_code(phone: String) -> bool:
	if not is_online():
		return false
	# var resp = await _post("/api/auth/sms", { "phone": phone })
	# return resp.code == 200
	return false
