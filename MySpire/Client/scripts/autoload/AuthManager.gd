## AuthManager.gd (Autoload)
## 跨平台登录封装层 —— 唯一的登录入口（架构检查：UI 不得直接调原生 SDK）。
## 三轨（与 PaymentManager 同构）：
##   - Android: Google Sign-In 插件（Phase 3 接入，需 Google Cloud Console OAuth Client）
##   - iOS: Sign in with Apple（Phase 2 接入，需 Apple Developer + 自定义 iOS 插件；非 Godot 内置）
##   - 桌面/编辑器: 内置模拟器（即时登录，离线可测 UI 与持久化）
## 平台检测在 _ready() 中完成，运行期间不变。登录会话通过 SaveManager 持久化（跨启动）。
## 登录流程：平台原生认证 → 拿到 identity token → NetworkClient 换取服务端 JWT → 持久化 → emit。
extends Node

## 登录流程开始。参数 provider: "google" | "apple"。
signal login_started(provider: String)
## 登录成功。参数 user: Dictionary（字段见 _normalize_user）。
signal login_succeeded(user: Dictionary)
## 登录失败。参数 error: Dictionary {code, message, provider}。
signal login_failed(error: Dictionary)
## 登出完成。
signal logged_out
## 短信验证码已发送。参数 phone: 完整手机号。
signal sms_code_sent(phone: String)
## 短信验证码发送失败。参数 error: Dictionary {code, message}。
signal sms_code_failed(error: Dictionary)

## 登录提供方。
enum Provider { GOOGLE = 0, APPLE = 1, MOBILE = 2 }

## 当前登录用户；null 表示未登录。字段见 _normalize_user。
var current_user: Variant = null
## 是否已认证（current_user != null 的便捷别名）。
var is_authenticated: bool = false
## 是否运行在 Android 真机。
var is_android: bool = false
## 是否运行在 iOS 真机。
var is_ios: bool = false

var _google: Object = null       # Android/iOS: GodotGoogleSignIn 插件单例（Phase 3）
var _apple: Object = null        # iOS: SignInWithApple 插件单例（Phase 2）
var _pending_provider: int = -1  # 正在登录的 Provider（用于回调归因）

const SIM_GOOGLE_USER_ID: String = "sim_google_001"
const SIM_APPLE_USER_ID: String = "sim_apple_001"


func _ready() -> void:
	is_android = OS.get_name() == "Android"
	is_ios = OS.get_name() == "iOS"

	# 各 provider 独立探测自己的插件单例——缺哪个走哪个的模拟器，互不影响。
	if is_android:
		if Engine.has_singleton("GodotGoogleSignIn"):
			_google = Engine.get_singleton("GodotGoogleSignIn")
			_connect_google_signals()
		else:
			push_warning("AuthManager: GodotGoogleSignIn plugin not found — Google login will use simulator. Install plugin for real Google login.")
	# iOS: Sign in with Apple 需自定义插件（非 Godot 内置，区别于 InAppStore）。
	if is_ios:
		if Engine.has_singleton("SignInWithApple"):
			_apple = Engine.get_singleton("SignInWithApple")
			_connect_apple_signals()
		else:
			push_warning("AuthManager: SignInWithApple plugin not found — Apple login will use simulator. Install plugin for real Apple login.")


# ─── 公开 API ──────────────────────────────────────────────────


## 发起 Google 登录。Android 主用；iOS/桌面走模拟器。
func login_with_google() -> void:
	_pending_provider = Provider.GOOGLE
	login_started.emit("google")
	if _google == null:
		_sim_login(Provider.GOOGLE)
		return
	_google.startSignIn()  # Phase 3: 传 server_client_id 换 ID token


## 发起 Sign in with Apple。iOS 主用；其他平台走模拟器。
func login_with_apple() -> void:
	_pending_provider = Provider.APPLE
	login_started.emit("apple")
	if _apple == null:
		_sim_login(Provider.APPLE)
		return
	_apple.startSignIn()  # Phase 2: 调 ASAuthorizationAppleIDProvider


## 登出：清内存 + 清持久化。
func logout() -> void:
	current_user = null
	is_authenticated = false
	SaveManager.clear_auth_session()
	logged_out.emit()


## 应用启动时从存档恢复会话。返回是否恢复了有效会话。
func restore_session() -> bool:
	var saved: Dictionary = SaveManager.load_auth_session()
	if saved.is_empty():
		return false
	current_user = saved
	is_authenticated = true
	return true


## 当前提供方（"google" / "apple" / "mobile" / ""）。
func get_provider() -> String:
	if current_user == null:
		return ""
	return String(current_user.get("provider", ""))


## 发送短信验证码。手机号格式校验在前端做，这里只做通道调用。
## 模拟器：0.5s 后 emit sms_code_sent（假设送达）。
func send_sms_code(phone: String) -> void:
	# Phase 2: NetworkClient.send_sms_code(phone) → POST /api/auth/sms { phone }
	await get_tree().create_timer(0.5).timeout
	sms_code_sent.emit(phone)


## 发起手机号 + 验证码登录。跨平台统一（三端均可用）。
## 模拟器：任意 4~6 位数字验证码视为有效，90% 成功率。
func login_with_phone(phone: String, code: String) -> void:
	_pending_provider = Provider.MOBILE
	login_started.emit("mobile")
	_sim_phone_login(phone, code)


