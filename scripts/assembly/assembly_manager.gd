class_name AssemblyManager
extends Node

signal score_changed(score: int)
signal tutorial_changed(message: String)
signal step_changed(step: int, part_id: StringName)

enum Mode { TRAINING, FREE_PRACTICE }

@export var score_label_path: NodePath
@export var tutorial_label_path: NodePath
@export var step_label_path: NodePath
@export var time_label_path: NodePath
@export var mistakes_label_path: NodePath
@export var mode_label_path: NodePath
@export var feedback_label_path: NodePath

var score: int = 0
var current_step: int = 1
var mistakes: int = 0
var completed_parts: Array[StringName] = []
var sequence: Array[StringName] = [&"auger", &"blade", &"plate", &"lock_ring", &"hopper_tray", &"pusher"]
var mode: Mode = Mode.TRAINING
var focus_part_id: StringName = &""
var elapsed_time: float = 0.0
var running: bool = false
var completed: bool = false

@onready var score_label: Label3D = get_node_or_null(score_label_path) as Label3D
@onready var tutorial_label: Label3D = get_node_or_null(tutorial_label_path) as Label3D
@onready var step_label: Label3D = get_node_or_null(step_label_path) as Label3D
@onready var time_label: Label3D = get_node_or_null(time_label_path) as Label3D
@onready var mistakes_label: Label3D = get_node_or_null(mistakes_label_path) as Label3D
@onready var mode_label: Label3D = get_node_or_null(mode_label_path) as Label3D
@onready var feedback_label: Label3D = get_node_or_null(feedback_label_path) as Label3D

var _score_audio: AudioStreamPlayer
var _error_audio: AudioStreamPlayer
var _complete_audio: AudioStreamPlayer
var _feedback_tween: Tween

func _ready() -> void:
	add_to_group("assembly_manager")
	_setup_audio()
	await get_tree().process_frame
	for part in _parts():
		part.set_initial_transform_from_current()
	start_training()

func _process(delta: float) -> void:
	if running and not completed:
		elapsed_time += delta
		_update_time_label()

func expected_part_id() -> StringName:
	if current_step < 1 or current_step > sequence.size():
		return &""
	return sequence[current_step - 1]

func is_sequence_enforced() -> bool:
	return mode == Mode.TRAINING and AssemblySettings.REQUIRE_CORRECT_ORDER

func can_place(part_id: StringName) -> bool:
	if not is_sequence_enforced():
		return true
	return part_id == expected_part_id()

func is_socket_active(part_id: StringName) -> bool:
	if completed:
		return false
	if mode == Mode.TRAINING:
		return part_id == expected_part_id()
	if focus_part_id == &"":
		return false
	return part_id == focus_part_id

func notify_part_picked(part: AssemblyPart) -> void:
	focus_part_id = part.part_id
	if mode == Mode.TRAINING and part.part_id != expected_part_id():
		mistakes += 1
		score = max(0, score - AssemblySettings.WRONG_PART_PENALTY)
		_show_feedback("−%d  قطعه این مرحله نیست" % AssemblySettings.WRONG_PART_PENALTY, Color(1.0, 0.35, 0.32))
		_play(_error_audio)
		_update_ui()
	_refresh_part_guides()

func notify_part_dropped(part: AssemblyPart) -> void:
	if completed or part.is_placed:
		return
	if mode == Mode.TRAINING:
		mistakes += 1
		score = max(0, score - AssemblySettings.MISPLACED_DROP_PENALTY)
		_show_feedback("−%d  قطعه در محل درست رها نشد" % AssemblySettings.MISPLACED_DROP_PENALTY, Color(1.0, 0.60, 0.22))
		_play(_error_audio)
		_update_ui()

func register_correct(part: AssemblyPart) -> void:
	if part.part_id in completed_parts:
		return

	completed_parts.append(part.part_id)
	var awarded := part.score_value if part.score_value > 0 else AssemblySettings.CORRECT_PLACEMENT_SCORE
	score += awarded
	_show_feedback("+%d  نصب صحیح" % awarded, Color(0.28, 1.0, 0.48))
	_play(_score_audio)

	if AssemblySettings.DEBUG_SNAP_LOGS:
		print("ASSEMBLY OK: ", part.part_id, " +", awarded, " score=", score)

	if mode == Mode.TRAINING:
		current_step += 1
		focus_part_id = &""
	else:
		focus_part_id = &""

	if completed_parts.size() >= sequence.size():
		_finish_session()
	else:
		score_changed.emit(score)
		step_changed.emit(current_step, expected_part_id())
		_update_ui()
		_refresh_part_guides()

func start_training() -> void:
	mode = Mode.TRAINING
	_reset_state()
	_show_feedback("حالت آموزش مرحله‌ای فعال شد", Color(0.35, 0.78, 1.0))

func start_free_practice() -> void:
	mode = Mode.FREE_PRACTICE
	_reset_state()
	_show_feedback("تمرین آزاد — هر قطعه را انتخاب کن", Color(0.55, 0.88, 1.0))

func reset_assembly() -> void:
	_reset_state()
	_show_feedback("مونتاژ از نو شروع شد", Color(0.9, 0.9, 0.95))

