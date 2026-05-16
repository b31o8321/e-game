extends GutTest

var combo: ComboSystem

func before_each() -> void:
	# ComboSystem 是 RefCounted（自 2026-05-17 改），不进场景树 → 不要 add_child。
	combo = ComboSystem.new()

func test_initial_count_is_zero() -> void:
	assert_eq(combo.count, 0)

func test_increment_increases_count() -> void:
	combo.increment()
	assert_eq(combo.count, 1)

func test_reset_clears_count() -> void:
	combo.increment()
	combo.increment()
	combo.reset()
	assert_eq(combo.count, 0)

func test_threshold_3_signal_emitted() -> void:
	watch_signals(combo)
	combo.increment()
	combo.increment()
	combo.increment()
	assert_signal_emitted(combo, "threshold_reached")
	assert_signal_emitted_with_parameters(combo, "threshold_reached", [3])

func test_threshold_5_signal_emitted() -> void:
	watch_signals(combo)
	for i in 5:
		combo.increment()
	assert_signal_emitted_with_parameters(combo, "threshold_reached", [5])

func test_threshold_10_signal_emitted() -> void:
	watch_signals(combo)
	for i in 10:
		combo.increment()
	assert_signal_emitted_with_parameters(combo, "threshold_reached", [10])

func test_reset_after_wrong_answer() -> void:
	combo.increment()
	combo.increment()
	combo.on_wrong_answer()
	assert_eq(combo.count, 0)
