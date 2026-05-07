## Cutscene 系统测试套件
##
## 覆盖：
##   - CutscenePanel.from_dict / to_dict round-trip
##   - CutscenePlayer.play() 触发 cutscene_started
##   - CutscenePlayer.skip() 同时触发 cutscene_skipped + cutscene_finished
##   - CutscenePlayer.skip() 解锁所有 panel 的 lore_codex_id
##   - CutscenePlayer.advance() 顺序推进与收尾
##   - LoreCodexSystem.unlock_lore / is_unlocked / 持久化
##   - CutsceneLoader.load_panels_from_json 缺失文件容错
extends GutTest

const TEST_LORE_PATH := "user://test_lore_unlocks.json"
const TEST_JSON_PATH := "user://test_cutscene_panels.json"

# 注：CutscenePlayer / LoreCodexSystem 是 autoload 名，所以
# 不能给它们加 class_name（会与单例同名冲突）。测试里用 preload 拿到 GDScript
# 再 .new() 实例化，绕过 autoload 命名空间。
const CutscenePlayerScript := preload("res://src/cutscene/cutscene_player.gd")
const LoreCodexSystemScript := preload("res://src/cutscene/lore_codex_system.gd")

var player: Node       # CutscenePlayer 实例
var codex: Node        # LoreCodexSystem 实例


func before_each() -> void:
	# 确保测试间互不干扰
	if FileAccess.file_exists(TEST_LORE_PATH):
		DirAccess.remove_absolute(TEST_LORE_PATH)
	if FileAccess.file_exists(TEST_JSON_PATH):
		DirAccess.remove_absolute(TEST_JSON_PATH)
	codex = LoreCodexSystemScript.new()
	codex.persist_path = TEST_LORE_PATH
	codex.name = "LoreCodexSystem"
	add_child_autofree(codex)
	player = CutscenePlayerScript.new()
	player.name = "CutscenePlayer"
	player.headless_mode = true
	add_child_autofree(player)
	# 显式注入测试 codex，避免 CutscenePlayer 解析到 autoload 单例
	player.inject_codex_system(codex)


func after_each() -> void:
	if FileAccess.file_exists(TEST_LORE_PATH):
		DirAccess.remove_absolute(TEST_LORE_PATH)
	if FileAccess.file_exists(TEST_JSON_PATH):
		DirAccess.remove_absolute(TEST_JSON_PATH)


# ---- 辅助 ----

func _make_panel(id: String, lore_id: String = "", text: String = "hi", next_id: String = "") -> CutscenePanel:
	var p := CutscenePanel.new()
	p.id = id
	p.text = text
	p.text_speed = 0.0  # 立即显示，避免测试中等 tween
	p.advance_on = "click"
	p.lore_codex_id = lore_id
	p.next_panel_id = next_id
	return p


func _typed_panels(arr: Array) -> Array[CutscenePanel]:
	var out: Array[CutscenePanel] = []
	for p in arr:
		out.append(p)
	return out


# ---- CutscenePanel ----

func test_panel_from_dict_basic() -> void:
	var data := {
		"id": "intro_1",
		"background_image_path": "res://bg.png",
		"bgm_path": "res://bgm.ogg",
		"speaker_name": "Hero",
		"speaker_position": "left",
		"text": "Hello [b]world[/b]",
		"text_speed": 25.0,
		"advance_on": "auto_3s",
		"next_panel_id": "intro_2",
		"lore_codex_id": "lore_intro",
		"tags": ["main", "intro"],
	}
	var p := CutscenePanel.from_dict(data)
	assert_eq(p.id, "intro_1")
	assert_eq(p.background_image_path, "res://bg.png")
	assert_eq(p.bgm_path, "res://bgm.ogg")
	assert_eq(p.speaker_name, "Hero")
	assert_eq(p.text, "Hello [b]world[/b]")
	assert_eq(p.text_speed, 25.0)
	assert_eq(p.advance_on, "auto_3s")
	assert_eq(p.next_panel_id, "intro_2")
	assert_eq(p.lore_codex_id, "lore_intro")
	assert_eq(p.tags.size(), 2)
	assert_eq(p.tags[0], "main")


func test_panel_from_dict_defaults() -> void:
	var p := CutscenePanel.from_dict({})
	assert_eq(p.id, "")
	assert_eq(p.advance_on, "click")
	assert_eq(p.text_speed, 30.0)
	assert_eq(p.transition_in, "instant")
	assert_eq(p.tags.size(), 0)


