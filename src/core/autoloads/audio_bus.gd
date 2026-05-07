## AudioBus — global BGM + SFX manager.
##
## Usage:
##   AudioBus.play_bgm("res://assets/audio/bgm/main_menu.ogg")
##   AudioBus.play_sfx("button_click")            # short alias
##   AudioBus.play_sfx_path("res://...something.ogg")
##   AudioBus.stop_bgm()
##
## BGM is looped automatically (loop point = 0) when the underlying
## AudioStreamOggVorbis supports it. Crossfade isn't implemented; we just
## cut and play. SFX go through a small pool of one-shot players so
## overlapping calls work.
##
## All audio is optional: if a file fails to load, we push_warning and
## skip silently — the game must remain playable in headless / asset-less
## environments (used by tests).
extends Node

const _BGM_BASE: String = "res://assets/audio/bgm/"
const _SFX_BASE: String = "res://assets/audio/sfx/"
const _SFX_POOL_SIZE: int = 8

# Volume defaults (linear; converted to dB on apply).
var _bgm_volume: float = 0.6
var _sfx_volume: float = 0.85

var _bgm_player: AudioStreamPlayer = null
var _current_bgm_path: String = ""
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0
# Cached loaded streams (path -> AudioStream)
var _stream_cache: Dictionary = {}


func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	_bgm_player.volume_db = linear_to_db(_bgm_volume)
	add_child(_bgm_player)

	for i in range(_SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = linear_to_db(_sfx_volume)
		add_child(p)
		_sfx_pool.append(p)


# ─── BGM ───────────────────────────────────────────────────────

## Start a BGM track (path = res:// path to .ogg). Loops by default.
## If `path` is the same as currently-playing track, do nothing.
func play_bgm(path: String, loop: bool = true) -> void:
	if path == "" or path == _current_bgm_path:
		return
	var stream: AudioStream = _load_stream(path)
	if stream == null:
		return
	# Set loop on the stream if it's a vorbis stream and the API exists.
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	_bgm_player.stream = stream
	_bgm_player.play()
	_current_bgm_path = path


func stop_bgm() -> void:
	if _bgm_player != null and _bgm_player.playing:
		_bgm_player.stop()
	_current_bgm_path = ""


func is_bgm_playing() -> bool:
	return _bgm_player != null and _bgm_player.playing


## Convenience: BGM-by-name (without "res://assets/audio/bgm/" prefix).
##   AudioBus.play_bgm_named("main_menu")
func play_bgm_named(name: String) -> void:
	play_bgm("%s%s.ogg" % [_BGM_BASE, name])


# ─── SFX ───────────────────────────────────────────────────────

## Play SFX by name (without "res://assets/audio/sfx/" prefix or extension).
## Silent no-op if the file is missing.
func play_sfx(name: String) -> void:
	play_sfx_path("%s%s.ogg" % [_SFX_BASE, name])


func play_sfx_path(path: String) -> void:
	if path == "":
		return
	var stream: AudioStream = _load_stream(path)
	if stream == null:
		return
	var p: AudioStreamPlayer = _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % _SFX_POOL_SIZE
	p.stream = stream
	p.play()


# ─── Volume ────────────────────────────────────────────────────

func set_bgm_volume(linear: float) -> void:
	_bgm_volume = clamp(linear, 0.0, 1.0)
	if _bgm_player != null:
		_bgm_player.volume_db = linear_to_db(max(_bgm_volume, 0.0001))


func set_sfx_volume(linear: float) -> void:
	_sfx_volume = clamp(linear, 0.0, 1.0)
	for p in _sfx_pool:
		p.volume_db = linear_to_db(max(_sfx_volume, 0.0001))


func get_bgm_volume() -> float:
	return _bgm_volume


func get_sfx_volume() -> float:
	return _sfx_volume


# ─── Internal ──────────────────────────────────────────────────

func _load_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	if not ResourceLoader.exists(path):
		push_warning("AudioBus: missing audio file %s" % path)
		return null
	var res = load(path)
	if res == null or not (res is AudioStream):
		push_warning("AudioBus: failed to load %s" % path)
		return null
	_stream_cache[path] = res
	return res
