## CardLoader — JSON → Card / ChallengeTemplate 加载工具
##
## 静态方法接口，不持有状态。所有错误用 push_error 记录，返回空数组以保证
## 调用方安全（不抛异常 / 不崩溃）。
class_name CardLoader extends RefCounted


## 从 JSON 文件加载 Card 数组。
## 支持两种顶层格式：
##   1) {"cards": [ {...}, {...} ]}
##   2) [ {...}, {...} ]
## 返回 Array[Card]；解析或读文件失败 → 空数组（并 push_error）。
static func load_cards_from_json(path: String) -> Array[Card]:
	var result: Array[Card] = []
	var raw := _read_file_text(path)
	if raw == "":
		return result

	var parsed = _parse_json(raw, path)
	if parsed == null:
		return result

	var entries: Array = _extract_entries(parsed, "cards")
	if entries.is_empty():
		# 注意：文件里可能就是空数组 / 空对象；这不算错误。
		return result

	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			push_error("[CardLoader] 跳过非对象卡条目: %s" % [entry])
			continue
		result.append(Card.from_dict(entry))
	return result


## 从 JSON 文件加载 ChallengeTemplate 数组。
## 支持顶层 {"challenges": [...]} 或裸数组。
static func load_challenges_from_json(path: String) -> Array[ChallengeTemplate]:
	var result: Array[ChallengeTemplate] = []
	var raw := _read_file_text(path)
	if raw == "":
		return result

	var parsed = _parse_json(raw, path)
	if parsed == null:
		return result

	var entries: Array = _extract_entries(parsed, "challenges")
	if entries.is_empty():
		return result

	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			push_error("[CardLoader] 跳过非对象 challenge 条目: %s" % [entry])
			continue
		result.append(ChallengeTemplate.from_dict(entry))
	return result


# --- 私有辅助 ---

static func _read_file_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		push_error("[CardLoader] 文件不存在: %s" % path)
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[CardLoader] 无法打开文件: %s (err=%d)" % [path, FileAccess.get_open_error()])
		return ""
	var text := f.get_as_text()
	f.close()
	return text


static func _parse_json(raw: String, path: String) -> Variant:
	var json := JSON.new()
	var err := json.parse(raw)
	if err != OK:
		push_error("[CardLoader] JSON 解析失败 %s 第 %d 行: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


## 从顶层 Variant 中提取数组。优先看 dict[key]，否则当裸数组。
static func _extract_entries(parsed: Variant, key: String) -> Array:
	if typeof(parsed) == TYPE_ARRAY:
		return parsed
	if typeof(parsed) == TYPE_DICTIONARY:
		var v = parsed.get(key, null)
		if typeof(v) == TYPE_ARRAY:
			return v
		push_error("[CardLoader] JSON 顶层缺少键 \"%s\" 或不是数组" % key)
		return []
	push_error("[CardLoader] JSON 顶层既不是数组也不是对象")
	return []
