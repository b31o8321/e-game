class_name SaveSystem extends Node

## Per-pack 存档系统
## 每个内容包独立一个 JSON 存档；切换学科不会丢失进度。
## 文件结构：
##   user://saves/active.cfg          # 当前激活的 pack_id
##   user://saves/<pack_id>.json      # 各学科独立存档
##
## 兼容旧调用：保留无参 save_game_state() / load_game_state() 及
## 老 save_path / save() / load_save() 接口，便于既有代码渐进迁移。

const SAVES_DIR: String = "user://saves"
const ACTIVE_CFG_PATH: String = "user://saves/active.cfg"
const LEGACY_SAVE_PATH: String = "user://save.json"
const DEFAULT_PACK_ID: String = "english_grade46"
const QUEUE_SAVE_DELAY: float = 1.0

## 存档版本号。
## v1 = v0.8 旧模型（hand/deck/discard + retained_card_ids）
## v2 = v1.0 静态卡库模型（enabled_library_card_ids，无 hand-retention）
const SAVE_VERSION_CURRENT: int = 2

## 默认解锁的楼层。0F 是教学层（字母厅），1F 是第一关；玩家从一开始就能进入这两层。
## 2F 仍然要打通 1F 的 Boss 才解锁。
const DEFAULT_UNLOCKED_FLOOR_IDS: Array[String] = ["0F", "1F"]

## 旧 API 兼容：直接读写指定路径（仅旧测试使用）
var save_path: String = "user://save.json"

var _active_pack_id: String = ""
var _queue_timer: Timer = null
var _pending_state: Dictionary = {}
var _has_pending: bool = false

# ---------------------------------------------------------------------------
# 生命周期
# ---------------------------------------------------------------------------

func _ready() -> void:
	# 启动时执行一次旧档迁移
	migrate_legacy()
	# 恢复上次激活的 pack（若存在）
	var loaded: String = _load_active_pack_id_from_disk()
	if loaded != "":
		_active_pack_id = loaded
	elif _active_pack_id == "":
		_active_pack_id = DEFAULT_PACK_ID

func _exit_tree() -> void:
	# 退出时若有挂起写入，立刻 flush
	if _has_pending:
		flush_save()

# ---------------------------------------------------------------------------
# Active pack 管理
# ---------------------------------------------------------------------------

func set_active_pack_id(pack_id: String) -> void:
	if pack_id == "":
		return
	_active_pack_id = pack_id
	_ensure_saves_dir()
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("meta", "active_pack_id", pack_id)
	cfg.save(ACTIVE_CFG_PATH)

func get_active_pack_id() -> String:
	if _active_pack_id == "":
		return DEFAULT_PACK_ID
	return _active_pack_id

func get_save_path() -> String:
	return SAVES_DIR + "/" + get_active_pack_id() + ".json"

func _load_active_pack_id_from_disk() -> String:
	if not FileAccess.file_exists(ACTIVE_CFG_PATH):
		return ""
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(ACTIVE_CFG_PATH)
	if err != OK:
		return ""
	return cfg.get_value("meta", "active_pack_id", "")

func _ensure_saves_dir() -> void:
	DirAccess.make_dir_recursive_absolute(SAVES_DIR)

# ---------------------------------------------------------------------------
# 核心读写
# ---------------------------------------------------------------------------

## 写入指定 state 到当前激活 pack 的存档；无参则从 GameState 收集
func save_game_state(state: Variant = null) -> void:
	var data: Dictionary = state if state is Dictionary else _collect_state_from_game_state()
	var path: String = get_save_path()
	_ensure_saves_dir()
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[SaveSystem] failed to open %s for write" % path)
		return
	f.store_string(JSON.stringify(data))
	f.close()

