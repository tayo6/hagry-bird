extends Node
class_name ApiClient
## Optional HTTP backend client — future-ready interface only.
##
## API contract (a real Go server can implement exactly this):
##   GET  {base}/api/health          -> {"status":"ok"}
##   GET  {base}/api/levels          -> same schema as generated/levels.json
##   POST {base}/api/score           -> body {"player_id","level_id","score","win"}
##
## The game NEVER depends on this being reachable: if GameSettings.api_base_url
## is empty (default), every call short-circuits and everything keeps working
## fully offline. This class exists so leaderboards/cloud-save/downloadable
## levels can be added later without touching game code.
##
## Concurrency safety: each request gets its OWN HTTPRequest node, and the
## request's purpose ("health" / "levels" / "score") is bound into that node's
## completion callback via a lambda closure. There is no shared mutable
## "_last_purpose" field, so overlapping requests can never corrupt routing.

signal health_checked(ok: bool, detail: String)
signal levels_fetched(levels: Array, error: String)
signal score_submitted(ok: bool, error: String)

var base_url: String = ""
var player_id: String = "guest"


func _ready() -> void:
	base_url = GameSettings.api_base_url
	if base_url != "":
		Log.api("backend enabled: %s" % base_url)
	else:
		Log.api("backend disabled (offline mode) — set GameSettings.api_base_url to enable")


func is_enabled() -> bool:
	return base_url != ""


func check_health() -> void:
	if not is_enabled():
		emit_signal("health_checked", false, "disabled")
		return
	_request("health", base_url.path_join("api/health"), HTTPClient.METHOD_GET)


func fetch_levels() -> void:
	if not is_enabled():
		emit_signal("levels_fetched", [], "disabled")
		return
	_request("levels", base_url.path_join("api/levels"), HTTPClient.METHOD_GET)


func submit_score(level_id: String, score: int, win: bool) -> void:
	if not is_enabled():
		emit_signal("score_submitted", false, "disabled")
		return
	var body := JSON.stringify({
		"player_id": player_id, "level_id": level_id,
		"score": score, "win": win,
	})
	_request("score", base_url.path_join("api/score"), HTTPClient.METHOD_POST,
		["Content-Type: application/json"], body)


# --- internals ---------------------------------------------------------------

## Spawns a dedicated one-shot HTTPRequest node per call. The `purpose` string
## is captured by the lambda below, so completion routing is per-request and
## immune to concurrent calls.
func _request(purpose: String, url: String, method: int,
		headers: PackedStringArray = PackedStringArray(), body: String = "") -> void:
	var http := HTTPRequest.new()
	http.use_threads = false if _is_web() else true
	add_child(http)
	http.request_completed.connect(
		func(result: int, status: int, _resp_headers: PackedStringArray, bytes: PackedByteArray) -> void:
			_on_completed(purpose, result, status, bytes)
			http.queue_free()
	)
	Log.api("request %s %s" % [_method_name(method), url])
	var err := http.request(url, headers, method, body)
	if err != OK:
		# Immediate failure: synthesize a completion so callers always get a signal.
		_on_completed(purpose, HTTPRequest.RESULT_CANT_CONNECT, -1, PackedByteArray())
		http.queue_free()


func _on_completed(purpose: String, result: int, status: int, bytes: PackedByteArray) -> void:
	var ok := result == HTTPRequest.RESULT_SUCCESS and status >= 200 and status < 300
	var text := bytes.get_string_from_utf8()
	if not ok:
		Log.api("request failed (result=%d http=%d) — game continues offline" % [result, status])
	match purpose:
		"levels":
			var parsed: Variant = JSON.parse_string(text) if ok else null
			var arr: Array = parsed.get("levels", []) if typeof(parsed) == TYPE_DICTIONARY else []
			emit_signal("levels_fetched", arr, "" if ok else "unavailable")
		"score":
			emit_signal("score_submitted", ok, "" if ok else "unavailable")
		_:
			emit_signal("health_checked", ok, text.left(120))


func _is_web() -> bool:
	return OS.has_feature("web_android") or OS.has_feature("web_linux") \
		or OS.has_feature("web_windows") or OS.has_feature("web_macos") \
		or OS.has_feature("web_ios")


func _method_name(m: int) -> String:
	match m:
		HTTPClient.METHOD_GET: return "GET"
		HTTPClient.METHOD_POST: return "POST"
	return "?"
