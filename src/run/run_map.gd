## RunMap — 单个 Act 的完整路径地图
##
## 由 `RunMapGenerator.generate()` 创建，作为 RunState.act_maps 中的一条。
##
## 详见: docs/superpowers/specs/2026-05-04-run-structure-design.md
class_name RunMap extends Resource

## 0-based act index（0 / 1 / 2）
@export var act_index: int = 0

## 该 Act 的全部节点（含 Boss），按 row 升序排列
@export var nodes: Array[RunNode] = []

## 邻接表：node.id → Array[String]（指向上一排可达节点的 id）
## 注意：方向是"从 row N 到 row N+1"——值是 row N+1 的可达节点 ID 列表。
@export var connections: Dictionary = {}

## 终点 Boss 节点 ID
@export var boss_node_id: String = ""


func get_node_by_id(node_id: String) -> RunNode:
	for n in nodes:
		if n.id == node_id:
			return n
	return null


## 起点节点列表（row == 0）
func get_start_nodes() -> Array[RunNode]:
	var arr: Array[RunNode] = []
	for n in nodes:
		if n.row == 0:
			arr.append(n)
	return arr


## 当前节点的下一步可达节点
func get_next_reachable(node_id: String) -> Array[String]:
	var raw: Variant = connections.get(node_id, [])
	if not (raw is Array):
		return []
	var out: Array[String] = []
	for x in raw:
		out.append(str(x))
	return out


## 总行数（row 范围 0 .. max_row）
func get_row_count() -> int:
	var max_row: int = 0
	for n in nodes:
		if n.row > max_row:
			max_row = n.row
	return max_row + 1