## 读取当前激活 pack 的存档；无文件返回 {}。
## 若 GameState autoload 存在，则同时把数据写回到 GameState（兼容旧调用）。
##
## 同时执行轻量级迁移：补齐缺失的 unlocked_floor_ids 默认（0F + 1F）。
## 对于在该字段引入前生成的旧存档，这能让 0F 在玩家重新进入游戏时也是解锁状态。
func load_game_state() -> Dictionary:
	var path: String = get_save_path()
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		return {}
	var data: Dictionary = parsed
	var changed: bool = false
	# v1 → v2：卡组结构迁移（current_deck → enabled_library_card_ids、清理 hand-retention 字段）
	var before_version: int = int(data.get("save_version", 1))
	data = _migrate_save(data)
	if int(data.get("save_version", 1)) != before_version:
		changed = true
	if _migrate_unlocked_floor_ids(data):
		changed = true
	if changed:
		# 迁移后立刻回写，使后续读取也能拿到补齐后的数据
		_write_state(data)
	_apply_state_to_game_state(data)
	return data


## v1 → v2 存档结构迁移。幂等：同一份 data 多次调用结果一致。
##
## 主要操作：
##   - current_deck → enabled_library_card_ids（旧字段保留，避免回滚时丢数据）
##   - 移除 retained_card_ids / hand_retain_max（新模型无 hand-retention）
##   - 写入 save_version = SAVE_VERSION_CURRENT
func _migrate_save(data: Dictionary) -> Dictionary:
	if data == null:
		return {}
	var version: int = int(data.get("save_version", 1))
	if version >= SAVE_VERSION_CURRENT:
		return data
	if version < 2:
		# 卡组字段重命名（旧字段保留以便回滚；新字段为准）
		if data.has("current_deck") and not data.has("enabled_library_card_ids"):
			var raw: Variant = data["current_deck"]
			if raw is Array:
				data["enabled_library_card_ids"] = raw
			else:
				data["enabled_library_card_ids"] = []
		# 旧 deck_templates 字段保留不动（pre_run_setup 仍按 templates[0] 读取）
		# 移除 hand-retention 相关字段
		data.erase("retained_card_ids")
		data.erase("hand_retain_max")
		data["save_version"] = SAVE_VERSION_CURRENT
	return data


## 老存档可能没有 unlocked_floor_ids 字段，或仅含 ["1F"]。
## 这里把默认条目补齐，但不删除玩家已有解锁。
## 返回 true 表示 data 被修改、需要回写。
func _migrate_unlocked_floor_ids(data: Dictionary) -> bool:
	var raw: Variant = data.get("unlocked_floor_ids", null)
	var changed: bool = false
	var existing: Array = []
	if raw is Array:
		existing = raw
	else:
		# 字段缺失或类型错：从默认起步
		changed = true
	for fid in DEFAULT_UNLOCKED_FLOOR_IDS:
		if not (fid in existing):
			existing.append(fid)
			changed = true
	if changed:
		data["unlocked_floor_ids"] = existing
	return changed

# ---------------------------------------------------------------------------
# Debounced save
# ---------------------------------------------------------------------------

## 短时间多次调用时只在末次后 1 秒内写入一次
func queue_save(state: Variant = null) -> void:
	if state is Dictionary:
		_pending_state = state
	else:
		_pending_state = _collect_state_from_game_state()
	_has_pending = true
	_ensure_queue_timer()
	_queue_timer.stop()
	_queue_timer.start(QUEUE_SAVE_DELAY)

## 立刻写入挂起的存档（如果存在）
func flush_save() -> void:
	if _queue_timer != null:
		_queue_timer.stop()
	if not _has_pending:
		return
	save_game_state(_pending_state)
	_pending_state = {}
	_has_pending = false

func _ensure_queue_timer() -> void:
	if _queue_timer != null:
		return
	_queue_timer = Timer.new()
	_queue_timer.one_shot = true
	_queue_timer.autostart = false
	add_child(_queue_timer)
	_queue_timer.timeout.connect(_on_queue_timer_timeout)

func _on_queue_timer_timeout() -> void:
	flush_save()

# ---------------------------------------------------------------------------
# 旧档迁移
# ---------------------------------------------------------------------------

