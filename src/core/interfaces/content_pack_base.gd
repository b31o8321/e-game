## ContentPackBase — 学科内容包接口（25 方法 + 背书的旧接口兼容层）
##
## 引擎层调用此接口获取所有学科特定数据；新学科 = 实现一个子类即可，零引擎改动。
## 详见: docs/superpowers/specs/2026-05-04-content-pack-interface-design.md
##
## 所有"新接口"方法均为 virtual：默认 push_error + 返回合理空值。
## 子类必须 override 自己关心的方法。
## 旧接口（get_question / get_buildings / ... ）保留为 @deprecated，Phase 2 迁移完成后移除。
class_name ContentPackBase extends Node

# ─── 旧接口兼容字段（@deprecated，Phase 2 移除）────────────────────
## @deprecated Phase 2: 改用 get_id()
@export var pack_id: String = ""
## @deprecated Phase 2: 改用 get_display_name()
@export var pack_name: String = ""
## @deprecated Phase 2: 改用 get_subject_category()
@export var subject: String = ""
## @deprecated Phase 2: 改用 get_grade_range()
@export var grades: Array[int] = []


# ═══════════════════════════════════════════════════════════════════
# 新 25 方法接口（spec: 2026-05-04-content-pack-interface-design.md）
# ═══════════════════════════════════════════════════════════════════

# ─── 身份 ──────────────────────────────────────────────────────────

## 学科包唯一标识，如 "english_grade46"
func get_id() -> String:
	push_error("ContentPackBase.get_id() not overridden by " + get_class())
	return pack_id  # 兜底使用旧字段

## 显示名称，如 "英语 4-6 年级"
func get_display_name() -> String:
	push_error("ContentPackBase.get_display_name() not overridden by " + get_class())
	return pack_name  # 兜底使用旧字段

## 学科类别，"english" | "math" | "science" | "chinese" | ...
func get_subject_category() -> String:
	push_error("ContentPackBase.get_subject_category() not overridden by " + get_class())
	return subject  # 兜底使用旧字段

## 年级范围，[4, 5, 6]
func get_grade_range() -> Array[int]:
	push_error("ContentPackBase.get_grade_range() not overridden by " + get_class())
	return grades  # 兜底使用旧字段

## 内容包语义版本，"0.1.0"
func get_version() -> String:
	push_error("ContentPackBase.get_version() not overridden by " + get_class())
	return "0.0.0"


# ─── 主题（视觉 + 音频）─────────────────────────────────────────────

## 主题色，{"primary": Color, "accent": Color, "danger": Color}
func get_theme_colors() -> Dictionary:
	push_error("ContentPackBase.get_theme_colors() not overridden by " + get_class())
	return {}

## 主菜单背景图路径
func get_main_menu_bg_path() -> String:
	push_error("ContentPackBase.get_main_menu_bg_path() not overridden by " + get_class())
	return ""

## 知识城背景图路径
func get_city_bg_path() -> String:
	push_error("ContentPackBase.get_city_bg_path() not overridden by " + get_class())
	return ""

## 楼层背景图路径
func get_floor_bg_path(_floor_id: String) -> String:
	push_error("ContentPackBase.get_floor_bg_path() not overridden by " + get_class())
	return ""

## 楼层战斗 BGM
func get_battle_bgm_path(_floor_id: String) -> String:
	push_error("ContentPackBase.get_battle_bgm_path() not overridden by " + get_class())
	return ""

## 主菜单 BGM
func get_main_menu_bgm_path() -> String:
	push_error("ContentPackBase.get_main_menu_bgm_path() not overridden by " + get_class())
	return ""

## 知识城 BGM
func get_city_bgm_path() -> String:
	push_error("ContentPackBase.get_city_bgm_path() not overridden by " + get_class())
	return ""


# ─── Card 类型词汇表 ───────────────────────────────────────────────

## 卡片类型列表，[{id, display, icon}, ...]
func get_card_types() -> Array[Dictionary]:
	push_error("ContentPackBase.get_card_types() not overridden by " + get_class())
	return []

## 词性列表（数学等不需要 POS 的包返回 []）
func get_pos_values() -> Array[Dictionary]:
	push_error("ContentPackBase.get_pos_values() not overridden by " + get_class())
	return []

## Tag 命名空间，[{id, display, values: [...]}, ...]
func get_tag_namespaces() -> Array[Dictionary]:
	push_error("ContentPackBase.get_tag_namespaces() not overridden by " + get_class())
	return []


# ─── Cards ────────────────────────────────────────────────────────

## 按 ID 取卡，返回 null 表示不存在
func get_card(_card_id: String) -> Card:
	push_error("ContentPackBase.get_card() not overridden by " + get_class())
	return null

