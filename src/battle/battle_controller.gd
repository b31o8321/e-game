## BattleController — 卡片对话战斗主控（多题棋盘改造版）
##
## 状态机：IDLE → PLAYER_TURN → CARD_VALIDATION → RESOLUTION → ENEMY_TURN → END
## 详见 docs/superpowers/specs/2026-05-04-battle-system-redesign.md
##
## ── 多题棋盘（2026-05-04 重构）──────────────────────────────────────
## 之前每回合只显示 1 道题，玩家无脑解；现在棋盘同时显示 BOARD_SIZE 道题，
## 每道题有不同 effect_type（伤害/回血/护盾/抽牌/加题/弱点强击/连击翻倍），
## 玩家根据当前血量、手牌、连击状态选解哪道——这是策略点。
##
## 棋盘状态：
##   available_challenges: Array[ChallengeTemplate]   // 当前可见的 BOARD_SIZE 道题
##   available_filled_slots: Array[Array]              // 每道题的填槽状态
##   selected_challenge_index: int                     // 当前正在填的那道题（-1 = 未选）
##   kept_indices: Array[int]                          // 玩家"留下"的题的 index（回合末不刷掉）
##
## 解题流程（B4 杀戮尖塔式：每回合 3 题，全部可解）：
##   1) 玩家点击棋盘上某道题 → set_selected_challenge_index(i)
##   2) 玩家点手牌 → 选中卡 → 点空槽 → try_place_card(card, slot_idx) 放入"已选中题"的槽
##   3) 全部填满 → submit_challenge() 结算 → 该道题被移除（解了的就消失）
##   4) 不再回合内自动补题；如果玩家解光了 3 道题就只能过牌（或留下 kept 题继续填）
##
## 回合末（end_player_turn）：
##   - 弃手牌 + 退槽
##   - kept_indices 标记的题保留；其它全部清掉
##   - 敌人攻击；伤害先抵护盾再扣 HP
##   - refill_board() 把空位补满（含 _queued_for_next_turn 加成）
##
## 兼容性：current_template + filled_slots 仍存在，作为 selected 题的"代理视图"。
## 旧测试（test_battle_controller_flow.gd 等）通过 try_place_card(card, slot_index) +
## current_template 继续工作，相当于在 BOARD_SIZE >= 1 的棋盘上自动选 0 号题。
class_name BattleController extends Node


enum State { IDLE, PLAYER_TURN, CARD_VALIDATION, RESOLUTION, ENEMY_TURN, END }

const APConnection = preload("res://src/battle/ap_connection.gd")

## 默认棋盘可见题数。可以由 setup() 通过 board_size 参数覆盖。
const DEFAULT_BOARD_SIZE: int = 3
## 玩家最多"留下"几道题（待技能 / 物品修改）。
const QUESTION_KEEP_MAX_DEFAULT: int = 1

# === 战斗参数 ===
var state: State = State.IDLE
var enemy_hp: int = 0
var enemy_max_hp: int = 0
var player_hp: int = 100
var player_max_hp: int = 100
## 临时护盾（shield 效果累加），敌人攻击时先扣这里再扣 HP
var player_shield: int = 0
## 敌人临时护盾（来自 EntityAbility "shield" 效果，玩家攻击时先扣这里再扣敌人 HP）。
var enemy_shield: int = 0

# === 卡库 ===
## 静态卡牌库——本场战斗玩家可用的所有卡。不消耗、不弃、不抽。
## （旧设计是 hand/deck/discard 循环；2026-05-08 改造为静态库。）
var card_library: Array[Card] = []

## 兼容代理：旧代码（UI / 测试）读 `controller.hand` 仍能拿到当前可见的卡集合。
## 静态库改造后：hand ≡ card_library，无独立 hand 概念。
## 写入会被转发到 card_library 替换（仅限测试便利路径；生产代码请用 card_library）。
var hand: Array[Card]:
	get:
		return card_library
	set(value):
		card_library.clear()
		for c in value:
			card_library.append(c)

# === 多题棋盘 ===
## 当前棋盘大小（一回合可见多少道题）
var board_size: int = DEFAULT_BOARD_SIZE
## 棋盘可见题（长度可在回合内 < board_size，回合末 refill 补满）
var available_challenges: Array[ChallengeTemplate] = []
## 每道题的填槽：available_filled_slots[i][slot_index] = Card | null
var available_filled_slots: Array = []
## 玩家"留下"的题的 template_id 集合（回合末刷棋盘时不丢）
var kept_template_ids: Array[String] = []
## "留下"题数上限。可被技能 / 装备覆盖。
var question_keep_max: int = QUESTION_KEEP_MAX_DEFAULT
## 已失败的题 index（一锤定音机制：放错卡 → 整题失败）。回合末 refill 时清空。
var _failed_challenge_indices: Array[int] = []
## 当前正在填的题 index（-1 = 未选）
var selected_challenge_index: int = -1
## 下次结算的伤害修饰符（"next_x2" 表示下题打 2 倍）
var pending_damage_modifier: String = ""
## 卡牌能力 draw_question 累积——下回合 refill 时额外加 N 道题进棋盘
var _queued_for_next_turn: int = 0

# === AP 队列（2026-05-07 重构 Phase 3）===
## 玩家本回合的连线队列，每条 = APConnection（卡 + 题 + 槽 + 预览）。
## Task 11 会把 submit_challenge 改为遍历此队列；目前与单题 try_place_card 路径并存。
var ap_queue: Array = []
## AP 队列容量上限。默认 3，可由技能 / 装备调整。
var ap_max: int = 3
## 完美连击给下回合的临时容量奖励（结算后清零）。
var ap_bonus_next_turn: int = 0

# === 实体能力（敌人 / 玩家共享）===
## 敌人能力实例（从 enemy.ability_ids 通过 AbilitiesRegistry 实例化）
var _enemy_abilities: Array[EntityAbility] = []
## 玩家能力实例（hook 用——后续装备 / 技能填充）
var _player_abilities: Array[EntityAbility] = []
## 敌人本回合额外行动次数（multi_action 能力累积）
var _pending_enemy_extra_actions: int = 0

# === 兼容代理 (旧 API: current_template / filled_slots 现在指向 selected 题) ===
var current_template: ChallengeTemplate:
	get:
		if selected_challenge_index < 0 or selected_challenge_index >= available_challenges.size():
			return null
		return available_challenges[selected_challenge_index]
	set(value):
		# 旧测试可能直接赋值 null —— 找到对应位置移除
		if value == null and selected_challenge_index >= 0:
			# 兼容：调用方期望"清空当前题"——保持 selected_challenge_index 不变，
			# 调用方通常紧接着会调 _advance_to_next_challenge()。
			pass
var filled_slots: Array:
	get:
		if selected_challenge_index < 0 or selected_challenge_index >= available_filled_slots.size():
			return []
		return available_filled_slots[selected_challenge_index]
	set(value):
		# 旧测试 / 内部代码可能直接赋值；忽略——通过专用 API 维护
		pass

# === 回合内统计（爽快感机制）===
var cards_played_this_turn: int = 0
var challenges_solved_this_turn: int = 0
const DRAW_PER_N_CARDS: int = 2

