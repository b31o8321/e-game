## BattleScene — playable card-battle UI for "知识神塔"（多题棋盘版）.
##
## Responsibilities (UI ONLY — game logic lives in BattleController):
##   - Read GameState.pending_enemy + RunState.current_deck and bootstrap a BattleController.
##   - Render TopBar (floor / act / battle counter + retreat button).
##   - Render EnemyArea (name, portrait placeholder, weakness, HP bar).
##   - Render ChallengeBoard (multiple ChallengeCards side by side, each with
##     its own effect badge, slots, and "📌 留下" toggle).
##   - Render PlayerStatus (HP / shield / combo / crystals).
##   - Render Hand (clickable card buttons).
##   - Click flow: click a challenge card to select it → click a hand card →
##     click an empty slot inside the selected challenge.
##   - Visual feedback: damage popups, enemy shake, heal/shield/draw/add-question
##     animations, victory/defeat overlay.
##
## All game logic (validation, damage, effects) is in BattleController. This
## script must NOT mutate enemy_hp / player_hp / hand directly.
extends Control


const RUN_MAP_SCENE: String = "res://src/run/run_map_scene.tscn"
const SETTLEMENT_SCENE: String = "res://src/run/settlement_scene.tscn"
const CAMP_SCENE: String = "res://src/run/camp_scene.tscn"
const DEBUG_OVERLAY_SCENE: String = "res://src/core/debug/debug_overlay.tscn"
const WRONG_ANSWER_MODAL_SCENE: String = "res://src/battle/wrong_answer_modal.tscn"

const TUTORIAL_CFG_PATH: String = "user://battle_prefs.cfg"
const TUTORIAL_FLAG_KEY: String = "seen_battle_tutorial"

const SLOT_PLACEHOLDER: String = "___"

const TYPE_COLORS: Dictionary = {
	"word": Color(0.45, 0.6, 1.0),
	"phrase": Color(0.55, 0.85, 0.65),
	"pattern": Color(0.95, 0.7, 0.45),
	"rule": Color(0.9, 0.55, 0.85),
	"sound": Color(0.65, 0.85, 0.95),
	"modifier": Color(0.85, 0.85, 0.55),
}

const TYPE_DISPLAY: Dictionary = {
	"word": "词卡",
	"phrase": "短语",
	"pattern": "句型",
	"rule": "规则",
	"sound": "听音",
	"modifier": "修饰",
}

const POS_DISPLAY: Dictionary = {
	"adjective": "形容词",
	"noun": "名词",
	"verb": "动词",
	"verb_be": "系动词",
	"adverb": "副词",
	"pronoun": "代词",
	"preposition": "介词",
	"conjunction": "连词",
	"determiner": "限定词",
	"article": "冠词",
	"letter": "字母",
	"syllable": "音节",
	"sight_word": "高频词",
}

const TAG_DISPLAY: Dictionary = {
	"positive_emotion": "积极情绪",
	"negative_emotion": "消极情绪",
	"feeling": "感受",
	"emotion": "情绪",
	"positive_personality": "正面性格",
	"negative_personality": "负面性格",
	"neutral_personality": "中性性格",
	"personality": "性格",
	"size": "大小",
	"physical_attribute": "身体特征",
	"appearance": "外貌",
	"positive_appearance": "正面外貌",
	"speed": "速度",
	"ability": "能力",
	"description": "描述",
	"family": "家庭",
	"male_relative": "男性亲属",
	"female_relative": "女性亲属",
	"parent": "父母辈",
	"sibling": "兄弟姐妹",
	"grandparent": "祖父母辈",
	"child": "子女辈",
	"body": "身体",
	"upper_body": "上肢",
	"lower_body": "下肢",
	"face": "面部",
	"paired_appendage": "成对的身体部位",
	"paired_part": "成对的器官",
	"single": "单一部位",
	"head_part": "头部",
	"object": "物品",
	"school": "学校用品",
	"stationery": "文具",
	"furniture": "家具",
	"container": "容器",
	"pronoun": "代词",
	"subject_form": "主格",
	"object_form": "宾格",
	"first_person": "第一人称",
	"second_person": "第二人称",
	"third_person": "第三人称",
	"singular": "单数",
	"plural": "复数",
	"plural_subject": "复数主语",
	"singular_subject": "单数主语",
	"male": "阳性",
	"female": "阴性",
	"neuter": "中性",
	"male_subject": "阳性主语",
	"neuter_subject": "中性主语",
	"be_verb": "be 动词",
	"verb_be": "be 动词",
	"present_tense": "现在时",
	"past_tense": "过去时",
	"sight_word": "高频词",
	"article": "冠词",
	"definite_article": "定冠词",
	"indefinite_article": "不定冠词",
	"demonstrative": "指示词",
	"near": "近指",
	"far": "远指",
	"possessive": "物主代词",
	"negation": "否定",
	"intensifier": "程度副词",
	"adverb": "副词",
	"sentence_pattern": "句型",
	"be_pattern": "be 句型",
	"letter": "字母",
	"alphabet": "字母表",
	"vowel": "元音字母",
	"consonant": "辅音字母",
	"syllable": "音节",
	"phonics": "拼读",
	"rime": "韵脚",
}

var _controller: BattleController
var _debug_overlay: Node = null

# Currently selected hand card (click-to-place flow).
var _selected_card: Card = null
# Cached refs to slot panels: _slot_nodes_by_challenge[challenge_idx] = Array of PanelContainer.
var _slot_nodes_by_challenge: Array = []
# Cached refs to challenge card panels (index parallel to controller.available_challenges).
var _challenge_card_nodes: Array = []
# Per-card buttons in hand.
var _card_buttons: Array[Button] = []
# Idle timer (seconds).
var _idle_seconds_since_action: float = 0.0
const HINT_REVEAL_AFTER_SECONDS: float = 5.0
# Force-show helper hint when hovering an empty slot (challenge_idx, slot_idx).
var _hovered_slot: Vector2i = Vector2i(-1, -1)

# Cached node refs.
@onready var _floor_label: Label = $TopBar/TopRow/FloorLabel
@onready var _retreat_button: Button = $TopBar/TopRow/RetreatButton
@onready var _enemy_name_label: Label = $EnemyArea/EnemyHeader/EnemyInfo/EnemyNameLabel
@onready var _enemy_portrait: ColorRect = $EnemyArea/EnemyHeader/EnemyPortrait
@onready var _enemy_hp_bar: ProgressBar = $EnemyArea/EnemyHeader/EnemyInfo/EnemyHpRow/EnemyHpBar
@onready var _enemy_hp_label: Label = $EnemyArea/EnemyHeader/EnemyInfo/EnemyHpRow/EnemyHpLabel
@onready var _weakness_label: Label = $EnemyArea/EnemyHeader/EnemyInfo/WeaknessLabel
@onready var _challenge_panel: PanelContainer = $ChallengeBoardPanel
@onready var _board_row: HBoxContainer = $ChallengeBoardPanel/ChallengeContent/BoardRow
@onready var _board_label: Label = get_node_or_null("ChallengeBoardPanel/ChallengeContent/BoardLabel")
@onready var _helper_label: Label = $ChallengeBoardPanel/ChallengeContent/HelperLabel
@onready var _player_hp_bar: ProgressBar = $PlayerStatus/PlayerHpBar
@onready var _player_hp_label: Label = $PlayerStatus/PlayerHpLabel
@onready var _shield_label: Label = $PlayerStatus/ShieldLabel
@onready var _combo_label: Label = $PlayerStatus/ComboLabel
@onready var _crystal_label: Label = $PlayerStatus/CrystalLabel
@onready var _hand_row: HBoxContainer = $HandRow
@onready var _hand_label: Label = get_node_or_null("HandLabel")
@onready var _end_turn_button: Button = $ActionRow/EndTurnButton
@onready var _status_hint: Label = $ActionRow/StatusHint
@onready var _fx_layer: Control = $FxLayer
@onready var _end_overlay: ColorRect = $EndOverlay
@onready var _end_title_label: Label = $EndOverlay/EndContent/EndTitleLabel
@onready var _end_sub_label: Label = $EndOverlay/EndContent/EndSubLabel
@onready var _end_button: Button = $EndOverlay/EndContent/EndButton
@onready var _tutorial_overlay: ColorRect = $TutorialOverlay
@onready var _log_toggle_button: Button = get_node_or_null("TopBar/TopRow/LogToggleButton")
@onready var _log_panel: PanelContainer = get_node_or_null("LogPanel")
@onready var _log_text: RichTextLabel = get_node_or_null("LogPanel/LogMargin/LogColumn/LogText")
@onready var _ap_blocks_container: HBoxContainer = get_node_or_null("ApRow/Margin/HBox/Blocks")
@onready var _submit_button: Button = get_node_or_null("ApRow/Margin/HBox/SubmitButton")

