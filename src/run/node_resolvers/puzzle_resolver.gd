## PuzzleResolver — "puzzle" 节点解析器（MVP 占位）
##
## 真实谜题节点会接入挑战系统；MVP 阶段先复用 BattleResolver 让流程跑通，
## 同时把奖励标记为"装备/卷轴"以与战斗节点区分（后续 spec 实现）。
class_name PuzzleResolver extends Object


static func resolve(node: RunNode, pack: ContentPackBase, tree: SceneTree) -> void:
	# 占位：直接转交战斗解析器
	BattleResolver.resolve(node, pack, tree)
