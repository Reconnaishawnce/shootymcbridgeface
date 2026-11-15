extends TestCase


func test_shake() -> void:
	var s := Shake.new()
	var still := Vector3(0.0, -9.81, 0.0)
	for i in range(60):
		check(not s.feed(still, float(i) * 0.016), "a phone lying still never shakes")
	var t := 2.0
	var shaken := false
	# Four hard swings a tenth of a second apart.
	for i in range(4):
		var a := Vector3(25.0 if i % 2 == 0 else -25.0, -9.81, 0.0)
		if s.feed(a, t):
			shaken = true
		t += 0.1
	check(shaken, "four jolts in a second is a shake")
	check(not s.feed(Vector3(25.0, -9.81, 0.0), t + 0.1), "and then a cooldown")
	var slow := Shake.new()
	var any := false
	for i in range(4):
		if slow.feed(Vector3(25.0, -9.81, 0.0), float(i) * 0.5):
			any = true
	check(not any, "four jolts spread over two seconds are not a shake")
	var fast := Shake.new()
	var n := 0
	for i in range(20):
		if fast.feed(Vector3(25.0, -9.81, 0.0), float(i) * 0.01):
			n += 1
	check_eq(n, 0, "one long swing sampled twenty times is one jolt, not twenty")
	check(not Shake.has_sensor(Vector3.ZERO) and Shake.has_sensor(still), "a desktop has no sensor")
