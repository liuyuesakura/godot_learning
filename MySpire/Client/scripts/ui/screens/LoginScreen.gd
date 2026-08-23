## LoginScreen.gd — 登录画面（对应 UI原型_登录页.html / UI设计系统.md §7.6）。
## 布局：氛围区（Logo+菱形装饰）→ 毛玻璃登录面板（手机号/验证码）→ 第三方圆形按钮 → 协议勾选区。
## 信号接线（AuthManager）：
##   login_started   → 按钮 loading 态
##   login_succeeded → 面板飞出 + 用户卡入场
##   login_failed    → Toast 错误提示
##   sms_code_sent   → 验证码按钮 60s 倒计时
## 架构检查：本画面只调用 AuthManager/NetworkClient 公开 API，不直接触碰原生 SDK。
class_name LoginScreen
extends Control

var _terms_agreed: bool = false
var _busy: bool = false
var _code_cd_left: int = 0

var _phone_input: LineEdit
var _code_input: LineEdit
var _code_btn: Button
var _login_btn: Button
var _terms_check: Button
var _login_panel: PanelContainer
var _user_card: PanelContainer
var _toast: Label
var _uc_name: Label
var _uc_meta: Label
var _uc_provider: Label
var _apple_btn: Button
var _google_btn: Button


func _ready() -> void:
	_build_background()
	_build_hero()
	_build_panel()
	_build_terms()
	_build_toast()
	_build_user_card()
	_connect_auth_signals()


func _exit_tree() -> void:
	if AuthManager.login_started.is_connected(_on_login_started):
		AuthManager.login_started.disconnect(_on_login_started)
		AuthManager.login_succeeded.disconnect(_on_login_succeeded)
		AuthManager.login_failed.disconnect(_on_login_failed)
		AuthManager.sms_code_sent.disconnect(_on_sms_code_sent)


# ─── 构建 ──────────────────────────────────────────────────────


func _build_background() -> void:
	add_child(UITheme.make_bg())
	# 星光粒子：随机散布的小标签，错峰明暗呼吸（对应原型 .star twinkle）。
	for i: int in 8:
		var star := UITheme.label("✦", 8 + (i % 3) * 2, Color(0.94, 0.84, 0.48, 0.0))
		star.position = Vector2(30.0 + (i * 83) % 640, 40.0 + (i * 61) % 220)
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(star)
		var tw := star.create_tween().set_loops()
		tw.tween_interval(0.4 + i * 0.15)
		tw.tween_property(star, "modulate:a", 0.85, 0.9).set_trans(Tween.TRANS_SINE)
		tw.tween_property(star, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE)


