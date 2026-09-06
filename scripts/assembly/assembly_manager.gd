class_name AssemblyManager
extends Node

signal score_changed(score: int)
signal tutorial_changed(message: String)
signal step_changed(step: int, part_id: StringName)

enum Mode { TRAINING, FREE_PRACTICE }
enum SessionState { MENU, RUNNING, COMPLETE }

@export var score_label_path: NodePath
@export var tutorial_label_path: NodePath
@export var step_label_path: NodePath
@export var time_label_path: NodePath
@export var mistakes_label_path: NodePath
@export var mode_label_path: NodePath
@export var feedback_label_path: NodePath
@export var accuracy_label_path: NodePath
@export var difficulty_label_path: NodePath
@export var result_panel_path: NodePath
@export var result_body_path: NodePath

var score: int = 0
var current_step: int = 1
var mistakes: int = 0
var first_try_count: int = 0
var completed_parts: Array[StringName] = []
var sequence: Array[StringName] = [&"auger", &"blade", &"plate", &"lock_ring", &"hopper_tray", &"pusher"]

var mode: Mode = Mode.TRAINING
var session_state: SessionState = SessionState.MENU
var focus_part_id: StringName = &""
var elapsed_time: float = 0.0

var _step_errors: int = 0
var _score_audio: AudioStreamPlayer
var _error_audio: AudioStreamPlayer
var _complete_audio: AudioStreamPlayer
var _ready_audio: AudioStreamPlayer
var _feedback_tween: Tween

@onready var score_label: Label3D = get_node_or_null(score_label_path) as Label3D
@onready var tutorial_label: Label3D = get_node_or_null(tutorial_label_path) as Label3D
@onready var step_label: Label3D = get_node_or_null(step_label_path) as Label3D
@onready var time_label: Label3D = get_node_or_null(time_label_path) as Label3D
@onready var mistakes_label: Label3D = get_node_or_null(mistakes_label_path) as Label3D
@onready var mode_label: Label3D = get_node_or_null(mode_label_path) as Label3D
@onready var feedback_label: Label3D = get_node_or_null(feedback_label_path) as Label3D
@onready var accuracy_label: Label3D = get_node_or_null(accuracy_label_path) as Label3D
@onready var difficulty_label: Label3D = get_node_or_null(difficulty_label_path) as Label3D
@onready var result_panel: Node3D = get_node_or_null(result_panel_path) as Node3D
@onready var result_body: Label3D = get_node_or_null(result_body_path) as Label3D

func _ready() -> void:
	add_to_group("assembly_manager")
	_setup_audio()
	AssemblySettings.apply_difficulty(AssemblySettings.Difficulty.NORMAL)
	await get_tree().process_frame
	for part in _parts():
		part.set_initial_transform_from_current()
	show_main_menu()

func _process(delta: float) -> void:
	if session_state == SessionState.RUNNING:
		elapsed_time += delta
		_update_time_label()

func can_interact_with_parts() -> bool:
	return session_state == SessionState.RUNNING

func expected_part_id() -> StringName:
	if current_step < 1 or current_step > sequence.size():
		return &""
	return sequence[current_step - 1]

func is_sequence_enforced() -> bool:
	return session_state == SessionState.RUNNING and mode == Mode.TRAINING and AssemblySettings.REQUIRE_CORRECT_ORDER

func can_place(part_id: StringName) -> bool:
	if session_state != SessionState.RUNNING:
		return false
	if not is_sequence_enforced():
		return true
	return part_id == expected_part_id()

func is_socket_active(part_id: StringName) -> bool:
	if session_state != SessionState.RUNNING:
		return false
	if mode == Mode.TRAINING:
		return part_id == expected_part_id()
	if focus_part_id == &"":
		return false
	return part_id == focus_part_id

func notify_part_picked(part: AssemblyPart) -> void:
	if session_state != SessionState.RUNNING:
		return

	focus_part_id = part.part_id
	_haptic_all(0.10, 0.035)

	if mode == Mode.TRAINING and part.part_id != expected_part_id():
		mistakes += 1
		_step_errors += 1
		score = max(0, score - AssemblySettings.WRONG_PART_PENALTY)
		_show_feedback("−%d  قطعه این مرحله نیست" % AssemblySettings.WRONG_PART_PENALTY, Color(1.0, 0.35, 0.32))
		_play(_error_audio)
		_haptic_error()
		_update_ui()

	_refresh_part_guides()

