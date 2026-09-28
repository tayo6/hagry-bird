extends Node
class_name AudioManager
## Procedural sound effects rendered to PCM at runtime — zero audio assets.
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
		p.volume_db = -8.0
		add_child(p)
		_players.append(p)
	Log.boot("audio: procedural PCM voices ready (%d)" % _players.size())


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
	# Resume the mixer by toggling pause on the Master bus (index 0).
	AudioServer.set_bus_mute(0, false)


# --- internals ---------------------------------------------------------------

func _play_tone(freq: float, duration: float, kind: String, volume: float) -> void:
	if _players.is_empty():
		return
	var p: AudioStreamPlayer = _players[_idx]
	_idx = (_idx + 1) % _players.size()
	var frames := int(SAMPLE_RATE * duration)
	if frames <= 0:
		return
	# Render the whole tone into an AudioStreamWAV and play it through the
	# shared AudioStreamPlayer. This avoids AudioStreamGeneratorPlayback,
	# whose API surface differs between Godot builds and breaks static
	# analysis / headless exports.
	var pcm := AudioStreamWAV.new()
	var data := PackedByteArray()
	data.resize(frames * 4)  # 32-bit float mono
	for i in frames:
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
		data.encode_float(i * 4, clampf(sample * env * volume * 0.5, -1.0, 1.0))
	# FORMAT_FLOAT == 5 in Godot 4.x (32-bit float PCM); numeric to stay
	# compatible with builds that do not expose the enum as GDScript constants.
	pcm.format = 5
	pcm.mix_rate = int(SAMPLE_RATE)
	pcm.loop_mode = 0
	pcm.data = data
	if p.playing:
		p.stop()
	p.stream = pcm
	p.play()


func _play_arpeggio(freqs: Array) -> void:
	for i in freqs.size():
		var timer := get_tree().create_timer(0.12 * i)
		timer.timeout.connect(_play_tone.bind(freqs[i], 0.14, "sine", 0.8))
