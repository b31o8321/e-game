extends GutTest

var loader: ContentLoader

func before_each():
	loader = ContentLoader.new()
	add_child_autofree(loader)

func test_register_and_get_pack():
	var pack = ContentPackBase.new()
	pack.pack_id = "test_pack"
	pack.subject = "english"
	loader.register_pack(pack)
	assert_eq(loader.get_pack("test_pack"), pack)

func test_get_unknown_pack_returns_null():
	assert_null(loader.get_pack("nonexistent"))

func test_active_pack_set_and_retrieved():
	var pack = ContentPackBase.new()
	pack.pack_id = "english_grade4_6"
	loader.register_pack(pack)
	loader.set_active_pack("english_grade4_6")
	assert_eq(loader.get_active_pack().pack_id, "english_grade4_6")

func test_set_active_pack_with_unknown_id_does_not_change_active():
	var pack = ContentPackBase.new()
	pack.pack_id = "real_pack"
	loader.register_pack(pack)
	loader.set_active_pack("real_pack")
	loader.set_active_pack("nonexistent")
	assert_eq(loader.get_active_pack().pack_id, "real_pack")
