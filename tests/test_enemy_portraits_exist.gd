## test_enemy_portraits_exist — Slice 11 防回归
##
## enemies.json + bosses.json 里 portrait_path 指向的 PNG 必须真存在；
## 否则战斗里头像是空。
extends GutTest


func _all_portrait_paths() -> Array[String]:
	var out: Array[String] = []
	var files: Array[String] = ["enemies.json", "bosses.json"]
	for fname in files:
		var path: String = "res://src/content/english/data/" + fname
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var raw: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if not (raw is Dictionary):
			continue
		var key: String = "enemies" if fname == "enemies.json" else "bosses"
		var arr: Variant = raw.get(key, [])
		if not (arr is Array):
			continue
		for e in arr:
			if e is Dictionary:
				var p: String = str(e.get("portrait_path", ""))
				if p != "":
					out.append(p)
	return out


func test_all_referenced_portraits_load() -> void:
	var paths := _all_portrait_paths()
	assert_gt(paths.size(), 0, "enemies+bosses should reference portraits")
	var missing: Array[String] = []
	for p in paths:
		if not ResourceLoader.exists(p):
			missing.append(p)
	assert_eq(missing, [] as Array[String],
		"all portrait_path PNGs must exist; missing: %s" % str(missing))


func test_anime_characters_remap_applied() -> void:
	# Slice 11 后大部分 portrait 应指向 anime_characters/，不再是程序化 portraits/
	var paths := _all_portrait_paths()
	var anime_count: int = 0
	for p in paths:
		if p.find("anime_characters/") >= 0:
			anime_count += 1
	assert_gt(anime_count, 10,
		"after Slice 11 remap, expect >10 portraits use anime_characters/ (got %d)" % anime_count)