func _build_hero() -> void:
	var hero := VBoxContainer.new()
	hero.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hero.offset_top = 110.0
	hero.add_theme_constant_override("separation", 6)
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(hero)

	# 菱形脉冲装饰（呼应角色选择页菱形链）。
	var diamonds := HBoxContainer.new()
	diamonds.alignment = BoxContainer.ALIGNMENT_CENTER
	diamonds.add_theme_constant_override("separation", 16)
	hero.add_child(diamonds)
	for i: int in 3:
		var d := UITheme.label("◆", 13, UITheme.GOLD)
		d.modulate.a = 0.55
		diamonds.add_child(d)
		var tw := d.create_tween().set_loops()
		tw.tween_interval(i * 0.35)
		tw.tween_property(d, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
		tw.tween_property(d, "modulate:a", 0.55, 0.7).set_trans(Tween.TRANS_SINE)

	var title := UITheme.label("MySpire", 46, UITheme.GOLD_L)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	hero.add_child(title)
	var subtitle := UITheme.label("T H E   M Y S T I C   S P I R E", 12, UITheme.DIM)
	hero.add_child(subtitle)
	var divider := UITheme.label("─────── ◆ ───────", 12, UITheme.GOLD)
	hero.add_child(divider)


func _build_panel() -> void:
	_login_panel = PanelContainer.new()
	_login_panel.add_theme_stylebox_override("panel", UITheme.panel_style(
		Color(0.063, 0.106, 0.243, 0.88), Color(0.788, 0.659, 0.298, 0.35), 10, 1
	))
	_login_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_login_panel.offset_left = 30.0
	_login_panel.offset_right = -30.0
	_login_panel.offset_top = 320.0
	add_child(_login_panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	_login_panel.add_child(vb)

	# 手机号行：+86 前缀 + 输入框。
	var phone_row := HBoxContainer.new()
	phone_row.add_theme_constant_override("separation", 8)
	vb.add_child(phone_row)
	var prefix := UITheme.label("+86 ▾", 14, UITheme.GOLD_L)
	prefix.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	phone_row.add_child(prefix)
	_phone_input = _make_input("请输入手机号")
	_phone_input.max_length = 11
	phone_row.add_child(_phone_input)

	# 验证码行：输入框 + 获取验证码按钮。
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 8)
	vb.add_child(code_row)
	_code_input = _make_input("验证码")
	_code_input.max_length = 6
	code_row.add_child(_code_input)
	_code_btn = UITheme.ghost_button("获取验证码", Vector2(112, 48))
	_code_btn.add_theme_color_override("font_color", UITheme.BLOCK_BLUE)
	_code_btn.pressed.connect(_on_send_code)
	code_row.add_child(_code_btn)

	# 登录主按钮（金色，字间距大）。
	_login_btn = UITheme.gold_button("登  录", Vector2(0, 48))
	_login_btn.pressed.connect(_on_phone_login)
	vb.add_child(_login_btn)

	# 分隔线。
	var sep := UITheme.label("───  其他登录方式  ───", 11, UITheme.DIM)
	vb.add_child(sep)

	# 第三方圆形按钮。
	var alt_row := HBoxContainer.new()
	alt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	alt_row.add_theme_constant_override("separation", 24)
	vb.add_child(alt_row)
	_apple_btn = _make_alt_button("", Color.BLACK, Color.WHITE, "Apple")
	_apple_btn.pressed.connect(_on_apple_login)
	alt_row.add_child(_apple_btn)
	_google_btn = _make_alt_button("G", Color.WHITE, Color("4285f4"), "Google")
	_google_btn.pressed.connect(_on_google_login)
	alt_row.add_child(_google_btn)


## 输入框：深黑底 + 聚焦金色边框（对应原型 .input-row:focus-within）。
func _make_input(placeholder: String) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.custom_minimum_size = Vector2(0, 48)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var normal := UITheme.panel_style(Color(0, 0, 0, 0.35), Color(0.54, 0.58, 0.66, 0.28), 6, 1)
	var focus := UITheme.panel_style(Color(0, 0, 0, 0.35), UITheme.GOLD, 6, 1)
	le.add_theme_stylebox_override("normal", normal)
	le.add_theme_stylebox_override("focus", focus)
	le.add_theme_color_override("font_color", UITheme.TEXT)
	le.add_theme_color_override("font_placeholder_color", UITheme.DIM)
	le.add_theme_font_size_override("font_size", 15)
	return le


## 第三方圆形按钮：48px 圆形，品牌底色（正式版替换为官方 logo 贴图）。
func _make_alt_button(icon_text: String, bg: Color, fg: Color, tooltip: String) -> Button:
	var b := Button.new()
	b.text = icon_text
	b.tooltip_text = tooltip
	b.custom_minimum_size = Vector2(48, 48)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(24)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.85) if bg == Color.BLACK else Color(0, 0, 0, 0.15)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 4
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", fg)
	b.add_theme_font_size_override("font_size", 20)
	return b


func _build_terms() -> void:
	var terms := HBoxContainer.new()
	terms.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	terms.offset_left = 30.0
	terms.offset_right = -30.0
	terms.offset_top = -64.0
	terms.offset_bottom = -46.0
	terms.alignment = BoxContainer.ALIGNMENT_CENTER
	terms.add_theme_constant_override("separation", 6)
	add_child(terms)

	_terms_check = Button.new()
	_terms_check.text = ""
	_terms_check.custom_minimum_size = Vector2(16, 16)
	_terms_check.add_theme_stylebox_override("normal", UITheme.panel_style(Color(0, 0, 0, 0.3), UITheme.DIM, 3, 1))
	_terms_check.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_terms_check.pressed.connect(_on_toggle_terms)
	terms.add_child(_terms_check)

	var hint := UITheme.label("我已阅读并同意《用户协议》与《隐私政策》", 10, UITheme.DIM)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	terms.add_child(hint)

	var version := UITheme.label("MySpire v1.0.0 · Debug Build", 9, Color(0.35, 0.37, 0.42, 0.7))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	version.offset_top = -30.0
	version.offset_bottom = -12.0
	add_child(version)


func _build_toast() -> void:
	_toast = UITheme.label("", 12, UITheme.GOLD_L)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 100.0
	_toast.modulate.a = 0.0
	_toast.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	add_child(_toast)


func _build_user_card() -> void:
	_user_card = PanelContainer.new()
	_user_card.add_theme_stylebox_override("panel", UITheme.panel_style(
		Color(0.063, 0.106, 0.243, 0.95), Color(0.788, 0.659, 0.298, 0.5), 16, 1
	))
	_user_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_user_card.offset_left = -140.0
	_user_card.offset_right = 140.0
	_user_card.offset_top = -110.0
	_user_card.offset_bottom = 110.0
	_user_card.modulate.a = 0.0
	_user_card.visible = false
	add_child(_user_card)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 10)
	_user_card.add_child(vb)

	vb.add_child(UITheme.label("🗼", 40, UITheme.TEXT))
	_uc_name = UITheme.label("", 18, UITheme.GOLD_L)
	vb.add_child(_uc_name)
	_uc_meta = UITheme.label("", 10, UITheme.DIM)
	vb.add_child(_uc_meta)
	_uc_provider = UITheme.label("", 9, UITheme.DIM)
	vb.add_child(_uc_provider)
	var enter := UITheme.gold_button("进入游戏", Vector2(180, 44))
	enter.pressed.connect(_on_enter_game)
	vb.add_child(enter)


