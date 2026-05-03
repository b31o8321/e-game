class_name ExplorationController extends Control

## 资源节点配置：[{resource_type, attack_type, amount, label}]
const RESOURCE_NODE_CONFIGS: Array[Dictionary] = [
	{ "resource_type": "vocabulary_crystal", "attack_type": "vocabulary", "amount": 2, "label": "📚 词灵结晶 ×2" },
	{ "resource_type": "vocabulary_crystal", "attack_type": "vocabulary", "amount": 1, "label": "📚 词灵结晶 ×1" },
	{ "resource_type": "grammar_ore",        "attack_type": "grammar",    "amount": 2, "label": "📝 法则矿石 ×2" },
	{ "resource_type": "grammar_ore",        "attack_type": "grammar",    "amount": 1, "label": "📝 法则矿石 ×1" },
]

## 敌人节点配置
const ENEMY_CONFIGS: Array[Dictionary] = [
	{
		"enemy_id": "forest_goblin",
		"enemy_name": "森林哥布林",
		"max_hp": 40,
		"base_attack": 6,
		"weaknesses": ["vocabulary"],
		"multipliers": { "vocabulary": 1.5 },
		"label": "⚔️ 森林哥布林 (弱点: 词灵)",
	},
	{
		"enemy_id": "stone_golem",
		"enemy_name": "石头傀儡",
		"max_hp": 60,
		"base_attack": 8,
		"weaknesses": ["grammar"],
		"multipliers": { "grammar": 2.0 },
		"label": "⚔️ 石头傀儡 (弱点: 法则)",
	},
]

var _pending_node: ResourceNode = null
var _question_controller: QuestionController = null
var _question_ui: Node = null

@onready var _node_area: VBoxContainer = $NodeArea
@onready var _resource_bar: Label = $ResourceBar
@onready var _return_button: Button = $ReturnButton

func _ready() -> void:
	_spawn_resource_nodes()
	_setup_question_ui()
	_return_button.pressed.connect(_on_return_pressed)
	_spawn_enemy_nodes()
	_spawn_gate_nodes()
	GameState.gate_completed.connect(_on_gate_completed)
	_update_resource_bar()

func _spawn_resource_nodes() -> void:
	var scene: PackedScene = load("res://src/exploration/resource_node.tscn")
	for cfg in RESOURCE_NODE_CONFIGS:
		var rn: ResourceNode = scene.instantiate() as ResourceNode
		rn.resource_type_id = cfg["resource_type"]
		rn.attack_type_id = cfg["attack_type"]
		rn.resource_amount = cfg["amount"]
		rn.text = cfg["label"]
		rn.question_requested.connect(_on_node_question_requested)
		rn.collected.connect(_on_resource_collected)
		_node_area.add_child(rn)

func _setup_question_ui() -> void:
	var scene: PackedScene = load("res://src/battle/question_ui.tscn")
	_question_ui = scene.instantiate() as Control
	_question_ui.visible = false
	add_child(_question_ui)
	_question_controller = _question_ui as QuestionController
	_question_controller.answered.connect(_on_question_answered)

func _on_node_question_requested(node: ResourceNode, question: Dictionary) -> void:
	_pending_node = node
	_question_controller.load_question(question)
	_question_ui.visible = true

func _on_question_answered(correct: bool, question_id: String) -> void:
	_question_ui.visible = false
	GameState.srs_system.record_answer(question_id, correct)
	if _pending_node and GameState.expedition_active:
		GameState.expedition_tracker.record_answer(question_id, _pending_node.attack_type_id, correct)
	if _pending_node:
		_pending_node.on_question_answered(correct)
		_pending_node = null
	_update_resource_bar()

func _on_resource_collected(_type: String, _amount: int) -> void:
	_update_resource_bar()

func _update_resource_bar() -> void:
	if not _resource_bar:
		return
	var parts: Array[String] = []
	for k in GameState.inventory_resources:
		parts.append("%s: %d" % [k, GameState.inventory_resources[k]])
	_resource_bar.text = "背包: " + (", ".join(parts) if not parts.is_empty() else "空")

func _on_return_pressed() -> void:
	if GameState.expedition_active:
		GameState.end_expedition(false)
		get_tree().change_scene_to_file("res://src/ui/retreat_report_scene.tscn")
	else:
		get_tree().change_scene_to_file("res://src/city/city_scene.tscn")

func _spawn_enemy_nodes() -> void:
	var scene: PackedScene = load("res://src/exploration/enemy_encounter_node.tscn")
	var area: VBoxContainer = $EnemyArea
	for cfg in ENEMY_CONFIGS:
		var een: EnemyEncounterNode = scene.instantiate() as EnemyEncounterNode
		var ed: EnemyData = EnemyData.new()
		ed.enemy_id = cfg["enemy_id"]
		ed.enemy_name = cfg["enemy_name"]
		ed.max_hp = cfg["max_hp"]
		ed.base_attack = cfg["base_attack"]
		ed.weaknesses = cfg["weaknesses"]
		ed.weakness_multipliers = cfg["multipliers"]
		een.enemy_data = ed
		een.text = cfg["label"]
		area.add_child(een)

func _spawn_gate_nodes() -> void:
	var pack: ContentPackBase = GameState.content_loader.get_active_pack()
	if not pack:
		return
	var gates: Array[Dictionary] = []
	gates.assign(pack.get_gates())
	for cfg in gates:
		var gn := KnowledgeGateNode.new()
		_node_area.add_child(gn)
		gn.setup(cfg)

func _on_gate_completed(_gate_id: String) -> void:
	for child in _node_area.get_children():
		if child is KnowledgeGateNode:
			child.setup(child.gate_config)
