class_name ContentPackBase extends Resource

## 学科包唯一标识，如 "english_grade4_6"
@export var pack_id: String = ""
## 显示名称
@export var pack_name: String = ""
## 学科类型 "english" | "math" | "chinese"
@export var subject: String = ""
## 支持年级列表 [4, 5, 6]
@export var grades: Array[int] = []

# ── 攻击类型 ────────────────────────────────────────────────────
## 返回该学科支持的攻击类型列表
## 每项格式: { id, name, icon, color, element }
func get_attack_types() -> Array[Dictionary]:
	return []

# ── 知识点 / 题目 ────────────────────────────────────────────────
## 返回已解锁的随机题目（用于战斗/探索）
## attack_type_id: 限定题目类型，"" 表示不限
## difficulty: 1-3
## exclude_ids: 排除题目ID（避免重复）
func get_question(attack_type_id: String, difficulty: int, exclude_ids: Array[String]) -> Dictionary:
	return {}

## 返回大关精选题目池（陷阱题/考点题）
## gate_id: 大关标识
func get_gate_questions(gate_id: String, count: int) -> Array[Dictionary]:
	return []

## 记录答题结果（供 SRS 系统调用）
func on_question_answered(question_id: String, correct: bool) -> void:
	pass

# ── 建筑 ─────────────────────────────────────────────────────────
## 返回城市建筑定义列表
## 每项格式: { id, name, max_level, upgrades: [{level, cost, effects}] }
func get_buildings() -> Array[Dictionary]:
	return []

# ── 技能 ─────────────────────────────────────────────────────────
## 返回可用技能定义列表（进入技能随机池）
## bd_path: "blaze" | "tank" | "element" | "summon" | "" 表示全部
func get_skills(bd_path: String) -> Array[Dictionary]:
	return []

# ── 装备 ─────────────────────────────────────────────────────────
## 返回装备定义列表
func get_equipment() -> Array[Dictionary]:
	return []

# ── 谜题 ─────────────────────────────────────────────────────────
## 返回对应知识点的解锁谜题场景路径
## knowledge_id: 如 "past_tense", "vocabulary_brave"
func get_puzzle_scene_path(knowledge_id: String) -> String:
	return ""

# ── 音频 ─────────────────────────────────────────────────────────
## 返回单词/句子的发音音频流
## 返回 null 表示该文本无对应音频（调用方须做空检查）
func get_audio(text: String) -> AudioStream:
	return null
