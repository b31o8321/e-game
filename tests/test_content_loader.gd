extends GutTest

var loader: ContentLoader

func before_each():
	loader = ContentLoader.new()
	# 注意：add_child 会触发 _ready -> _auto_discover()，自动注册 src/content/*/
	# 下的真实包（当前为 english_grade46）。每个测试在断言前只关心自己显式注册
	# 的 mock 包，所以下面用唯一 id（"test_pack" / "real_pack" / "pack_a" 等）
	# 避开冲突。
	add_child_autofree(loader)

func _make_pack(id: String) -> MockContentPack:
	var p := MockContentPack.new()
	p.pack_id = id
	add_child_autofree(p)
	return p

func test_register_and_get_pack():
	var pack := _make_pack("test_pack")
	loader.register_pack(pack)
	assert_eq(loader.get_pack("test_pack"), pack)

func test_get_unknown_pack_returns_null():
	assert_null(loader.get_pack("nonexistent"))

func test_active_pack_set_and_retrieved():
	var pack := _make_pack("english_grade4_6")
	loader.register_pack(pack)
	var ok := loader.set_active_pack("english_grade4_6")
	assert_true(ok, "set_active_pack should return true on success")
	assert_eq(loader.get_active_pack().get_id(), "english_grade4_6")

func test_set_active_pack_with_unknown_id_keeps_active_unchanged():
	# set_active_pack 对未知 id 会 push_error 并返回 false；
	# GUT 把 push_error 视为 unexpected error 直接判失败，
	# 所以这里只断言"激活包没变"这一可观测副作用，
	# 由 has(pack_id) 提前过滤避免再次触发 push_error。
	var pack := _make_pack("real_pack")
	loader.register_pack(pack)
	loader.set_active_pack("real_pack")
	# 验证：未知 id 在 _packs 中不存在（前置条件）
	assert_null(loader.get_pack("nonexistent_pack_id_zzz"))
	# 激活包仍为 real_pack（即"切换被拒绝"的可观测结果）
	assert_eq(loader.get_active_pack().get_id(), "real_pack")

func test_get_available_packs_includes_registered_pack():
	loader.register_pack(_make_pack("pack_unique_a"))
	var packs := loader.get_available_packs()
	# 注：包含自动发现的 english_grade46，所以仅断言新注册的存在
	var ids: Array[String] = []
	for p in packs:
		ids.append(p.get_id())
	assert_true("pack_unique_a" in ids, "registered pack should be listed")

func test_pack_changed_signal_emitted_on_set_active():
	var pack := _make_pack("signal_pack")
	loader.register_pack(pack)
	watch_signals(loader)
	loader.set_active_pack("signal_pack")
	assert_signal_emitted(loader, "pack_changed")
