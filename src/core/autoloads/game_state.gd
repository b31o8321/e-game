extends Node

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

func reset_expedition() -> void:
    expedition_active = false
    expedition_loot = {}
    combo_count = 0
    player_hp = player_max_hp
    active_bd_skills.clear()

func take_damage(amount: int) -> void:
    player_hp = max(0, player_hp - amount)
    combo_count = 0
    emit_signal("combo_changed", combo_count)
    emit_signal("hp_changed", player_hp, player_max_hp)
    if player_hp == 0:
        end_expedition(false)

func increment_combo() -> void:
    combo_count += 1
    emit_signal("combo_changed", combo_count)

func end_expedition(victory: bool) -> void:
    var report = {
        "victory": victory,
        "loot": expedition_loot.duplicate(),
        "peak_combo": combo_count
    }
    reset_expedition()
    emit_signal("expedition_ended", report)
