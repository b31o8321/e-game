extends Control

@onready var _title_label: Label = $TitleLabel
@onready var _stats_label: Label = $StatsLabel
@onready var _type_stats_label: Label = $TypeStatsLabel
@onready var _combo_label: Label = $ComboLabel
@onready var _loot_label: Label = $LootLabel
@onready var _wrong_label: Label = $WrongLabel
@onready var _practice_button: Button = $PracticeButton
@onready var _return_button: Button = $ReturnButton
@onready var _retry_button: Button = $RetryButton

func _ready() -> void:
	_display_report(GameState.last_expedition_report)
	_practice_button.pressed.connect(_on_practice_pressed)
	_return_button.pressed.connect(_on_return_pressed)
	_retry_button.pressed.connect(_on_retry_pressed)

func _display_report(report: Dictionary) -> void:
	if report.is_empty():
		_title_label.text = "暂无报告"
		return
	var victory: bool = report.get("victory", false)
	_title_label.text = "🏆 远征胜利！" if victory else "📋 撤退报告"
	var total: int = report.get("total_questions", 0)
	var correct: int = report.get("correct_count", 0)
	var pct: int = int(report.get("accuracy", 0.0) * 100)
	_stats_label.text = "答题: %d / %d   正确率: %d%%" % [correct, total, pct]
	var by_type: Dictionary = report.get("by_attack_type", {})
	var lines: Array[String] = []
	for t in by_type:
		var td: Dictionary = by_type[t]
		var tc: int = td.get("correct", 0)
		var tt: int = td.get("total", 0)
		var ta: int = int(float(tc) / float(tt) * 100) if tt > 0 else 0
		lines.append("  %s: %d/%d (%d%%)" % [t, tc, tt, ta])
	_type_stats_label.text = "\n".join(lines) if not lines.is_empty() else ""
	_combo_label.text = "最高连击: %d" % report.get("peak_combo", 0)
	var loot: Dictionary = report.get("loot", {})
	var loot_parts: Array[String] = []
	for k in loot:
		loot_parts.append("%s ×%d" % [k, loot[k]])
	_loot_label.text = "获得: " + (", ".join(loot_parts) if not loot_parts.is_empty() else "无")
	var wrong_ids: Dictionary = report.get("most_wrong_ids", {})
	if wrong_ids.is_empty():
		_wrong_label.text = "无错题记录"
		_practice_button.visible = false
	else:
		_wrong_label.text = "薄弱知识点: %d 个" % wrong_ids.size()
		_practice_button.visible = true

func _on_practice_pressed() -> void:
	var wrong_ids: Dictionary = GameState.last_expedition_report.get("most_wrong_ids", {})
	var ids: Array[String] = []
	ids.assign(wrong_ids.keys())
	GameState.practice_target_ids = ids
	get_tree().change_scene_to_file("res://src/city/practice_arena_scene.tscn")

func _on_return_pressed() -> void:
	get_tree().change_scene_to_file("res://src/city/city_scene.tscn")

func _on_retry_pressed() -> void:
	get_tree().change_scene_to_file("res://src/battle/expedition_setup.tscn")
