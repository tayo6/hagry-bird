extends CanvasLayer
class_name Hud
## All UI is constructed in code (no .tscn beyond main.tscn).
## Touch-first layout: big buttons, responsive anchors, keyboard never needed.

var score_label: Label = null
var ammo_label: Label = null
var targets_label: Label = null
var hint_label: Label = null
var banner: Label = null
var restart_button: Button = null
var sound_toggle: CheckBox = null

var _root: Control = null


func _init(parent: Node) -> void:
	layer = 10
	_root = Control.new()
	_root.name = "HudRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var top := HBoxContainer.new()
	top.name = "TopBar"
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_top = 8
	top.add_theme_constant_override("separation", 24)
	_root.add_child(top)

	score_label = _stat_label(top, "Score: 0")
	targets_label = _stat_label(top, "Targets: 0/0")
	ammo_label = _stat_label(top, "Balls: 0")

	hint_label = Label.new()
	hint_label.text = "Drag the red ball backward - release to fire!"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint_label.offset_top = 46
	hint_label.modulate = Color(1, 1, 1, 0.85)
	hint_label.add_theme_font_size_override("font_size", 18)
	_root.add_child(hint_label)

	banner = Label.new()
	banner.name = "Banner"
	banner.alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner.add_theme_font_size_override("font_size", 56)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	banner.add_theme_constant_override("outline_size", 12)
	banner.visible = false
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(banner)

	restart_button = Button.new()
	restart_button.name = "RestartButton"
	restart_button.text = "RESTART"
	restart_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	restart_button.offset_left = 12
	restart_button.offset_bottom = -12
	restart_button.offset_top = -60
	restart_button.offset_right = 150
	restart_button.add_theme_font_size_override("font_size", 20)
	_root.add_child(restart_button)

	sound_toggle = CheckBox.new()
	sound_toggle.name = "SoundToggle"
	sound_toggle.text = "Sound"
	sound_toggle.button_pressed = true
	sound_toggle.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	sound_toggle.offset_right = -14
	sound_toggle.offset_bottom = -14
	sound_toggle.offset_top = -44
	_root.add_child(sound_toggle)


func _stat_label(parent: Control, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("outline_size", 4)
	parent.add_child(l)
	return l


# --- bindings ------------------------------------------------------------------

func bind(state: GameState) -> void:
	state.score_changed.connect(func(s: int): score_label.text = "Score: %d" % s)
	state.ammo_changed.connect(func(a: int): ammo_label.text = "Balls: %d" % a)
	state.targets_changed.connect(func(rem: int, tot: int): targets_label.text = "Targets: %d/%d" % [tot - rem, tot])
	state.state_changed.connect(_on_state)


func _on_state(state: GameState.State) -> void:
	match state:
		GameState.State.AIMING:
			banner.visible = false
			hint_label.visible = true
		GameState.State.FLYING, GameState.State.SETTLING:
			hint_label.visible = false
		GameState.State.WON:
			_show_banner("LEVEL COMPLETE!", Color(0.3, 0.9, 0.4))
		GameState.State.LOST:
			_show_banner("OUT OF BALLS", Color(0.95, 0.4, 0.3))


func _show_banner(text: String, color: Color) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.visible = true
	Log.ui("banner: %s" % text)


func set_hint(text: String) -> void:
	hint_label.text = text