## 检测 user://save.json，将其搬到 user://saves/<DEFAULT_PACK_ID>.json
## 然后删除旧文件。仅会执行一次（启动时）。
func migrate_legacy() -> void:
	if not FileAccess.file_exists(LEGACY_SAVE_PATH):
		return
	var src: FileAccess = FileAccess.open(LEGACY_SAVE_PATH, FileAccess.READ)
	if src == null:
		return
	var text: String = src.get_as_text()
	src.close()
	# 即便解析失败也保留原始字符串，避免覆盖丢失
	var parsed: Variant = JSON.parse_string(text)
	var data: Dictionary = parsed if parsed is Dictionary else {}
	var dest_path: String = SAVES_DIR + "/" + DEFAULT_PACK_ID + ".json"
	_ensure_saves_dir()
	# 已有目标文件时不覆盖（避免重复迁移把后续进度盖掉）
	if not FileAccess.file_exists(dest_path):
		var dst: FileAccess = FileAccess.open(dest_path, FileAccess.WRITE)
		if dst == null:
			push_error("[SaveSystem] migrate_legacy: cannot write %s" % dest_path)
			return
		dst.store_string(JSON.stringify(data))
		dst.close()
	DirAccess.remove_absolute(LEGACY_SAVE_PATH)

# ---------------------------------------------------------------------------
# 旧 API（保留以便单元测试与渐进迁移）
# ---------------------------------------------------------------------------

func save(data: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()

func load_save() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var f: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null or not (parsed is Dictionary):
		return {}
	return parsed

# ---------------------------------------------------------------------------
# GameState <-> Dict 转换（兼容现有调用）
# ---------------------------------------------------------------------------

func _collect_state_from_game_state() -> Dictionary:
	if typeof(GameState) == TYPE_NIL:
		return {}
	var data: Dictionary = {
		"player_hp": GameState.player_hp,
		"player_max_hp": GameState.player_max_hp,
		"knowledge_level": GameState.knowledge_level,
		"unlocked_knowledge_ids": GameState.unlocked_knowledge_ids,
		"completed_gate_ids": GameState.completed_gate_ids,
		"city_building_levels": GameState.city_building_levels,
		"inventory_resources": GameState.inventory_resources,
		"equipment_slots": GameState.equipment_slots,
		"player_grade": GameState.player_grade,
		"saved_at": Time.get_datetime_string_from_system(true),
	}
	return data

func _apply_state_to_game_state(data: Dictionary) -> void:
	if typeof(GameState) == TYPE_NIL or data.is_empty():
		return
	GameState.player_hp = int(data.get("player_hp", GameState.player_hp))
	GameState.player_max_hp = int(data.get("player_max_hp", GameState.player_max_hp))
	GameState.knowledge_level = int(data.get("knowledge_level", GameState.knowledge_level))
	# 类型化数组字段必须显式转换：JSON 解析出的是无类型 Array
	if data.has("unlocked_knowledge_ids"):
		var ids: Array[String] = []
		for v in data["unlocked_knowledge_ids"]:
			ids.append(str(v))
		GameState.unlocked_knowledge_ids = ids
	if data.has("completed_gate_ids"):
		var gates: Array[String] = []
		for v in data["completed_gate_ids"]:
			gates.append(str(v))
		GameState.completed_gate_ids = gates
	GameState.city_building_levels = data.get("city_building_levels", GameState.city_building_levels)
	GameState.inventory_resources = data.get("inventory_resources", GameState.inventory_resources)
	GameState.equipment_slots = data.get("equipment_slots", GameState.equipment_slots)
	GameState.player_grade = int(data.get("player_grade", GameState.player_grade))

# ---------------------------------------------------------------------------
# 知识城新增字段访问助手
# 这些 helper 直接读写当前激活 pack 的 JSON，不依赖 GameState
# ---------------------------------------------------------------------------

func _read_state() -> Dictionary:
	var path: String = get_save_path()
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}

func _write_state(data: Dictionary) -> void:
	var path: String = get_save_path()
	_ensure_saves_dir()
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()

# ----- 钱包：crystals & blueprints -----

func get_wallet() -> Dictionary:
	var state: Dictionary = _read_state()
	var wallet: Variant = state.get("wallet", {})
	if not (wallet is Dictionary):
		wallet = {}
	var w: Dictionary = wallet
	if not w.has("crystals"):
		w["crystals"] = 0
	if not w.has("blueprints"):
		w["blueprints"] = 0
	return w

