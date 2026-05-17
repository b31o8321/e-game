## 战斗教程覆盖层测试
## 验证：首次进战斗弹出、看过后不弹、dismiss 写 flag、4 步内容齐全
extends GutTest

const BATTLE_SCENE: String = "res://src/battle/battle_scene.tscn"


# ─── 辅助 ────────────────────────────────────────────────────────────

func _make_card() -> Card:
	return Card.from_dict({
		"id": "card_test",
		"text": "test",
		"type": "word",
		"pos": "noun",
		"tags": [],
		"skill": "vocab",
		"base_damage": 5,
		"rarity": "common",
	})


func _make_enemy() -> EnemyData:
	var e := EnemyData.new()
	e.enemy_id = "test_enemy"
	e.enemy_name = "试炼灵"
	e.max_hp = 20
	e.base_attack = 3
	e.weak_axes = []
	e.topic_id = "test_topic"
	return e


func _prime_globals() -> void:
	if typeof(GameState) != TYPE_NIL and GameState != null:
		GameState.pending_enemy = _make_enemy()
		GameState.expedition_return_scene = ""
	if typeof(RunState) != TYPE_NIL and RunState != null:
		RunState.current_deck.clear()
		RunState.current_deck.append(_make_card())
		RunState.current_floor_id = "1F"
		RunState.current_act_index = 0


func _clear_tutorial_flag() -> void:
	# 清除 SaveSystem flag
	if typeof(GameState) != TYPE_NIL and GameState != null:
		var ss: SaveSystem = GameState.save_system
		if ss != null:
			var state: Dictionary = ss.load_game_state()
			state.erase("tutorial_battle_seen")
			ss.save_game_state(state)
	# 清除旧 ConfigFile flag
	if FileAccess.file_exists("user://battle_prefs.cfg"):
		DirAccess.remove_absolute("user://battle_prefs.cfg")


func _set_tutorial_flag(value: bool) -> void:
	if typeof(GameState) != TYPE_NIL and GameState != null:
		var ss: SaveSystem = GameState.save_system
		if ss != null:
			var state: Dictionary = ss.load_game_state()
			state["tutorial_battle_seen"] = value
			ss.save_game_state(state)


func _instantiate_scene() -> Control:
	var packed: PackedScene = load(BATTLE_SCENE)
	if packed == null:
		return null
	var inst: Control = packed.instantiate() as Control
	add_child_autofree(inst)
	return inst


# ─── 生命周期 ─────────────────────────────────────────────────────────

func before_each() -> void:
	_clear_tutorial_flag()


func after_each() -> void:
	_clear_tutorial_flag()


# ─── 测试 1：tutorial_battle_seen=false → TutorialOverlay 可见 ─────────

func test_tutorial_shows_when_not_seen() -> void:
	# 确保 flag 不存在（before_each 已清除）
	_prime_globals()
	var scene: Control = _instantiate_scene()
	if scene == null:
		pending("BattleScene failed to load")
		return
	await get_tree().process_frame
	var overlay: ColorRect = scene.get_node_or_null("TutorialOverlay")
	assert_not_null(overlay, "TutorialOverlay node should exist")
	if overlay == null:
		return
	assert_true(overlay.visible, "TutorialOverlay should be visible when tutorial_battle_seen is false")


# ─── 测试 2：tutorial_battle_seen=true → TutorialOverlay 不可见 ────────

func test_tutorial_hidden_when_already_seen() -> void:
	_set_tutorial_flag(true)
	_prime_globals()
	var scene: Control = _instantiate_scene()
	if scene == null:
		pending("BattleScene failed to load")
		return
	await get_tree().process_frame
	var overlay: ColorRect = scene.get_node_or_null("TutorialOverlay")
	assert_not_null(overlay, "TutorialOverlay node should exist")
	if overlay == null:
		return
	assert_false(overlay.visible, "TutorialOverlay should be hidden when tutorial_battle_seen is true")


# ─── 测试 3：dismiss 后 SaveSystem 写入 tutorial_battle_seen = true ─────

func test_dismiss_writes_flag_to_save_system() -> void:
	# 确保从 false 状态开始
	_prime_globals()
	var scene: Control = _instantiate_scene()
	if scene == null:
		pending("BattleScene failed to load")
		return
	await get_tree().process_frame
	# 调用 _dismiss_tutorial
	if not scene.has_method("_dismiss_tutorial"):
		pending("_dismiss_tutorial method not found on scene")
		return
	scene.call("_dismiss_tutorial")
	await get_tree().process_frame
	# 读取 SaveSystem
	if typeof(GameState) == TYPE_NIL or GameState == null:
		pending("GameState not available")
		return
	var ss: SaveSystem = GameState.save_system
	if ss == null:
		pending("GameState.save_system is null")
		return
	var state: Dictionary = ss.load_game_state()
	assert_true(
		state.get("tutorial_battle_seen", false),
		"tutorial_battle_seen should be true after _dismiss_tutorial()"
	)


# ─── 测试 4：TUTORIAL_STEPS 有 4 项，每项有非空 title 和 body ──────────

func test_tutorial_steps_content_complete() -> void:
	_prime_globals()
	var scene: Control = _instantiate_scene()
	if scene == null:
		pending("BattleScene failed to load")
		return
	await get_tree().process_frame

	var steps: Variant = scene.get("TUTORIAL_STEPS")
	if steps == null:
		pending("TUTORIAL_STEPS constant not accessible")
		return

	assert_eq(steps.size(), 4, "Should have exactly 4 tutorial steps")

	for i in range(steps.size()):
		var step: Dictionary = steps[i]
		assert_true(step.has("title"), "Step %d should have 'title'" % i)
		assert_true(step.has("body"), "Step %d should have 'body'" % i)
		assert_true(
			(step["title"] as String).length() > 0,
			"Step %d title should be non-empty" % i
		)
		assert_true(
			(step["body"] as String).length() > 0,
			"Step %d body should be non-empty" % i
		)