const APBlockViewScene = preload("res://src/battle/ap_block_view.tscn")


# ═══════════════════════════════════════════════════════════════════
# Lifecycle
# ═══════════════════════════════════════════════════════════════════

func _ready() -> void:
	_controller = BattleController.new()
	add_child(_controller)
	_connect_signals()
	_setup_controller()
	_render_top_bar()
	_render_enemy()
	_render_player_status()
	_controller.start_battle()
	_render_board()
	_render_hand()
	_render_ap_row()
	if _submit_button != null:
		_submit_button.pressed.connect(_on_submit_pressed)
	_maybe_show_tutorial()
	_setup_debug_overlay()


func _process(delta: float) -> void:
	if _controller == null or _controller.current_template == null:
		return
	var was_below: bool = _idle_seconds_since_action < HINT_REVEAL_AFTER_SECONDS
	_idle_seconds_since_action += delta
	if was_below and _idle_seconds_since_action >= HINT_REVEAL_AFTER_SECONDS:
		_update_helper_text()


func _unhandled_input(event: InputEvent) -> void:
	if _tutorial_overlay != null and _tutorial_overlay.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_dismiss_tutorial()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed:
			_dismiss_tutorial()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if _is_debug_enabled():
			match event.keycode:
				KEY_F1:
					_debug_kill_enemy()
					get_viewport().set_input_as_handled()
				KEY_F2:
					_debug_full_heal()
					get_viewport().set_input_as_handled()
				KEY_F3:
					_debug_force_defeat()
					get_viewport().set_input_as_handled()


func _connect_signals() -> void:
	_controller.battle_ended.connect(_on_battle_ended)
	_controller.hand_changed.connect(_on_hand_changed)
	_controller.damage_dealt.connect(_on_damage_dealt)
	_controller.damage_received.connect(_on_damage_received)
	_controller.challenge_advanced.connect(_on_challenge_advanced)
	_controller.card_played.connect(_on_card_played)
	_controller.board_changed.connect(_on_board_changed)
	if _controller.has_signal("cards_drawn"):
		_controller.cards_drawn.connect(_on_cards_drawn)
	if _controller.has_signal("turn_combo_advanced"):
		_controller.turn_combo_advanced.connect(_on_turn_combo_advanced)
	if _controller.has_signal("healed"):
		_controller.healed.connect(_on_healed)
	if _controller.has_signal("shielded"):
		_controller.shielded.connect(_on_shielded)
	if _controller.has_signal("questions_added"):
		_controller.questions_added.connect(_on_questions_added)
	if _controller.has_signal("combo_boost_armed"):
		_controller.combo_boost_armed.connect(_on_combo_boost_armed)
	if _controller.has_signal("challenge_failed"):
		_controller.challenge_failed.connect(_on_challenge_failed)
	if _controller.has_signal("log_appended"):
		_controller.log_appended.connect(_on_log_appended)
	if _controller.has_signal("enemy_shielded"):
		_controller.enemy_shielded.connect(_on_enemy_shielded)
	if _controller.has_signal("enemy_healed"):
		_controller.enemy_healed.connect(_on_enemy_healed)
	if _controller.has_signal("enemy_ability_triggered"):
		_controller.enemy_ability_triggered.connect(_on_enemy_ability_triggered)
	if _retreat_button != null:
		_retreat_button.pressed.connect(_on_retreat_pressed)
	if _end_turn_button != null:
		_end_turn_button.pressed.connect(_on_end_turn_pressed)
	if _end_button != null:
		_end_button.pressed.connect(_on_end_button_pressed)
	if _log_toggle_button != null:
		_log_toggle_button.pressed.connect(_on_log_toggle_pressed)


# ═══════════════════════════════════════════════════════════════════
# Controller setup
# ═══════════════════════════════════════════════════════════════════

func _setup_controller() -> void:
	var enemy: EnemyData = null
	var pack: ContentPackBase = null
	var deck: Array[Card] = []
	var srs: SRSSystem = null

	if typeof(GameState) != TYPE_NIL and GameState != null:
		enemy = GameState.pending_enemy
		if GameState.content_loader != null:
			pack = GameState.content_loader.get_active_pack()
		srs = GameState.srs_system

	if typeof(RunState) != TYPE_NIL and RunState != null:
		for c in RunState.current_deck:
			deck.append(c)

	if enemy == null:
		enemy = EnemyData.new()
		enemy.enemy_id = "dummy"
		enemy.enemy_name = "训练假人"
		enemy.max_hp = 30
		enemy.base_attack = 5

	if deck.is_empty() and pack != null:
		for cid in pack.get_starting_deck_card_ids():
			var c: Card = pack.get_card(cid)
			if c != null:
				deck.append(c)

	_controller.setup(enemy, pack, deck, srs)


# ═══════════════════════════════════════════════════════════════════
# Top bar
# ═══════════════════════════════════════════════════════════════════

func _render_top_bar() -> void:
	if _floor_label == null:
		return
	var floor_id: String = ""
	var act_idx: int = 0
	var node_idx: int = 0
	var node_total: int = 0
	if typeof(RunState) != TYPE_NIL and RunState != null:
		floor_id = RunState.current_floor_id
		act_idx = RunState.current_act_index
		var rmap: RunMap = RunState.get_current_map()
		if rmap != null:
			node_idx = max(1, RunState.current_node_index + 1)
			node_total = rmap.nodes.size() if rmap != null and rmap.nodes != null else 0
	var floor_display: String = floor_id if floor_id != "" else "?"
	var counter: String = ""
	if node_total > 0:
		counter = " · 战斗 %d/%d" % [node_idx, node_total]
	_floor_label.text = "楼层 %s · Act %d%s" % [floor_display, act_idx + 1, counter]


# ═══════════════════════════════════════════════════════════════════
# Enemy area
# ═══════════════════════════════════════════════════════════════════

func _render_enemy() -> void:
	var enemy: EnemyData = _controller._enemy
	if enemy == null:
		if _enemy_name_label != null:
			_enemy_name_label.text = "敌人正在准备..."
		if _weakness_label != null:
			_weakness_label.text = ""
		_update_enemy_hp()
		_render_enemy_abilities(null)
		return
	if _enemy_name_label != null:
		_enemy_name_label.text = enemy.enemy_name
	if _enemy_portrait != null:
		var seed_str: String = enemy.enemy_id if enemy.enemy_id != "" else enemy.enemy_name
		var h: int = seed_str.hash() if seed_str != "" else 0
		var hue: float = float(abs(h) % 360) / 360.0
		_enemy_portrait.color = Color.from_hsv(hue, 0.4, 0.55)
	if _weakness_label != null:
		if enemy.weak_axes.is_empty():
			_weakness_label.text = "弱点：无"
			_weakness_label.modulate = Color(0.7, 0.7, 0.7, 1)
		else:
			var first: String = str(enemy.weak_axes[0])
			_weakness_label.text = "弱点：%s" % first
			_weakness_label.modulate = Color(1, 0.8, 0.45, 1)
	_update_enemy_hp()
	_render_enemy_abilities(enemy)


func _update_enemy_hp() -> void:
	if _enemy_hp_bar != null:
		_enemy_hp_bar.max_value = max(1, _controller.enemy_max_hp)
		_enemy_hp_bar.value = _controller.enemy_hp
	if _enemy_hp_label != null:
		var s: int = _controller.enemy_shield if _controller != null else 0
		var shield_suffix: String = ("  🛡 %d" % s) if s > 0 else ""
		_enemy_hp_label.text = "%d/%d%s" % [_controller.enemy_hp, _controller.enemy_max_hp, shield_suffix]


## 在 EnemyInfo 下方显示敌人能力气泡（emoji + 简短中文描述）。
## 节点不存在则动态创建并缓存到 _enemy_abilities_label。
var _enemy_abilities_label: Label = null

func _render_enemy_abilities(enemy: EnemyData) -> void:
	# 懒创建：找不到就在 EnemyInfo 下追加一个 Label
	if _enemy_abilities_label == null:
		var info := get_node_or_null("EnemyArea/EnemyHeader/EnemyInfo")
		if info != null:
			_enemy_abilities_label = Label.new()
			_enemy_abilities_label.name = "EnemyAbilitiesLabel"
			_enemy_abilities_label.modulate = Color(0.95, 0.85, 0.55, 1)
			_enemy_abilities_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			info.add_child(_enemy_abilities_label)
	if _enemy_abilities_label == null:
		return
	if enemy == null or enemy.ability_ids.is_empty():
		_enemy_abilities_label.text = ""
		_enemy_abilities_label.visible = false
		return
	var parts: Array[String] = []
	for aid in enemy.ability_ids:
		var ab: EntityAbility = AbilitiesRegistry.make(str(aid))
		if ab != null:
			parts.append("%s %s" % [ab.icon, ab.description_zh])
	if parts.is_empty():
		_enemy_abilities_label.text = ""
		_enemy_abilities_label.visible = false
		return
	_enemy_abilities_label.text = "能力：" + "    ".join(parts)
	_enemy_abilities_label.visible = true