# ─── Android 插件信号回调（Phase 3 实装） ──────────────────────


func _connect_google_signals() -> void:
	# Phase 3:
	# _google.sign_in_succeeded.connect(_on_google_sign_in_succeeded)
	# _google.sign_in_failed.connect(_on_google_sign_in_failed)
	pass


func _on_google_sign_in_succeeded(result: Dictionary) -> void:
	# result: {id_token, user_id, display_name, email, ...}
	var user: Dictionary = _normalize_user(
		Provider.GOOGLE,
		String(result.get("user_id", "")),
		String(result.get("display_name", "Player")),
		String(result.get("email", "")),
		String(result.get("id_token", "")),
	)
	_complete_login(user)


func _on_google_sign_in_failed(error: Dictionary) -> void:
	_emit_failure("google", int(error.get("code", -1)), String(error.get("message", "Google sign-in failed")))


# ─── iOS 插件信号回调（Phase 2 实装） ──────────────────────────


func _connect_apple_signals() -> void:
	# Phase 2:
	# _apple.sign_in_succeeded.connect(_on_apple_sign_in_succeeded)
	# _apple.sign_in_failed.connect(_on_apple_sign_in_failed)
	pass


func _on_apple_sign_in_succeeded(result: Dictionary) -> void:
	# result: {identity_token, user_id, email（可能是 relay 地址）, ...}
	var user: Dictionary = _normalize_user(
		Provider.APPLE,
		String(result.get("user_id", "")),
		String(result.get("display_name", "Player")),
		String(result.get("email", "")),
		String(result.get("identity_token", "")),
	)
	_complete_login(user)


func _on_apple_sign_in_failed(error: Dictionary) -> void:
	_emit_failure("apple", int(error.get("code", -1)), String(error.get("message", "Apple sign-in failed")))


# ─── 登录完成内部处理（跨平台统一） ──────────────────────────


## 归一化各平台返回的用户信息为统一 Dictionary。
func _normalize_user(provider: int, user_id: String, display_name: String, email: String, id_token: String) -> Dictionary:
	return {
		"provider": _provider_name(provider),
		"user_id": user_id,
		"display_name": display_name,
		"email": email,
		"id_token": id_token,
		"login_time": Time.get_unix_time_from_system(),
	}


func _provider_name(provider: int) -> String:
	match provider:
		Provider.GOOGLE:
			return "google"
		Provider.APPLE:
			return "apple"
		Provider.MOBILE:
			return "mobile"
	return ""


## 登录成功收尾：服务端换 JWT → 持久化 → emit。
func _complete_login(user: Dictionary) -> void:
	# 1. 服务端换取 JWT（桩：离线信任；在线时 NetworkClient 调 /api/auth/exchange）。
	#    注意：exchange_auth_token 当前同步返回；Phase 2/3 实装在线换取时改为 await（见该函数注释）。
	var server_token: String = NetworkClient.exchange_auth_token(String(user["provider"]), String(user["id_token"]))
	if server_token == "":
		_emit_failure(String(user["provider"]), -2, "Server token exchange failed")
		_pending_provider = -1
		return
	user["server_token"] = server_token
	# 2. 持久化会话（跨启动恢复）。
	SaveManager.save_auth_session(user)
	# 3. 更新内存状态 + emit。
	current_user = user
	is_authenticated = true
	_pending_provider = -1
	login_succeeded.emit(user)


func _emit_failure(provider: String, code: int, message: String) -> void:
	_pending_provider = -1
	login_failed.emit({"code": code, "message": message, "provider": provider})


# ─── 桌面模拟器 ────────────────────────────────────────────────


func _sim_login(provider: int) -> void:
	await get_tree().create_timer(0.5).timeout
	# 模拟 90% 成功率（与 PaymentManager 一致，便于测失败 UI）。
	if randf() < 0.1:
		_emit_failure(_provider_name(provider), 1, "Simulated login failure")
		return
	var user: Dictionary
	if provider == Provider.GOOGLE:
		user = _normalize_user(
			Provider.GOOGLE,
			SIM_GOOGLE_USER_ID,
			"Tester (Google)",
			"tester.google@sim.local",
			"sim_google_id_token_%d" % Time.get_ticks_msec(),
		)
	else:
		user = _normalize_user(
			Provider.APPLE,
			SIM_APPLE_USER_ID,
			"Tester (Apple)",
			"privaterelay@icloud.com",
			"sim_apple_id_token_%d" % Time.get_ticks_msec(),
		)
	_complete_login(user)


## 模拟器：手机号登录。id_token 即"验证码会话票据"的占位。
func _sim_phone_login(phone: String, code: String) -> void:
	await get_tree().create_timer(1.2).timeout
	if randf() < 0.1:
		_emit_failure("mobile", 1, "验证码错误或已过期（模拟）")
		return
	var masked: String = phone.substr(0, 3) + "****" + phone.substr(7)
	var user: Dictionary = _normalize_user(
		Provider.MOBILE,
		"sim_mobile_%s" % phone,
		masked,
		"",
		"sim_mobile_ticket_%d" % Time.get_ticks_msec(),
	)
	user["phone"] = phone
	_complete_login(user)
