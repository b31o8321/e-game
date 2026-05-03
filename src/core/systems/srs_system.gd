class_name SRSSystem extends Node

# question_id -> { correct: int, wrong: int, last_wrong_time: float }
var _records: Dictionary = {}

func record_answer(question_id: String, correct: bool) -> void:
	if not _records.has(question_id):
		_records[question_id] = { "correct": 0, "wrong": 0, "last_wrong_time": 0.0 }
	if correct:
		_records[question_id]["correct"] += 1
	else:
		_records[question_id]["wrong"] += 1
		_records[question_id]["last_wrong_time"] = Time.get_unix_time_from_system()

## 优先级：错误次数权重高，时间衰减（越久没错优先级越低）
func get_priority(question_id: String) -> float:
	if not _records.has(question_id):
		return 0.0
	var r: Dictionary = _records[question_id]
	var wrong_weight: float = r["wrong"] * 3.0
	var correct_discount: float = r["correct"] * 1.0
	var time_decay: float = 0.0
	if r["last_wrong_time"] > 0:
		var hours_since: float = (Time.get_unix_time_from_system() - r["last_wrong_time"]) / 3600.0
		time_decay = hours_since * 0.5
	return max(0.0, wrong_weight - correct_discount - time_decay)

## 从候选ID列表中选出优先级最高的
func pick_question(candidate_ids: Array[String]) -> String:
	if candidate_ids.is_empty():
		return ""
	var best_id: String = candidate_ids[0]
	var best_priority: float = get_priority(best_id)
	for id in candidate_ids:
		var p: float = get_priority(id)
		if p > best_priority:
			best_priority = p
			best_id = id
	return best_id

func serialize() -> Dictionary:
	return _records.duplicate(true)

func deserialize(data: Dictionary) -> void:
	_records = data.duplicate(true)
