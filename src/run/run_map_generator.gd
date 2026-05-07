## RunMapGenerator — 三幕路径地图生成器（Slay-Spire 风格）
##
## 输入：act_config 字典：
##   {
##     "act_index": 0,
##     "node_count": 6,
##     "node_distribution": {"battle":3, "elite":1, "shop":1, "rest":0, "puzzle":1, "mystery":0},
##     "boss_id": "fog_whisperer",
##     "floor_id": "1F",                 # 用于生成 node id（可选）
##     "enemy_pool": ["enemy_a", ...],   # battle/elite 类型敌人池（可选）
##     "elite_pool": ["elite_a", ...],   # 精英专用敌人池（可选）
##   }
##
## 输出：填好 nodes / connections / boss_node_id 的 RunMap。
##
## 算法：
##   1. 把 distribution 里所有计数加总后 +1 作为 boss，按 row 0..R-2 切分
##      (R = ceil(node_count / 2)，至少 3 排)。最末排只有 Boss。
##   2. 每排 1-3 个节点，列号居中分布在 [0, 1, 2] 上。
##   3. 连线：每个节点向上一排"col 距离 ≤ 1"的节点连边；保证所有节点都至少
##      有一条入边（除起始排）和一条出边（除 Boss 排）。
##   4. 应用约束：精英不在 row 0；Boss 前一排至少一个 rest/shop/puzzle；
##      shop 至少一个；如果分布不满足约束，由 _enforce_constraints 做替换。
##
## 详见: docs/superpowers/specs/2026-05-04-run-structure-design.md
class_name RunMapGenerator extends Object


## 主入口：根据 act_config 生成一张 RunMap
static func generate(act_config: Dictionary) -> RunMap:
	var rng := RandomNumberGenerator.new()
	var seed: int = int(act_config.get("seed", 0))
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed

	var act_index: int = int(act_config.get("act_index", 0))
	var floor_id: String = str(act_config.get("floor_id", "F"))
	var node_count: int = int(act_config.get("node_count", 6))
	var distribution_in: Variant = act_config.get("node_distribution", {})
	var distribution: Dictionary = distribution_in if distribution_in is Dictionary else {}
	var boss_id: String = str(act_config.get("boss_id", "boss"))
	var enemy_pool_in: Variant = act_config.get("enemy_pool", [])
	var enemy_pool: Array = enemy_pool_in if enemy_pool_in is Array else []
	var elite_pool_in: Variant = act_config.get("elite_pool", [])
	var elite_pool: Array = elite_pool_in if elite_pool_in is Array else []

	# 1. 把 distribution 展平成一个类型列表，长度 = node_count
	var type_list: Array[String] = _flatten_distribution(distribution, node_count)
	# 应用约束：替换非法布局
	type_list = _enforce_constraints(type_list, rng)

	# 2. 计算行数 R：每排 1-3 个节点，最后一排只有 Boss
	#    优先 3 排（不含 Boss 排）= 4 排总。node_count 大就 4 排。
	var inner_rows: int = 3
	if node_count >= 8:
		inner_rows = 4
	if node_count <= 4:
		inner_rows = 2
	# 切分 type_list 到 inner_rows 排
	var rows_buckets: Array = _split_into_rows(type_list, inner_rows, rng)

	# 3. 实例化节点
	var run_map := RunMap.new()
	run_map.act_index = act_index
	var node_index: int = 0
	for r in inner_rows:
		var row_types: Array = rows_buckets[r]
		var width: int = row_types.size()
		# 居中分布：cols = [0..width-1] 偏移到中心 col=1
		var col_start: int = int(floor((3 - width) / 2.0))
		for c in width:
			var col: int = col_start + c
			var t: String = str(row_types[c])
			var nid: String = "%s-A%d-%s-%d" % [floor_id, act_index + 1, t, node_index]
			var enemy_id: String = ""
			if t == "battle" and enemy_pool.size() > 0:
				enemy_id = str(enemy_pool[rng.randi() % enemy_pool.size()])
			elif t == "elite" and elite_pool.size() > 0:
				enemy_id = str(elite_pool[rng.randi() % elite_pool.size()])
			elif t == "elite" and enemy_pool.size() > 0:
				enemy_id = str(enemy_pool[rng.randi() % enemy_pool.size()])
			var n := RunNode.make(nid, t, r, col, enemy_id)
			run_map.nodes.append(n)
			node_index += 1

	# Boss 节点：单独一排
	var boss_row: int = inner_rows
	var boss_node := RunNode.make("%s-A%d-boss" % [floor_id, act_index + 1], "boss", boss_row, 1, boss_id)
	run_map.nodes.append(boss_node)
	run_map.boss_node_id = boss_node.id

	# 4. 生成连接（保证所有节点可达 Boss）
	run_map.connections = _build_connections(run_map.nodes, inner_rows + 1, rng)

	return run_map


