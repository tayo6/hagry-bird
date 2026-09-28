extends Node
class_name AudioManager
## Procedural sound effects via AudioStreamGenerator — zero audio assets.
##
## Web browsers require a user gesture before audio can start; we simply
## resume the mixer on the first touch/click, which is exactly when the
## player drags the slingshot.

const SAMPLE_RATE := 22050.0

var _players: Array[AudioStreamPlayer] = []
var _idx: int = 0
var _unlocked: bool = false


func _ready() -> void:
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.stream = _make_generator_stream()
		p.volume_db = -8.0
		add_child(p)
		_players.append(p)
	Log.boot("audio: procedural generator ready (%d voices)" % _players.size())


func play_launch(power: float) -> void:
	# Whoosh: short downward sweep. power 0..1
	_play_tone(340.0 + 260.0 * power, 0.16, "noise_down", power)


func play_bounce(strength: float) -> void:
	_play_tone(160.0 + 90.0 * clampf(strength, 0.0, 1.0), 0.07, "sine", clampf(strength, 0.2, 1.0))


func play_target_pop() -> void:
	_play_tone(880.0, 0.12, "pop_up", 0.9)


func play_win() -> void:
	_play_arpeggio([523.0, 659.0, 784.0, 1047.0])


func play_lose() -> void:
	_play_arpeggio([392.0, 330.0, 262.0])


func unlock_from_gesture() -> void:
	if _unlocked:
		return
	_unlocked = true
	# On web this satisfies the autoplay policy; harmless elsewhere.
	AudioServer.is_bus_active(0)


# --- internals ---------------------------------------------------------------

func _make_generator_stream() -> AudioStreamGenerator:
	var s := AudioStreamGenerator.new()
	s.mix_rate = SAMPLE_RATE
	s.set_buffering_msec(80.0)
	return s


func _play_tone(freq: float, duration: float, kind: String, volume: float) -> void:
	if _players.is_empty():
		return
	var p: AudioStreamPlayer = _players[_idx]
	_idx = (_idx + 1) % _players.size()
	if not p.playing:
		p.play()
	var gen := p.get_stream_player()
	var frames := int(SAMPLE_RATE * duration)
	if gen == null or frames <= 0:
		return
	gen.set_mix_enable(false)
	for i in frames:
		if not gen.has_available_frames():
			await get_tree().process_frame
		var t := float(i) / SAMPLE_RATE
		var env := 1.0 - float(i) / float(frames)
		var sample := 0.0
		match kind:
			"sine":
				sample = sin(TAU * freq * t)
			"noise_down":
				var f := freq * (1.0 - 0.6 * float(i) / float(frames))
				sample = (sin(TAU * f * t) + randf() * 0.6 - 0.3)
			"pop_up":
				var f2 := freq * (1.0 + 0.8 * float(i) / float(frames))
				sample = sin(TAU * f2 * t)
		gen.push_sample(sample * env * volume * 0.5)
	gen.set_mix_enable(true)


func _play_arpeggio(freqs: Array) -> void:
	for i in freqs.size():
		var timer := get_tree().create_timer(0.12 * i)
		timer.timeout.connect(_play_tone.bind(freqs[i], 0.14, "sine", 0.8))