func notify_part_dropped(part: AssemblyPart) -> void:
	if session_state != SessionState.RUNNING or part.is_placed:
		return

	if mode == Mode.TRAINING:
		mistakes += 1
		_step_errors += 1
		score = max(0, score - AssemblySettings.MISPLACED_DROP_PENALTY)
		_show_feedback("−%d  در محل درست رها نشد" % AssemblySettings.MISPLACED_DROP_PENALTY, Color(1.0, 0.60, 0.22))
		_play(_error_audio)
		_haptic_error()
		_update_ui()

func notify_snap_ready(_part: AssemblyPart) -> void:
	if session_state != SessionState.RUNNING:
		return
	_play(_ready_audio)
	_haptic_all(0.16, 0.045)

func register_correct(part: AssemblyPart) -> void:
	if session_state != SessionState.RUNNING or part.part_id in completed_parts:
		return

	completed_parts.append(part.part_id)

	if mode == Mode.TRAINING:
		var base_award := part.score_value if part.score_value > 0 else AssemblySettings.CORRECT_PLACEMENT_SCORE
		var bonus := 0
		if _step_errors == 0:
			bonus = AssemblySettings.FIRST_TRY_BONUS
			first_try_count += 1
		score += base_award + bonus

		if bonus > 0:
			_show_feedback("+%d  نصب صحیح + اولین تلاش" % (base_award + bonus), Color(0.28, 1.0, 0.48))
		else:
			_show_feedback("+%d  نصب صحیح" % base_award, Color(0.28, 1.0, 0.48))

		current_step += 1
		_step_errors = 0
	else:
		_show_feedback("✓ قطعه نصب شد", Color(0.40, 0.95, 0.72))

	focus_part_id = &""
	_play(_score_audio)
	_haptic_all(0.34, 0.075)

	if AssemblySettings.DEBUG_SNAP_LOGS:
		print("ASSEMBLY OK: ", part.part_id, " score=", score, " first_try=", first_try_count)

	if completed_parts.size() >= sequence.size():
		if mode == Mode.TRAINING:
			score += AssemblySettings.COMPLETION_BONUS
		_finish_session()
	else:
		score_changed.emit(score)
		step_changed.emit(current_step, expected_part_id())
		_update_ui()
		_refresh_part_guides()

func show_main_menu() -> void:
	session_state = SessionState.MENU
	mode = Mode.TRAINING
	_reset_progress_and_parts()
	_set_result_visible(false)
	_update_ui()
	_refresh_part_guides()
	_show_feedback("حالت اجرا و سختی را از سمت راست تخته انتخاب کن", Color(0.55, 0.86, 1.0), 1.6)

func start_training() -> void:
	mode = Mode.TRAINING
	session_state = SessionState.RUNNING
	_reset_progress_and_parts()
	_set_result_visible(false)
	_update_ui()
	_refresh_part_guides()
	_show_feedback("آموزش مرحله‌ای شروع شد", Color(0.35, 0.78, 1.0))

func start_free_practice() -> void:
	mode = Mode.FREE_PRACTICE
	session_state = SessionState.RUNNING
	_reset_progress_and_parts()
	_set_result_visible(false)
	_update_ui()
	_refresh_part_guides()
	_show_feedback("تمرین آزاد — هر قطعه را انتخاب کن", Color(0.55, 0.88, 1.0))

func reset_assembly() -> void:
	if session_state == SessionState.MENU:
		_reset_progress_and_parts()
		_update_ui()
		_show_feedback("قطعات به جای اولیه برگشتند", Color(0.9, 0.9, 0.95))
	else:
		restart_current_mode()

func restart_current_mode() -> void:
	session_state = SessionState.RUNNING
	_reset_progress_and_parts()
	_set_result_visible(false)
	_update_ui()
	_refresh_part_guides()
	_show_feedback("جلسه از نو شروع شد", Color(0.82, 0.92, 1.0))

func set_difficulty_easy() -> void:
	_set_difficulty(AssemblySettings.Difficulty.EASY)