# ─────────────────────────────────────────────────────────────────
# 内部辅助
# ─────────────────────────────────────────────────────────────────

static func _flatten_distribution(distribution: Dictionary, node_count: int) -> Array[String]:
	# 展平 distribution 的计数并保证总数 == node_count
	var list: Array[String] = []
	for key in distribution.keys():
		var k: String = str(key)
		if k == "boss":
			continue  # boss 单独处理
		var n: int = int(distribution[key])
		for i in n:
			list.append(k)
	# 不足则补 battle，超出则截断
	while list.size() < node_count:
		list.append("battle")
	if list.size() > node_count:
		list = list.slice(0, node_count)
	return list


static func _enforce_constraints(types: Array[String], rng: RandomNumberGenerator) -> Array[String]:
	# 约束 1: 至少有一个 shop
	if not "shop" in types:
		# 把第一个 battle 替换成 shop（不影响精英分布）
		var idx: int = types.find("battle")
		if idx >= 0:
			types[idx] = "shop"
		else:
			# 没有 battle 也得塞进去
			types.append("shop")
	# 约束 2: 至少有一个调整型（rest / shop / puzzle）—— shop 已存在所以满足
	# 注：精英不在 row 0 由 _split_into_rows 处理（先放普通战，再放精英）
	rng.randf()  # 留作 future 随机插入用
	return types


static func _split_into_rows(types: Array[String], inner_rows: int, rng: RandomNumberGenerator) -> Array:
	# 把 types 分到 inner_rows 排，每排 1-3 个；row 0 不放 elite。
	# 策略：把 elite 抽出，先把非 elite 平均分配，再插入 elite 到 row >=1。
	var rows: Array = []
	for i in inner_rows:
		rows.append([] as Array)

	var elites: Array[String] = []
	var others: Array[String] = []
	for t in types:
		if t == "elite":
			elites.append(t)
		else:
			others.append(t)

	# 打乱 others，保证 type 分布在不同排
	others.shuffle()
	# 轮询分到各 row
	var row_ptr: int = 0
	for t in others:
		# 每排上限 3
		var safety: int = 0
		while rows[row_ptr].size() >= 3 and safety < inner_rows:
			row_ptr = (row_ptr + 1) % inner_rows
			safety += 1
		rows[row_ptr].append(t)
		row_ptr = (row_ptr + 1) % inner_rows

	# 把 elite 插入 row >= 1
	for e in elites:
		var target_row: int = 1 + (rng.randi() % max(1, inner_rows - 1))
		var safety2: int = 0
		while rows[target_row].size() >= 3 and safety2 < inner_rows:
			target_row = 1 + ((target_row + 1 - 1) % max(1, inner_rows - 1))
			safety2 += 1
		rows[target_row].append(e)

	# 约束：Boss 前一排（最后一个 inner row）必须含至少一个 rest/shop/puzzle
	var last_row: Array = rows[inner_rows - 1]
	var has_adjust: bool = false
	for t in last_row:
		if str(t) in ["rest", "shop", "puzzle"]:
			has_adjust = true
			break
	if not has_adjust:
		# 从 last_row 找一个 battle 替换为 rest（如没 battle 就换第一个）
		var swap_idx: int = -1
		for i in last_row.size():
			if str(last_row[i]) == "battle":
				swap_idx = i
				break
		if swap_idx == -1 and last_row.size() > 0:
			swap_idx = 0
		if swap_idx >= 0:
			last_row[swap_idx] = "rest"
			rows[inner_rows - 1] = last_row

	# 保证每排至少 1 节点
	for i in inner_rows:
		var bucket: Array = rows[i]
		if bucket.is_empty():
			# 从最长那排借一个非 elite
			var donor: int = 0
			for j in inner_rows:
				if rows[j].size() > rows[donor].size():
					donor = j
			if rows[donor].size() > 1:
				var item: Variant = rows[donor].pop_back()
				if i == 0 and str(item) == "elite":
					# row 0 不能放 elite —— 换成 battle
					rows[donor].append(item)
					bucket.append("battle")
				else:
					bucket.append(item)
				rows[i] = bucket
	return rows


