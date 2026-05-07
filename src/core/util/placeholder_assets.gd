## PlaceholderAssets — 程序化占位图生成器
##
## 目标：在没有真实美术资源前，让游戏启动时仍能呈现合理画面。
## 主要 API：
##   - make_gradient_texture(top, bottom, w, h)  → 渐变背景
##   - make_solid_color_texture(color, w, h)     → 纯色块
##   - make_portrait_texture(name, color, size)  → 圆形头像 + 首字
##
## 调用方仅需把返回的 Texture2D 喂进 TextureRect.texture / Sprite2D.texture。
## 不会在磁盘写文件 — 完全运行时生成，无需提交二进制。
##
## 学科主题色由 ContentPackBase.get_theme_colors() 提供；本工具只负责"画"。
class_name PlaceholderAssets extends RefCounted


## 生成竖直渐变纹理（默认 1280x720，匹配 viewport_width/height）
static func make_gradient_texture(
		top_color: Color,
		bottom_color: Color,
		w: int = 1280,
		h: int = 720) -> ImageTexture:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var t: float = float(y) / float(max(1, h - 1))
		var c: Color = top_color.lerp(bottom_color, t)
		for x in w:
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## 生成纯色纹理
static func make_solid_color_texture(color: Color, w: int = 256, h: int = 256) -> ImageTexture:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


## 生成圆形头像：实心圆 + 中心首字符。
## 注：纹理本身只画圆 + 抗锯齿；首字由调用方加 Label overlay 实现，
## 否则需要绑字体不便。这里仅返回纯色圆。
static func make_portrait_texture(color: Color, size: int = 256) -> ImageTexture:
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = float(size) * 0.5
	var cy: float = float(size) * 0.5
	var r: float = float(size) * 0.45
	for y in size:
		for x in size:
			var dx: float = float(x) - cx
			var dy: float = float(y) - cy
			var d: float = sqrt(dx * dx + dy * dy)
			if d <= r - 1.0:
				img.set_pixel(x, y, color)
			elif d <= r + 0.5:
				# soft edge
				var a: float = 1.0 - (d - (r - 1.0)) / 1.5
				var c: Color = color
				c.a = clamp(a, 0.0, 1.0)
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# ─── 楼层 / 场景预设 ──────────────────────────────────────────────

const MAIN_MENU_TOP: Color = Color(0.18, 0.10, 0.32, 1.0)      # 紫
const MAIN_MENU_BOTTOM: Color = Color(0.05, 0.07, 0.18, 1.0)   # 深蓝
const CITY_TOP: Color = Color(0.28, 0.22, 0.34, 1.0)
const CITY_BOTTOM: Color = Color(0.10, 0.12, 0.18, 1.0)
const FLOOR_0F_TOP: Color = Color(0.42, 0.30, 0.18, 1.0)       # 暖色
const FLOOR_0F_BOTTOM: Color = Color(0.18, 0.12, 0.08, 1.0)
const FLOOR_1F_TOP: Color = Color(0.34, 0.18, 0.42, 1.0)
const FLOOR_1F_BOTTOM: Color = Color(0.12, 0.08, 0.18, 1.0)
const FLOOR_2F_TOP: Color = Color(0.18, 0.32, 0.42, 1.0)
const FLOOR_2F_BOTTOM: Color = Color(0.06, 0.10, 0.18, 1.0)


## 按场景 ID 返回对应背景纹理
static func make_background_for(scene_id: String, w: int = 1280, h: int = 720) -> ImageTexture:
	match scene_id:
		"main_menu":
			return make_gradient_texture(MAIN_MENU_TOP, MAIN_MENU_BOTTOM, w, h)
		"city":
			return make_gradient_texture(CITY_TOP, CITY_BOTTOM, w, h)
		"0F":
			return make_gradient_texture(FLOOR_0F_TOP, FLOOR_0F_BOTTOM, w, h)
		"1F":
			return make_gradient_texture(FLOOR_1F_TOP, FLOOR_1F_BOTTOM, w, h)
		"2F":
			return make_gradient_texture(FLOOR_2F_TOP, FLOOR_2F_BOTTOM, w, h)
		_:
			return make_gradient_texture(MAIN_MENU_TOP, MAIN_MENU_BOTTOM, w, h)


# ─── 角色头像预设 ─────────────────────────────────────────────────

const PORTRAIT_PLAYER: Color = Color(0.55, 0.78, 0.98, 1.0)
const PORTRAIT_MENTOR: Color = Color(0.95, 0.82, 0.45, 1.0)
const PORTRAIT_ELDER: Color = Color(0.78, 0.68, 0.92, 1.0)
const PORTRAIT_BOSS_LIBRARIAN: Color = Color(0.85, 0.42, 0.42, 1.0)
const PORTRAIT_BOSS_VOID: Color = Color(0.32, 0.32, 0.42, 1.0)
const PORTRAIT_BOSS_KEEPER: Color = Color(0.42, 0.78, 0.55, 1.0)


## 按角色 ID 取颜色（供 make_portrait_texture）
static func portrait_color_for(character_id: String) -> Color:
	match character_id:
		"player": return PORTRAIT_PLAYER
		"mentor": return PORTRAIT_MENTOR
		"elder": return PORTRAIT_ELDER
		"librarian": return PORTRAIT_BOSS_LIBRARIAN
		"void": return PORTRAIT_BOSS_VOID
		"keeper": return PORTRAIT_BOSS_KEEPER
		_: return Color(0.5, 0.5, 0.5, 1.0)
