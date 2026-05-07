## ContentLoader — 内容包注册表 + 启动期自动发现 + 切换激活
##
## 责任：
##   - `_auto_discover()` 扫描 `res://src/content/*/`，对每个子目录加载
##     `<dirname>_content_pack.gd` 并注册（如果脚本存在）。
##   - `set_active_pack(id)` 切换激活包之前调 `validate()`，失败保持原状态。
##   - `get_active_pack()` / `get_available_packs()` 供其他系统查询。
##
## 详见: docs/superpowers/specs/2026-05-04-content-pack-interface-design.md
class_name ContentLoader extends Node

## 当前激活的内容包发生变化时发出
signal pack_changed(new_pack: ContentPackBase)

## 字典：pack_id (String) -> ContentPackBase
var _packs: Dictionary = {}
var _active_pack_id: String = ""

const _CONTENT_ROOT := "res://src/content/"


func _ready() -> void:
	_auto_discover()


# ─── 注册 / 发现 ───────────────────────────────────────────────────

## 扫描 `res://src/content/*/` 子目录，自动加载 `<dirname>_content_pack.gd`。
## 以 `_` / `.` 开头的目录（如 `_template`、`_validator`）跳过。
func _auto_discover() -> void:
	var dir := DirAccess.open(_CONTENT_ROOT)
	if dir == null:
		push_warning("ContentLoader: content root not found: " + _CONTENT_ROOT)
		return

	dir.list_dir_begin()
	while true:
		var subdir := dir.get_next()
		if subdir == "":
			break
		if subdir.begins_with(".") or subdir.begins_with("_"):
			continue
		if not dir.current_is_dir():
			continue

		var script_path := _CONTENT_ROOT + subdir + "/" + subdir + "_content_pack.gd"
		if not ResourceLoader.exists(script_path):
			continue
		var pack_class := load(script_path)
		if pack_class == null:
			push_error("ContentLoader: failed to load pack script: " + script_path)
			continue

		# 如果已通过外部 register_pack() 注册了同 ID 包（例如 GameState 启动序列
		# 提前注册了 EnglishContentPack），就跳过自动发现，避免重复实例。
		var pack_obj = pack_class.new()
		if not (pack_obj is ContentPackBase):
			push_error("ContentLoader: %s does not extend ContentPackBase" % script_path)
			if pack_obj is Node:
				pack_obj.queue_free()
			continue
		var id := _resolve_pack_id(pack_obj)
		if _packs.has(id):
			if pack_obj is Node:
				pack_obj.queue_free()
			continue
		add_child(pack_obj)
		register_pack(pack_obj)
		print("[ContentLoader] discovered pack: %s (%s)" % [id, script_path])
	dir.list_dir_end()


## 手动注册一个内容包（测试 / 启动顺序敏感的场景使用）。
## 以 `get_id()` 为主键；为兼容旧测试，同时支持仅设置了 `pack_id` 字段
## 而未实现 `get_id()` 的 stub 包。
func register_pack(pack: ContentPackBase) -> void:
	if pack == null:
		push_error("ContentLoader.register_pack(null)")
		return
	var id := _resolve_pack_id(pack)
	if id.is_empty():
		push_error("ContentLoader.register_pack: pack has empty id")
		return
	_packs[id] = pack


# ─── 查询 ──────────────────────────────────────────────────────────

func get_pack(pack_id: String) -> ContentPackBase:
	return _packs.get(pack_id, null)

## 当前激活包；未设置时返回 null
func get_active_pack() -> ContentPackBase:
	if _active_pack_id.is_empty():
		return null
	return _packs.get(_active_pack_id, null)

func get_active_pack_id() -> String:
	return _active_pack_id

## 全部已注册的内容包
func get_available_packs() -> Array[ContentPackBase]:
	var out: Array[ContentPackBase] = []
	for p in _packs.values():
		out.append(p)
	return out


# ─── 切换 ──────────────────────────────────────────────────────────

## 切换激活包：调 `validate()`，失败则保持原状态并返回 false。
## 成功时发出 `pack_changed` 信号。
func set_active_pack(pack_id: String) -> bool:
	if not _packs.has(pack_id):
		push_error("ContentLoader: pack not registered: " + pack_id)
		return false
	var pack: ContentPackBase = _packs[pack_id]
	var errors: Array[String] = pack.validate()
	if not errors.is_empty():
		push_error("ContentLoader: pack '%s' validation failed: %s" % [pack_id, str(errors)])
		return false
	_active_pack_id = pack_id
	pack_changed.emit(pack)
	return true


# ─── 内部 ──────────────────────────────────────────────────────────

func _resolve_pack_id(pack: ContentPackBase) -> String:
	# 优先使用新接口 get_id()；ContentPackBase 默认实现里 push_error 后会兜底返回 pack_id 字段，
	# 故老测试里仅设置 pack_id 字段的 stub 也能正确解析。
	var id: String = pack.get_id()
	if id.is_empty():
		id = pack.pack_id
	return id
