## LoreCodexSystem — 剧情图鉴解锁系统
##
## 维护"已解锁的剧情条目"集合，用于在图鉴馆显示玩家看过的剧情碎片。
## 持久化策略：
##   - 优先调用 SaveSystem.queue_save()（待 SaveSystem 暴露后接入）
##   - 当前实现：内联 JSON 文件 user://lore_unlocks.json
##
## TODO(autoload): 在 project.godot [autoload] 段注册：
##   LoreCodexSystem="*res://src/cutscene/lore_codex_system.gd"
##
## 参考: docs/superpowers/specs/2026-05-04-cutscene-system-design.md
extends Node

signal lore_unlocked(lore_id: String)

const PERSIST_PATH: String = "user://lore_unlocks.json"

# id -> unix_timestamp（解锁时刻）
var unlocked_lore_ids: Dictionary = {}

## 持久化路径，可在测试中覆盖
var persist_path: String = PERSIST_PATH


func _ready() -> void:
	_load_from_disk()


## 解锁一个剧情条目；重复解锁不会更新时间戳，也不会重复发信号
func unlock_lore(lore_id: String) -> void:
	if lore_id.is_empty():
		return
	if unlocked_lore_ids.has(lore_id):
		return
	unlocked_lore_ids[lore_id] = Time.get_unix_time_from_system()
	_persist()
	lore_unlocked.emit(lore_id)


## 是否已解锁
func is_unlocked(lore_id: String) -> bool:
	return unlocked_lore_ids.has(lore_id)


## 返回所有已解锁的 lore_id（无顺序保证）
func get_all_unlocked() -> Array[String]:
	var out: Array[String] = []
	for k in unlocked_lore_ids.keys():
		out.append(String(k))
	return out


## 测试用：清空内存与磁盘
func clear_all() -> void:
	unlocked_lore_ids.clear()
	if FileAccess.file_exists(persist_path):
		DirAccess.remove_absolute(persist_path)


# ---- 内部 ----

func _persist() -> void:
	# TODO: 当 SaveSystem 暴露 queue_save() 时切换到统一存档通道。
	# 目前直接落地到 persist_path（user://lore_unlocks.json）。
	_write_json_file()


func _write_json_file() -> void:
	var file := FileAccess.open(persist_path, FileAccess.WRITE)
	if file == null:
		push_warning("[LoreCodexSystem] failed to open %s for write" % persist_path)
		return
	file.store_string(JSON.stringify(unlocked_lore_ids))
	file.close()


func _load_from_disk() -> void:
	if not FileAccess.file_exists(persist_path):
		return
	var file := FileAccess.open(persist_path, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		unlocked_lore_ids = parsed
