extends GutTest

var controller: CityController
var mock_pack: MockContentPack

func before_each() -> void:
	controller = CityController.new()
	add_child_autofree(controller)
	mock_pack = MockContentPack.new()
	controller.setup(mock_pack)
	GameState.city_building_levels = {}
	GameState.inventory_resources = {}

func test_upgrade_increases_building_level() -> void:
	GameState.inventory_resources = { "vocabulary_crystal": 10 }
	controller.upgrade_building("vocabulary_library")
	assert_eq(GameState.city_building_levels.get("vocabulary_library", 0), 1)

func test_upgrade_deducts_resources() -> void:
	GameState.inventory_resources = { "vocabulary_crystal": 10 }
	controller.upgrade_building("vocabulary_library")
	assert_eq(GameState.inventory_resources.get("vocabulary_crystal", 0), 7)

func test_upgrade_returns_true_on_success() -> void:
	GameState.inventory_resources = { "vocabulary_crystal": 10 }
	var result: bool = controller.upgrade_building("vocabulary_library")
	assert_true(result)

func test_upgrade_fails_insufficient_resources() -> void:
	GameState.inventory_resources = { "vocabulary_crystal": 1 }
	var result: bool = controller.upgrade_building("vocabulary_library")
	assert_false(result)
	assert_eq(GameState.city_building_levels.get("vocabulary_library", 0), 0)

func test_upgrade_fails_at_max_level() -> void:
	GameState.city_building_levels = { "vocabulary_library": 3 }
	GameState.inventory_resources = { "vocabulary_crystal": 100 }
	var result: bool = controller.upgrade_building("vocabulary_library")
	assert_false(result)
	assert_eq(GameState.city_building_levels.get("vocabulary_library"), 3)

func test_can_afford_returns_true_when_affordable() -> void:
	GameState.inventory_resources = { "vocabulary_crystal": 5 }
	assert_true(controller.can_afford_upgrade("vocabulary_library"))

func test_can_afford_returns_false_when_not_affordable() -> void:
	GameState.inventory_resources = { "vocabulary_crystal": 2 }
	assert_false(controller.can_afford_upgrade("vocabulary_library"))

func test_get_buildings_returns_pack_data() -> void:
	var buildings: Array[Dictionary] = controller.get_buildings()
	assert_eq(buildings.size(), 2)
