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

signal health_checked(ok: bool, detail: String)
signal levels_fetched(levels: Array, error: String)
signal score_submitted(ok: bool, error: String)

var base_url: String = ""
var player_id: String = "guest"
var _http: HTTPRequest = null


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
	_request(base_url.path_join("api/health"), HTTPClient.METHOD_GET)


func fetch_levels() -> void:
	if not is_enabled():
		emit_signal("levels_fetched", [], "disabled")
		return
	_request(base_url.path_join("api/levels"), HTTPClient.METHOD_GET)


func submit_score(level_id: String, score: int, win: bool) -> void:
	if not is_enabled():
		emit_signal("score_submitted", false, "disabled")
		return
	var body := JSON.stringify({
		"player_id": player_id, "level_id": level_id,
		"score": score, "win": win,
	})
	_request(base_url.path_join("api/score"), HTTPClient.METHOD_POST,
		["Content-Type: application/json"], body)


# --- internals ---------------------------------------------------------------

func _request(url: String, method: int, headers: PackedStringArray = PackedStringArray(), body: String = "") -> void:
	if _http == null:
		_http = HTTPRequest.new()
		_http.use_threads = false if _is_web() else true
		add_child(_http)
		_http.request_completed.connect(_on_completed)
	Log.api("request %s %s" % [HTTPRequest.get_method_string(method) if false else _method_name(method), url])
	var err := _http.request(url, headers, method, body)
	if err != OK:
		_on_completed(err, -1, PackedStringArray(), PackedByteArray())


func _is_web() -> bool:
	return OS.has_feature("web_android") or OS.has_feature("web_linux") \
		or OS.has_feature("web_windows") or OS.has_feature("web_macos") \
		or OS.has_feature("web_ios")


func _method_name(m: int) -> String:
	match m:
		HTTPClient.METHOD_GET: return "GET"
		HTTPClient.METHOD_POST: return "POST"
	return "?"


var _last_purpose: String = ""

func _on_completed(result: int, status: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
	var ok := result == HTTPRequest.RESULT_SUCCESS and status >= 200 and status < 300
	var text := bytes.get_string_from_utf8()
	if not ok:
		Log.api("request failed (result=%d http=%d) — game continues offline" % [result, status])
	if _last_purpose == "levels":
		var parsed: Variant = JSON.parse_string(text) if ok else null
		var arr: Array = parsed.get("levels", []) if typeof(parsed) == TYPE_DICTIONARY else []
		emit_signal("levels_fetched", arr, "" if ok else "unavailable")
	elif _last_purpose == "score":
		emit_signal("score_submitted", ok, "" if ok else "unavailable")
	else:
		emit_signal("health_checked", ok, text.left(120))
	_last_purpose = ""
