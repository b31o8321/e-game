class_name ResourceNode extends Button

@export var resource_type_id: String = "vocabulary_crystal"
@export var resource_amount: int = 1
@export var attack_type_id: String = "vocabulary"

enum NodeState { AVAILABLE, PENDING_ANSWER, COLLECTED }
var node_state: NodeState = NodeState.AVAILABLE

signal question_requested(node: ResourceNode, question: Dictionary)
signal collected(resource_type_id: String, amount: int)

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	var pack: ContentPackBase = GameState.content_loader.get_active_pack()
	if pack:
		try_collect(pack)

func try_collect(pack: ContentPackBase) -> void:
	if node_state != NodeState.AVAILABLE:
		return
	node_state = NodeState.PENDING_ANSWER
	disabled = true
	var question: Dictionary = pack.get_question(attack_type_id, 1, [])
	question_requested.emit(self, question)

func on_question_answered(correct: bool) -> void:
	if correct:
		node_state = NodeState.COLLECTED
		modulate = Color(0.5, 0.5, 0.5)
		GameState.inventory_resources[resource_type_id] = \
			GameState.inventory_resources.get(resource_type_id, 0) + resource_amount
		collected.emit(resource_type_id, resource_amount)
	else:
		node_state = NodeState.AVAILABLE
		disabled = false
