extends SceneTree
## Acceptance test for scripts/nick_filter.gd and data/blocked_words.json. Run: tools/test.sh tests/test_nick_filter.gd

var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)


func _init() -> void:
	# clean: upper-case, only A-Z 0-9, at most 5
	check(NickFilter.clean("abc") == "ABC", "clean upper")
	check(NickFilter.clean("a b-c!") == "ABC", "clean drops other chars")
	check(NickFilter.clean("Henrik42") == "HENRI", "clean cuts to 5")
	check(NickFilter.clean("æøå") == "", "clean drops non-ASCII letters")
	check(NickFilter.clean("") == "", "clean empty")
	# normalize: leetspeak digits
	check(NickFilter.normalize("F0CK") == "FOCK", "normalize 0")
	check(NickFilter.normalize("5H17") == "SHIT", "normalize 5 1 7")
	check(NickFilter.normalize("B00B5") == "BOOBS", "normalize 0 and 5, letters stay")
	check(NickFilter.normalize("8") == "B", "normalize 8")
	check(NickFilter.normalize("2 6 9") == "2 6 9", "normalize leaves 2 6 9")

	# harmless names pass
	for n in ["HENRI", "ANNA", "BOB", "A", "Z9", "12345", "KLASS", "BASSE", "PIKE", "SPIKE", "TITAN", "SHORE",
			"GRAPE", "DRAPE", "MASSE", "KASSE", "CLASS", "GLASS", "PASTA", "SPICE", "CUMIN", "PARSE", "SWANK", "WHORL", "MANUS", "LOCUM", "OTTO", "HORSE", "TOM", "MAX", "LUKAS",
			"SUSSI", "EXTRA", "PISA", "KRAPE"]:
		check(NickFilter.is_ok(n), "harmless %s passes" % n)

	# blocked: substrings, leetspeak, Danish, exact-only words
	for n in ["FUCK", "FUCKS", "XFUCK", "FUCK1", "FVCK", "F4CK", "FUQ", "PHUK", "FCUK", "CVNT", "DIK", "5H1T", "SHIT", "CUNT", "C0CK",
			"N1GGA", "NAZI", "N4Z1", "HITLR", "FISSE", "F155E", "KUSSE", "LUDER", "PERKE", "LORT", "KNEP",
			"PISS", "P155", "CUM", "WANK", "WANKS", "ARSE", "ANUS", "ASS", "455", "PIK", "P1K", "TIT", "HORE", "H0RE", "SS", "55", "KYS", "RAPE",
			"R4P3", "RAPED", "PENIS", "SEXY", "WANK", "BITCH", "SLUT", "5LUT", "PORN", "P0RN"]:
		check(not NickFilter.is_ok(n), "offensive %s blocked" % n)

	# shape rules
	check(not NickFilter.is_ok(""), "empty rejected")
	check(not NickFilter.is_ok("ABCDEF"), "6 chars rejected")
	check(not NickFilter.is_ok("abc"), "lower case rejected (clean first)")
	check(not NickFilter.is_ok("A B"), "space rejected")

	# every blocklist entry is well-formed and blocks itself
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/blocked_words.json"))
	check(data is Dictionary and data["words"].size() > 50, "blocklist loads (%s words)" % (data["words"].size() if data is Dictionary else 0))
	if data is Dictionary:
		var re := RegEx.create_from_string("^=?[A-Z]{2,5}$")
		for w in data["words"]:
			var word := String(w)
			check(re.search(word) != null, "word %s is =?[A-Z]{2,5}" % word)
			check(not NickFilter.is_ok(word.trim_prefix("=")), "word %s blocks itself" % word)

	print("ALL TESTS PASSED" if fails == 0 else "%d FAILED" % fails)
	quit(1 if fails else 0)
