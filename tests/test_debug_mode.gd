extends GutTest

# 测试 DebugMode autoload 的 Konami 序列识别和 toggle 行为。
# DebugMode 已经被 project.godot 注册为 autoload；这里直接通过全局符号访问。

var _toggled_payloads: Array = []


func before_each() -> void:
	_toggled_payloads = []
	# 保险起见：每条测试开始时确保关闭
	DebugMode.set_enabled(false)
	DebugMode.debug_toggled.connect(_on_debug_toggled)


func after_each() -> void:
	if DebugMode.debug_toggled.is_connected(_on_debug_toggled):
		DebugMode.debug_toggled.disconnect(_on_debug_toggled)
	DebugMode.set_enabled(false)


func _on_debug_toggled(enabled: bool) -> void:
	_toggled_payloads.append(enabled)


# ---------------------------------------------------------------------------
# 默认状态
# ---------------------------------------------------------------------------

func test_disabled_by_default():
	assert_false(DebugMode.enabled, "DebugMode 默认应是关闭状态")


# ---------------------------------------------------------------------------
# Konami 序列触发 toggle
# ---------------------------------------------------------------------------

func test_konami_sequence_toggles_on():
	_simulate_konami()
	assert_true(DebugMode.enabled, "Konami 序列结束后应进入 enabled 状态")
	assert_eq(_toggled_payloads, [true], "应触发一次 debug_toggled(true) 信号")


func test_konami_sequence_toggles_off_when_already_on():
	DebugMode.set_enabled(true)
	_toggled_payloads.clear()
	_simulate_konami()
	assert_false(DebugMode.enabled, "再次输入 Konami 应关闭")
	assert_eq(_toggled_payloads, [false])


# ---------------------------------------------------------------------------
# 错误序列：被非方向键打断 → 不触发
# ---------------------------------------------------------------------------

func test_non_arrow_key_clears_buffer():
	DebugMode.simulate_key(KEY_UP)
	DebugMode.simulate_key(KEY_UP)
	# 一个非方向键打断
	DebugMode.simulate_key(KEY_A)
	# 然后输入剩下的 Konami；因为 buffer 已清，达不到完整序列
	DebugMode.simulate_key(KEY_DOWN)
	DebugMode.simulate_key(KEY_DOWN)
	DebugMode.simulate_key(KEY_LEFT)
	DebugMode.simulate_key(KEY_RIGHT)
	DebugMode.simulate_key(KEY_LEFT)
	DebugMode.simulate_key(KEY_RIGHT)
	assert_false(DebugMode.enabled, "中途有非方向键时不该触发")


func test_wrong_arrow_only_keeps_recent_window():
	# 全错的方向键序列；buffer 应只保留最近 N 个，且不会等于完整 Konami
	for _i in range(20):
		DebugMode.simulate_key(KEY_LEFT)
	assert_false(DebugMode.enabled, "全 LEFT 不应触发")
	var buffer: Array[int] = DebugMode.get_buffer_for_test()
	assert_eq(buffer.size(), DebugMode.get_konami_sequence_for_test().size(),
		"buffer 长度应被裁剪到 Konami 序列长度")


# ---------------------------------------------------------------------------
# 直接 set_enabled / toggle 也应发信号
# ---------------------------------------------------------------------------

func test_set_enabled_emits_signal_on_change():
	DebugMode.set_enabled(true)
	assert_eq(_toggled_payloads, [true])


func test_set_enabled_idempotent():
	# 已经是 false；再 set false 不该触发信号
	DebugMode.set_enabled(false)
	assert_eq(_toggled_payloads, [])


func test_toggle_method():
	DebugMode.toggle()
	assert_true(DebugMode.enabled)
	DebugMode.toggle()
	assert_false(DebugMode.enabled)
	assert_eq(_toggled_payloads, [true, false])


# ---------------------------------------------------------------------------
# 工具：完整模拟 ↑↑↓↓←→←→
# ---------------------------------------------------------------------------

func _simulate_konami() -> void:
	for k in [
		KEY_UP, KEY_UP, KEY_DOWN, KEY_DOWN,
		KEY_LEFT, KEY_RIGHT, KEY_LEFT, KEY_RIGHT,
	]:
		DebugMode.simulate_key(k)
