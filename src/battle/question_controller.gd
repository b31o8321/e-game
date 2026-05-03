class_name QuestionController extends Node

var current_question: Dictionary = {}
var _answered: bool = false

## default time limit in seconds; skills can modify this
var time_limit: float = 10.0

signal answered(correct: bool, question_id: String)
signal explanation_ready(text: String, audio_text: String)

func load_question(question: Dictionary) -> void:
	current_question = question
	_answered = false

func submit_answer(option_index: int) -> void:
	if _answered or current_question.is_empty():
		return
	_answered = true
	var correct: bool = option_index == current_question.get("correct_index", -1)
	var qid: String = current_question.get("id", "")
	answered.emit(correct, qid)
	if not correct:
		var explanation: String = current_question.get("explanation", "")
		var audio_text: String = current_question.get("audio_text", "")
		explanation_ready.emit(explanation, audio_text)

func on_timer_expired() -> void:
	submit_answer(-1)
