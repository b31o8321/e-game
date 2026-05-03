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

# 进度状态
var unlocked_knowledge_ids: Array[String] = []
var completed_gate_ids: Array[String] = []
var city_building_levels: Dictionary = {}  # building_id -> level

# 当前远征状态
var expedition_active: bool = false
var expedition_loot: Dictionary = {}

# 信号
signal hp_changed(new_hp: int, max_hp: int)
signal combo_changed(count: int)
signal knowledge_unlocked(knowledge_id: String)
signal gate_completed(gate_id: String)
signal expedition_ended(report: Dictionary)

func _ready() -> void:
	content_loader = ContentLoader.new()
	add_child(content_loader)
	srs_system = SRSSystem.new()
	add_child(srs_system)
	save_system = SaveSystem.new()
	add_child(save_system)
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

func end_expedition(victory: bool) -> void:
	if not expedition_active:
		return
	var report: Dictionary = {
		"victory": victory,
		"loot": expedition_loot.duplicate(),
		"peak_combo": combo_count
	}
	reset_expedition()
	expedition_ended.emit(report)
	save_system.save_game_state()
