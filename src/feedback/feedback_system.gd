## FeedbackSystem — autoload，记录玩家对题/卡/敌人的反馈
##
## 持久化：append-only JSON Lines @ user://feedback.jsonl
## 每行一条：{timestamp, type, id, reason, comment}
##
## type 枚举: "question" | "card" | "enemy" | "boss" | "general"
## reason: 视 type 而定（dialogue_unclear / answer_unreasonable /
##         translation_wrong / audio_missing / meaning_wrong / etc.）
extends Node

const _DEFAULT_PATH := "user://feedback.jsonl"

var _persist_path_override: String = ""


func _path() -> String:
	return _persist_path_override if _persist_path_override != "" else _DEFAULT_PATH


func report(type: String, id: String, reason: String, comment: String = "") -> void:
	var entry := {
		"timestamp": Time.get_datetime_string_from_system(true) + "Z",
		"type": type,
		"id": id,
		"reason": reason,
		"comment": comment,
	}
	var path := _path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f: FileAccess
	if FileAccess.file_exists(path):
		f = FileAccess.open(path, FileAccess.READ_WRITE)
		if f != null:
			f.seek_end()
	else:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("FeedbackSystem: cannot write " + path)
		return
	f.store_line(JSON.stringify(entry))
	f.close()


func get_all() -> Array:
	var path := _path()
	if not FileAccess.file_exists(path):
		return []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return []
	var entries: Array = []
	while not f.eof_reached():
		var line := f.get_line()
		if line.is_empty():
			continue
		var parsed = JSON.parse_string(line)
		if parsed != null:
			entries.append(parsed)
	f.close()
	return entries


func export_json() -> String:
	return JSON.stringify(get_all(), "  ")


func clear() -> void:
	var path := _path()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