func set_difficulty_normal() -> void:
	_set_difficulty(AssemblySettings.Difficulty.NORMAL)

func set_difficulty_hard() -> void:
	_set_difficulty(AssemblySettings.Difficulty.HARD)

func _set_difficulty(level: int) -> void:
	AssemblySettings.apply_difficulty(level)
	_update_ui()
	_refresh_part_guides()
	_show_feedback(
		"سختی: %s   |   Snap: %d cm" % [
			AssemblySettings.difficulty_name_fa(),
			int(round(AssemblySettings.SNAP_RADIUS_M * 100.0))
		],
		Color(0.72, 0.90, 1.0)
	)

func is_menu_action_selected(action: String) -> bool:
	match action:
		"training":
			return session_state == SessionState.RUNNING and mode == Mode.TRAINING
		"free_practice":
			return session_state == SessionState.RUNNING and mode == Mode.FREE_PRACTICE
		"difficulty_easy":
			return AssemblySettings.CURRENT_DIFFICULTY == AssemblySettings.Difficulty.EASY
		"difficulty_normal":
			return AssemblySettings.CURRENT_DIFFICULTY == AssemblySettings.Difficulty.NORMAL
		"difficulty_hard":
			return AssemblySettings.CURRENT_DIFFICULTY == AssemblySettings.Difficulty.HARD
	return false

func menu_haptic() -> void:
	_haptic_all(0.14, 0.040)

func _reset_progress_and_parts() -> void:
	score = 0
	current_step = 1
	mistakes = 0
	first_try_count = 0
	_step_errors = 0
	completed_parts.clear()
	focus_part_id = &""
	elapsed_time = 0.0

	for part in _parts():
		part.reset_part()
	for node in get_tree().get_nodes_in_group("assembly_sockets"):
		if node.has_method("reset_socket"):
			node.call("reset_socket")

func _finish_session() -> void:
	session_state = SessionState.COMPLETE
	focus_part_id = &""
	_play(_complete_audio)
	_haptic_all(0.55, 0.20)
	_show_feedback("✓ مونتاژ کامل شد", Color(0.35, 1.0, 0.58), 1.4)
	_update_ui()
	_refresh_part_guides()
	_set_result_visible(true)
	_update_result_panel()

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
		elif session_state != SessionState.RUNNING:
			part.set_guide_off()
		elif mode == Mode.TRAINING and part.part_id == expected_part_id():
			part.set_guide_target()
		elif mode == Mode.FREE_PRACTICE and focus_part_id != &"" and part.part_id == focus_part_id:
			part.set_guide_target()
		else:
			part.set_guide_off()

