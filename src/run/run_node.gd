## RunNode — 路径地图上的单个节点（数据类）
##
## 由 `run_map_generator.gd` 生成、存储在 `RunMap.nodes` 中、被 `run_map_scene.gd`
## 渲染为按钮、被 `node_resolvers/*.gd` 解析为具体场景跳转。
##
## 详见: docs/superpowers/specs/2026-05-04-run-structure-design.md
class_name RunNode extends Resource

## 唯一 ID，惯例为 "<floor>-A<act>-<type>-<index>"，例如 "1F-A1-battle-3"
@export var id: String = ""

## 节点类型："battle" | "elite" | "shop" | "rest" | "puzzle" | "mystery" | "boss"
@export var type: String = ""

## 网格位置：row 0 = 起始排（Act 入口），最大 row = Boss
@export var row: int = 0
@export var col: int = 0

## 战斗类型节点关联的敌人 / Boss ID（其他类型为空）
@export var enemy_id: String = ""

## 任意附加数据（例如商店库存预生成、神秘事件 ID 等）
@export var metadata: Dictionary = {}


static func make(p_id: String, p_type: String, p_row: int, p_col: int, p_enemy_id: String = "") -> RunNode:
	var n := RunNode.new()
	n.id = p_id
	n.type = p_type
	n.row = p_row
	n.col = p_col
	n.enemy_id = p_enemy_id
	return n


func to_dict() -> Dictionary:
	return {
		"id": id,
		"type": type,
		"row": row,
		"col": col,
		"enemy_id": enemy_id,
		"metadata": metadata,
	}
