extends GutTest

const SAVES_DIR := "user://saves"
const ACTIVE_CFG := "user://saves/active.cfg"
const LEGACY_PATH := "user://save.json"

var save_sys: SaveSystem

func before_each() -> void:
	save_sys = SaveSystem.new()
	add_child_autofree(save_sys)
	# 设定一个隔离的测试 pack id，避免污染默认 english_grade46
	save_sys.set_active_pack_id("test_pack_a")

func after_each() -> void:
	# 清理测试痕迹
	_remove_if_exists(SAVES_DIR + "/test_pack_a.json")
	_remove_if_exists(SAVES_DIR + "/test_pack_b.json")
	_remove_if_exists(SAVES_DIR + "/english_grade46.json")
	_remove_if_exists(LEGACY_PATH)
	_remove_if_exists("user://test_save.json")
	_remove_if_exists(ACTIVE_CFG)

func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

# ---------------------------------------------------------------------------
# 旧 API 向后兼容
# ---------------------------------------------------------------------------

func test_legacy_save_and_load_roundtrip():
	save_sys.save_path = "user://test_save.json"
	var data: Dictionary = { "player_hp": 80, "combo": 5, "unlocked": ["past_tense"] }
	save_sys.save(data)
	var loaded: Dictionary = save_sys.load_save()
	assert_eq(loaded["player_hp"], 80)
	assert_eq(loaded["unlocked"][0], "past_tense")

func test_legacy_load_returns_empty_when_no_file():
	save_sys.save_path = "user://test_save.json"
	_remove_if_exists("user://test_save.json")
	var loaded: Dictionary = save_sys.load_save()
	assert_eq(loaded, {})

# ---------------------------------------------------------------------------
# 核心：per-pack 路径
# ---------------------------------------------------------------------------

func test_get_save_path_for_active_pack():
	save_sys.set_active_pack_id("test_pack_a")
	assert_eq(save_sys.get_save_path(), "user://saves/test_pack_a.json")
	save_sys.set_active_pack_id("test_pack_b")
	assert_eq(save_sys.get_save_path(), "user://saves/test_pack_b.json")

func test_get_active_pack_id_default_when_empty():
	var fresh: SaveSystem = SaveSystem.new()
	# 不 add_child 不触发 _ready，避免读取磁盘 active.cfg
	assert_eq(fresh.get_active_pack_id(), SaveSystem.DEFAULT_PACK_ID)
	fresh.free()

# ---------------------------------------------------------------------------
# save_game_state / load_game_state 往返
# ---------------------------------------------------------------------------

func test_save_game_state_then_load_returns_identical_dict():
	save_sys.set_active_pack_id("test_pack_a")
	var state: Dictionary = {
		"wallet": { "crystals": 50, "blueprints": 3 },
		"unlocked_card_ids": ["card_alpha", "card_beta"],
		"saved_at": "2026-05-04T00:00:00Z",
	}
	save_sys.save_game_state(state)
	var loaded: Dictionary = save_sys.load_game_state()
	assert_eq(loaded.get("unlocked_card_ids"), ["card_alpha", "card_beta"])
	assert_eq(int(loaded.get("wallet", {}).get("crystals", 0)), 50)
	assert_eq(int(loaded.get("wallet", {}).get("blueprints", 0)), 3)
	assert_eq(loaded.get("saved_at"), "2026-05-04T00:00:00Z")

func test_load_game_state_returns_empty_when_no_file():
	save_sys.set_active_pack_id("test_pack_a")
	_remove_if_exists("user://saves/test_pack_a.json")
	var loaded: Dictionary = save_sys.load_game_state()
	assert_eq(loaded, {})

# ---------------------------------------------------------------------------
# 隔离：不同 pack_id 写不同文件
# ---------------------------------------------------------------------------

func test_save_isolation_across_packs():
	save_sys.set_active_pack_id("test_pack_a")
	save_sys.save_game_state({ "owner": "english" })

	save_sys.set_active_pack_id("test_pack_b")
	save_sys.save_game_state({ "owner": "math" })

	# 切回 a，应该读到 english
	save_sys.set_active_pack_id("test_pack_a")
	var a: Dictionary = save_sys.load_game_state()
	assert_eq(a.get("owner"), "english")

	# 切到 b，应该读到 math
	save_sys.set_active_pack_id("test_pack_b")
	var b: Dictionary = save_sys.load_game_state()
	assert_eq(b.get("owner"), "math")

	# 文件物理隔离
	assert_true(FileAccess.file_exists("user://saves/test_pack_a.json"))
	assert_true(FileAccess.file_exists("user://saves/test_pack_b.json"))

# ---------------------------------------------------------------------------
# 旧档迁移
# ---------------------------------------------------------------------------

