## 在内置 mp3 词表里查找；命中返回 AudioStream，未命中返回 null
class_name LocalMp3CacheBackend extends IVoiceTtsBackend

const WORDS_DIR := "res://src/content/english/audio/words/"
const LETTERS_DIR := "res://src/content/english/audio/letters/"

func is_available() -> bool:
	return DirAccess.dir_exists_absolute(WORDS_DIR)

func get_id() -> String:
	return "local_mp3_cache"

func synthesize(text: String, _lang: String = "en") -> AudioStream:
	var lower := text.to_lower()
	var fname := lower.replace(" ", "_") + ".mp3"
	var candidates: Array = [LETTERS_DIR, WORDS_DIR] if lower.length() == 1 else [WORDS_DIR, LETTERS_DIR]
	for dir in candidates:
		var path: String = (dir as String).path_join(fname)
		if ResourceLoader.exists(path):
			return load(path)
	return null
