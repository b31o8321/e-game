class_name ContentLoader extends Node

var _packs: Dictionary = {}      # pack_id -> ContentPackBase
var _active_pack_id: String = ""

func register_pack(pack: ContentPackBase) -> void:
	_packs[pack.pack_id] = pack

func get_pack(pack_id: String) -> ContentPackBase:
	return _packs.get(pack_id, null)

func set_active_pack(pack_id: String) -> void:
	assert(_packs.has(pack_id), "Pack not registered: " + pack_id)
	_active_pack_id = pack_id

func get_active_pack() -> ContentPackBase:
	return _packs.get(_active_pack_id, null)
