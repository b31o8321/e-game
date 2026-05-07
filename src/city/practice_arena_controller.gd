class_name PracticeArenaController extends Control

const SESSION_SIZE: int = 10

var _question_ids: Array[String] = []
var _current_index: int = 0
var _correct_count: int = 0
var _pack: ContentPackBase = null
# TODO Phase 4: rebuild — QuestionController/question_ui removed in Phase 1 cleanup;
# practice arena will be rewritten on top of the new card system in Phase 4.
var _question_controller: Node = null
var _question_ui: Node = null

@onready var _progress_label: Label = $ProgressLabel
@onready var _result_panel: Control = $ResultPanel
@onready var _result_label: Label = $ResultPanel/ResultLabel
@onready var _next_button: Button = $NextButton
@onready var _finish_button: Button = $ResultPanel/FinishButton
@onready var _back_button: Button = $BackButton

func _ready() -> void:
	_pack = GameState.content_loader.get_active_pack()
	_build_question_list()
	# TODO Phase 4: rebuild — _setup_question_ui disabled (question_ui removed in Phase 1)
	# _setup_question_ui()
	_next_button.pressed.connect(_on_next_pressed)
	_finish_button.pressed.connect(_on_finish_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_result_panel.visible = false
	if _question_ids.is_empty():
		_show_no_data()
	else:
		_show_next_question()

func _build_question_list() -> void:
	if not GameState.practice_target_ids.is_empty():
		_question_ids = GameState.practice_target_ids.duplicate()
		GameState.practice_target_ids = []
		return
	var all_records: Dictionary = GameState.srs_system.serialize()
	var candidates: Array[String] = []
	for qid in all_records:
		if all_records[qid].get("wrong", 0) > 0:
			candidates.append(qid)
	candidates.sort_custom(func(a: String, b: String) -> bool:
		return GameState.srs_system.get_priority(a) > GameState.srs_system.get_priority(b))
	_question_ids = candidates.slice(0, min(SESSION_SIZE, candidates.size()))

func _setup_question_ui() -> void:
	# TODO Phase 4: rebuild — question_ui.tscn / QuestionController removed in Phase 1 cleanup
	pass

func _show_next_question() -> void:
	if _pack == null:
		_show_no_data()
		return
	while _current_index < _question_ids.size():
		var qid: String = _question_ids[_current_index]
		var q: Dictionary = _pack.get_question_by_id(qid)
		if not q.is_empty():
			_progress_label.text = "第 %d / %d 题" % [_current_index + 1, _question_ids.size()]
			# TODO Phase 4: rebuild — QuestionController/question_ui removed in Phase 1 cleanup
			# _question_controller.load_question(q)
			# _question_ui.visible = true
			_next_button.visible = false
			return
		_current_index += 1
	_show_results()

func _on_question_answered(correct: bool, question_id: String) -> void:
	GameState.srs_system.record_answer(question_id, correct)
	if correct:
		_correct_count += 1
	_current_index += 1
	_next_button.visible = true

func _on_next_pressed() -> void:
	_next_button.visible = false
	# TODO Phase 4: rebuild — question_ui removed in Phase 1 cleanup
	# _question_ui.visible = false
	_show_next_question()

func _show_results() -> void:
	# TODO Phase 4: rebuild — question_ui removed in Phase 1 cleanup
	# _question_ui.visible = false
	_progress_label.visible = false
	_next_button.visible = false
	var reward: int = _correct_count / 2
	if reward > 0:
		GameState.inventory_resources["vocabulary_crystal"] = \
			GameState.inventory_resources.get("vocabulary_crystal", 0) + reward
		GameState.save_system.save_game_state()
	_result_label.text = "练习完成！\n答对 %d / %d 题\n获得词汇结晶 ×%d" % [
		_correct_count, _question_ids.size(), reward]
	_result_panel.visible = true

func _show_no_data() -> void:
	_progress_label.text = "暂无薄弱知识点记录\n先去野外探索积累答题记录！"
	_next_button.visible = false

func _on_finish_pressed() -> void:
	get_tree().change_scene_to_file("res://src/city/city_scene.tscn")

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://src/city/city_scene.tscn")
