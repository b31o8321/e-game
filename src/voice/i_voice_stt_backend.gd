class_name IVoiceSttBackend extends RefCounted

func is_available() -> bool:
	return false

func get_id() -> String:
	push_error("IVoiceSttBackend.get_id() not overridden")
	return ""

func transcribe(_audio: AudioStream, _lang: String = "en") -> String:
	push_error("IVoiceSttBackend.transcribe() not overridden")
	return ""