func _update_ui() -> void:
	if difficulty_label:
		difficulty_label.text = "سختی  %s" % AssemblySettings.difficulty_name_fa()

	if score_label:
		if mode == Mode.FREE_PRACTICE and session_state != SessionState.MENU:
			score_label.text = "امتیاز  —"
		else:
			score_label.text = "امتیاز  %d / %d" % [score, AssemblySettings.MAX_TRAINING_SCORE]

	if mistakes_label:
		mistakes_label.text = "خطا  %d" % mistakes

	if accuracy_label:
		if mode == Mode.FREE_PRACTICE and session_state != SessionState.MENU:
			accuracy_label.text = "دقت  —"
		else:
			accuracy_label.text = "دقت  %d%%" % _accuracy_percent()

	if mode_label:
		match session_state:
			SessionState.MENU:
				mode_label.text = "منوی اصلی"
			SessionState.COMPLETE:
				mode_label.text = "جلسه تکمیل شد"
			_:
				mode_label.text = "آموزش مرحله‌ای" if mode == Mode.TRAINING else "تمرین آزاد"

	if step_label:
		if session_state == SessionState.MENU:
			step_label.text = "آماده شروع"
		elif session_state == SessionState.COMPLETE:
			step_label.text = "۶ از ۶ — تکمیل"
		elif mode == Mode.TRAINING:
			step_label.text = "مرحله %d از %d" % [current_step, sequence.size()]
		else:
			step_label.text = "%d از %d قطعه" % [completed_parts.size(), sequence.size()]

	_update_time_label()

	if tutorial_label:
		if session_state == SessionState.MENU:
			tutorial_label.text = "۱) سختی را انتخاب کن\n۲) «آموزش» یا «تمرین آزاد» را با نزدیک کردن دست و U شروع کن."
		elif session_state == SessionState.COMPLETE:
			tutorial_label.text = "نتیجه روی پنل نمایش داده شده است."
		elif mode == Mode.FREE_PRACTICE:
			tutorial_label.text = "تمرین آزاد\nهر قطعه را بردار؛ لبه صحیح همان قطعه راهنمایت می‌کند. جریمه و ترتیب اجباری خاموش است."
		else:
			match expected_part_id():
				&"auger":
					tutorial_label.text = "مارپیچ را بردار\nلبه قرمز را به حلقه قرمز دهانه نزدیک کن؛ سبز یعنی آماده Snap."
				&"blade":
					tutorial_label.text = "تیغه را بردار\nسوراخ مرکز تیغه را روبروی محور جلوی مارپیچ قرار بده."
				&"plate":
					tutorial_label.text = "صفحه سوراخ‌دار را بردار\nسوراخ مرکزی را روی محور و جلوی تیغه قرار بده."
				&"lock_ring":
					tutorial_label.text = "مهره قفل را بردار\nآن را روی مجموعه جلویی ببر تا در امتداد محور بسته شود."
				&"hopper_tray":
					tutorial_label.text = "سینی ورودی را بردار\nاتصال زیر سینی را روی گلویی بالای دستگاه قرار بده."
				&"pusher":
					tutorial_label.text = "گوشت‌کوب را بردار\nآن را از بالا داخل ورودی سینی قرار بده."
				_:
					tutorial_label.text = "مونتاژ کامل شد"
		tutorial_changed.emit(tutorial_label.text)

func _update_time_label() -> void:
	if time_label:
		time_label.text = "زمان  %s" % _format_time(elapsed_time)

func _accuracy_percent() -> int:
	var good := completed_parts.size()
	var total := good + mistakes
	if total <= 0:
		return 100
	return int(round((float(good) / float(total)) * 100.0))

func _format_time(value: float) -> String:
	var total := int(value)
	return "%02d:%02d" % [int(total / 60), total % 60]

func _set_result_visible(value: bool) -> void:
	if result_panel:
		result_panel.visible = value

func _update_result_panel() -> void:
	if result_body == null:
		return

	if mode == Mode.FREE_PRACTICE:
		result_body.text = (
			"تمرین آزاد کامل شد\n"
			+ "زمان: %s\n" % _format_time(elapsed_time)
			+ "قطعات نصب‌شده: %d / %d\n" % [completed_parts.size(), sequence.size()]
			+ "در این حالت امتیاز و جریمه محاسبه نمی‌شود."
		)
	else:
		result_body.text = (
			"امتیاز نهایی: %d / %d\n" % [score, AssemblySettings.MAX_TRAINING_SCORE]
			+ "زمان: %s\n" % _format_time(elapsed_time)
			+ "دقت: %d%%    |    خطا: %d\n" % [_accuracy_percent(), mistakes]
			+ "نصب در اولین تلاش: %d / %d" % [first_try_count, sequence.size()]
		)

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
	_ready_audio = _new_audio("ReadyAudio", "res://assets/audio/ready.wav", -9.0)

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

func _controllers() -> Array[XRController3D]:
	var result: Array[XRController3D] = []
	for controller_name in ["left_hand", "right_hand"]:
		var node := get_tree().root.find_child(controller_name, true, false)
		if node is XRController3D:
			result.append(node as XRController3D)
	return result

func _haptic_all(amplitude: float, duration_s: float) -> void:
	for controller in _controllers():
		if controller.has_method("trigger_haptic_pulse"):
			controller.call("trigger_haptic_pulse", &"haptic", 0.0, amplitude, duration_s, 0.0)

func _haptic_error() -> void:
	for controller in _controllers():
		if controller.has_method("trigger_haptic_pulse"):
			controller.call("trigger_haptic_pulse", &"haptic", 0.0, 0.24, 0.055, 0.0)
			controller.call("trigger_haptic_pulse", &"haptic", 0.0, 0.24, 0.055, 0.11)