# ═══════════════════════════════════════════════════════════════════
# Player status
# ═══════════════════════════════════════════════════════════════════

func _render_player_status() -> void:
	if _player_hp_bar != null:
		_player_hp_bar.max_value = max(1, _controller.player_max_hp)
		_player_hp_bar.value = _controller.player_hp
	if _player_hp_label != null:
		_player_hp_label.text = "%d/%d" % [_controller.player_hp, _controller.player_max_hp]
	if _shield_label != null:
		var s: int = _controller.player_shield if _controller != null else 0
		_shield_label.text = ("🛡 %d" % s) if s > 0 else ""
	_update_combo_label()
	_update_crystal_label()


func _update_combo_label() -> void:
	if _combo_label == null:
		return
	var combo: int = 0
	if _controller != null and _controller._combo != null:
		combo = _controller._combo.count
	var solved: int = _controller.challenges_solved_this_turn if _controller != null else 0
	var boost: String = ""
	if _controller != null and _controller.pending_damage_modifier == "next_x2":
		boost = "  ✨下击×2"
	if solved >= 2:
		_combo_label.text = "连击 %d🔥  ·  本回合连过 %d 题!%s" % [combo, solved, boost]
	else:
		_combo_label.text = "连击 %d🔥%s" % [combo, boost]


func _update_crystal_label() -> void:
	if _crystal_label == null:
		return
	var crystals: int = 0
	if typeof(RunState) != TYPE_NIL and RunState != null:
		crystals = RunState.crystals_collected
	_crystal_label.text = "词晶 %d🔮" % crystals


# ═══════════════════════════════════════════════════════════════════
# Multi-Challenge Board
# ═══════════════════════════════════════════════════════════════════

func _render_board() -> void:
	if _board_row == null:
		return
	for child in _board_row.get_children():
		child.queue_free()
	_slot_nodes_by_challenge.clear()
	_challenge_card_nodes.clear()
	_update_board_label()
	if _controller == null or _controller.available_challenges.is_empty():
		var lbl := Label.new()
		lbl.text = "敌人正在准备..."
		_board_row.add_child(lbl)
		if _helper_label != null:
			_helper_label.text = ""
		return

	for i in _controller.available_challenges.size():
		var tmpl: ChallengeTemplate = _controller.available_challenges[i]
		var card_node: PanelContainer = _make_challenge_card(i, tmpl)
		_board_row.add_child(card_node)
		_challenge_card_nodes.append(card_node)
	_render_slots_filled()
	_update_helper_text()


## 更新题板顶部标签：显示当前留下进度。
func _update_board_label() -> void:
	if _board_label == null or _controller == null:
		return
	_board_label.text = "题板：选一道题作答  ·  📌 留下 %d/%d" % [
		_controller.get_kept_count(), _controller.question_keep_max]


func _make_challenge_card(idx: int, tmpl: ChallengeTemplate) -> PanelContainer:
	var card := PanelContainer.new()
	# 240×180 keeps 3 cards readable at 1280×720 while leaving room for header /
	# inline-flow dialogue / footer without squashing text into vertical strips.
	card.custom_minimum_size = Vector2(240, 180)
	card.set_meta("challenge_index", idx)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.clip_contents = true

	# Click on card body (anywhere not on a slot/keep button) → select this challenge
	card.gui_input.connect(_on_challenge_card_clicked.bind(idx))

	var failed: bool = false
	if _controller != null and _controller.has_method("is_failed"):
		failed = _controller.is_failed(idx)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(vbox)

	# ─ Header: effect badge (B4: 游戏属性优先) + Keep button ─
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_child(header)

	var effect_lbl := Label.new()
	if failed:
		effect_lbl.text = "❌ 已失败"
		effect_lbl.modulate = Color(0.9, 0.45, 0.45, 1)
	else:
		effect_lbl.text = _effect_badge_text(tmpl)
		effect_lbl.modulate = _effect_badge_color(tmpl.effect_type)
	# B4: 大字 22pt（从 26 缩到 22 给 dialogue 让位），让效果图标第一眼抢眼
	effect_lbl.add_theme_font_size_override("font_size", 22)
	effect_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	effect_lbl.clip_text = true
	header.add_child(effect_lbl)

	# 听力题：在 header 加 🔊 播放按钮，让玩家可主动重听音频
	if tmpl != null and not tmpl.audio_path.is_empty():
		var audio_btn := Button.new()
		audio_btn.text = "🔊 播放"
		audio_btn.tooltip_text = "播放听力音频"
		audio_btn.flat = true
		audio_btn.disabled = failed
		audio_btn.pressed.connect(_play_challenge_audio.bind(tmpl))
		header.add_child(audio_btn)

	var keep_btn := Button.new()
	var is_kept: bool = _controller.is_kept(idx)
	keep_btn.text = ("📌已留" if is_kept else "📌留下")
	# 显示 X/Y 提示当前留下用量
	keep_btn.tooltip_text = "保留此题到下回合（不被刷掉）  📌 %d/%d" % [
		_controller.get_kept_count(), _controller.question_keep_max]
	keep_btn.flat = true
	keep_btn.disabled = failed
	_apply_keep_button_style(keep_btn, is_kept)
	keep_btn.pressed.connect(_on_keep_button_pressed.bind(idx))
	header.add_child(keep_btn)

	# ─ Middle: dialogue with inline slots (HFlowContainer wraps content)
	# 使用 HFlowContainer 让"text 片段 + slot 控件"在一行流式排版，超宽自动换行。
	# 解决了之前 HBoxContainer 把 label 挤成一字一行的问题。
	var dialogue_row := HFlowContainer.new()
	dialogue_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_row.add_theme_constant_override("h_separation", 4)
	dialogue_row.add_theme_constant_override("v_separation", 4)
	vbox.add_child(dialogue_row)

	var slot_nodes: Array = []
	var dialogue: String = tmpl.dialogue
	var parts: PackedStringArray = dialogue.split(SLOT_PLACEHOLDER, true)
	var slot_count: int = tmpl.slots.size()
	for j in parts.size():
		if parts[j] != "":
			# 把 part 拆词，让 HFlowContainer 能在词与词之间换行而不是按字符。
			# 这样长句子（如 "Listen: c-___-t. Spell it. ___"）能像普通段落一样阅读。
			_append_text_fragments(dialogue_row, parts[j])
		if j < parts.size() - 1 and j < slot_count:
			var slot_node: PanelContainer = _make_slot_node(idx, j)
			dialogue_row.add_child(slot_node)
			slot_nodes.append(slot_node)
	# 兜底：dialogue 中 ___ 不够时，把多余的 slot 直接追加到末尾。
	while slot_nodes.size() < slot_count:
		var sj: int = slot_nodes.size()
		var slot_node2: PanelContainer = _make_slot_node(idx, sj)
		dialogue_row.add_child(slot_node2)
		slot_nodes.append(slot_node2)

	# topic_hint inline label (语义提示)
	if tmpl.topic_hint != "":
		var hint_lbl := Label.new()
		hint_lbl.text = "(" + tmpl.topic_hint + ")"
		hint_lbl.modulate = Color(0.85, 0.78, 0.55, 0.9)
		hint_lbl.add_theme_font_size_override("font_size", 13)
		hint_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hint_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dialogue_row.add_child(hint_lbl)

	# ─ Footer: select/selected indicator ─
	var footer := Label.new()
	var selected: bool = (idx == _controller.selected_challenge_index)
	if failed:
		footer.text = "已失败 — 不可作答"
		footer.modulate = Color(0.85, 0.45, 0.45, 0.9)
	else:
		footer.text = ("✓ 选中作答中" if selected else "点此选中作答")
		footer.modulate = (Color(0.95, 0.85, 0.45, 1) if selected else Color(0.65, 0.65, 0.7, 0.9))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 12)
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.size_flags_vertical = Control.SIZE_SHRINK_END
	vbox.add_child(footer)

	_apply_challenge_card_style(card, selected, is_kept)
	if failed:
		card.modulate = Color(1, 1, 1, 0.55)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_nodes_by_challenge.append(slot_nodes)
	return card