## 本回合已触发过能力的卡 id 列表（T2: card-library redesign）。
## 卡放入 AP 队列 + submit_all_ap 结算后，其 id 加入此列表；
## CardAbilities.apply_pre_submit 跳过 id 在此列表的卡，避免无限触发。
## 在 setup / start_battle / end_player_turn 清空。
var _used_ability_card_ids_this_turn: Array[String] = []

# === 内部依赖 ===
var _enemy: EnemyData
var _pack: ContentPackBase
var _selector: ChallengeSelector
var _combo: ComboSystem
var _srs: SRSSystem
## 本场战斗已抽过的题模板 id，用于避免重复（池足够大时）
var _seen_template_ids: Array[String] = []
var _used_card_ids_this_battle: Array[String] = []

# === 战斗日志（B6: 玩家可回顾近 30 条行动）===
## 每条字符串可含 BBCode 标签，UI 用 RichTextLabel 渲染。
## 超过 LOG_MAX_ENTRIES 时从头丢弃。
const LOG_MAX_ENTRIES: int = 30
var battle_log: Array[String] = []

# === 信号 ===
signal battle_started()
signal card_played(card: Card, slot_index: int)
signal card_returned(card: Card, slot_index: int)
signal damage_dealt(amount: int, is_crit: bool, is_weakness: bool)
signal damage_received(amount: int)
## 旧信号：单道题切换时发；多题改造后只在"selected 题切换"时发。
signal challenge_advanced(template: ChallengeTemplate)
## 棋盘整体变化（题被移除 / 加入 / kept 状态变 / selected 变化）。UI 通过此重渲染棋盘。
signal board_changed()
## 卡库内容变化（卡的可用 / 已用状态、库内卡集合改变）。
## 旧名 hand_changed 保留，避免破坏现有 UI 监听器；payload 现在是 card_library。
signal hand_changed(library: Array)
signal turn_ended(was_player_turn: bool)
signal battle_ended(victory: bool)
signal new_cards_unlocked(card_ids: Array)
signal cards_drawn(count: int)
signal turn_combo_advanced(challenges_solved: int)
## 玩家被回血了
signal healed(amount: int)
## 玩家加了护盾
signal shielded(amount: int)
## 敌人加了护盾（敌人能力 shield 效果触发）
signal enemy_shielded(amount: int)
## 敌人回血了（敌人能力 heal 效果触发）
signal enemy_healed(amount: int)
## 敌人能力被触发（icon + 描述），UI 可弹气泡 / 高亮
signal enemy_ability_triggered(icon: String, description_zh: String)
## 棋盘被加了题（draw_question 效果）
signal questions_added(count: int)
## 下一题伤害将翻倍（combo_boost 触发后）
signal combo_boost_armed()
## 玩家放错卡 → 整道题失败。UI 收到此信号弹出"答错反馈"模态。
##   challenge_index：失败的那道题在 available_challenges 中的 index
##   correct_card_id：perfect_match_card_ids[0]（如有），用于在模态里展示正确答案
signal challenge_failed(challenge_index: int, correct_card_id: String)
## B6 战斗日志：每次 _log() 调用后发，UI 可增量追加到滚动面板。
signal log_appended(message: String)


# ═══════════════════════════════════════════════════════════════════
# 战斗日志
# ═══════════════════════════════════════════════════════════════════

## 追加一条战斗日志。message 可包含 BBCode（[color=...]、[b]）以让 RichTextLabel 高亮。
## 超过 LOG_MAX_ENTRIES 自动丢最早一条。
func _log(message: String) -> void:
	if message.is_empty():
		return
	battle_log.append(message)
	while battle_log.size() > LOG_MAX_ENTRIES:
		battle_log.pop_front()
	log_appended.emit(message)


## 把卡的人类可读名拼起来（用于"用 brave + happy 解决了..."）。
func _format_cards_for_log(cards: Array) -> String:
	var names: Array[String] = []
	for c in cards:
		if c is Card:
			names.append(str(c.text) if c.text != "" else c.id)
	if names.is_empty():
		return "（无卡）"
	return " + ".join(names)


## 取一段对话用于日志（取前 28 字 ＋ ...）。
func _short_dialogue(tmpl: ChallengeTemplate) -> String:
	if tmpl == null:
		return "?"
	var d: String = tmpl.dialogue
	if d.length() > 28:
		return d.substr(0, 28) + "…"
	return d


# ═══════════════════════════════════════════════════════════════════
# 公共 API
# ═══════════════════════════════════════════════════════════════════

func setup(
		enemy: EnemyData,
		pack: ContentPackBase,
		library: Array[Card],
		srs: SRSSystem = null,
		board_size_override: int = -1) -> void:
	_enemy = enemy
	_pack = pack
	_srs = srs
	enemy_max_hp = enemy.max_hp
	enemy_hp = enemy.max_hp
	if Engine.has_singleton("GameState") or _has_game_state():
		player_max_hp = GameState.player_max_hp
		player_hp = GameState.player_hp
	player_shield = 0
	enemy_shield = 0
	_pending_enemy_extra_actions = 0
	# 重置 / 实例化敌人能力
	_enemy_abilities.clear()
	if enemy != null and not enemy.ability_ids.is_empty():
		var raw_ids: Array = []
		for v in enemy.ability_ids:
			raw_ids.append(v)
		_enemy_abilities = AbilitiesRegistry.make_many(raw_ids)
	# 玩家能力 hook：当前留空，后续装备 / 技能填充
	_player_abilities.clear()
	card_library.clear()
	for c in library:
		card_library.append(c)
	available_challenges.clear()
	available_filled_slots.clear()
	kept_template_ids.clear()
	question_keep_max = QUESTION_KEEP_MAX_DEFAULT
	_failed_challenge_indices.clear()
	selected_challenge_index = -1
	pending_damage_modifier = ""
	_queued_for_next_turn = 0
	_seen_template_ids.clear()
	_used_card_ids_this_battle.clear()
	_used_ability_card_ids_this_turn.clear()
	battle_log.clear()
	cards_played_this_turn = 0
	challenges_solved_this_turn = 0
	if board_size_override > 0:
		board_size = board_size_override
	else:
		board_size = DEFAULT_BOARD_SIZE
	if _selector == null:
		_selector = ChallengeSelector.new()
	if _combo == null:
		_combo = ComboSystem.new()
	_apply_boss_topic_coverage()
	state = State.IDLE


## Alias for clarity in new code (T1 of card-library redesign).
func setup_with_library(
		enemy: EnemyData,
		pack: ContentPackBase,
		library: Array[Card],
		srs: SRSSystem = null,
		board_size_override: int = -1) -> void:
	setup(enemy, pack, library, srs, board_size_override)


func _apply_boss_topic_coverage() -> void:
	if _enemy == null or _pack == null or _selector == null:
		return
	var boss_id: String = _enemy.enemy_id
	if boss_id.ends_with("_boss"):
		boss_id = boss_id.substr(0, boss_id.length() - len("_boss"))
	var boss: BossBase = _pack.get_boss(boss_id)
	if boss == null:
		return
	if boss.requires_topic_coverage.is_empty():
		return
	_selector.set_required_coverage(boss.requires_topic_coverage)


func set_selector(selector: ChallengeSelector) -> void:
	_selector = selector

func set_combo_system(combo: ComboSystem) -> void:
	_combo = combo


