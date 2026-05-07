## CutscenePlayer — 通用剧情面板播放器（autoload 单例）
##
## 引擎层不含任何具体故事内容。消费者把 panels 数组喂进来，播放器负责：
##   1. 实例化 CutsceneScene 顶层 UI
##   2. 顺序渲染每个 CutscenePanel
##   3. 处理 advance / skip / 解锁图鉴
##
## TODO(autoload): 在 project.godot [autoload] 段注册：
##   CutscenePlayer="*res://src/cutscene/cutscene_player.gd"
##   LoreCodexSystem="*res://src/cutscene/lore_codex_system.gd"
##
## 用法：
##   CutscenePlayer.play("intro", pack.get_intro_panels())
##   await CutscenePlayer.cutscene_finished
##
## 参考: docs/superpowers/specs/2026-05-04-cutscene-system-design.md
extends Node

signal cutscene_started(cutscene_id: String)
signal cutscene_finished(cutscene_id: String)
signal panel_advanced(panel_id: String)
signal cutscene_skipped(cutscene_id: String)

const CUTSCENE_SCENE_PATH: String = "res://src/cutscene/cutscene_scene.tscn"

# CutsceneScene 实例（CanvasLayer），按需创建并 reparent 到根
var _scene_instance: Node = null
var _current_panels: Array[CutscenePanel] = []
var _current_index: int = 0
var _cutscene_id: String = ""
var _is_playing: bool = false

## 测试钩子：true 时 _ensure_scene_loaded() 不实际加载 .tscn，
## 而是创建一个轻量 stub Node，并要求由测试 inject_scene() 注入；
## 否则尝试加载 cutscene_scene.tscn。
var headless_mode: bool = false


## 主入口：播放一段剧情。如果当前正在播放，则替换为新的（idempotent）。
func play(cutscene_id: String, panels: Array[CutscenePanel]) -> void:
	# 替换语义：如果正在播放别的，先静默收尾（不 emit finished，避免歧义）
	if _is_playing:
		_teardown(false)
	_cutscene_id = cutscene_id
	_current_panels = panels
	_current_index = 0
	_is_playing = true
	_ensure_scene_loaded()
	cutscene_started.emit(cutscene_id)
	if _current_panels.is_empty():
		# 空序列：立即收尾
		_finish()
		return
	_show_current_panel()


## 跳过整段：所有未触达的 lore_codex_id 一并解锁
func skip() -> void:
	if not _is_playing or _current_panels.is_empty():
		return
	_record_remaining_codex_entries()
	cutscene_skipped.emit(_cutscene_id)
	_finish()


## 推进到下一面板；已到末尾则收尾
func advance() -> void:
	if not _is_playing:
		return
	if _current_index >= _current_panels.size() - 1:
		_finish()
		return
	_current_index += 1
	_show_current_panel()


## 当前播放状态
func is_playing() -> bool:
	return _is_playing


## 当前面板（测试用）
func get_current_panel() -> CutscenePanel:
	if _current_panels.is_empty():
		return null
	if _current_index < 0 or _current_index >= _current_panels.size():
		return null
	return _current_panels[_current_index]


## 测试钩子：注入 mock scene（必须在 play() 之前 + headless_mode = true）
func inject_scene(scene: Node) -> void:
	_scene_instance = scene


## 测试钩子：注入 codex system，覆盖 autoload 解析。
## 用于 GUT 测试，避免 autoload 实例和测试实例不一致。
func inject_codex_system(codex_node: Node) -> void:
	_injected_codex = codex_node


# 注入后的 codex 引用（测试用，nil 表示走 autoload 解析）
var _injected_codex: Node = null


# ---- 内部 ----

func _show_current_panel() -> void:
	var panel := _current_panels[_current_index]
	if _scene_instance != null and _scene_instance.has_method("render_panel"):
		_scene_instance.render_panel(panel)
	if not panel.lore_codex_id.is_empty():
		_unlock_lore(panel.lore_codex_id)
	panel_advanced.emit(panel.id)


func _record_remaining_codex_entries() -> void:
	# 包含当前以及之后所有面板（current 也算"未读完"）
	for i in range(_current_index, _current_panels.size()):
		var p := _current_panels[i]
		if p != null and not p.lore_codex_id.is_empty():
			_unlock_lore(p.lore_codex_id)


func _unlock_lore(lore_id: String) -> void:
	# 通过自定义查找逻辑找到 LoreCodexSystem，避免硬依赖 autoload 名字
	var sys := _resolve_codex_system()
	if sys != null:
		sys.unlock_lore(lore_id)


func _resolve_codex_system() -> Node:
	# 测试注入优先（避免 GUT 环境同时存在 autoload 和测试实例时拿错）
	if _injected_codex != null and is_instance_valid(_injected_codex):
		return _injected_codex
	if not is_inside_tree():
		return null
	var root := get_tree().root
	# autoload 名约定为 LoreCodexSystem
	if root.has_node("LoreCodexSystem"):
		return root.get_node("LoreCodexSystem")
	# 兜底：递归全场景树寻找任何具备图鉴接口的节点（测试场景常见）
	return _find_codex_recursive(root)


func _find_codex_recursive(node: Node) -> Node:
	if node == null:
		return null
	if node != self and node.has_method("unlock_lore") and node.has_method("is_unlocked"):
		return node
	for child in node.get_children():
		var found := _find_codex_recursive(child)
		if found != null:
			return found
	return null


func _finish() -> void:
	var finished_id := _cutscene_id
	if _scene_instance != null and _scene_instance.has_method("fade_out"):
		_scene_instance.fade_out()
	_teardown(true)
	cutscene_finished.emit(finished_id)


func _teardown(_emit_finished: bool) -> void:
	# _emit_finished 仅作为语义注释；信号由 _finish() 直接发出
	_current_panels = []
	_current_index = 0
	_cutscene_id = ""
	_is_playing = false


func _ensure_scene_loaded() -> void:
	if _scene_instance != null and is_instance_valid(_scene_instance):
		# 已经存在的 scene 复用即可
		return
	if headless_mode:
		# 测试模式：保持 null，让测试代码 inject_scene()
		return
	var packed: PackedScene = load(CUTSCENE_SCENE_PATH)
	if packed == null:
		push_warning("[CutscenePlayer] cannot load %s" % CUTSCENE_SCENE_PATH)
		return
	_scene_instance = packed.instantiate()
	if is_inside_tree():
		get_tree().root.add_child(_scene_instance)
