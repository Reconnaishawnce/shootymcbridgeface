extends SceneTree
## Headless unit test runner.
## Usage: godot --headless --path . -s tests/run_tests.gd
## Exit code is non-zero when any test fails.

const TEST_SCRIPTS := [
	"res://tests/test_gate_math.gd",
	"res://tests/test_difficulty.gd",
	"res://tests/test_formation.gd",
	"res://tests/test_save_data.gd",
	"res://tests/test_sfx.gd",
	"res://tests/test_perks.gd",
	"res://tests/test_meta.gd",
	"res://tests/test_daily.gd",
	"res://tests/test_gate_math_extra.gd",
	"res://tests/test_wardrobe.gd",
	"res://tests/test_run11.gd",
	"res://tests/test_run12.gd",
	"res://tests/test_run13.gd",
	"res://tests/test_convoy.gd",
	"res://tests/test_goals.gd",
	"res://tests/test_season.gd",
	"res://tests/test_road.gd",
	"res://tests/test_report.gd",
	"res://tests/test_combo.gd",
	"res://tests/test_powerups.gd",
	"res://tests/test_progression.gd",
]


func _init() -> void:
	var total := 0
	var failed := 0
	for path in TEST_SCRIPTS:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			print("FAIL could not load or compile %s" % path)
			failed += 1
			continue
		var inst: TestCase = script.new()
		print(path)
		for m in inst.get_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			total += 1
			inst.failures = []
			inst.call(name)
			if inst.failures.is_empty():
				print("  PASS %s" % name)
			else:
				failed += 1
				print("  FAIL %s" % name)
				for f in inst.failures:
					print("       - %s" % f)
	print("")
	print("%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