## 启动战斗：填满棋盘，发出库内容信号。
## 卡库是静态的（T1：旧版的洗牌 / 发牌 5 张已移除）。
func start_battle() -> void:
	if state != State.IDLE:
		return
	_used_ability_card_ids_this_turn.clear()
	refill_board()
	# 默认选中第 0 道题（玩家可手动切）
	if not available_challenges.is_empty():
		selected_challenge_index = 0
	state = State.PLAYER_TURN
	battle_started.emit()
	hand_changed.emit(card_library.duplicate())
	board_changed.emit()
	if selected_challenge_index >= 0:
		challenge_advanced.emit(current_template)
	# B6 日志
	var enemy_name: String = (_enemy.enemy_name if _enemy != null and _enemy.enemy_name != "" else "?")
	_log("[color=#ffd86b]进入战斗：%s[/color]" % enemy_name)


## 选中棋盘上的某道题（之后的 try_place_card 都填到这里）。
func set_selected_challenge_index(index: int) -> void:
	if index < 0 or index >= available_challenges.size():
		return
	# 失败的题不能被选中作答
	if index in _failed_challenge_indices:
		return
	if selected_challenge_index == index:
		return
	selected_challenge_index = index
	board_changed.emit()
	challenge_advanced.emit(current_template)


## 把一张卡放进【当前 selected 题】的指定槽。返回 true 表示放置成功。
##
## 重载形式：
##   try_place_card(card, slot_index)                 → 放入 selected 题
##   try_place_card(card, slot_index, challenge_idx)  → 放入指定题（同时切换 selected）
##
## 一锤定音（2026-05-04 教育反馈改造）：
##   放进的卡如果不通过 CardValidator → 整道题立即失败：
##     - 标记 challenge index 为 failed
##     - 不应用任何效果（无伤害 / 无回血 / 无加题）
##     - combo 重置
##     - 发 challenge_failed 信号给 UI 弹"正确答案 + 中文释义"模态
func try_place_card(card: Card, slot_index: int, challenge_index: int = -1) -> bool:
	if state != State.PLAYER_TURN and state != State.CARD_VALIDATION:
		return false
	if card == null:
		return false
	if challenge_index >= 0:
		if challenge_index >= available_challenges.size():
			return false
		selected_challenge_index = challenge_index
	if selected_challenge_index < 0 or selected_challenge_index >= available_challenges.size():
		return false
	# 已失败的题不能再操作
	if selected_challenge_index in _failed_challenge_indices:
		return false
	var tmpl: ChallengeTemplate = available_challenges[selected_challenge_index]
	if tmpl == null:
		return false
	if slot_index < 0 or slot_index >= tmpl.slots.size():
		return false
	if not (card in card_library):
		return false
	var slots: Array = available_filled_slots[selected_challenge_index]
	if slots[slot_index] != null:
		return false
	state = State.CARD_VALIDATION
	var slot: ChallengeSlot = tmpl.slots[slot_index]
	var ok: bool = CardValidator.can_place(card, slot)
	if _srs != null and card.id != "":
		_srs.record_answer(card.id, ok)
	if not ok:
		# 一锤定音：放错 → 整题失败
		_combo.reset()
		_mark_challenge_failed(selected_challenge_index, tmpl)
		state = State.PLAYER_TURN
		return false
	# 静态卡库：不再从库中移除卡——卡只是被放入题槽。
	slots[slot_index] = card
	if not (card.id in _used_card_ids_this_battle):
		_used_card_ids_this_battle.append(card.id)
	cards_played_this_turn += 1
	card_played.emit(card, slot_index)
	hand_changed.emit(card_library.duplicate())
	if _all_slots_filled_for(selected_challenge_index):
		submit_challenge()
	else:
		state = State.PLAYER_TURN
	return true


## 该 index 的题是否已经失败（玩家放错过卡）。
func is_failed(challenge_index: int) -> bool:
	return challenge_index in _failed_challenge_indices


## 若棋盘上所有题都已失败 —— UI 可据此提示玩家"过牌"。
func has_solvable_challenges() -> bool:
	if available_challenges.is_empty():
		return false
	for i in available_challenges.size():
		if not (i in _failed_challenge_indices):
			return true
	return false


## 标记一道题为失败：清空该题槽位（卡仍留在 card_library），发信号给 UI。
func _mark_challenge_failed(idx: int, tmpl: ChallengeTemplate) -> void:
	if idx < 0 or idx >= available_challenges.size():
		return
	if idx in _failed_challenge_indices:
		return
	# 静态卡库：失败题里残留的已放卡不入弃牌堆；卡一直留在库里。仅清空槽。
	if idx < available_filled_slots.size():
		var slots: Array = available_filled_slots[idx]
		for j in slots.size():
			slots[j] = null
	_failed_challenge_indices.append(idx)
	# 失败题不再保留为"留下"
	if tmpl != null and tmpl.template_id in kept_template_ids:
		kept_template_ids.erase(tmpl.template_id)
	var correct_card_id: String = ""
	if tmpl != null and not tmpl.perfect_match_card_ids.is_empty():
		correct_card_id = tmpl.perfect_match_card_ids[0]
	# B6 日志：错答记录正确答案，便于回顾
	var correct_disp: String = correct_card_id if correct_card_id != "" else "?"
	_log("[color=#ff7777]你: 答错 [%s] 正确答案: %s[/color]" % [
		_short_dialogue(tmpl), correct_disp])
	board_changed.emit()
	challenge_failed.emit(idx, correct_card_id)


## 撤回 selected 题的某槽中已放的卡（卡一直在 card_library 中，仅清槽）。
func remove_card_from_slot(slot_index: int) -> void:
	if state != State.PLAYER_TURN and state != State.CARD_VALIDATION:
		return
	if selected_challenge_index < 0 or selected_challenge_index >= available_challenges.size():
		return
	var slots: Array = available_filled_slots[selected_challenge_index]
	if slot_index < 0 or slot_index >= slots.size():
		return
	var card = slots[slot_index]
	if card == null:
		return
	slots[slot_index] = null
	card_returned.emit(card, slot_index)
	hand_changed.emit(card_library.duplicate())


## 切换"留下"该题（回合末不会刷掉）。返回切换后的状态（true = 已留）。
##
## 受 question_keep_max 限制：达到上限时再点新题会被静默拒绝（返回 false）。
## 已留下的题取消保留不受上限限制。
func toggle_keep(challenge_index: int) -> bool:
	if challenge_index < 0 or challenge_index >= available_challenges.size():
		return false
	# 失败的题不能留下
	if challenge_index in _failed_challenge_indices:
		return false
	var tmpl: ChallengeTemplate = available_challenges[challenge_index]
	if tmpl == null or tmpl.template_id == "":
		return false
	var tid: String = tmpl.template_id
	if tid in kept_template_ids:
		kept_template_ids.erase(tid)
		board_changed.emit()
		return false
	# 超过上限——静默拒绝（UI 应据此显示提示）
	if kept_template_ids.size() >= question_keep_max:
		return false
	kept_template_ids.append(tid)
	board_changed.emit()
	return true


