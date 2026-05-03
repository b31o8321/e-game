class_name PuzzleBase extends Node

## 对应的知识点ID
@export var knowledge_id: String = ""
## 谜题名称
@export var puzzle_name: String = ""

## 信号：谜题通关
signal puzzle_completed(knowledge_id: String)
## 信号：玩家退出谜题（未完成）
signal puzzle_exited()

## 谜题初始化（引擎调用）
func setup(pack: ContentPackBase) -> void:
	pass

## 检查通关条件（子类实现具体逻辑）
func _check_completion() -> void:
	pass
