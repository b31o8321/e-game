## DebugMode — 玩测调试模式 (autoload)
##
## 通过 Konami 码 ↑↑↓↓←→←→ 切换开关。
## 开启后：
##   - 战斗中显示当前 Challenge 的 template_id / topic_id / 正确答案
##     （由 BattleScene 实例化的 DebugOverlay 订阅本 autoload 的信号）
##   - 卡片显示 ID + tags（由 BattleScene 在 hand 渲染时附加）
##   - 备战界面显示 [DEBUG] 提示 + 资源作弊按钮
##   - 屏幕右上角显示一个 "🔧 DEBUG ON" CanvasLayer 角标
##
## 测试入口：
##   - DebugMode.simulate_key(KEY_UP) 注入按键，方便单测验证 Konami 序列
##   - DebugMode.is_konami_sequence_for_test() 暴露内部序列给单测断言
extends Node


signal debug_toggled(enabled: bool)


## 是否处于调试模式。autoload 创建后默认关闭。
var enabled: bool = false

## Konami 码：↑↑↓↓←→←→
var _konami_sequence: Array[int] = [
	KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN,
	KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT,
]
var _key_buffer: Array[int] = []
var _badge: CanvasLayer = null


func _ready() -> void:
	# 调试模式即使在 SceneTree 暂停时也要响应（例如战斗结束 overlay 后）
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_badge()


# ═══════════════════════════════════════════════════════════════════
# 输入处理：识别 Konami 码
# ═══════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke: InputEventKey = event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	_handle_keycode(ke.keycode)


## 测试入口：模拟一次按键事件，避免在单测里手动构造 InputEventKey 派发到全局。
func simulate_key(keycode: int) -> void:
	_handle_keycode(keycode)


func _handle_keycode(keycode: int) -> void:
	if keycode != KEY_UP and keycode != KEY_DOWN \
			and keycode != KEY_LEFT and keycode != KEY_RIGHT:
		# 任何非方向键都打断序列
		_key_buffer.clear()
		return
	_key_buffer.append(keycode)
	if _key_buffer.size() > _konami_sequence.size():
		_key_buffer.pop_front()
	if _key_buffer == _konami_sequence:
		toggle()
		_key_buffer.clear()


# ═══════════════════════════════════════════════════════════════════
# 切换 / 查询
# ═══════════════════════════════════════════════════════════════════

func toggle() -> void:
	enabled = not enabled
	print("[DebugMode] %s" % ("ENABLED" if enabled else "DISABLED"))
	debug_toggled.emit(enabled)
	if _badge != null:
		_badge.visible = enabled


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	debug_toggled.emit(enabled)
	if _badge != null:
		_badge.visible = enabled


## 给单测使用：暴露 Konami 序列长度（用于断言 buffer 行为）。
func get_konami_sequence_for_test() -> Array[int]:
	return _konami_sequence.duplicate()


## 给单测使用：返回当前 buffer 状态（只读快照）。
func get_buffer_for_test() -> Array[int]:
	return _key_buffer.duplicate()


# ═══════════════════════════════════════════════════════════════════
# 角标
# ═══════════════════════════════════════════════════════════════════

func _setup_badge() -> void:
	_badge = CanvasLayer.new()
	_badge.layer = 1000
	_badge.visible = false
	var label: Label = Label.new()
	label.text = "🔧 DEBUG ON"
	label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 18)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	label.offset_left = -180
	label.offset_top = 12
	label.offset_right = -16
	label.offset_bottom = 40
	_badge.add_child(label)
	add_child(_badge)
