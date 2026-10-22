extends Node
## Leaderboard + play counters on Supabase (autoload "Net"). Every call is a POST to a database function
## (supabase/migrations/): submit_run, top_runs, count_event. Only the public key lives here; the database validates
## every write. Failures never interrupt the game: callers get {ok = false, error = "..."} and show "offline".
##   --net=fake     canned answers, no network (probes; the autopilot uses it too)
##   --net=offline  every call fails (probes)
##   --no-net       no network at all (the default in headless runs and under --autopilot)

const URL := "https://aspruukfevqvoefvgpbr.supabase.co"
const KEY := "sb_publishable_6A2OXGxpl9Dq7Vn01S6BgA_BMfINHoS"   # the project's public anon / publishable key (Supabase > Project Settings > API keys)
const TIMEOUT := 6.0

var mode := "live"   # live | fake | offline | off
var calls: Array[Dictionary] = []   # {fn, body, ok} of every call that reached the network layer (probes read it)
var _fake_runs: Array = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--net=fake" in args:
		mode = "fake"
	elif "--net=offline" in args:
		mode = "offline"
	elif "--no-net" in args or "--autopilot" in args or DisplayServer.get_name() == "headless" or KEY == "":
		mode = "off"
	GameEvent.marker("NET", "mode=%s" % mode)


## A won game. Returns {ok, data = {id, score, rank_all, rank_week}} or {ok = false, error = bad_nick | implausible |
## too_fast | offline}.
func submit_run(nick: String, b: Board, island: int, seed_value: int) -> Dictionary:
	return await call_fn("submit_run", {"p_nick": nick, "p_gold": b.gold, "p_crew": b.crew, "p_turns": b.turns,
		"p_island": island, "p_seed": seed_value})


## Top 10 of "all" or "week": {ok, data = [{id, nick, score, turns, island, created_at}, ...]}.
func top_runs(period: String) -> Dictionary:
	return await call_fn("top_runs", {"p_period": period})


## Play counter (loaded | played | won | lost), fire and forget.
func count(event: String, island: int) -> void:
	call_fn("count_event", {"p_event": event, "p_island": island})


func call_fn(fn: String, body: Dictionary) -> Dictionary:
	var res: Dictionary
	match mode:
		"off":
			res = {"ok": false, "error": "offline"}
		"offline":
			await get_tree().process_frame
			res = {"ok": false, "error": "offline"}
		"fake":
			await get_tree().process_frame
			res = _fake(fn, body)
		_:
			res = await _post(fn, body)
	if mode != "off":
		calls.append({"fn": fn, "body": body, "ok": res["ok"]})
		GameEvent.marker("NET", "fn=%s ok=%s%s" % [fn, res["ok"], "" if res["ok"] else " error=%s" % res["error"]])
	return res


func _post(fn: String, body: Dictionary) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	# Web: the browser has already gunzipped the body, but Supabase exposes Content-Encoding: gzip, so Godot would
	# gunzip it again and fail (RESULT_BODY_DECOMPRESS_FAILED). The replies are tiny; don't ask for gzip at all.
	http.accept_gzip = false
	add_child(http)
	var headers := PackedStringArray(["Content-Type: application/json", "apikey: " + KEY])
	if KEY.begins_with("eyJ"):   # a legacy anon key is a JWT and also goes in Authorization; a publishable key does not
		headers.append("Authorization: Bearer " + KEY)
	var err := http.request("%s/rest/v1/rpc/%s" % [URL, fn], headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		return {"ok": false, "error": "offline"}
	var r: Array = await http.request_completed
	http.queue_free()
	var code: int = r[1]
	var text := (r[3] as PackedByteArray).get_string_from_utf8()
	var data: Variant = JSON.parse_string(text) if text != "" else null
	if r[0] != HTTPRequest.RESULT_SUCCESS:
		GameEvent.marker("NET", "fn=%s result=%d" % [fn, r[0]])
		return {"ok": false, "error": "offline"}
	if code >= 200 and code < 300:
		return {"ok": true, "data": data}
	# a function's `raise exception 'x'` arrives as {"message": "x", ...}
	var msg := "offline"
	if data is Dictionary and data.get("message", "") in ["bad_nick", "implausible", "too_fast"]:
		msg = data["message"]
	return {"ok": false, "error": msg}


func _fake(fn: String, body: Dictionary) -> Dictionary:
	match fn:
		"submit_run":
			if not NickFilter.is_ok(String(body["p_nick"])):
				return {"ok": false, "error": "bad_nick"}
			var score: int = body["p_gold"] + body["p_crew"] * 100 + maxi(0, 400 - 2 * int(body["p_turns"]))
			var run := {"id": 1000 + _fake_runs.size(), "nick": body["p_nick"], "score": score,
				"turns": body["p_turns"], "island": body["p_island"], "created_at": ""}
			_fake_runs.append(run)
			var rank := 1 + _fake_rows().filter(func(x): return x["score"] > score).size()
			return {"ok": true, "data": {"id": run["id"], "score": score, "rank_all": rank, "rank_week": rank}}
		"top_runs":
			var rows := _fake_rows()
			rows.sort_custom(func(a, b): return a["score"] > b["score"] or (a["score"] == b["score"] and a["turns"] < b["turns"]))
			return {"ok": true, "data": rows.slice(0, 10)}
	return {"ok": true, "data": null}


func _fake_rows() -> Array:
	var rows: Array = []
	for i in 12:   # more than ten, so a weak run lands outside the top 10
		rows.append({"id": i + 1, "nick": "BOT%d" % i, "score": 1100 - i * 60, "turns": 60 + i, "island": i % 25,
			"created_at": ""})
	rows.append_array(_fake_runs)
	return rows
