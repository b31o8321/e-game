## CutsceneLoader — 从 JSON 加载 CutscenePanel 序列
##
## 工具类（无状态），所有方法 static。从内容包路径或任意 res://、user:// 路径读取
## JSON 数组并实例化为 Array[CutscenePanel]。文件缺失时返回空数组并打印 warning，
## 不会抛错——保证消费者可以安全地 await/iterate 结果。
##
## 参考: docs/superpowers/specs/2026-05-04-cutscene-system-design.md
class_name CutsceneLoader extends RefCounted


## 从 JSON 文件加载面板序列。
## - path 不存在：返回空数组 + warning
## - JSON 解析失败：返回空数组 + warning
## - 顶层非数组：返回空数组 + warning
static func load_panels_from_json(path: String) -> Array[CutscenePanel]:
	var out: Array[CutscenePanel] = []
	if path.is_empty():
		push_warning("[CutsceneLoader] empty path")
		return out
	if not FileAccess.file_exists(path):
		push_warning("[CutsceneLoader] file not found: %s" % path)
		return out
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[CutsceneLoader] failed to open: %s" % path)
		return out
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null:
		push_warning("[CutsceneLoader] JSON parse failed: %s" % path)
		return out
	if not (parsed is Array):
		push_warning("[CutsceneLoader] expected top-level array in %s" % path)
		return out
	for entry in parsed:
		if entry is Dictionary:
			out.append(CutscenePanel.from_dict(entry))
	return out


## 直接从 Array[Dictionary]（已经解析的数据）构造，便于内容包内置常量。
static func load_panels_from_array(data: Array) -> Array[CutscenePanel]:
	var out: Array[CutscenePanel] = []
	for entry in data:
		if entry is Dictionary:
			out.append(CutscenePanel.from_dict(entry))
	return out