func _connect_auth_signals() -> void:
	AuthManager.login_started.connect(_on_login_started)
	AuthManager.login_succeeded.connect(_on_login_succeeded)
	AuthManager.login_failed.connect(_on_login_failed)
	AuthManager.sms_code_sent.connect(_on_sms_code_sent)


# ─── 交互回调 ──────────────────────────────────────────────────


func _on_toggle_terms() -> void:
	_terms_agreed = not _terms_agreed
	_terms_check.text = "✓" if _terms_agreed else ""
	_terms_check.add_theme_color_override("font_color", UITheme.GOLD_L)


func _on_send_code() -> void:
	if _code_cd_left > 0:
		return
	var phone: String = _phone_input.text.strip_edges()
	if not _is_valid_phone(phone):
		_show_toast("请输入 11 位手机号")
		return
	_code_btn.disabled = true
	AuthManager.send_sms_code(phone)


func _on_sms_code_sent(_phone: String) -> void:
	_show_toast("验证码已发送（原型模拟）", true)
	_code_cd_left = 60
	_countdown_tick()


func _countdown_tick() -> void:
	await get_tree().create_timer(1.0).timeout
	# 画面已切走/销毁时静默退出。
	if not is_instance_valid(_code_btn):
		return
	_code_cd_left -= 1
	if _code_cd_left <= 0:
		_code_btn.disabled = false
		_code_btn.text = "获取验证码"
	else:
		_code_btn.text = "%ds 后重发" % _code_cd_left
		_countdown_tick()


func _on_phone_login() -> void:
	if _busy:
		return
	if not _terms_agreed:
		_shake_login_btn()
		_show_toast("请先阅读并勾选用户协议")
		return
	var phone: String = _phone_input.text.strip_edges()
	var code: String = _code_input.text.strip_edges()
	if not _is_valid_phone(phone):
		_show_toast("请输入 11 位手机号")
		return
	if code.length() < 4 or code.length() > 6:
		_show_toast("请输入验证码")
		return
	AuthManager.login_with_phone(phone, code)


func _on_apple_login() -> void:
	if not _guard_terms():
		return
	AuthManager.login_with_apple()


func _on_google_login() -> void:
	if not _guard_terms():
		return
	AuthManager.login_with_google()


## 协议前置校验。返回是否通过。
func _guard_terms() -> bool:
	if _busy:
		return false
	if not _terms_agreed:
		_shake_login_btn()
		_show_toast("请先阅读并勾选用户协议")
		return false
	return true


# ─── AuthManager 信号 ──────────────────────────────────────────


func _on_login_started(_provider: String) -> void:
	_busy = true
	_login_btn.disabled = true
	_login_btn.text = "登录中…"


func _on_login_succeeded(user: Dictionary) -> void:
	_busy = false
	_reset_login_btn()
	# 面板飞出 + 用户卡入场（对应原型 500ms 飞出 + 回弹入场）。
	var tw := create_tween().set_parallel()
	tw.tween_property(_login_panel, "position:y", _login_panel.position.y - 460.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_login_panel, "modulate:a", 0.0, 0.5)
	_uc_name.text = String(user.get("display_name", "Player"))
	var meta: String = String(user.get("email", ""))
	if meta == "":
		meta = String(user.get("phone", ""))
	_uc_meta.text = meta + " · 会话已保存" if meta != "" else "会话已保存"
	_uc_provider.text = String(user.get("provider", "")).to_upper()
	_user_card.visible = true
	_user_card.scale = Vector2(0.94, 0.94)
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(_user_card, "modulate:a", 1.0, 0.4)
	tw2.tween_property(_user_card, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_login_failed(error: Dictionary) -> void:
	_busy = false
	_reset_login_btn()
	_show_toast(String(error.get("message", "登录失败")))


func _on_enter_game() -> void:
	GameManager.change_screen(&"main_menu")


# ─── 工具 ──────────────────────────────────────────────────────


func _is_valid_phone(phone: String) -> bool:
	return phone.length() == 11 and phone.begins_with("1") and phone.is_valid_int()


func _reset_login_btn() -> void:
	_login_btn.disabled = false
	_login_btn.text = "登  录"


## 协议未勾选抖动（对应原型 350ms shake）。
func _shake_login_btn() -> void:
	var origin: float = _login_btn.position.x
	var tw := create_tween()
	tw.tween_property(_login_btn, "position:x", origin - 7.0, 0.05)
	tw.tween_property(_login_btn, "position:x", origin + 7.0, 0.05)
	tw.tween_property(_login_btn, "position:x", origin - 4.0, 0.05)
	tw.tween_property(_login_btn, "position:x", origin, 0.05)


func _show_toast(msg: String, _ok: bool = false) -> void:
	_toast.text = msg
	var tw := create_tween()
	tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.0)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.35)
