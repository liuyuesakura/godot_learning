## UITheme.gd — 设计系统工具（对应 UI设计系统.md 的色彩/组件规范）。
## 碧蓝幻想风视觉：深蓝底 + 金色镶边 + 毛玻璃感面板。
## 全部静态工具，无状态。
class_name UITheme
extends Object

const BG_DEEP := Color("080814")
const BG_MID := Color("101a30")
const BG_TOP := Color("1a2f5c")
const GOLD := Color("c9a84c")
const GOLD_L := Color("e8cf8b")
const TEXT := Color("e6e1d5")
const DIM := Color("8a94a8")
const ATTACK := Color("b4443c")
const SKILL := Color("3c8a5a")
const POWER := Color("7a4c9e")
const HP_RED := Color("c0392b")
const BLOCK_BLUE := Color("4a90d9")
const PANEL_BG := Color(0.063, 0.10, 0.19, 0.94)


static func panel_style(
		bg: Color = PANEL_BG,
		border: Color = Color(0.788, 0.659, 0.298, 0.35),
		radius: int = 12,
		border_width: int = 1
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_width)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	return sb


## 全屏垂直渐变背景。
static func make_bg(top: Color = BG_TOP, bottom: Color = BG_DEEP) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func label(text: String, size: int, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func gold_button(text: String, min_size: Vector2 = Vector2(240, 52)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	var normal := panel_style(Color("3d2f14"), GOLD, 10, 1)
	normal.shadow_color = Color(0.79, 0.66, 0.30, 0.30)
	normal.shadow_size = 8
	var hover := panel_style(Color("57431d"), GOLD_L, 10, 2)
	hover.shadow_color = Color(0.91, 0.81, 0.55, 0.45)
	hover.shadow_size = 14
	var pressed := panel_style(Color("2a2010"), GOLD, 10, 1)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", GOLD_L)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.55, 0.55))
	b.add_theme_font_size_override("font_size", 18)
	return b


static func ghost_button(text: String, min_size: Vector2 = Vector2(160, 44)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	var sb := panel_style(Color(0.04, 0.06, 0.12, 0.8), Color(0.54, 0.58, 0.66, 0.5), 8, 1)
	var sb_h := panel_style(Color(0.08, 0.12, 0.22, 0.9), Color(0.8, 0.84, 0.92, 0.7), 8, 1)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb_h)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", DIM)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_font_size_override("font_size", 14)
	return b


static func make_hp_bar(width: float) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.custom_minimum_size = Vector2(width, 14)
	pb.show_percentage = false
	pb.min_value = 0
	pb.add_theme_stylebox_override("background", panel_style(Color(0.04, 0.05, 0.09, 0.95), Color(0, 0, 0, 0.4), 7))
	pb.add_theme_stylebox_override("fill", panel_style(HP_RED, Color(0, 0, 0, 0), 7))
	return pb


static func type_color(card_type: String) -> Color:
	match card_type:
		"attack":
			return ATTACK
		"skill":
			return SKILL
		"power":
			return POWER
	return DIM


static func rarity_color(rarity: String) -> Color:
	match rarity:
		"basic":
			return Color(0.5, 0.55, 0.62)
		"common":
			return Color(0.62, 0.66, 0.72)
		"uncommon":
			return BLOCK_BLUE
		"rare":
			return GOLD
	return DIM


static func type_name(card_type: String) -> String:
	match card_type:
		"attack":
			return "攻击"
		"skill":
			return "技能"
		"power":
			return "能力"
	return card_type


## 效果数组 → 中文描述（卡面与提示用）。
static func describe_effects(effects: Array) -> String:
	var parts: Array[String] = []
	for e: Dictionary in effects:
		var amount: int = int(e.get("amount", 0))
		match String(e.get("effect", "")):
			"damage":
				parts.append("造成 %d 点伤害" % amount)
			"damage_all":
				parts.append("对所有敌人造成 %d 点伤害" % amount)
			"block":
				parts.append("获得 %d 点格挡" % amount)
			"strength":
				parts.append("获得 %d 点力量" % amount)
			"weak":
				parts.append("施加 %d 层虚弱" % amount)
			"vulnerable":
				parts.append("施加 %d 层易伤" % amount)
			"draw":
				parts.append("抽 %d 张牌" % amount)
			"energy":
				parts.append("获得 %d 点能量" % amount)
	return "\n".join(parts)
