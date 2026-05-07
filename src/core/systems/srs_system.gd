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

## 该 ID 答对次数（无记录返回 0）
func get_correct_count(question_id: String) -> int:
	if not _records.has(question_id):
		return 0
	return int(_records[question_id].get("correct", 0))

## 该 ID 答错次数（无记录返回 0）
func get_wrong_count(question_id: String) -> int:
	if not _records.has(question_id):
		return 0
	return int(_records[question_id].get("wrong", 0))

## 是否存在弱点（任意题目错过且优先级 > 0）
func has_weak_questions() -> bool:
	for id in _records.keys():
		if get_priority(id) > 0.0:
			return true
	return false

## 取优先级最高（最弱）的若干题目 ID（按 priority 降序）
func get_weakest_card_ids(count: int) -> Array[String]:
	var ids: Array[String] = []
	for id in _records.keys():
		ids.append(str(id))
	ids.sort_custom(func(a: String, b: String) -> bool:
		return get_priority(a) > get_priority(b))
	# 仅保留 priority > 0 的
	var filtered: Array[String] = []
	for id in ids:
		if get_priority(id) <= 0.0:
			continue
		filtered.append(id)
		if filtered.size() >= count:
			break
	return filtered

func serialize() -> Dictionary:
	return _records.duplicate(true)

func deserialize(data: Dictionary) -> void:
	_records = data.duplicate(true)
