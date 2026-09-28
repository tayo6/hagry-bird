extends Node
class_name Log
## Tiny tagged-logger used across the project.
##
## Tags match the CI/debug requirements:
##   [BOOT] [LEVEL] [PHYSICS] [INPUT] [GO DATA] [EXPORT] [API] [UI]
##
## Logs are one-shot or event-driven only; nothing in the game logs per frame.

enum Level { QUIET = 0, INFO = 1, DEBUG = 2 }

static var verbosity: int = Level.INFO

static func set_verbosity(v: int) -> void:
	verbosity = v

# --- tag helpers -----------------------------------------------------------

static func boot(msg: String) -> void:
	_print("BOOT", msg)

static func level(msg: String) -> void:
	_print("LEVEL", msg)

static func physics(msg: String) -> void:
	_print("PHYSICS", msg)

static func input_ev(msg: String) -> void:
	_print("INPUT", msg)

static func go_data(msg: String) -> void:
	_print("GO DATA", msg)

static func export_tag(msg: String) -> void:
	_print("EXPORT", msg)

static func api(msg: String) -> void:
	_print("API", msg)

static func ui(msg: String) -> void:
	_print("UI", msg)

static func error(tag: String, msg: String) -> void:
	push_error("[%s] %s" % [tag, msg])
	printerr("[ERROR][%s] %s" % [tag, msg])

static func debug(tag: String, msg: String) -> void:
	if verbosity >= Level.DEBUG:
		print("[DEBUG][%s] %s" % [tag, msg])

static func _print(tag: String, msg: String) -> void:
	if verbosity >= Level.INFO:
		print("[%s] %s" % [tag, msg])