## 把一段文本按空白切成 word-fragment Label，添加到 HFlowContainer。
## 这样 dialogue 能在词与词之间换行而不是被挤成竖排。保留前后 / 词间空格作
## inline label，避免 "c-" 和 "-t" 之间的连字符黏到 slot 上。
func _append_text_fragments(parent: HFlowContainer, text: String) -> void:
	if text == "":
		return
	# 用正则把"空白串"和"非空白串"切分成有序片段，保留空白作为独立 label，
	# 这样 "Listen: c-" 会拆成 ["Listen:", " ", "c-"]，"-t. Spell it. " 拆成
	# ["-t.", " ", "Spell", " ", "it.", " "]——单词作 label，空格用 spacer label。
	var i: int = 0
	var n: int = text.length()
	while i < n:
		var ch: String = text[i]
		var is_ws: bool = ch == " " or ch == "\t" or ch == "\n"
		var j: int = i + 1
		while j < n:
			var ch2: String = text[j]
			var is_ws2: bool = ch2 == " " or ch2 == "\t" or ch2 == "\n"
			if is_ws2 != is_ws:
				break
			j += 1
		var chunk: String = text.substr(i, j - i)
		var lbl := Label.new()
		lbl.text = chunk
		# 词性次要：16pt 浅色（与之前保持一致）
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.modulate = Color(0.88, 0.91, 0.97, 1)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# 关键：fragment 用 SHRINK_BEGIN，自然宽度不抢空间，HFlowContainer 才能 wrap。
		lbl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		parent.add_child(lbl)
		i = j


func _effect_badge_text(tmpl: ChallengeTemplate) -> String:
	if tmpl == null:
		return ""
	var icon: String = ChallengeEffects.icon(tmpl.effect_type)
	var name_str: String = ChallengeEffects.display_name(tmpl.effect_type)
	var mag: int = tmpl.effect_magnitude
	# damage 默认走公式（来自卡片）；magnitude>0 时是固定额外伤害
	match tmpl.effect_type:
		"damage", "":
			if mag > 0:
				return "%s %s +%d" % [icon, name_str, mag]
			return "%s 卡牌攻击" % icon
		"weakness_strike":
			return "%s %s ×1.5" % [icon, name_str]
		"combo_boost":
			return "%s %s ×2(下击)" % [icon, name_str]
		_:
			return "%s %s +%d" % [icon, name_str, mag]


func _effect_badge_color(effect_type: String) -> Color:
	match effect_type:
		"heal":
			return Color(0.55, 0.95, 0.6, 1)
		"shield":
			return Color(0.55, 0.85, 1.0, 1)
		"draw_card":
			return Color(0.95, 0.85, 0.55, 1)
		"draw_question":
			return Color(0.85, 0.7, 1.0, 1)
		"weakness_strike":
			return Color(1.0, 0.65, 0.45, 1)
		"combo_boost":
			return Color(1.0, 0.95, 0.55, 1)
	return Color(1, 0.85, 0.55, 1)


func _apply_challenge_card_style(panel: PanelContainer, selected: bool, kept: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.16, 0.22, 1)
	if selected:
		sb.border_color = Color(1, 0.92, 0.45, 1)
		sb.set_border_width_all(4)
	elif kept:
		sb.border_color = Color(0.45, 0.7, 1.0, 1)
		sb.set_border_width_all(3)
	else:
		sb.border_color = Color(0.4, 0.42, 0.5, 1)
		sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", sb)


func _apply_keep_button_style(btn: Button, kept: bool) -> void:
	var sb := StyleBoxFlat.new()
	if kept:
		sb.bg_color = Color(0.25, 0.4, 0.7, 1)
		sb.border_color = Color(0.45, 0.7, 1.0, 1)
	else:
		sb.bg_color = Color(0.18, 0.20, 0.26, 1)
		sb.border_color = Color(0.45, 0.5, 0.6, 1)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", sb)