func test_panel_to_dict_round_trip() -> void:
	var original := _make_panel("p1", "lore_1", "world")
	original.bgm_path = "res://x.ogg"
	original.speaker_name = "Sage"
	original.tags = ["a", "b"]
	var d := original.to_dict()
	var rebuilt := CutscenePanel.from_dict(d)
	assert_eq(rebuilt.id, original.id)
	assert_eq(rebuilt.lore_codex_id, original.lore_codex_id)
	assert_eq(rebuilt.text, original.text)
	assert_eq(rebuilt.bgm_path, original.bgm_path)
	assert_eq(rebuilt.speaker_name, original.speaker_name)
	assert_eq(rebuilt.tags.size(), 2)


# ---- CutscenePlayer ----

func test_play_emits_cutscene_started() -> void:
	watch_signals(player)
	var panels := _typed_panels([_make_panel("p1", "", "a", "p2"), _make_panel("p2")])
	player.play("intro", panels)
	assert_signal_emitted_with_parameters(player, "cutscene_started", ["intro"])
	assert_true(player.is_playing(), "player should be playing after play()")


func test_play_emits_panel_advanced_for_first_panel() -> void:
	watch_signals(player)
	var panels := _typed_panels([_make_panel("p1"), _make_panel("p2")])
	player.play("intro", panels)
	assert_signal_emitted_with_parameters(player, "panel_advanced", ["p1"])


func test_advance_moves_to_next_panel() -> void:
	watch_signals(player)
	var panels := _typed_panels([_make_panel("p1"), _make_panel("p2"), _make_panel("p3")])
	player.play("intro", panels)
	player.advance()
	assert_signal_emitted_with_parameters(player, "panel_advanced", ["p2"])
	assert_eq(player.get_current_panel().id, "p2")


func test_advance_at_last_panel_finishes() -> void:
	watch_signals(player)
	var panels := _typed_panels([_make_panel("p1")])
	player.play("intro", panels)
	player.advance()
	assert_signal_emitted_with_parameters(player, "cutscene_finished", ["intro"])
	assert_false(player.is_playing(), "player should not be playing after finish")


func test_skip_emits_both_skipped_and_finished() -> void:
	watch_signals(player)
	var panels := _typed_panels([
		_make_panel("p1", "lore_a"),
		_make_panel("p2", "lore_b"),
		_make_panel("p3", "lore_c"),
	])
	player.play("intro", panels)
	player.skip()
	assert_signal_emitted_with_parameters(player, "cutscene_skipped", ["intro"])
	assert_signal_emitted_with_parameters(player, "cutscene_finished", ["intro"])


func test_skip_unlocks_all_remaining_lore() -> void:
	var panels := _typed_panels([
		_make_panel("p1", "lore_a"),
		_make_panel("p2", "lore_b"),
		_make_panel("p3", "lore_c"),
	])
	player.play("intro", panels)
	player.skip()
	assert_true(codex.is_unlocked("lore_a"))
	assert_true(codex.is_unlocked("lore_b"))
	assert_true(codex.is_unlocked("lore_c"))


func test_first_panel_unlocks_lore_on_play() -> void:
	var panels := _typed_panels([_make_panel("p1", "lore_a"), _make_panel("p2", "lore_b")])
	player.play("intro", panels)
	assert_true(codex.is_unlocked("lore_a"), "first panel lore should unlock when shown")
	assert_false(codex.is_unlocked("lore_b"), "later panel lore should not unlock until reached")


func test_play_is_idempotent_replaces_current() -> void:
	watch_signals(player)
	player.play("a", _typed_panels([_make_panel("a1"), _make_panel("a2")]))
	player.play("b", _typed_panels([_make_panel("b1")]))
	# 第二次 play 应当也发出 cutscene_started("b")
	assert_signal_emit_count(player, "cutscene_started", 2)
	assert_eq(player.get_current_panel().id, "b1")


func test_skip_when_not_playing_is_noop() -> void:
	watch_signals(player)
	player.skip()
	assert_signal_emit_count(player, "cutscene_skipped", 0)
	assert_signal_emit_count(player, "cutscene_finished", 0)


func test_play_with_empty_panels_finishes_immediately() -> void:
	watch_signals(player)
	player.play("empty", _typed_panels([]))
	assert_signal_emitted(player, "cutscene_started")
	assert_signal_emitted(player, "cutscene_finished")
	assert_false(player.is_playing())


# ---- LoreCodexSystem ----

func test_lore_unlock_and_query() -> void:
	codex.unlock_lore("lore_x")
	assert_true(codex.is_unlocked("lore_x"))
	assert_false(codex.is_unlocked("lore_y"))


func test_lore_unlock_empty_id_ignored() -> void:
	codex.unlock_lore("")
	assert_eq(codex.get_all_unlocked().size(), 0)


func test_lore_unlock_emits_signal_once() -> void:
	watch_signals(codex)
	codex.unlock_lore("lore_a")
	codex.unlock_lore("lore_a")  # duplicate
	assert_signal_emit_count(codex, "lore_unlocked", 1)