func test_migrate_legacy_moves_old_save_to_default_pack():
	# 准备：清掉目标，写一份旧档
	_remove_if_exists("user://saves/english_grade46.json")
	var legacy: Dictionary = { "player_hp": 42, "marker": "legacy_data" }
	var f: FileAccess = FileAccess.open(LEGACY_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(legacy))
	f.close()
	assert_true(FileAccess.file_exists(LEGACY_PATH))

	save_sys.migrate_legacy()

	# 旧文件应被清理
	assert_false(FileAccess.file_exists(LEGACY_PATH), "legacy save.json should be deleted")
	# 新文件应包含原数据
	assert_true(FileAccess.file_exists("user://saves/english_grade46.json"))
	var migrated: FileAccess = FileAccess.open("user://saves/english_grade46.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(migrated.get_as_text())
	migrated.close()
	assert_true(parsed is Dictionary)
	assert_eq(int(parsed.get("player_hp", 0)), 42)
	assert_eq(parsed.get("marker"), "legacy_data")

func test_migrate_legacy_noop_when_no_legacy_file():
	_remove_if_exists(LEGACY_PATH)
	_remove_if_exists("user://saves/english_grade46.json")
	# 不应抛错，也不应创建空文件
	save_sys.migrate_legacy()
	assert_false(FileAccess.file_exists("user://saves/english_grade46.json"))

# ---------------------------------------------------------------------------
# queue_save 防抖
# ---------------------------------------------------------------------------

func test_queue_save_debounces_within_one_second():
	save_sys.set_active_pack_id("test_pack_a")
	_remove_if_exists("user://saves/test_pack_a.json")

	# 连续三次入队，最后一次的 state 才是预期落盘内容
	save_sys.queue_save({ "v": 1 })
	save_sys.queue_save({ "v": 2 })
	save_sys.queue_save({ "v": 3 })

	# 立即检查：debounce 期间不应已经写入
	assert_false(FileAccess.file_exists("user://saves/test_pack_a.json"),
		"queue_save should not write immediately")

	# flush 强制落盘
	save_sys.flush_save()
	assert_true(FileAccess.file_exists("user://saves/test_pack_a.json"))
	var loaded: Dictionary = save_sys.load_game_state()
	assert_eq(int(loaded.get("v", 0)), 3, "last queued state should win")

func test_flush_save_no_pending_is_noop():
	save_sys.set_active_pack_id("test_pack_a")
	_remove_if_exists("user://saves/test_pack_a.json")
	save_sys.flush_save()
	assert_false(FileAccess.file_exists("user://saves/test_pack_a.json"))

# ---------------------------------------------------------------------------
# Helpers: 钱包
# ---------------------------------------------------------------------------

func test_add_and_spend_crystals():
	save_sys.set_active_pack_id("test_pack_a")
	_remove_if_exists("user://saves/test_pack_a.json")
	save_sys.add_crystals(100)
	assert_eq(int(save_sys.get_wallet().get("crystals", 0)), 100)

	var ok: bool = save_sys.spend_crystals(30)
	assert_true(ok)
	assert_eq(int(save_sys.get_wallet().get("crystals", 0)), 70)

	var fail: bool = save_sys.spend_crystals(999)
	assert_false(fail)
	assert_eq(int(save_sys.get_wallet().get("crystals", 0)), 70, "balance unchanged on insufficient")

func test_add_and_spend_blueprints():
	save_sys.set_active_pack_id("test_pack_a")
	_remove_if_exists("user://saves/test_pack_a.json")
	save_sys.add_blueprints(5)
	assert_eq(int(save_sys.get_wallet().get("blueprints", 0)), 5)
	assert_true(save_sys.spend_blueprints(2))
	assert_eq(int(save_sys.get_wallet().get("blueprints", 0)), 3)
	assert_false(save_sys.spend_blueprints(10))

# ---------------------------------------------------------------------------
# Helpers: 卡牌 / 图鉴
# ---------------------------------------------------------------------------

func test_unlock_card_dedupes():
	save_sys.set_active_pack_id("test_pack_a")
	_remove_if_exists("user://saves/test_pack_a.json")
	save_sys.unlock_card("card_x")
	save_sys.unlock_card("card_x")
	save_sys.unlock_card("card_y")
	assert_true(save_sys.is_card_unlocked("card_x"))
	assert_true(save_sys.is_card_unlocked("card_y"))
	var state: Dictionary = save_sys.load_game_state()
	var arr: Array = state.get("unlocked_card_ids", [])
	assert_eq(arr.size(), 2)

func test_record_lore_into_codex():
	save_sys.set_active_pack_id("test_pack_a")
	_remove_if_exists("user://saves/test_pack_a.json")
	save_sys.record_lore("lore_intro")
	save_sys.record_lore("lore_intro")  # dedupe
	save_sys.record_enemy_defeated("fog_whisperer")
	var state: Dictionary = save_sys.load_game_state()
	var codex: Dictionary = state.get("codex", {})
	assert_eq(codex.get("triggered_lore", []), ["lore_intro"])
	assert_eq(codex.get("defeated_enemies", []), ["fog_whisperer"])