func _make_slot_node(challenge_idx: int, slot_index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	# 70×28 inline-friendly：与 16pt 文本同高，不再像之前 96×36 把对话挤变形。
	panel.custom_minimum_size = Vector2(70, 28)
	panel.set_meta("slot_index", slot_index)
	panel.set_meta("challenge_index", challenge_idx)
	# inline 流式排版：槽位走自然尺寸，竖直居中和文字一行高度对齐。
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lbl := Label.new()
	lbl.text = SLOT_PLACEHOLDER
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.name = "SlotLabel"
	panel.add_child(lbl)
	panel.gui_input.connect(_on_slot_clicked.bind(challenge_idx, slot_index, panel))
	panel.mouse_entered.connect(_on_slot_hovered.bind(challenge_idx, slot_index))
	panel.mouse_exited.connect(_on_slot_unhovered.bind(challenge_idx, slot_index))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_slot_style(panel, false, false)
	return panel


func _on_slot_hovered(challenge_idx: int, slot_index: int) -> void:
	_hovered_slot = Vector2i(challenge_idx, slot_index)
	_update_helper_text()


func _on_slot_unhovered(challenge_idx: int, slot_index: int) -> void:
	if _hovered_slot.x == challenge_idx and _hovered_slot.y == slot_index:
		_hovered_slot = Vector2i(-1, -1)
		_update_helper_text()


## 槽位仅有"已填 / 未填"两种状态。
##
## 教育性考量：早期版本会在选中卡时把"合法槽"涂绿，相当于把答案直接给玩家——
## 这违背了"逼玩家理解卡牌词义"的设计意图。所有未填槽现在视觉等价，玩家必须
## 自己想"这张卡能不能放进这道题"，点错就走 wrong-answer 反馈学习。
func _apply_slot_style(panel: PanelContainer, _valid_highlight: bool, filled: bool) -> void:
	var sb := StyleBoxFlat.new()
	if filled:
		sb.bg_color = Color(0.15, 0.32, 0.18, 1)
		sb.border_color = Color(0.5, 0.95, 0.55, 1)
	else:
		sb.bg_color = Color(0.13, 0.15, 0.2, 1)
		sb.border_color = Color(0.4, 0.42, 0.5, 1)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	# inline-tighter padding：与 16pt 文本同行高，不抢竖直空间。
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	panel.add_theme_stylebox_override("panel", sb)


func _flash_slot_red(panel: PanelContainer) -> void:
	var orig := panel.modulate
	panel.modulate = Color(1.4, 0.5, 0.5, 1)
	var tw := create_tween()
	tw.tween_property(panel, "modulate", orig, 0.35)


func _render_slots_filled() -> void:
	if _controller == null:
		return
	for ci in _slot_nodes_by_challenge.size():
		if ci >= _controller.available_challenges.size():
			continue
		var tmpl: ChallengeTemplate = _controller.available_challenges[ci]
		if tmpl == null:
			continue
		var slots_arr: Array = []
		if ci < _controller.available_filled_slots.size():
			slots_arr = _controller.available_filled_slots[ci]
		var slot_panels: Array = _slot_nodes_by_challenge[ci]
		for si in slot_panels.size():
			var panel: PanelContainer = slot_panels[si]
			if panel == null:
				continue
			var lbl: Label = panel.get_node_or_null("SlotLabel")
			var card = null
			if si < slots_arr.size():
				card = slots_arr[si]
			var filled: bool = card != null
			# 教育性：未填槽全部用同色，不暴露"哪个槽接受当前卡"——玩家必须
			# 自己理解词义后再点。详见 _apply_slot_style 注释。
			_apply_slot_style(panel, false, filled)
			if lbl != null:
				lbl.text = (card.text if card is Card else SLOT_PLACEHOLDER)


## 教育性提示文字。
##
## 旧版本会暴露槽位的 required_pos / required_type / required_tags，例如
## "选一张【字母】卡填入" —— 这相当于直接把答题类型告诉玩家，丧失了"理解词义"
## 的教育意义。新版本只展示通用操作提示："点击空格放置选中的卡"，让玩家凭
## 对话内容 + 中文 topic_hint 自己判断。
func _update_helper_text() -> void:
	if _helper_label == null:
		return
	if _controller == null:
		_helper_label.text = ""
		return
	if _selected_card == null:
		_helper_label.text = ""
		return
	# selected 题如果还有空槽，提示玩家点击放卡——但不透露槽位的类型/词性。
	var sci: int = _controller.selected_challenge_index
	if sci < 0 or sci >= _controller.available_challenges.size():
		_helper_label.text = ""
		return
	var tmpl: ChallengeTemplate = _controller.available_challenges[sci]
	if tmpl == null:
		_helper_label.text = ""
		return
	var slots_arr: Array = []
	if sci < _controller.available_filled_slots.size():
		slots_arr = _controller.available_filled_slots[sci]
	var has_empty: bool = false
	for i in tmpl.slots.size():
		var existing = slots_arr[i] if i < slots_arr.size() else null
		if existing == null:
			has_empty = true
			break
	if not has_empty:
		_helper_label.text = ""
		return
	_helper_label.text = "💡 点击空格放置选中的卡"


func _on_challenge_card_clicked(event: InputEvent, idx: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	_idle_seconds_since_action = 0.0
	_controller.set_selected_challenge_index(idx)


func _on_keep_button_pressed(idx: int) -> void:
	_idle_seconds_since_action = 0.0
	# 记录当前是否已留下（toggle_keep 返回 true 仅代表"现在已留"）。
	# 触达上限会被 controller 静默拒绝（return false 且未变 kept_template_ids）——
	# 这里区分"取消保留"与"上限拒绝"。
	var was_kept: bool = _controller.is_kept(idx)
	var now_kept: bool = _controller.toggle_keep(idx)
	if now_kept:
		_set_status_hint("📌 已留下：下回合此题不会被刷")
	elif was_kept:
		# was_kept=true → 现在不 kept，说明刚被取消
		_set_status_hint("已取消留卡")
	else:
		# was_kept=false 且 now_kept=false → 没生效（达上限）
		_set_status_hint("最多留下 %d 题（提升上限需要装备/技能）" % _controller.question_keep_max)


func _on_slot_clicked(event: InputEvent, challenge_idx: int, slot_index: int, panel: PanelContainer) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed:
		return
	_idle_seconds_since_action = 0.0
	# 失败的题不能再操作（一锤定音）
	if _controller.is_failed(challenge_idx):
		_set_status_hint("这题已失败 — 选其它题作答")
		return
	# 如果点的不是当前 selected 题——先切到它
	if challenge_idx != _controller.selected_challenge_index:
		_controller.set_selected_challenge_index(challenge_idx)
	# 一锤定音：右键撤回功能已移除
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _selected_card == null:
		_set_status_hint("先点选一张手牌，再点空格放入")
		return
	var tmpl: ChallengeTemplate = _controller.available_challenges[challenge_idx]
	if tmpl == null or slot_index >= tmpl.slots.size():
		return
	# 一锤定音：放卡 = 提交。validator 拒绝 → controller 会标 failed 并发 challenge_failed 信号
	# （battle_scene 在 _on_challenge_failed 弹模态展示正确答案）。
	var ok: bool = _controller.try_place_card(_selected_card, slot_index, challenge_idx)
	if ok:
		_selected_card = null
		_set_status_hint("")
	else:
		# 失败路径 — 控制器已发 challenge_failed；这里只清状态
		_flash_slot_red(panel)
		_selected_card = null


# ═══════════════════════════════════════════════════════════════════
# Hand rendering & click flow
# ═══════════════════════════════════════════════════════════════════

func _render_hand() -> void:
	if _hand_row == null:
		return
	for child in _hand_row.get_children():
		child.queue_free()
	_card_buttons.clear()
	if _selected_card != null and not (_selected_card in _controller.hand):
		_selected_card = null
	# Tighten separation so all 5 cards fit on narrower screens (1024px)
	_hand_row.add_theme_constant_override("separation", 8)
	# 更新手牌标签显示保留进度
	_update_hand_label()

	if _controller.hand.is_empty():
		var lbl := Label.new()
		lbl.text = "（手牌空了，点过牌重抽）"
		lbl.modulate = Color(0.7, 0.7, 0.7, 1)
		_hand_row.add_child(lbl)
		return

	var srs: SRSSystem = null
	if typeof(GameState) != TYPE_NIL and GameState != null:
		srs = GameState.srs_system

	var debug_on: bool = _is_debug_enabled()
	for c in _controller.hand:
		var btn: Button = _make_card_button(c, srs)
		if debug_on:
			var wrap: VBoxContainer = VBoxContainer.new()
			wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
			wrap.add_child(btn)
			var dbg_lbl: Label = Label.new()
			var tag_str: String = ", ".join(c.tags) if not c.tags.is_empty() else "-"
			dbg_lbl.text = "%s\n#%s" % [c.id, tag_str]
			dbg_lbl.add_theme_font_size_override("font_size", 10)
			dbg_lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
			dbg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			dbg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			dbg_lbl.custom_minimum_size = Vector2(0, 0)
			wrap.add_child(dbg_lbl)
			_hand_row.add_child(wrap)
		else:
			_hand_row.add_child(btn)
		_card_buttons.append(btn)


## 更新手牌标签上的"保留 X/Y"计数提示。
func _update_hand_label() -> void:
	if _hand_label == null or _controller == null:
		return
	_hand_label.text = "手牌：📌 %d/%d  ·  右键标记保留（回合末此牌不被弃）" % [
		_controller.get_retained_count(), _controller.hand_retain_max]


func _make_card_button(card: Card, srs: SRSSystem) -> Button:
	var btn := Button.new()
	# Smaller min so 5 cards always fit even on 1024×768; expand to share width.
	btn.custom_minimum_size = Vector2(96, 120)
	btn.text = _card_button_text(card, srs)
	btn.tooltip_text = _card_tooltip(card, srs) + "\n\n[右键标记 📌 保留：回合末此牌不入弃牌堆]"
	btn.clip_text = false
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var retained: bool = _controller != null and _controller.is_hand_retained(card.id)
	_apply_card_button_style(btn, card, false, retained)
	btn.pressed.connect(_on_card_button_pressed.bind(card, btn))
	# 右键 / 中键：标记保留
	btn.gui_input.connect(_on_hand_card_input.bind(card))
	# 在按钮右上角加📌徽章
	if retained:
		var badge := Label.new()
		badge.text = "📌"
		badge.add_theme_font_size_override("font_size", 18)
		badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.anchor_left = 1.0
		badge.anchor_right = 1.0
		badge.anchor_top = 0.0
		badge.anchor_bottom = 0.0
		badge.offset_left = -22.0
		badge.offset_top = 2.0
		badge.offset_right = -2.0
		badge.offset_bottom = 22.0
		btn.add_child(badge)
	return btn


## 右键 / 中键 toggle 手牌保留。左键继续走 button.pressed → _on_card_button_pressed。
func _on_hand_card_input(event: InputEvent, card: Card) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index != MOUSE_BUTTON_RIGHT and mb.button_index != MOUSE_BUTTON_MIDDLE:
		return
	if _controller == null or card == null:
		return
	_idle_seconds_since_action = 0.0
	var was_retained: bool = _controller.is_hand_retained(card.id)
	var changed: bool = _controller.toggle_hand_retain(card.id)
	if changed:
		_render_hand()
		if was_retained:
			_set_status_hint("已取消 📌 保留")
		else:
			_set_status_hint("📌 已保留：回合末此牌不入弃牌堆 (%d/%d)" % [
				_controller.get_retained_count(), _controller.hand_retain_max])
	else:
		# 静默拒绝——超过上限
		_set_status_hint("最多保留 %d 张（提升上限需要装备/技能）" % _controller.hand_retain_max)


func _card_button_text(card: Card, srs: SRSSystem) -> String:
	if card == null:
		return "?"
	# B4：游戏属性优先——大字伤害，副字英文/词性，徽章给能力
	var icon: String = MasterySystem.get_icon(MasterySystem.get_level(card.id, srs))
	var type_disp: String = ""
	if card.pos != "":
		type_disp = POS_DISPLAY.get(card.pos, card.pos)
	elif card.type != "":
		type_disp = TYPE_DISPLAY.get(card.type, card.type)
	# 第 1 行：大字 ⚔ 伤害（如果 >0），否则 mastery 图标
	var line1: String = ""
	if card.base_damage > 0:
		line1 = "⚔ %d" % card.base_damage
	else:
		line1 = icon
	# 第 2 行：英文文本（次要）
	var line2: String = card.text
	# 第 3 行：词性 + 能力徽章
	var line3_parts: Array[String] = []
	if type_disp != "":
		line3_parts.append(type_disp)
	if CardAbilities.has_ability(card):
		var ico: String = CardAbilities.icon(card.ability_type)
		var mag: int = card.ability_magnitude
		if mag > 0:
			line3_parts.append("%s+%d" % [ico, mag])
		else:
			line3_parts.append(ico)
	var line3: String = " ".join(line3_parts)
	if line3 == "":
		return "%s\n%s" % [line1, line2]
	return "%s\n%s\n%s" % [line1, line2, line3]


func _card_tooltip(card: Card, srs: SRSSystem) -> String:
	if card == null:
		return ""
	var lines: Array[String] = []
	lines.append("[%s] %s" % [TYPE_DISPLAY.get(card.type, card.type), card.text])
	if card.phonetic != "":
		lines.append("音标: %s" % card.phonetic)
	if card.meaning != "":
		lines.append("释义: %s" % card.meaning)
	if card.example_en != "":
		lines.append("例: %s" % card.example_en)
	if card.example_zh != "":
		lines.append("    %s" % card.example_zh)
	if card.pos != "":
		lines.append("词性: %s" % POS_DISPLAY.get(card.pos, card.pos))
	if not card.tags.is_empty():
		lines.append("标签: " + ", ".join(card.tags))
	if card.skill != "":
		lines.append("技能: " + card.skill)
	lines.append("伤害: %d" % card.base_damage)
	if CardAbilities.has_ability(card):
		var atxt: String = "%s %s" % [
			CardAbilities.icon(card.ability_type),
			CardAbilities.display_name(card.ability_type),
		]
		if card.ability_magnitude > 0:
			atxt += " +%d" % card.ability_magnitude
		lines.append("能力: " + atxt)
		if card.ability_description != "":
			lines.append("    " + card.ability_description)
	var lvl: int = MasterySystem.get_level(card.id, srs)
	lines.append("熟练: %s %s" % [
		MasterySystem.get_icon(lvl),
		MasterySystem.get_display_name(lvl),
	])
	return "\n".join(lines)


func _apply_card_button_style(btn: Button, card: Card, selected: bool, retained: bool = false) -> void:
	var border_color: Color = TYPE_COLORS.get(card.type, Color(0.6, 0.6, 0.6, 1))
	var sb := StyleBoxFlat.new()
	# 保留的卡：偏蓝色调暗示
	if retained:
		sb.bg_color = Color(0.18, 0.22, 0.36, 1)
	else:
		sb.bg_color = Color(0.16, 0.18, 0.24, 1)
	if selected:
		sb.border_color = Color(1, 1, 0.55, 1)
	elif retained:
		sb.border_color = Color(1, 0.85, 0.3, 1)  # 金黄表示📌
	else:
		sb.border_color = border_color
	sb.set_border_width_all(3 if (selected or retained) else 2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 6.0
	btn.add_theme_stylebox_override("normal", sb)
	var sb_hover := sb.duplicate() as StyleBoxFlat
	sb_hover.bg_color = sb.bg_color.lightened(0.08)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_hover)
	btn.add_theme_stylebox_override("focus", sb_hover)


func _on_card_button_pressed(card: Card, _btn: Button) -> void:
	if _controller.available_challenges.is_empty():
		_set_status_hint("敌人正在准备下一题...")
		return
	if _selected_card == card:
		_selected_card = null
	else:
		_selected_card = card
	_idle_seconds_since_action = 0.0
	_refresh_card_button_styles()
	_render_slots_filled()
	# 教育性：不再提前透露"这张卡能放进哪个槽"。让玩家自己判断词义对应——
	# 错了走 wrong-answer 模态学习。只给一个通用操作提示。
	if _selected_card != null:
		_set_status_hint("点空格放入选中的卡（点错会答错）")
	else:
		_set_status_hint("")


## 找当前 selected 题的第一个合法空槽，没有则返回 -1。
func _find_any_valid_slot(card: Card) -> int:
	if _controller == null:
		return -1
	var sci: int = _controller.selected_challenge_index
	if sci < 0 or sci >= _controller.available_challenges.size():
		return -1
	var tmpl: ChallengeTemplate = _controller.available_challenges[sci]
	if tmpl == null:
		return -1
	var slots_arr: Array = []
	if sci < _controller.available_filled_slots.size():
		slots_arr = _controller.available_filled_slots[sci]
	for i in tmpl.slots.size():
		var existing = slots_arr[i] if i < slots_arr.size() else null
		if existing != null:
			continue
		if CardValidator.can_place(card, tmpl.slots[i]):
			return i
	return -1


func _refresh_card_button_styles() -> void:
	for i in _card_buttons.size():
		var btn: Button = _card_buttons[i]
		if btn == null:
			continue
		if i >= _controller.hand.size():
			continue
		var c: Card = _controller.hand[i]
		var retained: bool = _controller.is_hand_retained(c.id)
		_apply_card_button_style(btn, c, c == _selected_card, retained)


# ═══════════════════════════════════════════════════════════════════
# Status hint helper
# ═══════════════════════════════════════════════════════════════════

func _set_status_hint(text: String) -> void:
	if _status_hint != null:
		_status_hint.text = text
		_status_hint.modulate = Color(1, 1, 1, 1)


func _set_status_hint_educational(text: String) -> void:
	if _status_hint == null:
		return
	_status_hint.text = text
	_status_hint.modulate = Color(1, 0.92, 0.55, 1)
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(_status_hint, "modulate:a", 0.0, 0.5)


func _explain_rejection(card: Card, slot: ChallengeSlot) -> String:
	if card == null or slot == null:
		return "这张卡不能放进这个空格"
	if not slot.accept_card_ids.is_empty():
		return "「%s」在这个语境里不太合适，再想想哦！" % card.text
	if slot.required_type != "" and card.type != slot.required_type:
		var disp: String = TYPE_DISPLAY.get(slot.required_type, slot.required_type)
		return "这里需要【%s】卡" % disp
	if slot.required_pos != "" and card.pos != slot.required_pos:
		var pdisp: String = POS_DISPLAY.get(slot.required_pos, slot.required_pos)
		return "这里需要【%s】" % pdisp
	if not slot.required_tags.is_empty():
		var labels: Array[String] = []
		for t in slot.required_tags:
			labels.append(TAG_DISPLAY.get(t, str(t)))
		var joiner: String = "、" if slot.tag_match_mode == "all" else " 或 "
		return "这里需要含【%s】属性的卡" % joiner.join(labels)
	if not slot.forbidden_tags.is_empty():
		for t in card.tags:
			if t in slot.forbidden_tags:
				var fdisp: String = TAG_DISPLAY.get(t, t)
				return "这张卡是【%s】，不能放在这里" % fdisp
	return "这张卡不能放进这个空格"


# ═══════════════════════════════════════════════════════════════════
# Controller signal handlers
# ═══════════════════════════════════════════════════════════════════

func _on_hand_changed(_hand: Array) -> void:
	_render_hand()
	_render_player_status()


func _on_card_played(_card: Card, _slot_index: int) -> void:
	_render_slots_filled()
	_update_helper_text()
	_render_hand()


func _on_board_changed() -> void:
	_render_board()
	_maybe_show_no_solvable_hint()


## 当棋盘没填满（手牌中没题可解）时，给玩家提示"过牌抽新卡"。
## 不打扰玩家正常出题状态——只在棋盘小于预期时露出。
func _maybe_show_no_solvable_hint() -> void:
	if _controller == null:
		return
	if _controller.state == BattleController.State.END:
		return
	var expected: int = _controller.board_size
	var actual: int = _controller.available_challenges.size()
	if actual >= expected:
		return
	if actual == 0:
		_set_status_hint("手牌中没有可解的题——过牌抽新卡")
	else:
		_set_status_hint("剩余 %d 题；新题需手牌补齐后才会出现——过牌抽新卡" % actual)


func _on_damage_dealt(amount: int, crit: bool, weak: bool) -> void:
	_update_enemy_hp()
	_update_combo_label()
	_animate_enemy_shake()
	_animate_combo_glow()
	var label_parts: Array[String] = ["%d 伤害" % amount]
	if crit:
		label_parts.append("暴击!")
	if weak:
		label_parts.append("命中弱点!")
	_spawn_floating_text(" ".join(label_parts), Color(1, 0.85, 0.5, 1))


func _on_damage_received(amount: int) -> void:
	_render_player_status()
	if amount <= 0:
		# 全被护盾抵掉——闪一下盾色
		_spawn_floating_text("🛡 抵挡!", Color(0.55, 0.85, 1, 1), true)
		return
	_animate_screen_red_tint()
	_spawn_floating_text("-%d HP" % amount, Color(1, 0.5, 0.5, 1), true)


func _on_challenge_advanced(template: ChallengeTemplate) -> void:
	_idle_seconds_since_action = 0.0
	_render_board()
	_render_hand()
	_animate_challenge_advance_sparkle()
	# 听力题自动播放一次（小延迟避免一切到题就刺耳）
	if template != null and not template.audio_path.is_empty():
		_schedule_audio_autoplay(template)


func _schedule_audio_autoplay(template: ChallengeTemplate) -> void:
	if get_tree() == null:
		return
	var t: SceneTreeTimer = get_tree().create_timer(0.3)
	if t == null:
		return
	await t.timeout
	# 切走了 / 关掉了战斗界面就别播
	if not is_inside_tree():
		return
	_play_challenge_audio(template)


func _on_cards_drawn(count: int) -> void:
	_render_hand()
	_render_player_status()
	if count > 0:
		_spawn_floating_text("+%d 抽牌" % count, Color(0.6, 0.95, 0.6, 1), true)
	_animate_hand_draw_pulse()


func _on_turn_combo_advanced(challenges_solved: int) -> void:
	_update_combo_label()
	_animate_combo_glow()
	_spawn_floating_text("连过 %d 题!" % challenges_solved, Color(1, 0.92, 0.45, 1))


func _on_healed(amount: int) -> void:
	_render_player_status()
	if amount > 0:
		_spawn_floating_text("+%d HP" % amount, Color(0.55, 1, 0.6, 1), true)


func _on_shielded(amount: int) -> void:
	_render_player_status()
	if amount > 0:
		_spawn_floating_text("🛡 +%d" % amount, Color(0.55, 0.85, 1, 1), true)


func _on_questions_added(count: int) -> void:
	if count > 0:
		_spawn_floating_text("+%d 题" % count, Color(0.85, 0.7, 1, 1))


## 敌人能力效果：自给护盾 / 自回血 / 多动 / 反伤等触发时由 BattleController 发信号。
func _on_enemy_shielded(amount: int) -> void:
	_update_enemy_hp()
	if amount > 0:
		_spawn_floating_text("敌🛡 +%d" % amount, Color(0.55, 0.85, 1, 1))


func _on_enemy_healed(amount: int) -> void:
	_update_enemy_hp()
	if amount > 0:
		_spawn_floating_text("敌+%d HP" % amount, Color(0.55, 1, 0.6, 1))


func _on_enemy_ability_triggered(icon: String, description_zh: String) -> void:
	if icon == "" and description_zh == "":
		return
	_spawn_floating_text("%s %s" % [icon, description_zh], Color(0.95, 0.8, 0.45, 1))


func _on_combo_boost_armed() -> void:
	_update_combo_label()
	_spawn_floating_text("✨ 下击 ×2!", Color(1, 0.95, 0.55, 1))


## 一锤定音：玩家放错卡 → 弹模态展示正确答案 + 中文释义；关闭后视觉上灰掉这道题。
func _on_challenge_failed(challenge_index: int, correct_card_id: String) -> void:
	_selected_card = null
	_update_combo_label()
	_render_player_status()
	# 取出题目对话 + 正确卡数据
	var dialogue: String = ""
	if _controller != null and challenge_index >= 0 and challenge_index < _controller.available_challenges.size():
		var tmpl: ChallengeTemplate = _controller.available_challenges[challenge_index]
		if tmpl != null:
			dialogue = tmpl.dialogue
	var correct_card: Card = null
	if correct_card_id != "" and typeof(GameState) != TYPE_NIL and GameState != null:
		var pack: ContentPackBase = null
		if GameState.content_loader != null:
			pack = GameState.content_loader.get_active_pack()
		if pack != null:
			correct_card = pack.get_card(correct_card_id)
	_show_wrong_answer_modal(dialogue, correct_card)
	# 重渲染棋盘——失败题会以灰态展示并锁交互
	_render_board()
	_set_status_hint_educational("答错了！选其它题继续作答")


func _show_wrong_answer_modal(dialogue: String, correct_card: Card) -> void:
	if not ResourceLoader.exists(WRONG_ANSWER_MODAL_SCENE):
		return
	var packed: PackedScene = load(WRONG_ANSWER_MODAL_SCENE) as PackedScene
	if packed == null:
		return
	var modal: Node = packed.instantiate()
	if modal == null:
		return
	add_child(modal)
	if modal.has_method("setup"):
		modal.call("setup", dialogue, correct_card)


# ═══════════════════════════════════════════════════════════════════
# Visual effects
# ═══════════════════════════════════════════════════════════════════

func _animate_enemy_shake() -> void:
	if _enemy_portrait == null:
		return
	var orig: Vector2 = _enemy_portrait.position
	var tw := create_tween()
	tw.tween_property(_enemy_portrait, "position", orig + Vector2(8, 0), 0.05)
	tw.tween_property(_enemy_portrait, "position", orig + Vector2(-8, 0), 0.05)
	tw.tween_property(_enemy_portrait, "position", orig + Vector2(6, 0), 0.05)
	tw.tween_property(_enemy_portrait, "position", orig, 0.05)


func _animate_combo_glow() -> void:
	if _combo_label == null:
		return
	var tw := create_tween()
	tw.tween_property(_combo_label, "scale", Vector2(1.3, 1.3), 0.12)
	tw.tween_property(_combo_label, "scale", Vector2(1.0, 1.0), 0.18)


func _animate_screen_red_tint() -> void:
	if _fx_layer == null:
		return
	var rect := ColorRect.new()
	rect.color = Color(1, 0.2, 0.2, 0.25)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, 0.4)
	tw.tween_callback(rect.queue_free)


func _animate_challenge_advance_sparkle() -> void:
	if _challenge_panel == null:
		return
	var orig_modulate: Color = _challenge_panel.modulate
	var tw := create_tween()
	tw.tween_property(_challenge_panel, "modulate", Color(1.4, 1.4, 1.0, 1), 0.12)
	tw.tween_property(_challenge_panel, "modulate", orig_modulate, 0.18)


func _animate_hand_draw_pulse() -> void:
	if _hand_row == null:
		return
	var orig_pos: Vector2 = _hand_row.position
	var tw := create_tween()
	tw.tween_property(_hand_row, "position", orig_pos + Vector2(0, -6), 0.08)
	tw.tween_property(_hand_row, "position", orig_pos, 0.16)


# ═══════════════════════════════════════════════════════════════════
# 战斗日志面板（B6: 玩家可回顾近 30 条行动）
# ═══════════════════════════════════════════════════════════════════

func _on_log_appended(message: String) -> void:
	if _log_text == null:
		return
	_log_text.append_text(message + "\n")
	_refresh_log_toggle_label()


func _on_log_toggle_pressed() -> void:
	if _log_panel == null:
		return
	_log_panel.visible = not _log_panel.visible
	if _log_panel.visible:
		# 切到可见时把当前 log 全量灌进去（避免错过开战时的几条）
		_repopulate_log_text()


func _repopulate_log_text() -> void:
	if _log_text == null or _controller == null:
		return
	_log_text.clear()
	for line in _controller.battle_log:
		_log_text.append_text(line + "\n")


func _refresh_log_toggle_label() -> void:
	if _log_toggle_button == null or _controller == null:
		return
	var n: int = _controller.battle_log.size()
	_log_toggle_button.text = "📜 战斗日志 (%d)" % n


## 播放听力题音频。
## 优先：本地文件命中（template.audio_path 指向已存在的 mp3/ogg）。
## 退到：VoiceClient.tts(text) 由 Piper / LocalMp3Cache / Stub 自动合成。
func _play_challenge_audio(template: ChallengeTemplate) -> void:
	if template == null:
		return
	# 优先：本地文件命中
	var path: String = template.audio_path
	if not path.is_empty() and ResourceLoader.exists(path):
		var stream: AudioStream = load(path) as AudioStream
		if stream != null:
			_play_stream(stream)
			return
		push_warning("Audio resource is not AudioStream: " + path)
	# 退到 VoiceClient（Piper / Stub / LocalMp3Cache 自动）
	var text: String = _extract_audio_text(template)
	if text.is_empty():
		return
	var root := get_tree().root if get_tree() != null else null
	if root == null or not root.has_node("VoiceClient"):
		return
	var vc: Node = root.get_node("VoiceClient")
	var synthesized: AudioStream = await vc.tts(text)
	if synthesized != null:
		_play_stream(synthesized)


func _play_stream(stream: AudioStream) -> void:
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## 听力题音频文本提取：
##   有 audio_path → 用文件名 basename（如 res://.../brave.mp3 → "brave"）
##   否则 → 取 dialogue 中除 ___ 以外的部分
func _extract_audio_text(template: ChallengeTemplate) -> String:
	if not template.audio_path.is_empty():
		return template.audio_path.get_file().get_basename()
	return template.dialogue.replace("___", "").strip_edges()


func _spawn_floating_text(text: String, color: Color, near_player: bool = false) -> void:
	if _fx_layer == null:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.modulate = color
	lbl.add_theme_font_size_override("font_size", 28)
	var target_node: Control = (_player_hp_bar if near_player else _enemy_portrait)
	if target_node != null and target_node.is_inside_tree():
		var rect := target_node.get_global_rect()
		lbl.position = rect.position + Vector2(rect.size.x * 0.5 - 40, -10)
	else:
		lbl.position = Vector2(640, 360)
	_fx_layer.add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 60, 0.9)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(lbl.queue_free)


