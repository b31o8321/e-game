extends Node

var content_loader: ContentLoader
var srs_system: SRSSystem
var save_system: SaveSystem

# 玩家核心状态
var player_hp: int = 100
var player_max_hp: int = 100
var combo_count: int = 0
var knowledge_level: int = 1        # 当前知识层级，决定怪物难度
var active_bd_skills: Array[String] = []
var inventory_resources: Dictionary = {}  # resource_id -> count
var equipment_slots: Dictionary = {
	"weapon": "",
	"armor": "",
	"accessory": "",
	"mount": ""
}
var player_grade: int = 5       # 4 | 5 | 6，影响题目难度池

# 进度状态
var unlocked_knowledge_ids: Array[String] = []
var completed_gate_ids: Array[String] = []
var city_building_levels: Dictionary = {}  # building_id -> level

# 当前远征状态
var expedition_active: bool = false
var expedition_loot: Dictionary = {}
## 待进入战斗的敌人，ExplorationController 写入，BattleController 读取后置 null
var pending_enemy: EnemyData = null
## 战斗结束后返回的场景路径；空字符串 = 不跳转（单元测试场景）
var expedition_return_scene: String = ""
# TODO Phase 2: re-evaluate — ExpeditionTracker removed in Phase 1 cleanup;
# tracking semantics will be redesigned for the Run/card-battle system.
# var expedition_tracker: ExpeditionTracker
## 上次远征完整统计报告，供 RetreatReportController 读取
var last_expedition_report: Dictionary = {}
## 专项练习指定题目 ID 列表；空 = 自动从 SRS 选取
var practice_target_ids: Array[String] = []

# 大关状态
var pending_gate_id: String = ""
var pending_gate_config: Dictionary = {}
var gate_wave_index: int = 0
var gate_wave_count: int = 0
var gate_questions_pool: Array[Dictionary] = []
var is_gate_active: bool = false
var gate_boss_defeat_lines: Array[String] = []

# 信号
signal hp_changed(new_hp: int, max_hp: int)
signal combo_changed(count: int)
signal knowledge_unlocked(knowledge_id: String)
signal gate_completed(gate_id: String)
signal expedition_ended(report: Dictionary)

func _ready() -> void:
	content_loader = ContentLoader.new()
	add_child(content_loader)
	# ContentLoader._ready() 已自动扫描 src/content/*/ 注册所有包；
	# 此处只需选择激活的 pack。Phase 2 会改为读 SaveSystem 中持久化的 active_pack_id。
	content_loader.set_active_pack("english_grade46")
	srs_system = SRSSystem.new()
	add_child(srs_system)
	# TODO Phase 2: re-evaluate — ExpeditionTracker removed in Phase 1 cleanup
	# expedition_tracker = ExpeditionTracker.new()
	# add_child(expedition_tracker)
	save_system = SaveSystem.new()
	add_child(save_system)
	# 同步 active pack 到 SaveSystem，确保读写到对应学科存档
	save_system.set_active_pack_id(content_loader.get_active_pack_id())
	save_system.load_game_state()

func reset_expedition() -> void:
	expedition_active = false
	expedition_loot = {}
	combo_count = 0
	player_hp = player_max_hp
	active_bd_skills.clear()

func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	player_hp = max(0, player_hp - amount)
	combo_count = 0
	combo_changed.emit(combo_count)
	hp_changed.emit(player_hp, player_max_hp)
	if player_hp == 0:
		end_expedition(false)

func increment_combo() -> void:
	combo_count += 1
	combo_changed.emit(combo_count)
	# TODO Phase 2: re-evaluate — ExpeditionTracker removed in Phase 1 cleanup
	# if expedition_tracker:
	# 	expedition_tracker.update_peak_combo(combo_count)

## 开始新远征：重置状态并启动追踪器
func start_expedition() -> void:
	expedition_loot = {}
	combo_count = 0
	player_hp = player_max_hp
	active_bd_skills.clear()
	# TODO Phase 2: re-evaluate — ExpeditionTracker removed in Phase 1 cleanup
	# if expedition_tracker:
	# 	expedition_tracker.reset()
	expedition_active = true

## 进入大关：存储配置、预设波数、重置状态
func start_gate(gate_config: Dictionary, questions: Array[Dictionary]) -> void:
	pending_gate_id = gate_config.get("gate_id", "")
	pending_gate_config = gate_config
	gate_wave_index = 0
	gate_wave_count = gate_config.get("wave_count", 0)
	gate_questions_pool = questions
	is_gate_active = true
	player_hp = player_max_hp

## 大关失败：重置波次和题目池，保留 gate config 供重试
func fail_gate() -> void:
	gate_wave_index = 0
	gate_questions_pool.clear()
	player_hp = player_max_hp

## 大关通关：写入解锁，触发信号，存档
func complete_gate() -> void:
	var gate_id: String = pending_gate_config.get("gate_id", "")
	if gate_id not in completed_gate_ids:
		completed_gate_ids.append(gate_id)
	var new_level: int = pending_gate_config.get("unlock_knowledge_level", knowledge_level)
	knowledge_level = max(knowledge_level, new_level)
	is_gate_active = false
	gate_completed.emit(gate_id)
	save_system.save_game_state()

func end_expedition(victory: bool) -> void:
	if not expedition_active:
		return
	# TODO Phase 2: re-evaluate — ExpeditionTracker removed in Phase 1 cleanup
	var tracker_report: Dictionary = {}
	last_expedition_report = {
		"victory": victory,
		"loot": expedition_loot.duplicate(),
		"peak_combo": tracker_report.get("peak_combo", 0),
		"total_questions": tracker_report.get("total_questions", 0),
		"correct_count": tracker_report.get("correct_count", 0),
		"accuracy": tracker_report.get("accuracy", 0.0),
		"by_attack_type": tracker_report.get("by_attack_type", {}),
		"most_wrong_ids": tracker_report.get("most_wrong_ids", {}),
	}
	reset_expedition()
	expedition_ended.emit(last_expedition_report)
	save_system.save_game_state()