func test_lore_get_all_unlocked() -> void:
	codex.unlock_lore("lore_1")
	codex.unlock_lore("lore_2")
	codex.unlock_lore("lore_3")
	var all: Array = codex.get_all_unlocked()
	assert_eq(all.size(), 3)
	assert_true("lore_1" in all)
	assert_true("lore_2" in all)
	assert_true("lore_3" in all)


func test_lore_persistence_round_trip() -> void:
	codex.unlock_lore("lore_persist")
	# 验证文件落盘
	assert_true(FileAccess.file_exists(TEST_LORE_PATH), "persist file should be written")
	# 用一个新的 system 实例从同一个路径读
	var codex2 = LoreCodexSystemScript.new()
	codex2.persist_path = TEST_LORE_PATH
	add_child_autofree(codex2)
	assert_true(codex2.is_unlocked("lore_persist"))


# ---- CutsceneLoader ----

func test_loader_missing_file_returns_empty() -> void:
	var panels := CutsceneLoader.load_panels_from_json("user://does_not_exist.json")
	assert_eq(panels.size(), 0)


func test_loader_reads_valid_json() -> void:
	var data := [
		{"id": "p1", "text": "first", "next_panel_id": "p2"},
		{"id": "p2", "text": "second"},
	]
	var f := FileAccess.open(TEST_JSON_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	var panels := CutsceneLoader.load_panels_from_json(TEST_JSON_PATH)
	assert_eq(panels.size(), 2)
	assert_eq(panels[0].id, "p1")
	assert_eq(panels[0].text, "first")
	assert_eq(panels[1].id, "p2")


func test_loader_from_array() -> void:
	var panels := CutsceneLoader.load_panels_from_array([
		{"id": "x1", "text": "hi"},
		{"id": "x2", "text": "bye"},
	])
	assert_eq(panels.size(), 2)
	assert_eq(panels[0].id, "x1")


# ---- 端到端：intro.json 实数据 + CutsceneScene 渲染 ----

const ENGLISH_INTRO_JSON := "res://src/content/english/data/lore/intro.json"
const CUTSCENE_SCENE_TSCN := "res://src/cutscene/cutscene_scene.tscn"


func test_english_intro_json_loads_non_empty_panels() -> void:
	# 回归：用户曾报告"剧情没有展示，就几个颜色页面和对话框，但是都是空白的"。
	# 即使 panels 加载成功，如果 panel.text 是空，渲染也会空白；本测试确保数据非空。
	var panels := CutsceneLoader.load_panels_from_json(ENGLISH_INTRO_JSON)
	assert_gt(panels.size(), 0, "intro.json should yield at least one panel")
	var first := panels[0]
	assert_ne(first.text, "", "first intro panel should have non-empty text")
	assert_eq(first.id, "intro_1")


func test_cutscene_scene_render_panel_sets_text_label() -> void:
	# 回归 bug：cutscene_scene.gd 之前用 $DialogueLayer/DialoguePanel/TextLabel
	# 但 .tscn 实际层级是 .../DialoguePanel/VBox/TextLabel，导致 text_label 为 null,
	# render_panel() 中 _run_typewriter() 因 null check 静默 no-op，对话框永远空白。
	var packed: PackedScene = load(CUTSCENE_SCENE_TSCN)
	assert_not_null(packed, "cutscene_scene.tscn must load")
	var scene = packed.instantiate()
	add_child_autofree(scene)
	# 等 _ready() 跑完，让 @onready 生效
	await get_tree().process_frame

	assert_not_null(scene.text_label, "text_label @onready must resolve to a node")
	assert_not_null(scene.speaker_name_label, "speaker_name_label @onready must resolve to a node")
	assert_not_null(scene.continue_indicator, "continue_indicator @onready must resolve to a node")

	var panel := _make_panel("intro_1", "", "你好世界")
	panel.text_speed = 0.0  # 立即显示，便于断言 visible_characters
	scene.render_panel(panel)
	# 等 tween 完成（text_speed=0 时 _on_typing_finished 同步触发）
	await get_tree().process_frame

	assert_eq(scene.text_label.text, "你好世界")
	assert_eq(scene.text_label.visible_characters, panel.text.length())


func test_cutscene_scene_render_panel_with_speaker() -> void:
	var packed: PackedScene = load(CUTSCENE_SCENE_TSCN)
	var scene = packed.instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame

	var panel := _make_panel("p_speaker", "", "对话内容")
	panel.text_speed = 0.0
	panel.speaker_name = "词语之师"
	scene.render_panel(panel)
	await get_tree().process_frame

	assert_eq(scene.speaker_name_label.text, "词语之师")
	assert_true(scene.speaker_name_label.visible)
	assert_eq(scene.text_label.text, "对话内容")