# ═══════════════════════════════════════════════════════════════════
# Buttons (retreat, end turn)
# ═══════════════════════════════════════════════════════════════════

func _on_retreat_pressed() -> void:
	if typeof(RunState) != TYPE_NIL and RunState != null:
		RunState.settle_retreat()
	if get_tree() != null:
		get_tree().change_scene_to_file(SETTLEMENT_SCENE)


func _on_end_turn_pressed() -> void:
	_selected_card = null
	_set_status_hint("")
	_idle_seconds_since_action = 0.0
	_controller.end_player_turn()


# ═══════════════════════════════════════════════════════════════════
# Battle end
# ═══════════════════════════════════════════════════════════════════

func _on_battle_ended(victory: bool) -> void:
	_set_status_hint("")
	if victory:
		_show_victory_overlay()
	else:
		_show_defeat_overlay()


func _show_victory_overlay() -> void:
	if _end_overlay == null:
		_route_after_victory()
		return
	_end_overlay.color = Color(1, 1, 1, 0.0)
	_end_overlay.visible = true
	var tw := create_tween()
	tw.tween_property(_end_overlay, "color", Color(1, 1, 1, 0.85), 0.15)
	tw.tween_property(_end_overlay, "color", Color(0, 0, 0, 0.6), 0.4)
	if _end_title_label != null:
		_end_title_label.text = "胜利!"
		_end_title_label.modulate = Color(1, 0.95, 0.5, 1)
	if _end_sub_label != null:
		_end_sub_label.text = "敌人倒下了"
	if _end_button != null:
		_end_button.text = "继续"
		_end_button.disabled = false