## 全部卡片
func get_all_cards() -> Array[Card]:
	push_error("ContentPackBase.get_all_cards() not overridden by " + get_class())
	return []

## 起手卡组 ID 列表（首次进入战斗时的初始 12 张）
func get_starting_deck_card_ids() -> Array[String]:
	push_error("ContentPackBase.get_starting_deck_card_ids() not overridden by " + get_class())
	return []

## 按楼层定制的起手卡组 ID 列表（floor_id 为空 / 子类未覆写时回退到 get_starting_deck_card_ids）。
## 用于解决"题目和手卡对不上"——0F 字母拼读楼层应给字母卡，1F 形容词楼层应给形容词卡。
func get_starting_deck_for_floor(_floor_id: String) -> Array[String]:
	# 默认回退到通用 starting deck，子类可覆写实现按楼层定制
	return get_starting_deck_card_ids()

## 楼层战利品卡池
func get_card_pool_for_floor(_floor_id: String) -> Array[Card]:
	push_error("ContentPackBase.get_card_pool_for_floor() not overridden by " + get_class())
	return []


# ─── Challenges ───────────────────────────────────────────────────

## 按模板 ID 取 ChallengeTemplate，返回 null 表示不存在
func get_challenge_template(_template_id: String) -> ChallengeTemplate:
	push_error("ContentPackBase.get_challenge_template() not overridden by " + get_class())
	return null

## 按主题取所有 Challenge
func get_challenges_for_topic(_topic_id: String) -> Array[ChallengeTemplate]:
	push_error("ContentPackBase.get_challenges_for_topic() not overridden by " + get_class())
	return []

## 包支持的 Challenge kind 列表
## 英语: ["fill_in_blank", "error_correct", "listening_fill", "pronounce_attack", "sentence_build"]
## 数学: ["fill_in_blank", "equation_solve", "shape_identify"]
func get_supported_challenge_kinds() -> Array[String]:
	push_error("ContentPackBase.get_supported_challenge_kinds() not overridden by " + get_class())
	return []


# ─── Enemies / Bosses ─────────────────────────────────────────────

## 按 ID 取敌人数据
func get_enemy(_enemy_id: String) -> EnemyData:
	push_error("ContentPackBase.get_enemy() not overridden by " + get_class())
	return null

## 按 ID 取 Boss（已实例化的 BossBase）
func get_boss(_boss_id: String) -> BossBase:
	push_error("ContentPackBase.get_boss() not overridden by " + get_class())
	return null

## 楼层敌人池
func get_enemy_pool_for_floor(_floor_id: String) -> Array[EnemyData]:
	push_error("ContentPackBase.get_enemy_pool_for_floor() not overridden by " + get_class())
	return []


# ─── Floors（楼层 + 三幕配置）──────────────────────────────────────

## 楼层完整配置，包含三幕（act）结构
## { floor_id, unit_name, recommended_run_minutes, acts: [{sub_topic_id, node_count, ...}] }
func get_floor_config(_floor_id: String) -> Dictionary:
	push_error("ContentPackBase.get_floor_config() not overridden by " + get_class())
	return {}

## 全部楼层 ID（按解锁顺序），["1F", "2F", ...]
func get_all_floor_ids() -> Array[String]:
	push_error("ContentPackBase.get_all_floor_ids() not overridden by " + get_class())
	return []

## 楼层解锁链，[{floor_id: "1F", unlocks: ["2F"]}, ...]
func get_floor_unlock_chain() -> Array[Dictionary]:
	push_error("ContentPackBase.get_floor_unlock_chain() not overridden by " + get_class())
	return []


# ─── Spices（学科特色机制）─────────────────────────────────────────

## 此包支持的所有 Spice 实例
## 注：返回类型是 Resource — Phase 2 引入 SubjectSpiceBase 类后会替换
func get_available_spices() -> Array:
	push_error("ContentPackBase.get_available_spices() not overridden by " + get_class())
	return []

## 按 ID 取单个 Spice 实例
func get_spice(_spice_id: String) -> Resource:
	push_error("ContentPackBase.get_spice() not overridden by " + get_class())
	return null


# ─── Equipment / Loot（Phase 2 接口预留）───────────────────────────

## 全部装备池（EquipmentBase 实例）
func get_equipment_pool() -> Array:
	push_error("ContentPackBase.get_equipment_pool() not overridden by " + get_class())
	return []

## 楼层战利品掉落表，{ "common": [...], "rare": [...], ...}
func get_loot_table_for_floor(_floor_id: String) -> Dictionary:
	push_error("ContentPackBase.get_loot_table_for_floor() not overridden by " + get_class())
	return {}


# ─── 剧情面板（Cutscene 系统消费）──────────────────────────────────

## 开篇面板序列
func get_intro_panels() -> Array[CutscenePanel]:
	push_error("ContentPackBase.get_intro_panels() not overridden by " + get_class())
	return []

