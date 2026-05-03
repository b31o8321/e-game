class_name EnglishContentPack extends ContentPackBase

var _questions: Array[Dictionary] = []
var _gates: Array[Dictionary] = []

func _init() -> void:
	pack_id = "english_grade46"
	pack_name = "小学英语 4-6年级"
	subject = "english"
	grades = [4, 5, 6]

func _ready() -> void:
	_load_questions()
	_load_gates()

func _load_questions() -> void:
	var path := "res://src/content/english/data/questions.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("EnglishContentPack: failed to open " + path)
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary) or not parsed.has("questions"):
		push_error("EnglishContentPack: invalid JSON at " + path)
		return
	_questions.assign(parsed["questions"])

func _load_gates() -> void:
	var path := "res://src/content/english/data/gates.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("EnglishContentPack: failed to open " + path)
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary) or not parsed.has("gates"):
		push_error("EnglishContentPack: invalid JSON at " + path)
		return
	_gates.assign(parsed["gates"])

func get_question(attack_type_id: String, _difficulty: int, exclude_ids: Array[String]) -> Dictionary:  # difficulty unused: JSON has no difficulty field
	var candidates: Array[Dictionary] = []
	for q in _questions:
		if q.get("grade", 99) > GameState.player_grade:
			continue
		if not attack_type_id.is_empty() and q.get("attack_type_id", "") != attack_type_id:
			continue
		if q.get("id", "") in exclude_ids:
			continue
		candidates.append(q)
	if candidates.is_empty():
		return {}
	return candidates[randi() % candidates.size()]

func get_question_by_id(question_id: String) -> Dictionary:
	for q in _questions:
		if q.get("id", "") == question_id:
			return q
	return {}

func get_gate_questions(_gate_id: String, count: int) -> Array[Dictionary]:  # gate_id unused: single-gate pack, all grade-eligible questions serve as pool
	var pool: Array[Dictionary] = []
	for q in _questions:
		if q.get("grade", 99) <= GameState.player_grade:
			pool.append(q)
	pool.shuffle()
	var result: Array[Dictionary] = []
	result.assign(pool.slice(0, min(count, pool.size())))
	return result

func get_gates() -> Array[Dictionary]:
	return _gates

func get_attack_types() -> Array[Dictionary]:
	return [
		{ "id": "vocabulary", "name": "词汇", "icon": "📚", "color": "#667eea", "element": "fire" },
		{ "id": "grammar",    "name": "语法", "icon": "📝", "color": "#f5576c", "element": "ice" },
	]

func get_buildings() -> Array[Dictionary]:
	return [
		{ "id": "vocabulary_library", "name": "词汇图书馆", "attack_type_id": "vocabulary", "base_damage": 10, "levels": [1, 2, 3] },
		{ "id": "grammar_academy",    "name": "语法学院",   "attack_type_id": "grammar",    "base_damage": 10, "levels": [1, 2, 3] },
	]

func on_question_answered(question_id: String, correct: bool) -> void:
	pass

func get_skills(bd_path: String) -> Array[Dictionary]:
	return []

func get_equipment() -> Array[Dictionary]:
	return []

func get_puzzle_scene_path(knowledge_id: String) -> String:
	return ""

func get_audio(text: String) -> AudioStream:
	return null