## 当前 challenge_index 是否处于"留下"状态。
func is_kept(challenge_index: int) -> bool:
	if challenge_index < 0 or challenge_index >= available_challenges.size():
		return false
	var tmpl: ChallengeTemplate = available_challenges[challenge_index]
	if tmpl == null or tmpl.template_id == "":
		return false
	return tmpl.template_id in kept_template_ids


## 当前已"留下"的题数量。
func get_kept_count() -> int:
	return kept_template_ids.size()


# ═══════════════════════════════════════════════════════════════════
# AP 队列（Phase 3）
# ═══════════════════════════════════════════════════════════════════

## 把一张卡库中的卡追加到 AP 队列尾部，绑定到 challenge_index 的 slot_index 槽。
## 返回 true 表示加入成功；满（>= ap_max + ap_bonus_next_turn）或卡不在库中返回 false。
##
## 静态卡库（T1）：卡 NOT 从 card_library 移除——库内卡始终可见；
## UI 可读 ap_queue 来判断"已入队/已用"状态以渲染禁用样式。
func add_to_ap_queue(card: Card, challenge_index: int, slot_index: int) -> bool:
	if ap_queue.size() >= ap_max + ap_bonus_next_turn:
		return false
	if not (card in card_library):
		return false
	var conn := APConnection.new()
	conn.slot_index = ap_queue.size()
	conn.card = card
	conn.challenge_index = challenge_index
	conn.question_slot_index = slot_index
	conn.preview = _compute_preview(card, challenge_index, slot_index)
	ap_queue.append(conn)
	if has_signal("hand_changed"):
		hand_changed.emit(card_library.duplicate())
	if has_signal("board_changed"):
		board_changed.emit()
	return true