func _set_wallet(wallet: Dictionary) -> void:
	var state: Dictionary = _read_state()
	state["wallet"] = wallet
	_write_state(state)

func add_crystals(amount: int) -> void:
	if amount == 0:
		return
	var w: Dictionary = get_wallet()
	w["crystals"] = int(w.get("crystals", 0)) + amount
	_set_wallet(w)

func spend_crystals(amount: int) -> bool:
	if amount <= 0:
		return true
	var w: Dictionary = get_wallet()
	var have: int = int(w.get("crystals", 0))
	if have < amount:
		return false
	w["crystals"] = have - amount
	_set_wallet(w)
	return true

func add_blueprints(amount: int) -> void:
	if amount == 0:
		return
	var w: Dictionary = get_wallet()
	w["blueprints"] = int(w.get("blueprints", 0)) + amount
	_set_wallet(w)

func spend_blueprints(amount: int) -> bool:
	if amount <= 0:
		return true
	var w: Dictionary = get_wallet()
	var have: int = int(w.get("blueprints", 0))
	if have < amount:
		return false
	w["blueprints"] = have - amount
	_set_wallet(w)
	return true

# ----- 卡牌解锁与图鉴 -----

func unlock_card(card_id: String) -> void:
	if card_id == "":
		return
	var state: Dictionary = _read_state()
	var arr: Array = state.get("unlocked_card_ids", [])
	if not (arr is Array):
		arr = []
	if card_id not in arr:
		arr.append(card_id)
		state["unlocked_card_ids"] = arr
		_write_state(state)

func is_card_unlocked(card_id: String) -> bool:
	var state: Dictionary = _read_state()
	var arr: Variant = state.get("unlocked_card_ids", [])
	return (arr is Array) and card_id in arr

func _append_to_codex(field: String, value: String) -> void:
	if value == "":
		return
	var state: Dictionary = _read_state()
	var codex: Variant = state.get("codex", {})
	if not (codex is Dictionary):
		codex = {}
	var c: Dictionary = codex
	var arr: Variant = c.get(field, [])
	if not (arr is Array):
		arr = []
	var list: Array = arr
	if value not in list:
		list.append(value)
		c[field] = list
		state["codex"] = c
		_write_state(state)

func record_lore(lore_id: String) -> void:
	_append_to_codex("triggered_lore", lore_id)

func record_card_discovered(card_id: String) -> void:
	_append_to_codex("discovered_cards", card_id)

func record_enemy_defeated(enemy_id: String) -> void:
	_append_to_codex("defeated_enemies", enemy_id)

func record_boss_defeated(boss_id: String) -> void:
	_append_to_codex("defeated_bosses", boss_id)

func record_equipment_found(equipment_id: String) -> void:
	_append_to_codex("found_equipment", equipment_id)

# ----- 楼层进度 -----

func mark_floor_completed(floor_id: String) -> void:
	if floor_id == "":
		return
	var state: Dictionary = _read_state()
	var arr: Variant = state.get("completed_floor_ids", [])
	if not (arr is Array):
		arr = []
	var list: Array = arr
	if floor_id not in list:
		list.append(floor_id)
		state["completed_floor_ids"] = list
		_write_state(state)

func unlock_floor(floor_id: String) -> void:
	if floor_id == "":
		return
	var state: Dictionary = _read_state()
	var arr: Variant = state.get("unlocked_floor_ids", [])
	if not (arr is Array):
		arr = []
	var list: Array = arr
	if floor_id not in list:
		list.append(floor_id)
		state["unlocked_floor_ids"] = list
		_write_state(state)

func set_three_star(floor_id: String, stars: Array) -> void:
	if floor_id == "":
		return
	var state: Dictionary = _read_state()
	var prog: Variant = state.get("three_star_progress", {})
	if not (prog is Dictionary):
		prog = {}
	var p: Dictionary = prog
	p[floor_id] = stars
	state["three_star_progress"] = p
	_write_state(state)
