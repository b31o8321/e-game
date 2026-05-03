class_name ComboSystem extends Node

var count: int = 0

## 阈值列表，到达时触发 threshold_reached 信号
const THRESHOLDS: Array[int] = [3, 5, 10]

signal combo_updated(count: int)
signal threshold_reached(threshold: int)

func increment() -> void:
	count += 1
	combo_updated.emit(count)
	if count in THRESHOLDS:
		threshold_reached.emit(count)

func reset() -> void:
	count = 0
	combo_updated.emit(count)

func on_wrong_answer() -> void:
	reset()