## 把指定 slot_index 的连线移出 AP 队列；卡本来就一直在卡库里。其它连线 slot_index 重新编号。
func remove_from_ap_queue(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= ap_queue.size():
		return false
	ap_queue.remove_at(slot_index)
	# 重新编号
	for i in ap_queue.size():
		ap_queue[i].slot_index = i
	if has_signal("hand_changed"):
		hand_changed.emit(card_library.duplicate())
	if has_signal("board_changed"):
		board_changed.emit()
	return true


## 调整 AP 队列内连线顺序：把 from_idx 的连线移到 to_idx 位置，重新编号。
func reorder_ap_queue(from_idx: int, to_idx: int) -> bool:
	if from_idx < 0 or from_idx >= ap_queue.size():
		return false
	if to_idx < 0 or to_idx >= ap_queue.size():
		return false
	var conn = ap_queue[from_idx]
	ap_queue.remove_at(from_idx)
	ap_queue.insert(to_idx, conn)
	for i in ap_queue.size():
		ap_queue[i].slot_index = i
	if has_signal("board_changed"):
		board_changed.emit()
	return true


## 在新回合开始时调用：清掉上回合留下的 ap_bonus_next_turn。
##
## 说明：完美连击的奖励语义是"作用于紧接的下一回合"。submit_all_ap 在回合末
## 把 bonus 写为 1（perfect）或 0（imperfect）。下一回合 add_to_ap_queue 用
## ap_max + ap_bonus_next_turn 作为容量上限，所以 bonus 自然在下一回合生效。
##
## 当下一回合的 submit_all_ap 再次执行时它会覆写 bonus，因此理论上不需要显式
## 重置。但 UI 在 turn_start 调一次本方法可以保证：即使玩家整回合不提交
## （例如全部从 AP 队列撤回），bonus 也不会跨多个回合"残留"——只生效一次。
##
## UI 应在新回合 _on_turn_start 时调用此方法。
func consume_ap_bonus_for_turn() -> void:
	ap_bonus_next_turn = 0


## 按 AP 顺序逐条结算所有连线。
## 每条连线独立验证：
##   - 对 → 填槽；若该题全填且全对，应用题效果；卡入弃牌堆
##   - 错 → _mark_challenge_failed（弹答错模态信号）；卡入弃牌堆
## 全对（且队列非空）→ 完美连击 → ap_bonus_next_turn = 1
## 否则（队列非空但有错）→ ap_bonus_next_turn = 0
## 队列为空时直接返回，不动 bonus。
## 注：end_player_turn 由 UI 触发；submit_all_ap 只负责结算。
func submit_all_ap() -> void:
	if ap_queue.is_empty():
		return
	var ordered: Array = ap_queue.duplicate()
	ordered.sort_custom(func(a, b): return a.slot_index < b.slot_index)
	var perfect: bool = true
	for conn in ordered:
		var ok: bool = _resolve_connection(conn)
		if not ok:
			perfect = false
		# T2：标记本卡能力本回合已触发（同卡同回合再放仍可造成伤害，但能力不再加成）
		if conn != null and conn.card != null and conn.card.id != "":
			mark_card_ability_used(conn.card.id)
	# 完美连击 → 下回合 +1 AP 容量
	if perfect:
		ap_bonus_next_turn = 1
	else:
		ap_bonus_next_turn = 0
	ap_queue.clear()
	if has_signal("hand_changed"):
		hand_changed.emit(card_library.duplicate())
	if has_signal("board_changed"):
		board_changed.emit()


## 单条连线结算。返回 true 表示对，false 表示错。
## 错连：标失败 + 弹模态信号（通过 _mark_challenge_failed），卡入弃牌堆。
## 对连：填到 available_filled_slots[ch_idx][slot_idx]，若该题全填且全对，应用效果。
##
## Task 24 修复：原实现直接用 conn.challenge_index 作为 available_challenges 的下标，
## 但 submit_challenge 会从 available_challenges 移除已解的题（remove_at(idx)），
## 导致后续连线 challenge_index 失效（指向错位 / 越界）。修复方案：用 conn.preview
## 中存的 template_id 作为稳定键，每次结算前在当前 available_challenges 里按 id 重查
## 实际下标。这样即使前面的连线把某道题解掉，后面的连线仍能找到自己的目标题（如果
## 还在棋盘上），或者 fail-safe（不在棋盘 = 已被解掉/移除 → 卡浪费）。
func _resolve_connection(conn: APConnection) -> bool:
	if conn == null or conn.card == null:
		return false
	# 用 template_id 重新定位棋盘上的目标题（避开 index-shift bug）
	var target_template_id: String = ""
	if conn.preview != null and conn.preview is Dictionary:
		target_template_id = str(conn.preview.get("template_id", ""))
	# Fallback：preview 不可用时退回到 challenge_index（兼容直接构造的连线）
	var ch_idx: int = -1
	if target_template_id != "":
		for i in available_challenges.size():
			var t: ChallengeTemplate = available_challenges[i]
			if t != null and t.template_id == target_template_id:
				ch_idx = i
				break
	else:
		ch_idx = conn.challenge_index
	if ch_idx < 0 or ch_idx >= available_challenges.size():
		# 题已不在棋盘（被前面的连线解掉或者非法 index）→ 卡未生效；
		# 静态卡库：卡仍在库里，不入弃牌堆。
		return false
	# 该题已失败：后续连线全部判错（卡仍留在库里）
	if ch_idx in _failed_challenge_indices:
		return false
	var template: ChallengeTemplate = available_challenges[ch_idx]
	if template == null:
		return false
	if conn.question_slot_index < 0 or conn.question_slot_index >= template.slots.size():
		return false
	var slot: ChallengeSlot = template.slots[conn.question_slot_index]
	# 校验卡是否能放进该槽
	if not CardValidator.can_place(conn.card, slot):
		# 错连：标整道题失败（弹模态信号）。卡留在库里。
		_mark_challenge_failed(ch_idx, template)
		return false
	# 对：填槽
	if ch_idx < available_filled_slots.size():
		var slots_state: Array = available_filled_slots[ch_idx]
		while slots_state.size() <= conn.question_slot_index:
			slots_state.append(null)
		# 槽里已有卡（前面的连线已填同槽）→ 视为浪费，但不算错。卡留在库里。
		if slots_state[conn.question_slot_index] != null:
			return true
		slots_state[conn.question_slot_index] = conn.card
	# SRS 记录（与 try_place_card 保持一致）
	if _srs != null and conn.card.id != "":
		_srs.record_answer(conn.card.id, true)
	# 检查是否全填且全对 → 走 submit_challenge 应用完整题效果
	if _all_slots_filled_for(ch_idx) and not (ch_idx in _failed_challenge_indices):
		# submit_challenge 会移除该题 + 修正失败索引。
		# 注意：submit_challenge 移除 ch_idx 后，available_challenges 索引会左移；
		# 后续连线在本函数开头通过 template_id 重查下标，因此不会受影响。
		submit_challenge(ch_idx)
	return true


## 计算 AP 槽内单条连线的伤害预览，供 UI 显示，不应用任何状态变更。
func _compute_preview(card: Card, ch_idx: int, slot_idx: int) -> Dictionary:
	if ch_idx < 0 or ch_idx >= available_challenges.size():
		return {}
	var ch = available_challenges[ch_idx]
	if ch == null:
		return {}
	var base: int = card.base_damage
	var template_id: String = ""
	if ch is ChallengeTemplate:
		template_id = ch.template_id
	return {
		"damage": base,
		"card_id": card.id,
		"template_id": template_id,
		"slot_index": slot_idx,
	}


## 给棋盘加一道题（draw_question 效果用）。返回是否成功。
func add_to_board(template: ChallengeTemplate) -> bool:
	if template == null:
		return false
	available_challenges.append(template)
	var slots: Array = []
	for _i in template.slots.size():
		slots.append(null)
	available_filled_slots.append(slots)
	if not (template.template_id in _seen_template_ids):
		_seen_template_ids.append(template.template_id)
	board_changed.emit()
	return true


## 刷新棋盘：保留 kept 的题；其它清掉；从池里抽新题填满到 board_size + 排队的加题。
##
## B4：如果上回合卡牌 draw_question 能力累积了 _queued_for_next_turn，下回合
## 多补 N 题（target = board_size + queued）。补完后清零。
##
## B5（手牌感知）：刷盘时只挑选"当前手牌可解"的题——避免卡手。
##
## Task 13（降级填充）：如果可解题池榨干仍补不满 target_size，走 fallback
## 直接从池里挑（不过滤），并把 is_warn = true，让 UI 可渲染 🟡 提示。
## 这避免了"题板有时候没有问题"的体验黑洞——空板永远比警告板差。
func refill_board() -> void:
	# 1. 留 kept 的题 + 它们的填槽（回合末玩家可能没填完）。失败的题永远不留。
	var new_chals: Array[ChallengeTemplate] = []
	var new_slots: Array = []
	for i in available_challenges.size():
		var tmpl: ChallengeTemplate = available_challenges[i]
		if i in _failed_challenge_indices:
			continue
		if tmpl != null and tmpl.template_id in kept_template_ids:
			# 保留下来的题——重新评估 is_warn（静态库基本不会变，但仍计算）
			tmpl.is_warn = not _can_solve_with_library(tmpl, card_library)
			new_chals.append(tmpl)
			# kept 题的填槽清空——玩家下回合重新填
			var fresh_slots: Array = []
			for _j in tmpl.slots.size():
				fresh_slots.append(null)
			new_slots.append(fresh_slots)
	available_challenges = new_chals
	available_filled_slots = new_slots
	# 失败标记是按 index 的——刷盘后旧 index 失效，全清
	_failed_challenge_indices.clear()
	# 2. 计算目标数量（board_size + 卡牌 draw_question 累计加题）
	var target_size: int = board_size + max(0, _queued_for_next_turn)
	_queued_for_next_turn = 0
	# 3. 抽新题填到 target_size。先尽量去重（dedup pass），失败则强制填到目标数量。
	#    B5：每次抽到的题都要 _can_solve_with_library(tmpl, card_library) — 否则跳过。
	var dedup_attempts: int = 0
	while available_challenges.size() < target_size and dedup_attempts < 30:
		dedup_attempts += 1
		var picked: ChallengeTemplate = _pick_next_template()
		if picked == null:
			break
		var dup: bool = false
		for c in available_challenges:
			if c != null and c.template_id == picked.template_id:
				dup = true
				break
		if dup:
			continue
		if not _can_solve_with_library(picked, card_library):
			continue
		picked.is_warn = false
		add_to_board(picked)
	# 兜底：dedup pass 没补够（小池子）—— 允许重复 template_id，但仍要可解。
	var force_attempts: int = 0
	while available_challenges.size() < target_size and force_attempts < 20:
		force_attempts += 1
		var picked2: ChallengeTemplate = _pick_next_template()
		if picked2 == null:
			break
		if not _can_solve_with_library(picked2, card_library):
			continue
		picked2.is_warn = false
		add_to_board(picked2)
	# Task 13: Fallback —— 可解池抽不够则放宽过滤，标 is_warn=true 让 UI 提示玩家。
	# 永远比留空板更友好。
	var fallback_attempts: int = 0
	while available_challenges.size() < target_size and fallback_attempts < 30:
		fallback_attempts += 1
		var picked3: ChallengeTemplate = _pick_next_template()
		if picked3 == null:
			break
		picked3.is_warn = true
		add_to_board(picked3)
	# 4. 修正 selected_challenge_index
	if selected_challenge_index >= available_challenges.size():
		selected_challenge_index = -1
	if selected_challenge_index < 0 and not available_challenges.is_empty():
		selected_challenge_index = 0
	board_changed.emit()


## 判断 library 中的卡是否能填满 template 的所有槽（贪心匹配，每张卡仅占一槽）。
## 简单 1-2 槽场景下贪心结果正确；更复杂的多槽组合可能漏判（比如槽1=A|B、槽2=B
## 时贪心给槽1放 A 后槽2无解），但 MVP 题库基本是 1-2 槽，足够用。
##
## 边界：
##   - template == null → 视为可解（兼容空 selector 路径）
##   - template.slots 为空 → 视为可解（无需填卡）
##   - library 为空且 slots 非空 → false
func _can_solve_with_library(template: ChallengeTemplate, library_cards: Array[Card]) -> bool:
	if template == null:
		return true
	var slots: Array = template.slots
	if slots.is_empty():
		return true
	var used_indices: Array[int] = []
	for slot in slots:
		var found_index: int = -1
		for i in library_cards.size():
			if i in used_indices:
				continue
			var c: Card = library_cards[i]
			if c == null:
				continue
			if CardValidator.can_place(c, slot):
				found_index = i
				break
		if found_index == -1:
			return false
		used_indices.append(found_index)
	return true


## 返回本回合已触发能力的卡 id 列表的副本（T2）。
## 外部调用方（如 CardAbilities）用此列表跳过已触发的卡，避免无限触发。
## 返回 duplicate 防止外部 mutate 内部状态。
func get_used_ability_card_ids() -> Array[String]:
	return _used_ability_card_ids_this_turn.duplicate()


## 标记某卡的能力本回合已触发（T2）。空字符串或已在列表中则跳过。
func mark_card_ability_used(card_id: String) -> void:
	if card_id == "":
		return
	if card_id in _used_ability_card_ids_this_turn:
		return
	_used_ability_card_ids_this_turn.append(card_id)


## 测试辅助：直接覆盖 card_library。仅供测试用。
func set_library_for_test(new_library: Array[Card]) -> void:
	card_library.clear()
	for c in new_library:
		card_library.append(c)
	hand_changed.emit(card_library.duplicate())


## 在所有槽都填满时由 try_place_card 自动调用；
## 也支持手动指定 challenge_index 提交（默认 = selected）。
##
## B4 改造：
## 1) 应用 CardAbilities.apply_pre_submit 拿到卡牌能力修饰
## 2) 应用 ChallengeEffects.apply 拿到题目效果
## 3) 把卡牌能力的 modifier（damage / heal / shield 倍率）作用到题目效果上
## 4) 加上卡牌专属字段：extra_heal、extra_draw、queue_questions、combo_extra
## 5) 不再自动补题——回合末才 refill_board()
func submit_challenge(challenge_index: int = -1) -> void:
	var idx: int = challenge_index if challenge_index >= 0 else selected_challenge_index
	if idx < 0 or idx >= available_challenges.size():
		return
	if not _all_slots_filled_for(idx):
		return
	state = State.RESOLUTION

	var tmpl: ChallengeTemplate = available_challenges[idx]
	var slots: Array = available_filled_slots[idx]
	var combo_count: int = _combo.count
	var base_damage: int = DamageCalculator.calculate(
		slots, tmpl, _enemy, combo_count, _srs)
	# 应用待生效的 modifier（譬如 combo_boost 上一题留下的 next_x2）
	if pending_damage_modifier == "next_x2":
		base_damage = base_damage * 2
		pending_damage_modifier = ""

	# === B4: 应用卡牌能力前置（伤害倍率 / 抽牌 / 加题 / 回血等）===
	var card_result: Dictionary = CardAbilities.apply_pre_submit(self, slots, base_damage)
	var dmg_mod: float = float(card_result.get("damage_modifier", 1.0))
	var heal_mod: float = float(card_result.get("heal_modifier", 1.0))
	var shield_mod: float = float(card_result.get("shield_modifier", 1.0))
	base_damage = int(round(float(base_damage) * dmg_mod))

	var crit: bool = DamageCalculator.is_crit(slots, tmpl)
	var weak: bool = DamageCalculator.is_weakness(slots, _enemy)

	# 走 ChallengeEffects 把 effect_type 翻译成具体结果
	var effects: Dictionary = ChallengeEffects.apply(self, tmpl, base_damage)

	# 应用伤害（先扣敌人护盾，再扣 HP；可触发反伤 / hp_threshold 能力）
	var dmg: int = int(effects.get("damage_to_enemy", 0))
	if dmg > 0:
		var absorbed_by_enemy: int = min(enemy_shield, dmg)
		enemy_shield -= absorbed_by_enemy
		var actual_to_enemy: int = dmg - absorbed_by_enemy
		if actual_to_enemy > 0:
			enemy_hp = max(0, enemy_hp - actual_to_enemy)
		_combo_increment_with_extra(int(card_result.get("combo_extra", 0)))
		damage_dealt.emit(dmg, crit, weak)
		# 反伤能力（reflect_25 等）—— 用原伤害 dmg（含被盾抵的）按百分比反弹给玩家
		_apply_enemy_reflect(dmg)
		# HP 阈值能力（shield_at_50 等）
		_apply_enemy_abilities("on_hp_threshold")
		# on_damage_taken 触发（如有）
		_apply_enemy_abilities("on_damage_taken")
	# 回血（卡牌 heal_on_use 叠加 + double_effect 倍率）
	var heal_base: int = int(effects.get("heal_player", 0))
	var heal: int = int(round(float(heal_base) * heal_mod)) + int(card_result.get("extra_heal", 0))
	if heal > 0:
		var actual: int = min(heal, player_max_hp - player_hp)
		player_hp += actual
		if _has_game_state():
			GameState.player_hp = player_hp
		_combo_increment_with_extra(int(card_result.get("combo_extra", 0)))
		healed.emit(actual)
	# 护盾（double_effect 倍率）
	var shield_base: int = int(effects.get("shield_added", 0))
	var shield: int = int(round(float(shield_base) * shield_mod))
	if shield > 0:
		player_shield += shield
		_combo_increment_with_extra(int(card_result.get("combo_extra", 0)))
		shielded.emit(shield)
	# 抽牌效果（题目 draw_card + 卡牌 draw_card）：
	# 静态卡库下"抽牌"不再有意义——保留信号 emit 兼容 UI 计数，但不变库内容。
	# TODO(T2/T5)：考虑改成 "刷新可用卡" / "下回合 AP 容量 +1" 等替代效果。
	var to_draw: int = int(effects.get("cards_drawn", 0)) + int(card_result.get("extra_draw", 0))
	if to_draw > 0:
		_combo_increment_with_extra(int(card_result.get("combo_extra", 0)))
		cards_drawn.emit(to_draw)
	# 加题（题目 draw_question 效果立即生效 / 卡牌 draw_question 能力排队下回合）
	var to_add: int = int(effects.get("questions_drawn", 0))
	if to_add > 0:
		_combo_increment_with_extra(int(card_result.get("combo_extra", 0)))
		var added: int = 0
		for _i in to_add:
			var t: ChallengeTemplate = _pick_next_template()
			if t == null:
				break
			# 不去重——加题就是要"多选项"
			available_challenges.append(t)
			var fresh: Array = []
			for _j in t.slots.size():
				fresh.append(null)
			available_filled_slots.append(fresh)
			if not (t.template_id in _seen_template_ids):
				_seen_template_ids.append(t.template_id)
			added += 1
		if added > 0:
			questions_added.emit(added)
	# 卡牌 draw_question 排队到下回合（refill 时多补 N 道）
	var queue_q: int = int(card_result.get("queue_questions", 0))
	if queue_q > 0:
		_queued_for_next_turn += queue_q
	# 修饰符（combo_boost）
	var mod: String = str(effects.get("modifier", ""))
	if mod != "":
		pending_damage_modifier = mod
		combo_boost_armed.emit()

	# B6 日志：成功解题摘要
	var summary_parts: Array[String] = []
	if dmg > 0:
		summary_parts.append("[color=#ffd066]%d 伤害[/color]" % dmg)
	if heal > 0:
		summary_parts.append("[color=#7fe88f]+%d HP[/color]" % heal)
	if shield > 0:
		summary_parts.append("[color=#7ad6ff]+%d 🛡[/color]" % shield)
	if to_draw > 0:
		summary_parts.append("抽 %d 牌" % to_draw)
	if to_add > 0:
		summary_parts.append("加 %d 题" % to_add)
	if mod == "next_x2":
		summary_parts.append("[color=#fff066]✨下击×2[/color]")
	var summary_text: String = " · ".join(summary_parts) if not summary_parts.is_empty() else "无效果"
	_log("你: 用 %s 解决 [%s] → %s" % [
		_format_cards_for_log(slots), _short_dialogue(tmpl), summary_text])

	# 静态卡库：槽中的卡留在 card_library，不入弃牌堆。
	# 把这道题从棋盘移除（无论是否 kept——已解决就解了）
	# kept 仅影响"回合末刷不刷"，已解的题不应该再保留。
	var solved_template_id: String = tmpl.template_id
	if solved_template_id in kept_template_ids:
		kept_template_ids.erase(solved_template_id)
	available_challenges.remove_at(idx)
	available_filled_slots.remove_at(idx)
	# 修正失败索引：被移走的 idx 后面的位移 -1，等于的不可能（idx 解了不可能 failed）
	var shifted: Array[int] = []
	for fi in _failed_challenge_indices:
		if fi == idx:
			continue  # 不可能但兜底
		if fi > idx:
			shifted.append(fi - 1)
		else:
			shifted.append(fi)
	_failed_challenge_indices = shifted
	# 修正 selected：跳过失败题
	if selected_challenge_index >= available_challenges.size():
		selected_challenge_index = max(-1, available_challenges.size() - 1)
	if selected_challenge_index < 0 and not available_challenges.is_empty():
		selected_challenge_index = 0
	# 如果 selected 落到 failed 题上，找下一个可解的
	if selected_challenge_index in _failed_challenge_indices:
		var found: int = -1
		for i in available_challenges.size():
			if not (i in _failed_challenge_indices):
				found = i
				break
		selected_challenge_index = found
	board_changed.emit()

	challenges_solved_this_turn += 1
	if challenges_solved_this_turn >= 2:
		turn_combo_advanced.emit(challenges_solved_this_turn)

	if enemy_hp <= 0:
		_on_enemy_dead()
		return

	# B4：不再回合内自动补题。如果玩家解光所有题——只能过牌或留下 kept 继续。
	# 棋盘补满发生在 end_player_turn → _run_enemy_turn → refill_board()。
	if selected_challenge_index >= 0:
		challenge_advanced.emit(current_template)
	state = State.PLAYER_TURN


## combo +1 默认；combo_charge 卡可让一次 +N（额外加 extra）。
func _combo_increment_with_extra(extra: int) -> void:
	_combo.increment()
	for _i in max(0, extra):
		_combo.increment()


## 玩家点"过牌"。
##
## 静态卡库（T1 改造）：卡不再进入弃牌堆——库内容永远不变。
## 仅清空棋盘上未解题的填槽（卡留在库里，下回合可继续使用）。
##
## T2：清空"本回合已触发能力"列表，让下回合卡的能力可以再次触发。
func end_player_turn() -> void:
	# T2：能力 once-per-turn 列表清空在 state check 之前，
	# 这样测试场景（state == IDLE）调用 end_player_turn 也能清空。
	_used_ability_card_ids_this_turn.clear()
	if state != State.PLAYER_TURN and state != State.CARD_VALIDATION:
		return
	# 清空所有题里已放的卡（卡仍留在 card_library，不进弃牌堆）
	for i in available_filled_slots.size():
		var slots: Array = available_filled_slots[i]
		for j in slots.size():
			slots[j] = null
	cards_played_this_turn = 0
	challenges_solved_this_turn = 0
	turn_ended.emit(true)
	_run_enemy_turn()


# ═══════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════

func _all_slots_filled_for(idx: int) -> bool:
	if idx < 0 or idx >= available_challenges.size():
		return false
	var tmpl: ChallengeTemplate = available_challenges[idx]
	if tmpl == null:
		return false
	var slots: Array = available_filled_slots[idx]
	if slots.size() != tmpl.slots.size():
		return false
	for c in slots:
		if c == null:
			return false
	return true


## 从池里抽下一道题。优先用 selector；selector 给的题如果已在棋盘则跳过若干次。
func _pick_next_template() -> ChallengeTemplate:
	if _selector == null:
		_selector = ChallengeSelector.new()
	# 反复 ask selector 几次避免重复（最多 5 次）
	for _i in 5:
		var t: ChallengeTemplate = _selector.pick_challenge(_enemy, _pack, _srs)
		if t == null:
			return null
		# 棋盘内重复检查
		var on_board: bool = false
		for c in available_challenges:
			if c != null and c.template_id == t.template_id:
				on_board = true
				break
		if not on_board:
			return t
	# 全是重复——退而求其次直接返回最后一次结果（哪怕重复）
	return _selector.pick_challenge(_enemy, _pack, _srs)


## 旧 API：让 selected 题前进到下一道（保留以兼容旧测试 / 旧 UI）。
func _advance_to_next_challenge() -> void:
	if available_challenges.is_empty():
		refill_board()
	if not available_challenges.is_empty() and selected_challenge_index < 0:
		selected_challenge_index = 0
	if selected_challenge_index >= 0:
		challenge_advanced.emit(current_template)
	board_changed.emit()


## 静态卡库下抽牌不再有意义；保留 stub 兼容外部调用（CardAbilities 等可能引用）。
## 返回值固定为 0。如果未来想恢复抽牌玩法，请改回 deck/hand 结构或扩展库容量。
func draw_cards(_count: int) -> int:
	return 0


# ═══════════════════════════════════════════════════════════════════
# 实体能力（敌人 / 玩家共享接口）
# ═══════════════════════════════════════════════════════════════════

## 在指定阶段（"turn_start" / "turn_end" / "on_hp_threshold" / "on_damage_taken" / "on_attack"）
## 遍历敌人能力并应用结果。
func _apply_enemy_abilities(phase: String) -> void:
	if _enemy_abilities.is_empty():
		return
	var state_dict := {
		"hp": enemy_hp,
		"max_hp": _enemy.max_hp if _enemy != null else 1,
	}
	for a in _enemy_abilities:
		if a == null or a.trigger != phase:
			continue
		if not a.should_trigger(state_dict):
			continue
		var result: Dictionary = a.apply(state_dict)
		var healed_n: int = int(result.get("healed", 0))
		var shielded_n: int = int(result.get("shielded", 0))
		var extra_actions_n: int = int(result.get("extra_actions", 0))
		# reflect 不在这里立即结算（需攻击者伤害值），由 _apply_enemy_reflect 统一处理。
		if healed_n > 0 and _enemy != null:
			var actual_heal: int = min(healed_n, _enemy.max_hp - enemy_hp)
			if actual_heal > 0:
				enemy_hp = min(_enemy.max_hp, enemy_hp + actual_heal)
				_log("[color=#7fe88f]敌人能力: %s +%d HP[/color]" % [a.icon, actual_heal])
				enemy_healed.emit(actual_heal)
				enemy_ability_triggered.emit(a.icon, a.description_zh)
		if shielded_n > 0:
			enemy_shield += shielded_n
			_log("[color=#7ad6ff]敌人能力: %s +%d 护盾[/color]" % [a.icon, shielded_n])
			enemy_shielded.emit(shielded_n)
			enemy_ability_triggered.emit(a.icon, a.description_zh)
		if extra_actions_n > 0:
			_pending_enemy_extra_actions += extra_actions_n
			_log("[color=#ffaa55]敌人能力: %s 多 %d 次行动[/color]" % [a.icon, extra_actions_n])
			enemy_ability_triggered.emit(a.icon, a.description_zh)
		# 一次性触发标记
		if a.trigger == "on_hp_threshold":
			a.mark_triggered()
		# state_dict 在循环中使用最新 hp / max_hp，刷新一下
		state_dict["hp"] = enemy_hp


## 处理 reflect 能力：玩家本次对敌人造成的伤害 incoming，按反伤百分比反弹给玩家。
## incoming 是实际写入 enemy 的伤害（含被敌人盾抵掉的，按 spec "受到伤害时反弹"）。
func _apply_enemy_reflect(incoming_damage: int) -> void:
	if incoming_damage <= 0:
		return
	if _enemy_abilities.is_empty():
		return
	var state_dict := {
		"hp": enemy_hp,
		"max_hp": _enemy.max_hp if _enemy != null else 1,
	}
	for a in _enemy_abilities:
		if a == null:
			continue
		if a.effect_type != "reflect":
			continue
		if a.trigger != "on_damage_taken":
			continue
		if not a.should_trigger(state_dict):
			continue
		var result: Dictionary = a.apply(state_dict)
		var pct: int = int(result.get("reflected_damage", 0))
		if pct <= 0:
			continue
		var refl: int = int(round(float(incoming_damage) * float(pct) / 100.0))
		if refl <= 0:
			continue
		# 反伤直接扣玩家盾→HP
		var absorbed: int = min(player_shield, refl)
		player_shield -= absorbed
		var actual_refl: int = refl - absorbed
		if actual_refl > 0:
			player_hp = max(0, player_hp - actual_refl)
			if _has_game_state():
				GameState.take_damage(actual_refl)
			damage_received.emit(actual_refl)
		_log("[color=#ff7777]敌人能力: %s 反弹 %d 伤害[/color]" % [a.icon, refl])
		enemy_ability_triggered.emit(a.icon, a.description_zh)
		if player_hp <= 0:
			_on_player_dead()
			return


## 玩家能力 hook（当前为空 stub——后续装备 / 技能填充 _player_abilities 后此处统一处理）。
func _apply_player_abilities(phase: String) -> void:
	if _player_abilities.is_empty():
		return
	var state_dict := {
		"hp": player_hp,
		"max_hp": player_max_hp,
	}
	for a in _player_abilities:
		if a == null or a.trigger != phase:
			continue
		if not a.should_trigger(state_dict):
			continue
		var result: Dictionary = a.apply(state_dict)
		var healed_n: int = int(result.get("healed", 0))
		var shielded_n: int = int(result.get("shielded", 0))
		if healed_n > 0:
			var actual_heal: int = min(healed_n, player_max_hp - player_hp)
			if actual_heal > 0:
				player_hp += actual_heal
				if _has_game_state():
					GameState.player_hp = player_hp
				healed.emit(actual_heal)
		if shielded_n > 0:
			player_shield += shielded_n
			shielded.emit(shielded_n)
		if a.trigger == "on_hp_threshold":
			a.mark_triggered()
		state_dict["hp"] = player_hp


## 玩家回合开始时调用。后续装备 / 技能填充 _player_abilities 后此处统一处理。
## 当前为空 stub（兼容未来）。
func apply_player_turn_start_abilities() -> void:
	_apply_player_abilities("turn_start")


func _run_enemy_turn() -> void:
	state = State.ENEMY_TURN
	# 敌人回合开始：触发 turn_start 能力（可能加盾、回血、累积额外行动）
	_pending_enemy_extra_actions = 0
	_apply_enemy_abilities("turn_start")
	var attacks_this_turn: int = 1 + max(0, _pending_enemy_extra_actions)
	_pending_enemy_extra_actions = 0
	# 玩家回合 hook（敌人回合开始 = 玩家回合刚结束）：触发 turn_end
	# （未来玩家能力的 on_turn_end）
	_apply_player_abilities("turn_end")
	for attack_i in attacks_this_turn:
		var raw_dmg: int = _enemy.base_attack if _enemy != null else 0
		if raw_dmg <= 0:
			break
		# 先抵护盾
		var absorbed: int = min(player_shield, raw_dmg)
		player_shield -= absorbed
		var actual: int = raw_dmg - absorbed
		if actual > 0:
			player_hp = max(0, player_hp - actual)
			if _has_game_state():
				GameState.take_damage(actual)
			damage_received.emit(actual)
			# B6 日志
			var prefix: String = ""
			if attacks_this_turn > 1:
				prefix = "[color=#ffaa55]⚡ 多动 %d/%d[/color] " % [attack_i + 1, attacks_this_turn]
			if absorbed > 0:
				_log("%s[color=#ff8a8a]敌人: 攻击你 (%d 伤害, 🛡 抵 %d)[/color]" % [prefix, actual, absorbed])
			else:
				_log("%s[color=#ff8a8a]敌人: 攻击你 (%d 伤害)[/color]" % [prefix, actual])
		else:
			# 全被护盾抵掉——通知 UI 但伤害=0
			damage_received.emit(0)
			if raw_dmg > 0:
				_log("[color=#7ad6ff]敌人: 攻击 %d 伤害被🛡完全抵掉[/color]" % raw_dmg)
		_combo.reset()
		if player_hp <= 0:
			_on_player_dead()
			return
	# 静态卡库：不再补抽手牌。
	# 刷新棋盘：保留 kept 题，其它换新
	refill_board()
	hand_changed.emit(card_library.duplicate())
	state = State.PLAYER_TURN
	turn_ended.emit(false)


func _on_enemy_dead() -> void:
	state = State.END
	var new_card_ids: Array[String] = []
	if _has_run_state():
		new_card_ids = RunState.record_cards_used(_used_card_ids_this_battle)
		if not new_card_ids.is_empty():
			RunState.add_crystals(5 * new_card_ids.size())
			RunState.add_crystals(10)
			new_cards_unlocked.emit(new_card_ids)
	if _has_game_state() and GameState.save_system != null and _enemy != null:
		GameState.save_system.record_enemy_defeated(_enemy.enemy_id)
		GameState.save_system.add_crystals(10)
		for cid in _used_card_ids_this_battle:
			GameState.save_system.record_card_discovered(cid)
	_log("[color=#ffd86b][b]胜利！敌人倒下了[/b][/color]")
	battle_ended.emit(true)


func _on_player_dead() -> void:
	state = State.END
	_log("[color=#ff7777][b]战败...守护者倒下了[/b][/color]")
	battle_ended.emit(false)


func _has_game_state() -> bool:
	var ok := false
	if Engine.get_main_loop() != null:
		var root := Engine.get_main_loop()
		if root is SceneTree:
			var n := (root as SceneTree).root.get_node_or_null("GameState")
			ok = n != null
	return ok


func _has_run_state() -> bool:
	if Engine.get_main_loop() != null:
		var root := Engine.get_main_loop()
		if root is SceneTree:
			return (root as SceneTree).root.get_node_or_null("RunState") != null
	return false


# ═══════════════════════════════════════════════════════════════════
# 场景挂载支持
# ═══════════════════════════════════════════════════════════════════

func _ready() -> void:
	pass