## 楼层开场面板
func get_floor_intro_panels(_floor_id: String) -> Array[CutscenePanel]:
	push_error("ContentPackBase.get_floor_intro_panels() not overridden by " + get_class())
	return []

## Boss 战前面板
func get_boss_pre_panels(_boss_id: String) -> Array[CutscenePanel]:
	push_error("ContentPackBase.get_boss_pre_panels() not overridden by " + get_class())
	return []

## Boss 战后面板
func get_boss_post_panels(_boss_id: String) -> Array[CutscenePanel]:
	push_error("ContentPackBase.get_boss_post_panels() not overridden by " + get_class())
	return []

## 楼层通关面板
func get_floor_complete_panels(_floor_id: String) -> Array[CutscenePanel]:
	push_error("ContentPackBase.get_floor_complete_panels() not overridden by " + get_class())
	return []

## 终局结局面板
func get_ending_panels() -> Array[CutscenePanel]:
	push_error("ContentPackBase.get_ending_panels() not overridden by " + get_class())
	return []

## NPC 对话面板
func get_npc_dialogue_panels(_npc_id: String) -> Array[CutscenePanel]:
	push_error("ContentPackBase.get_npc_dialogue_panels() not overridden by " + get_class())
	return []

## 图鉴馆显示的剧情条目友好名称（如 "0F · 楼层介绍 (1)"）
## 子类可覆盖以提供本地化标题；默认返回 lore_id 本身作为兜底。
func get_lore_title(lore_id: String) -> String:
	return lore_id

## 返回包含指定 lore_id 的剧情面板序列（用于图鉴馆"重播"功能）。
## 子类应在所有 lore 文件中查找 lore_codex_id == lore_id 的面板，
## 并返回其所属 JSON 文件的完整面板序列（重播整段最自然）。
## 默认返回空数组。
func get_panels_containing_lore(_lore_id: String) -> Array[CutscenePanel]:
	return []

## 主菜单标题
func get_game_title() -> String:
	push_error("ContentPackBase.get_game_title() not overridden by " + get_class())
	return ""

## 主菜单副标题
func get_game_subtitle() -> String:
	push_error("ContentPackBase.get_game_subtitle() not overridden by " + get_class())
	return ""


# ─── 验证 ──────────────────────────────────────────────────────────

## 启动期完整性验证；返回错误信息列表，空 = 通过。
## 子类应覆盖此方法实现具体校验：身份字段、卡组引用、楼层 boss 引用、
## challenge slot type 在 card_types 中、spice 实现完整 等。
func validate() -> Array[String]:
	var errors: Array[String] = []
	if get_id().is_empty():
		errors.append("get_id() returned empty")
	if get_display_name().is_empty():
		errors.append("get_display_name() returned empty")
	return errors


# ═══════════════════════════════════════════════════════════════════
# 旧接口（@deprecated — Phase 2 迁移完成后移除）
# 保留以避免破坏 BattleController / CityController / PracticeArenaController
# 等现有调用方。子类可继续覆盖；新代码请走上面的新接口。
# ═══════════════════════════════════════════════════════════════════

## @deprecated Phase 2: 攻击类型概念被 Card.type / Card.skill 取代
func get_attack_types() -> Array[Dictionary]:
	return []

## @deprecated Phase 2: 题目概念被 Card + ChallengeTemplate 取代
func get_question(_attack_type_id: String, _difficulty: int, _exclude_ids: Array[String]) -> Dictionary:
	return {}

## @deprecated Phase 2: 大关精选题目被 floor_config + Boss 卡池取代
func get_gate_questions(_gate_id: String, _count: int) -> Array[Dictionary]:
	return []

## @deprecated Phase 2: gates 概念被 floors 取代
func get_gates() -> Array[Dictionary]:
	return []

## @deprecated Phase 2: 答题统计走 SRSSystem
func on_question_answered(_question_id: String, _correct: bool) -> void:
	pass

## @deprecated Phase 2: 题目按 ID 检索改走 Card / ChallengeTemplate
func get_question_by_id(_question_id: String) -> Dictionary:
	return {}

## @deprecated Phase 2: 建筑数据迁移到知识城专属配置
func get_buildings() -> Array[Dictionary]:
	return []

## @deprecated Phase 2: 技能系统重做
func get_skills(_bd_path: String) -> Array[Dictionary]:
	return []

## @deprecated Phase 2: 改用 get_equipment_pool()
func get_equipment() -> Array[Dictionary]:
	return []

## @deprecated Phase 2: 谜题系统重做
func get_puzzle_scene_path(_knowledge_id: String) -> String:
	return ""

## @deprecated Phase 2: 音频改由 Card.audio_path / Spice 自管
func get_audio(_text: String) -> AudioStream:
	return null
