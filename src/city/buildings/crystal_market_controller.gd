## CrystalMarketController — 水晶集市子场景（永久小升级）
##
## MVP 占位：仅显示当前钱包 + 一个返回按钮，便于完成 city 链路烟雾测试。
## 详细的购买/升级逻辑会在 Phase 4 后续接入；当前阶段先保证场景可以加载、
## 玩家不会卡死。
##
## 详见: docs/superpowers/specs/2026-05-04-knowledge-city-design.md
extends Control


const CITY_SCENE_PATH: String = "res://src/city/city_scene.tscn"


@onready var _back_button: Button = $Header/BackButton
@onready var _wallet_label: Label = $WalletLabel
@onready var _item_list: VBoxContainer = $ItemScroll/ItemList
@onready var _status_label: Label = $StatusLabel


func _ready() -> void:
	if _back_button != null:
		_back_button.pressed.connect(_on_back_pressed)
	_refresh_wallet()
	_render_placeholder_items()


func _refresh_wallet() -> void:
	if _wallet_label == null:
		return
	var crystals: int = 0
	if typeof(GameState) != TYPE_NIL and GameState != null and GameState.save_system != null:
		var w: Dictionary = GameState.save_system.get_wallet()
		crystals = int(w.get("crystals", 0))
	_wallet_label.text = "🔮 词晶: %d" % crystals


func _render_placeholder_items() -> void:
	if _item_list == null:
		return
	for child in _item_list.get_children():
		child.queue_free()
	var lbl := Label.new()
	lbl.text = "（水晶集市永久升级正在开发中——Phase 4 后续接入）"
	_item_list.add_child(lbl)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(CITY_SCENE_PATH)