static func _build_connections(nodes: Array[RunNode], total_rows: int, rng: RandomNumberGenerator) -> Dictionary:
	# 用 row -> Array[RunNode] 索引
	var by_row: Dictionary = {}
	for n in nodes:
		var arr: Array = by_row.get(n.row, [])
		arr.append(n)
		by_row[n.row] = arr

	var conns: Dictionary = {}

	# row 0 .. total_rows-2 → 连到下一排
	for r in total_rows - 1:
		var cur_arr: Array = by_row.get(r, [])
		var next_arr: Array = by_row.get(r + 1, [])
		# 每个当前节点：连到下一排中 col 距离最近的 1-2 个
		for cur_idx in cur_arr.size():
			var cur: RunNode = cur_arr[cur_idx]
			var picks: Array[String] = _pick_neighbors(cur, next_arr, rng)
			conns[cur.id] = picks
		# 反向保证：下一排每个节点至少有 1 条入边
		var inbound: Dictionary = {}
		for cur_node in cur_arr:
			for tgt in conns.get(cur_node.id, []):
				inbound[tgt] = true
		for nxt in next_arr:
			if not inbound.has(nxt.id):
				# 找 cur_arr 里 col 最近的一个，把它的 picks 追加到 nxt
				var closest: RunNode = _closest_by_col(nxt, cur_arr)
				if closest != null:
					var existing: Variant = conns.get(closest.id, [])
					var existing_arr: Array[String] = []
					if existing is Array:
						for x in existing:
							existing_arr.append(str(x))
					if not nxt.id in existing_arr:
						existing_arr.append(nxt.id)
					conns[closest.id] = existing_arr

	# Boss 行无出边
	if by_row.has(total_rows - 1):
		for boss_n in by_row[total_rows - 1]:
			conns[boss_n.id] = [] as Array[String]

	return conns


static func _pick_neighbors(cur: RunNode, next_arr: Array, rng: RandomNumberGenerator) -> Array[String]:
	# 选 col 距离 ≤ 1 的 1-2 个节点
	var candidates: Array = []
	for n in next_arr:
		if abs(n.col - cur.col) <= 1:
			candidates.append(n)
	if candidates.is_empty() and next_arr.size() > 0:
		# 没有相邻就连最近的一个
		candidates.append(_closest_by_col(cur, next_arr))
	candidates.shuffle()
	var pick_count: int = 1
	if candidates.size() >= 2 and rng.randf() < 0.45:
		pick_count = 2
	var out: Array[String] = []
	for i in min(pick_count, candidates.size()):
		var c: RunNode = candidates[i]
		out.append(c.id)
	return out


static func _closest_by_col(target: RunNode, arr: Array) -> RunNode:
	var best: RunNode = null
	var best_d: int = 99
	for n in arr:
		var d: int = abs(n.col - target.col)
		if d < best_d:
			best_d = d
			best = n
	return best


## 测试辅助：从 RunMap 起点做 BFS，返回所有可达节点 ID 集合
static func compute_reachable_from_start(run_map: RunMap) -> Dictionary:
	var visited: Dictionary = {}
	var frontier: Array[String] = []
	for n in run_map.get_start_nodes():
		frontier.append(n.id)
		visited[n.id] = true
	while frontier.size() > 0:
		var cur: String = frontier.pop_front()
		for nxt in run_map.get_next_reachable(cur):
			if not visited.has(nxt):
				visited[nxt] = true
				frontier.append(nxt)
	return visited
