extends ProbeBase
## Acceptance probe for T19 (treasure effects). Run: tools/probe.sh tests/play_treasure.tscn 90 "TREASURE OK" --skip-intro


func run() -> void:
	var fx = main.get("fx")
	var hud = main.hud
	check(fx != null and fx.has_method("treasure"), "main.fx has treasure()")
	check(hud.has_method("fly_coins") and hud.has_method("count_gold"), "hud has fly_coins() and count_gold()")
	if fx == null or not fx.has_method("treasure") or not hud.has_method("count_gold"):
		print("TREASURE FAILED")
		return
	await land()
	await wait(1.0)
	var gold_label := hud.find_child("Gold", true, false) as Label

	# a chest's worth of gold at a tile next to the camp
	var b = main.board
	var keys: Array = b.revealed.keys()
	var at: Vector3 = Hex.to_world(keys[0]) + Vector3(0, Art.TILE_TOP, 0)
	var before: int = b.gold
	b.gold += 30
	hud.update_from(b)
	check(gold_label.text == "Gold %d" % b.gold, "update_from still shows the new gold at once (%s)" % gold_label.text)
	fx.treasure(at, 30)
	hud.count_gold(before, b.gold, 0.8)
	await frames(2)
	check(fx.find_child("Sparkle", true, false) is CPUParticles3D, "the chest sparkles")
	var coins: Array = hud.find_children("Coin*", "Control", true, false)
	check(coins.size() >= 3 and coins.size() <= 8, "3 to 8 coins fly (%d)" % coins.size())
	await wait(0.3)
	var counting := gold_label.text != "Gold %d" % b.gold and gold_label.text.begins_with("Gold ")
	check(counting, "the gold counter is still counting up (%s)" % gold_label.text)
	# coins move towards the gold label
	var target: Vector2 = gold_label.get_global_rect().get_center()
	var closer := 0
	coins = hud.find_children("Coin*", "Control", true, false)
	var d0: Array = coins.map(func(c): return (c as Control).get_global_rect().get_center().distance_to(target))
	await wait(0.15)
	for i in coins.size():
		if is_instance_valid(coins[i]) and (coins[i] as Control).get_global_rect().get_center().distance_to(target) < d0[i]:
			closer += 1
	check(closer > 0, "coins fly towards the gold counter (%d)" % closer)
	await wait(1.2)
	check(gold_label.text == "Gold %d" % b.gold, "the counter ends on the gold (%s)" % gold_label.text)
	check(hud.find_children("Coin*", "Control", true, false).is_empty(), "the coins are gone")
	check(fx.find_child("Sparkle", true, false) == null, "the sparkle is gone")
	print("TREASURE OK" if fails == 0 else "TREASURE FAILED: %d" % fails)
