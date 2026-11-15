extends Node
## Autoload: scene flow shared by all levels (Esc = level select, win = next level,
## time up = restart level), the countdown HUD drawn on top of every level, and the
## background music, which keeps playing across scene changes.

const LEVEL_SELECT_SCENE: String = "res://level_select.tscn"
const LEVEL_PATH_TEMPLATE: String = "res://level%d.tscn"
const LEVEL_COUNT: int = 10
const WIN_DELAY_SEC: float = 1.5
const FAIL_DELAY_SEC: float = 1.5

const BGM_PATH: String = "res://bgm.mp3"

const HUD_LAYER: int = 10
const HUD_MARGIN: int = 16
const TIMER_FONT_SIZE: int = 56
const TIMER_OUTLINE_SIZE: int = 8
const TIMER_TEXT_TEMPLATE: String = "Time: %d"
const TIME_UP_TEXT: String = "TIME UP"
const TIME_UP_COLOR: Color = Color(1.0, 0.3, 0.3)

var _level_regex: RegEx = RegEx.create_from_string("^res://level(\\d+)\\.tscn$")
var _hud: CanvasLayer
var _timer_label: Label
var _active_emitter: Node
var _bgm_player: AudioStreamPlayer


func _ready() -> void:
	_build_hud()
	_start_bgm()
	get_tree().node_added.connect(_on_node_added)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _current_level() > 0:
		_change_scene(LEVEL_SELECT_SCENE)


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "TimerHud"
	_hud.layer = HUD_LAYER
	_hud.visible = false
	add_child(_hud)

	_timer_label = Label.new()
	_timer_label.name = "TimerLabel"
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_label.add_theme_font_size_override(&"font_size", TIMER_FONT_SIZE)
	_timer_label.add_theme_constant_override(&"outline_size", TIMER_OUTLINE_SIZE)
	_timer_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_hud.add_child(_timer_label)
	_timer_label.set_anchors_and_offsets_preset(
		Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, HUD_MARGIN
	)


## Plays the background track on a loop for the whole session.
func _start_bgm() -> void:
	if not ResourceLoader.exists(BGM_PATH):
		push_error("Background music not found: %s" % BGM_PATH)
		return
	var stream: AudioStreamMP3 = load(BGM_PATH) as AudioStreamMP3
	if stream == null:
		push_error("Failed to load %s as an MP3 stream" % BGM_PATH)
		return
	stream.loop = true

	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BgmPlayer"
	_bgm_player.stream = stream
	_bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_bgm_player)
	_bgm_player.play()


func _on_node_added(node: Node) -> void:
	if node.name != &"Emitter" or not node.has_signal(&"bulb_lit"):
		return
	node.connect(&"bulb_lit", _on_bulb_lit, CONNECT_ONE_SHOT)
	if node.has_signal(&"time_changed") and node.has_signal(&"beam_failed"):
		_track_emitter(node)


## Hooks the level's emitter up to the HUD and shows the countdown.
func _track_emitter(emitter: Node) -> void:
	if emitter.is_connected(&"time_changed", _on_time_changed):
		return
	_active_emitter = emitter
	emitter.connect(&"time_changed", _on_time_changed)
	emitter.connect(&"beam_failed", _on_beam_failed.bind(emitter), CONNECT_ONE_SHOT)
	emitter.tree_exiting.connect(_on_emitter_exiting.bind(emitter), CONNECT_ONE_SHOT)

	_timer_label.remove_theme_color_override(&"font_color")
	var limit: Variant = emitter.get(&"time_limit")
	if limit is float or limit is int:
		_on_time_changed(float(limit))
	else:
		_timer_label.text = ""
	_hud.visible = true


func _on_time_changed(seconds_left: float) -> void:
	_timer_label.text = TIMER_TEXT_TEMPLATE % ceili(maxf(seconds_left, 0.0))


func _on_beam_failed(emitter: Node) -> void:
	_timer_label.text = TIME_UP_TEXT
	_timer_label.add_theme_color_override(&"font_color", TIME_UP_COLOR)
	await get_tree().create_timer(FAIL_DELAY_SEC).timeout
	# The player may have restarted (R) or left (Esc) during the delay.
	if not is_instance_valid(emitter) or not emitter.is_inside_tree():
		return
	var err: Error = get_tree().reload_current_scene()
	if err != OK:
		push_error("Failed to restart level (error %d)" % err)


func _on_emitter_exiting(emitter: Node) -> void:
	if _active_emitter == emitter:
		_active_emitter = null
		_hud.visible = false


func _on_bulb_lit() -> void:
	var level: int = _current_level()
	if level <= 0:
		return
	var scene: Node = get_tree().current_scene
	await get_tree().create_timer(WIN_DELAY_SEC).timeout
	if get_tree().current_scene != scene:
		return
	if level < LEVEL_COUNT:
		_change_scene(LEVEL_PATH_TEMPLATE % (level + 1))
	else:
		_change_scene(LEVEL_SELECT_SCENE)


## Returns the current level number (1-based), or 0 when not inside a level.
func _current_level() -> int:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return 0
	var result: RegExMatch = _level_regex.search(scene.scene_file_path)
	if result == null:
		return 0
	return result.get_string(1).to_int()


func _change_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("Scene not found: %s" % path)
		return
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Failed to load %s (error %d)" % [path, err])
