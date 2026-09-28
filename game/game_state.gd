extends Node
class_name GameState
## Pure game-state machine + score keeper (no scene dependencies).
##
## States: LOADING -> AIMING -> FLYING -> SETTLING -> (AIMING | WON | LOST)
## Kept separate from the world so it can be unit-tested headlessly.

enum State { LOADING, AIMING, FLYING, SETTLING, WON, LOST }

signal state_changed(state: State)
signal score_changed(score: int)
signal targets_changed(remaining: int, total: int)
signal ammo_changed(remaining: int)

var state: State = State.LOADING:
	set(value):
		if state == value:
			return
		state = value
		emit_signal("state_changed", value)

var score: int = 0:
	set(value):
		score = maxi(value, 0)
		emit_signal("score_changed", score)

var targets_total: int = 0
var targets_remaining: int = 0
var projectiles_total: int = 0
var projectiles_remaining: int = 0


func begin_level(target_count: int, projectile_count: int) -> void:
	targets_total = target_count
	targets_remaining = target_count
	projectiles_total = projectile_count
	projectiles_remaining = projectile_count
	score = 0
	emit_signal("targets_changed", targets_remaining, targets_total)
	emit_signal("ammo_changed", projectiles_remaining)
	Log.level("state: level armed (%d targets, %d shots)" % [target_count, projectile_count])
	state = State.AIMING


func spend_projectile() -> void:
	projectiles_remaining = maxi(projectiles_remaining - 1, 0)
	emit_signal("ammo_changed", projectiles_remaining)


func register_target_destroyed(points: int) -> void:
	targets_remaining = maxi(targets_remaining - 1, 0)
	score += points
	emit_signal("targets_changed", targets_remaining, targets_total)


func add_score(points: int) -> void:
	score += points


func remaining_targets() -> int:
	return targets_remaining


func has_projectiles() -> bool:
	return projectiles_remaining > 0


func win() -> void:
	if state == State.WON:
		return
	var bonus := GameSettings.unused_projectile_bonus * projectiles_remaining
	if bonus > 0:
		add_score(bonus)
	state = State.WON


func lose() -> void:
	if state == State.LOST:
		return
	state = State.LOST


func state_name(s: State = state) -> String:
	match s:
		State.LOADING: return "LOADING"
		State.AIMING: return "AIMING"
		State.FLYING: return "FLYING"
		State.SETTLING: return "SETTLING"
		State.WON: return "WON"
		State.LOST: return "LOST"
	return "?"