func _show_defeat_overlay() -> void:
	if _end_overlay == null:
		await _delayed_settlement()
		return
	_end_overlay.color = Color(0, 0, 0, 0.0)
	_end_overlay.visible = true
	var tw := create_tween()
	tw.tween_property(_end_overlay, "color", Color(0, 0, 0, 0.85), 0.5)
	if _end_title_label != null:
		_end_title_label.text = "撤退"
		_end_title_label.modulate = Color(0.9, 0.55, 0.55, 1)
	if _end_sub_label != null:
		_end_sub_label.text = "守护者倒下了"
	if _end_button != null:
		_end_button.text = "返回"
		_end_button.disabled = false
	await _delayed_settlement()


func _delayed_settlement() -> void:
	var t := get_tree().create_timer(2.0) if get_tree() != null else null
	if t != null:
		await t.timeout
	_route_after_defeat()


func _on_end_button_pressed() -> void:
	if _controller == null:
		return
	if _controller.state != BattleController.State.END:
		return
	if _controller.enemy_hp <= 0:
		_route_after_victory()
	else:
		_route_after_defeat()


func _route_after_victory() -> void:
	var enemy: EnemyData = _controller._enemy
	var is_boss: bool = enemy != null and enemy.enemy_id.ends_with("_boss")
	if typeof(RunState) != TYPE_NIL and RunState != null:
		var nid: String = RunState.current_node_id
		if nid != "":
			RunState.complete_node(nid)
	if is_boss:
		await _maybe_play_boss_post(enemy)
		_change_scene(CAMP_SCENE)
		return
	var return_scene: String = ""
	if typeof(GameState) != TYPE_NIL and GameState != null:
		return_scene = GameState.expedition_return_scene
	if return_scene.is_empty():
		return_scene = RUN_MAP_SCENE
	_change_scene(return_scene)


