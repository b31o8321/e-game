extends Control

@onready var _gate_name_label: Label = $GateNameLabel
@onready var _dialogue_label: Label = $DialogueLabel
@onready var _start_button: Button = $StartButton
@onready var _back_button: Button = $BackButton

var _lines: Array[String] = []
var _line_index: int = 0

func _ready() -> void:
	_reload_gate_for_attempt()
	_start_button.pressed.connect(_on_start_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	if _gate_name_label:
		_gate_name_label.text = GameState.pending_gate_config.get("gate_name", "大关")
	_show_current_line()

func _reload_gate_for_attempt() -> void:
	var cfg: Dictionary = GameState.pending_gate_config
	if cfg.is_empty():
		return
	var pack: ContentPackBase = GameState.content_loader.get_active_pack()
	var questions_per_wave: int = cfg.get("questions_per_wave", 3)
	var wave_count: int = cfg.get("wave_count", 0)
	var total: int = questions_per_wave * (wave_count + 1)
	GameState.gate_questions_pool = pack.get_gate_questions(cfg["gate_id"], total)
	GameState.gate_wave_index = 0
	var boss_path: String = cfg.get("boss_script_path", "")
	if not boss_path.is_empty():
		var boss_script := load(boss_path)
		if boss_script:
			var boss: BossBase = boss_script.new() as BossBase
			if boss:
				_lines = boss.get_intro_dialogue()
				return
	_lines = ["准备好了吗？大关开始！"]

func _show_current_line() -> void:
	if _lines.is_empty():
		_dialogue_label.text = ""
		return
	_dialogue_label.text = _lines[min(_line_index, _lines.size() - 1)]

func _on_start_pressed() -> void:
	if _line_index < _lines.size() - 1:
		_line_index += 1
		_show_current_line()
		return
	_start_wave()

func _start_wave() -> void:
	var cfg: Dictionary = GameState.pending_gate_config
	if cfg.get("wave_count", 0) == 0:
		_go_to_boss()
		return
	var wave_cfg: Dictionary = cfg.get("wave_enemy", {})
	var ed := EnemyData.new()
	ed.enemy_id = "gate_wave_enemy"
	ed.enemy_name = wave_cfg.get("enemy_name", "关卡敌人")
	ed.max_hp = wave_cfg.get("max_hp", 20)
	ed.base_attack = wave_cfg.get("base_attack", 3)
	ed.weaknesses = wave_cfg.get("weaknesses", [])
	ed.weakness_multipliers = wave_cfg.get("multipliers", {})
	GameState.pending_enemy = ed
	get_tree().change_scene_to_file("res://src/gate/gate_wave_scene.tscn")

func _go_to_boss() -> void:
	var cfg: Dictionary = GameState.pending_gate_config
	var boss_cfg: Dictionary = cfg.get("boss_enemy", {})
	var ed := EnemyData.new()
	ed.enemy_id = cfg.get("gate_id", "boss") + "_boss"
	ed.enemy_name = boss_cfg.get("enemy_name", "Boss")
	ed.max_hp = boss_cfg.get("max_hp", 150)
	ed.base_attack = boss_cfg.get("base_attack", 10)
	ed.weaknesses = boss_cfg.get("weaknesses", [])
	ed.weakness_multipliers = boss_cfg.get("multipliers", {})
	GameState.pending_enemy = ed
	get_tree().change_scene_to_file("res://src/gate/boss_battle_scene.tscn")

func _on_back_pressed() -> void:
	GameState.is_gate_active = false
	GameState.pending_gate_id = ""
	GameState.pending_gate_config = {}
	GameState.gate_questions_pool.clear()
	get_tree().change_scene_to_file("res://src/exploration/exploration_scene.tscn")
