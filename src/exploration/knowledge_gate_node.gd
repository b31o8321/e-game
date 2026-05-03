class_name KnowledgeGateNode extends Button

var gate_config: Dictionary = {}

func _ready() -> void:
	pressed.connect(_on_pressed)

func setup(cfg: Dictionary) -> void:
	gate_config = cfg
	var gate_id: String = cfg.get("gate_id", "")
	var required_level: int = cfg.get("required_knowledge_level", 1)
	var gate_name: String = cfg.get("gate_name", "大关")
	var is_completed: bool = gate_id in GameState.completed_gate_ids
	var is_locked: bool = GameState.knowledge_level < required_level
	if is_completed:
		text = "[通关] " + gate_name
		disabled = false
	elif is_locked:
		text = "[锁定] " + gate_name + "（需知识层级 %d）" % required_level
		disabled = true
	else:
		text = "[挑战] " + gate_name
		disabled = false

func _on_pressed() -> void:
	if gate_config.is_empty():
		return
	var pack: ContentPackBase = GameState.content_loader.get_active_pack()
	var cfg: Dictionary = gate_config
	var questions_per_wave: int = cfg.get("questions_per_wave", 3)
	var wave_count: int = cfg.get("wave_count", 0)
	var total: int = questions_per_wave * (wave_count + 1)
	var questions: Array[Dictionary] = []
	questions.assign(pack.get_gate_questions(cfg["gate_id"], total))
	GameState.start_gate(cfg, questions)
	get_tree().change_scene_to_file("res://src/gate/gate_intro_scene.tscn")