func _reset_state() -> void:
	score = 0
	current_step = 1
	mistakes = 0
	completed_parts.clear()
	focus_part_id = &""
	elapsed_time = 0.0
	completed = false
	running = true
	for part in _parts():
		part.reset_part()
	_update_ui()
	_refresh_part_guides()

func _finish_session() -> void:
	completed = true
	running = false
	focus_part_id = &""
	_play(_complete_audio)
	_show_feedback("✓ مونتاژ کامل شد", Color(0.35, 1.0, 0.58), 2.2)
	_update_ui()
	_refresh_part_guides()

func _parts() -> Array[AssemblyPart]:
	var out: Array[AssemblyPart] = []
	for node in get_tree().get_nodes_in_group("assembly_parts"):
		var part := node as AssemblyPart
		if part:
			out.append(part)
	return out

func _refresh_part_guides() -> void:
	for part in _parts():
		if part.is_placed:
			part.set_guide_placed()
		elif mode == Mode.TRAINING and part.part_id == expected_part_id():
			part.set_guide_target()
		elif mode == Mode.FREE_PRACTICE and focus_part_id != &"" and part.part_id == focus_part_id:
			part.set_guide_target()
		else:
			part.set_guide_off()

func _update_ui() -> void:
	if score_label:
		score_label.text = "امتیاز  %d" % score
	if mistakes_label:
		mistakes_label.text = "خطا  %d" % mistakes
	if mode_label:
		mode_label.text = "آموزش مرحله‌ای" if mode == Mode.TRAINING else "تمرین آزاد"
	if step_label:
		if completed:
			step_label.text = "تکمیل شد"
		elif mode == Mode.TRAINING:
			step_label.text = "مرحله %d از %d" % [current_step, sequence.size()]
		else:
			step_label.text = "%d از %d قطعه" % [completed_parts.size(), sequence.size()]
	_update_time_label()

	if tutorial_label:
		if completed:
			tutorial_label.text = "مونتاژ با موفقیت کامل شد\nامتیاز: %d   |   زمان: %s   |   خطا: %d" % [score, _format_time(elapsed_time), mistakes]
		elif mode == Mode.FREE_PRACTICE:
			tutorial_label.text = "تمرین آزاد\nیک قطعه را بردار؛ نام آن نزدیک دست ظاهر می‌شود و لبه صحیح راهنمایت می‌کند."
		else:
			match expected_part_id():
				&"auger": tutorial_label.text = "مارپیچ را بردار\nلبه قرمز قطعه را به حلقه قرمز دهانه نزدیک کن؛ وقتی هر دو سبز شدند رها کن."
				&"blade": tutorial_label.text = "تیغه را بردار\nمرکز تیغه را به محور جلوی مارپیچ نزدیک کن."
				&"plate": tutorial_label.text = "صفحه سوراخ‌دار را بردار\nآن را روی تیغه و محور جلو قرار بده."
				&"lock_ring": tutorial_label.text = "مهره جلویی را بردار\nآن را روی مجموعه جلویی قرار بده تا قفل شود."
				&"hopper_tray": tutorial_label.text = "سینی را بردار\nاتصال زیر سینی را روی گلویی بالای دستگاه بگذار."
				&"pusher": tutorial_label.text = "گوشت‌کوب را بردار\nآن را از بالا داخل ورودی سینی قرار بده."
				_: tutorial_label.text = "مونتاژ کامل شد"
		tutorial_changed.emit(tutorial_label.text)

func _update_time_label() -> void:
	if time_label:
		time_label.text = "زمان  %s" % _format_time(elapsed_time)

func _format_time(value: float) -> String:
	var total := int(value)
	return "%02d:%02d" % [int(total / 60), total % 60]

func _show_feedback(text: String, color: Color, duration: float = 1.0) -> void:
	if feedback_label == null:
		return
	if _feedback_tween and _feedback_tween.is_running():
		_feedback_tween.kill()
	feedback_label.text = text
	feedback_label.modulate = color
	feedback_label.modulate.a = 0.0
	feedback_label.scale = Vector3.ONE * 0.82
	feedback_label.visible = true
	_feedback_tween = create_tween()
	_feedback_tween.set_parallel(true)
	_feedback_tween.tween_property(feedback_label, "modulate:a", 1.0, 0.14)
	_feedback_tween.tween_property(feedback_label, "scale", Vector3.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.set_parallel(false)
	_feedback_tween.tween_interval(duration)
	_feedback_tween.set_parallel(true)
	_feedback_tween.tween_property(feedback_label, "modulate:a", 0.0, 0.25)
	_feedback_tween.tween_property(feedback_label, "scale", Vector3.ONE * 1.06, 0.25)

func _setup_audio() -> void:
	_score_audio = _new_audio("ScoreAudio", "res://assets/audio/score.wav", -4.0)
	_error_audio = _new_audio("ErrorAudio", "res://assets/audio/error.wav", -7.0)
	_complete_audio = _new_audio("CompleteAudio", "res://assets/audio/complete.wav", -3.0)

func _new_audio(node_name: String, path: String, volume_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.stream = load(path)
	p.volume_db = volume_db
	add_child(p)
	return p

func _play(player: AudioStreamPlayer) -> void:
	if player and player.stream:
		player.stop()
		player.play()
