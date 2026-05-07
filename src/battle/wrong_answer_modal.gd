## WrongAnswerModal — 答错反馈模态框
##
## 当玩家在多题棋盘上放错卡 → BattleController 发 challenge_failed →
## BattleScene 实例化此场景，传入对话 + 正确答案 Card → 玩家看完点"知道了"关闭。
##
## 教育属性优先于游戏惩罚：失败不扣血、不扣手牌（已经扣了 combo），
## 但要让玩家"看到正确答案 + 中文释义 + 例句"，把错变成学习契机。
extends CanvasLayer


signal dismissed


@onready var _root: Control = $Root
@onready var _bg: ColorRect = $Root/Background
@onready var _panel: PanelContainer = $Root/CenterPanel
@onready var _dialogue_label: Label = $Root/CenterPanel/Box/DialogueLabel
@onready var _correct_word_label: Label = $Root/CenterPanel/Box/CorrectWordLabel
@onready var _meaning_label: Label = $Root/CenterPanel/Box/MeaningLabel
@onready var _phonetic_label: Label = $Root/CenterPanel/Box/PhoneticLabel
@onready var _example_en_label: Label = $Root/CenterPanel/Box/ExampleEnLabel
@onready var _example_zh_label: Label = $Root/CenterPanel/Box/ExampleZhLabel
@onready var _ok_button: Button = $Root/CenterPanel/Box/Buttons/OkButton
@onready var _continue_button: Button = $Root/CenterPanel/Box/Buttons/ContinueButton


func _ready() -> void:
	if _ok_button != null:
		_ok_button.pressed.connect(_on_dismiss_pressed)
	if _continue_button != null:
		_continue_button.pressed.connect(_on_dismiss_pressed)
	# Fade-in
	if _root != null:
		_root.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_root, "modulate:a", 1.0, 0.2)


## 由 BattleScene 调用：传入题目对话 + 正确答案 Card（可为 null 退化）。
func setup(dialogue: String, correct_card: Card) -> void:
	if _dialogue_label != null:
		var d: String = dialogue if dialogue != null else ""
		if d == "":
			d = "—"
		_dialogue_label.text = d
	if correct_card == null:
		if _correct_word_label != null:
			_correct_word_label.text = "（暂无最佳答案）"
		if _meaning_label != null:
			_meaning_label.text = ""
		if _phonetic_label != null:
			_phonetic_label.text = ""
		if _example_en_label != null:
			_example_en_label.text = ""
		if _example_zh_label != null:
			_example_zh_label.text = ""
		return
	if _correct_word_label != null:
		_correct_word_label.text = correct_card.text
	if _meaning_label != null:
		var meaning: String = correct_card.meaning
		_meaning_label.text = ("中文释义：" + meaning) if meaning != "" else ""
		_meaning_label.visible = meaning != ""
	if _phonetic_label != null:
		var ph: String = correct_card.phonetic
		_phonetic_label.text = ("音标：" + ph) if ph != "" else ""
		_phonetic_label.visible = ph != ""
	if _example_en_label != null:
		var ex_en: String = correct_card.example_en
		_example_en_label.text = ("例句：" + ex_en) if ex_en != "" else ""
		_example_en_label.visible = ex_en != ""
	if _example_zh_label != null:
		var ex_zh: String = correct_card.example_zh
		_example_zh_label.text = ("        " + ex_zh) if ex_zh != "" else ""
		_example_zh_label.visible = ex_zh != ""


func _on_dismiss_pressed() -> void:
	# Fade-out then queue_free
	if _root == null:
		dismissed.emit()
		queue_free()
		return
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func() -> void:
		dismissed.emit()
		queue_free()
	)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_ENTER or k.keycode == KEY_ESCAPE or k.keycode == KEY_SPACE:
			_on_dismiss_pressed()
			get_viewport().set_input_as_handled()
