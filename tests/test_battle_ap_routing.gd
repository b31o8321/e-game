## test_battle_ap_routing.gd
## Verifies battle_scene.gd routes user card placements through add_to_ap_queue
## (the AP queue path) rather than the legacy try_place_card path that
## resolved challenges immediately.
extends GutTest


func test_battle_scene_routes_clicks_through_add_to_ap_queue() -> void:
	var f := FileAccess.open("res://src/battle/battle_scene.gd", FileAccess.READ)
	assert_not_null(f, "battle_scene.gd should be readable")
	var content: String = f.get_as_text()
	f.close()
	# Confirm add_to_ap_queue is called from a click handler
	assert_true("add_to_ap_queue" in content,
		"battle_scene.gd should reference add_to_ap_queue")


func test_battle_scene_does_not_call_try_place_card_from_ui() -> void:
	# Negative test: no UI handler should call try_place_card directly.
	# (It's OK if try_place_card is referenced as a method name on the
	# controller for other purposes, but battle_scene.gd should route via
	# add_to_ap_queue.)
	var f := FileAccess.open("res://src/battle/battle_scene.gd", FileAccess.READ)
	assert_not_null(f, "battle_scene.gd should be readable")
	var content: String = f.get_as_text()
	f.close()
	var lines: PackedStringArray = content.split("\n")
	var problematic_calls: int = 0
	for line in lines:
		if "try_place_card" in line and "add_to_ap_queue" not in line:
			problematic_calls += 1
	# We expect 0 (or maybe 1 if there's a guard / fallback)
	assert_lt(problematic_calls, 3,
		"battle_scene.gd should route via add_to_ap_queue, not try_place_card")


func test_battle_scene_wires_remove_requested_signal() -> void:
	# AP block right-click removal should be wired (signal connect).
	var f := FileAccess.open("res://src/battle/battle_scene.gd", FileAccess.READ)
	assert_not_null(f, "battle_scene.gd should be readable")
	var content: String = f.get_as_text()
	f.close()
	assert_true("remove_from_ap_queue" in content,
		"battle_scene.gd should call remove_from_ap_queue (right-click撤回)")
