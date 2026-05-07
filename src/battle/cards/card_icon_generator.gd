## CardIconGenerator — 程序化卡片图标生成器
##
## 当 Card.icon_path 为空（未挂美术资源）时，CardView 调用此工具生成
## 一张占位图标。规则：
##   - 背景色基于 type（word=蓝 / phrase=绿 / pattern=紫 / sound=橙 / rule=金 / modifier=灰）
##   - 边框色基于 rarity（common=灰 / rare=蓝 / epic=紫 / legendary=金）
##   - 中心由 CardView 用 Label overlay 显示卡面文字 — 本工具只画底图
##
## 注：返回的是 ImageTexture，不写盘。设计目标：跑得起来 > 美观。
class_name CardIconGenerator extends RefCounted


const ICON_SIZE: int = 128
const BORDER_THICKNESS: int = 6
const CORNER_RADIUS: int = 12


static func type_color(card_type: String) -> Color:
	match card_type:
		"word": return Color(0.32, 0.55, 0.85, 1.0)
		"phrase": return Color(0.34, 0.72, 0.55, 1.0)
		"pattern": return Color(0.62, 0.42, 0.85, 1.0)
		"sound": return Color(0.95, 0.65, 0.32, 1.0)
		"rule": return Color(0.92, 0.78, 0.32, 1.0)
		"modifier": return Color(0.60, 0.60, 0.60, 1.0)
		_: return Color(0.45, 0.45, 0.55, 1.0)


static func rarity_color(rarity: String) -> Color:
	match rarity:
		"common": return Color(0.65, 0.65, 0.65, 1.0)
		"rare": return Color(0.32, 0.62, 0.92, 1.0)
		"epic": return Color(0.72, 0.45, 0.92, 1.0)
		"legendary": return Color(0.95, 0.78, 0.28, 1.0)
		_: return Color(0.5, 0.5, 0.5, 1.0)


## 生成卡片图标 ImageTexture（仅底图 + 边框；卡面文字由调用方叠 Label）。
static func generate(card: Card, size: int = ICON_SIZE) -> ImageTexture:
	if card == null:
		return _make_solid(Color(0.3, 0.3, 0.3, 1.0), size)
	var bg: Color = type_color(card.type)
	var border: Color = rarity_color(card.rarity)
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	# 圆角矩形背景
	for y in size:
		for x in size:
			if _in_rounded_rect(x, y, 0, 0, size, size, CORNER_RADIUS):
				img.set_pixel(x, y, bg)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	# 边框
	for y in size:
		for x in size:
			if _in_rounded_rect(x, y, 0, 0, size, size, CORNER_RADIUS) and \
					not _in_rounded_rect(
							x, y,
							BORDER_THICKNESS, BORDER_THICKNESS,
							size - BORDER_THICKNESS, size - BORDER_THICKNESS,
							max(1, CORNER_RADIUS - BORDER_THICKNESS)):
				img.set_pixel(x, y, border)
	return ImageTexture.create_from_image(img)


# ─── 私有 ─────────────────────────────────────────────────────────

static func _make_solid(c: Color, size: int) -> ImageTexture:
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)


static func _in_rounded_rect(
		px: int, py: int, x: int, y: int, w: int, h: int, r: int) -> bool:
	if px < x or px >= w or py < y or py >= h:
		return false
	# 角落圆
	var inside_horizontal: bool = (px >= x + r) and (px < w - r)
	var inside_vertical: bool = (py >= y + r) and (py < h - r)
	if inside_horizontal or inside_vertical:
		return true
	# 四角检查
	var cx: int
	var cy: int
	if px < x + r and py < y + r:
		cx = x + r; cy = y + r
	elif px >= w - r and py < y + r:
		cx = w - r - 1; cy = y + r
	elif px < x + r and py >= h - r:
		cx = x + r; cy = h - r - 1
	else:
		cx = w - r - 1; cy = h - r - 1
	var dx: int = px - cx
	var dy: int = py - cy
	return (dx * dx + dy * dy) <= (r * r)