func _route_after_defeat() -> void:
	if typeof(RunState) != TYPE_NIL and RunState != null:
		RunState.settle_retreat()
	_change_scene(SETTLEMENT_SCENE)


func _change_scene(path: String) -> void:
	if get_tree() == null:
		return
	get_tree().change_scene_to_file(path)


func _maybe_play_boss_post(enemy: EnemyData) -> void:
	if enemy == null:
		return
	if typeof(GameState) == TYPE_NIL or GameState == null or GameState.content_loader == null:
		return
	var pack: ContentPackBase = GameState.content_loader.get_active_pack()
	if pack == null:
		return
	var boss_id: String = enemy.enemy_id
	if boss_id.ends_with("_boss"):
		boss_id = boss_id.substr(0, boss_id.length() - len("_boss"))
	var panels: Array[CutscenePanel] = pack.get_boss_post_panels(boss_id)
	if panels.is_empty():
		return
	if typeof(CutscenePlayer) == TYPE_NIL or CutscenePlayer == null:
		return
	if GameState.save_system != null:
		GameState.save_system.record_boss_defeated(boss_id)
	CutscenePlayer.play("boss_post_" + boss_id, panels)
	await CutscenePlayer.cutscene_finished


# ═══════════════════════════════════════════════════════════════════
# First-time tutorial overlay
# ═══════════════════════════════════════════════════════════════════

func _maybe_show_tutorial() -> void:
	if _tutorial_overlay == null:
		return
	if _has_seen_tutorial():
		_tutorial_overlay.visible = false
		return
	_tutorial_overlay.visible = true


func _dismiss_tutorial() -> void:
	if _tutorial_overlay == null:
		return
	_tutorial_overlay.visible = false
	_set_seen_tutorial()


func _has_seen_tutorial() -> bool:
	var cfg := ConfigFile.new()
	var err: int = cfg.load(TUTORIAL_CFG_PATH)
	if err != OK:
		return false
	return bool(cfg.get_value("battle", TUTORIAL_FLAG_KEY, false))


func _set_seen_tutorial() -> void:
	var cfg := ConfigFile.new()
	cfg.load(TUTORIAL_CFG_PATH)
	cfg.set_value("battle", TUTORIAL_FLAG_KEY, true)
	cfg.save(TUTORIAL_CFG_PATH)


# ═══════════════════════════════════════════════════════════════════
# DebugMode integration
# ═══════════════════════════════════════════════════════════════════

func _setup_debug_overlay() -> void:
	if not ResourceLoader.exists(DEBUG_OVERLAY_SCENE):
		return
	var scene: PackedScene = load(DEBUG_OVERLAY_SCENE) as PackedScene
	if scene == null:
		return
	_debug_overlay = scene.instantiate()
	if _debug_overlay == null:
		return
	add_child(_debug_overlay)
	if _debug_overlay.has_method("attach_controller"):
		_debug_overlay.attach_controller(_controller)
	var dm: Node = _resolve_debug_mode()
	if dm != null and not dm.debug_toggled.is_connected(_on_debug_mode_toggled):
		dm.debug_toggled.connect(_on_debug_mode_toggled)


func _on_debug_mode_toggled(_enabled: bool) -> void:
	_render_hand()


func _is_debug_enabled() -> bool:
	var dm: Node = _resolve_debug_mode()
	return dm != null and bool(dm.enabled)


func _resolve_debug_mode() -> Node:
	if get_tree() == null:
		return null
	return get_tree().root.get_node_or_null("DebugMode")


func _debug_kill_enemy() -> void:
	if _controller == null or _controller.state == BattleController.State.END:
		return
	_controller.enemy_hp = 0
	_controller.state = BattleController.State.END
	_controller.battle_ended.emit(true)
	_set_status_hint("[DEBUG] 敌人即时击破")


func _debug_full_heal() -> void:
	if _controller == null:
		return
	_controller.player_hp = _controller.player_max_hp
	if typeof(GameState) != TYPE_NIL and GameState != null:
		GameState.player_hp = _controller.player_max_hp
	_render_player_status()
	_set_status_hint("[DEBUG] 满血恢复")


func _debug_force_defeat() -> void:
	if _controller == null or _controller.state == BattleController.State.END:
		return
	_controller.player_hp = 0
	_controller.state = BattleController.State.END
	_controller.battle_ended.emit(false)
	_set_status_hint("[DEBUG] 强制失败")


# ═══════════════════════════════════════════════════════════════════
# Compat shim — old _render_challenge() kept for tests / debug overlay
# ═══════════════════════════════════════════════════════════════════

## 旧 API 兼容：测试 / 调试覆盖层调用 _render_challenge() 触发重渲染。
func _render_challenge() -> void:
	_render_board()


# ═══════════════════════════════════════════════════════════════════
# AP Row (T15)
# ═══════════════════════════════════════════════════════════════════

## 渲染 AP 行：把 controller.ap_queue 里每条连线展示为 APBlockView，
## 后面用空 placeholder 补到 ap_max + ap_bonus_next_turn 个槽位。
func _render_ap_row() -> void:
	if _ap_blocks_container == null:
		return
	for child in _ap_blocks_container.get_children():
		child.queue_free()
	if _controller == null:
		return
	for conn in _controller.ap_queue:
		var v = APBlockViewScene.instantiate()
		_ap_blocks_container.add_child(v)
		v.render(conn)
		if v.has_signal("reorder_requested"):
			v.reorder_requested.connect(_on_ap_reorder_requested)
	# 空占位：补足 ap_max + ap_bonus_next_turn 个槽位
	var total_slots: int = _controller.ap_max + _controller.ap_bonus_next_turn
	for i in range(_controller.ap_queue.size(), total_slots):
		var placeholder := PanelContainer.new()
		placeholder.custom_minimum_size = Vector2(120, 96)
		var lbl := Label.new()
		lbl.text = "[%d]\n空" % (i + 1)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.add_child(lbl)
		_ap_blocks_container.add_child(placeholder)


func _on_ap_reorder_requested(from_idx: int, to_idx: int) -> void:
	if _controller == null:
		return
	_controller.reorder_ap_queue(from_idx, to_idx)
	_render_ap_row()


func _on_submit_pressed() -> void:
	if _controller == null or _controller.ap_queue.is_empty():
		return
	_controller.submit_all_ap()
	# 触发整体重绘（沿用现有渲染分发）
	_render_board()
	_render_hand()
	_render_player_status()
	_render_enemy()
	_render_ap_row()
