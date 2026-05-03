class_name ExpeditionTracker extends Node

var _answers: Array[Dictionary] = []
var _peak_combo: int = 0

func reset() -> void:
	_answers.clear()
	_peak_combo = 0

func record_answer(question_id: String, attack_type: String, correct: bool) -> void:
	_answers.append({
		"question_id": question_id,
		"attack_type": attack_type,
		"correct": correct,
	})

func update_peak_combo(combo: int) -> void:
	if combo > _peak_combo:
		_peak_combo = combo

func build_report() -> Dictionary:
	var total: int = _answers.size()
	var correct_count: int = 0
	var by_type: Dictionary = {}
	var wrong_counts: Dictionary = {}

	for a in _answers:
		var is_correct: bool = a["correct"]
		var attack_type: String = a["attack_type"]
		var qid: String = a["question_id"]

		if is_correct:
			correct_count += 1
		else:
			wrong_counts[qid] = wrong_counts.get(qid, 0) + 1

		if not by_type.has(attack_type):
			by_type[attack_type] = { "correct": 0, "total": 0 }
		by_type[attack_type]["total"] += 1
		if is_correct:
			by_type[attack_type]["correct"] += 1

	return {
		"total_questions": total,
		"correct_count": correct_count,
		"accuracy": float(correct_count) / float(total) if total > 0 else 0.0,
		"by_attack_type": by_type,
		"most_wrong_ids": wrong_counts,
		"peak_combo": _peak_combo,
	}
