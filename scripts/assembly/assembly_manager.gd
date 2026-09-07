class_name AssemblyManager
extends Node

signal score_changed(score: int)
signal tutorial_changed(message: String)
signal step_changed(step: int, part_id: StringName)

enum Mode { TRAINING, FREE_PRACTICE }
enum SessionState { MENU, RUNNING, COMPLETE, FAILED }
enum Scenario { MANUAL, ELECTRIC, SAUSAGE, TIMED }

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

const CORE_SEQUENCE: Array[StringName] = [&"auger", &"blade", &"plate", &"lock_ring", &"hopper_tray", &"pusher"]
const MANUAL_SEQUENCE: Array[StringName] = [&"auger", &"blade", &"plate", &"lock_ring", &"handle", &"hopper_tray", &"pusher"]
const ELECTRIC_SEQUENCE: Array[StringName] = [&"auger", &"blade", &"plate", &"lock_ring", &"motor_unit", &"hopper_tray", &"pusher"]
const SAUSAGE_SEQUENCE: Array[StringName] = [&"auger", &"blade", &"plate", &"lock_ring", &"sausage_attachment", &"handle", &"hopper_tray", &"pusher"]
const OPTIONAL_IDS: Array[StringName] = [&"handle", &"motor_unit", &"sausage_attachment"]
const TIMED_LIMIT_S: float = 90.0

var score: int = 0
var current_step: int = 1
var mistakes: int = 0
var first_try_count: int = 0
var completed_parts: Array[StringName] = []
var sequence: Array[StringName] = MANUAL_SEQUENCE.duplicate()

var mode: Mode = Mode.TRAINING
var session_state: SessionState = SessionState.MENU
var scenario: Scenario = Scenario.MANUAL
var focus_part_id: StringName = &""
var elapsed_time: float = 0.0
var timed_bonus: int = 0

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
	_ensure_scenario_panel()
	_ensure_optional_parts_and_sockets()
	AssemblySettings.apply_difficulty(AssemblySettings.Difficulty.NORMAL)
	_configure_scenario(Scenario.MANUAL)
	await get_tree().process_frame
	for part in _parts():
		part.set_initial_transform_from_current()
	show_main_menu()

func _process(delta: float) -> void:
	if session_state != SessionState.RUNNING:
		return
	elapsed_time += delta
	if scenario == Scenario.TIMED and elapsed_time >= TIMED_LIMIT_S:
		elapsed_time = TIMED_LIMIT_S
		_fail_timed_session()
		return
	_update_time_label()

func can_interact_with_parts() -> bool:
	return session_state == SessionState.RUNNING

func is_part_enabled(part_id: StringName) -> bool:
	return part_id in sequence

func expected_part_id() -> StringName:
	if current_step < 1 or current_step > sequence.size():
		return &""
	return sequence[current_step - 1]

func is_sequence_enforced() -> bool:
	return session_state == SessionState.RUNNING and mode == Mode.TRAINING and AssemblySettings.REQUIRE_CORRECT_ORDER

func show_target_guides() -> bool:
	return not (scenario == Scenario.TIMED and session_state == SessionState.RUNNING)

func can_place(part_id: StringName) -> bool:
	if session_state != SessionState.RUNNING or not is_part_enabled(part_id):
		return false
	if not is_sequence_enforced():
		return true
	return part_id == expected_part_id()

func is_socket_active(part_id: StringName) -> bool:
	if session_state != SessionState.RUNNING or not is_part_enabled(part_id):
		return false
	if mode == Mode.TRAINING:
		return part_id == expected_part_id()
	return focus_part_id != &"" and part_id == focus_part_id

func notify_part_picked(part: AssemblyPart) -> void:
	if session_state != SessionState.RUNNING or not is_part_enabled(part.part_id):
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
	if session_state != SessionState.RUNNING or part.is_placed or not is_part_enabled(part.part_id):
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
		_show_feedback(
			"+%d  نصب صحیح%s" % [base_award + bonus, " + اولین تلاش" if bonus > 0 else ""],
			Color(0.28, 1.0, 0.48)
		)
		current_step += 1
		_step_errors = 0
	else:
		_show_feedback("✓ قطعه نصب شد", Color(0.40, 0.95, 0.72))

	focus_part_id = &""
	_play(_score_audio)
	_haptic_all(0.34, 0.075)

	if AssemblySettings.DEBUG_SNAP_LOGS:
		print("ASSEMBLY OK: ", part.part_id, " scenario=", scenario_name_en(), " score=", score)

	if completed_parts.size() >= sequence.size():
		if mode == Mode.TRAINING:
			score += AssemblySettings.COMPLETION_BONUS
			if scenario == Scenario.TIMED:
				timed_bonus = max(0, int(floor(TIMED_LIMIT_S - elapsed_time)))
				score += timed_bonus
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
	_show_feedback("سناریو را انتخاب کن، سپس آموزش یا تمرین آزاد را شروع کن", Color(0.55, 0.86, 1.0), 1.8)

func start_training() -> void:
	if scenario == Scenario.TIMED:
		start_timed_challenge()
		return
	mode = Mode.TRAINING
	session_state = SessionState.RUNNING
	_reset_progress_and_parts()
	_set_result_visible(false)
	_update_ui()
	_refresh_part_guides()
	_show_feedback("%s — آموزش مرحله‌ای شروع شد" % scenario_name_fa(), Color(0.35, 0.78, 1.0))

func start_free_practice() -> void:
	if scenario == Scenario.TIMED:
		_configure_scenario(Scenario.MANUAL)
	mode = Mode.FREE_PRACTICE
	session_state = SessionState.RUNNING
	_reset_progress_and_parts()
	_set_result_visible(false)
	_update_ui()
	_refresh_part_guides()
	_show_feedback("%s — تمرین آزاد" % scenario_name_fa(), Color(0.55, 0.88, 1.0))

func start_timed_challenge() -> void:
	_configure_scenario(Scenario.TIMED)
	mode = Mode.TRAINING
	AssemblySettings.apply_difficulty(AssemblySettings.Difficulty.HARD)
	session_state = SessionState.RUNNING
	_reset_progress_and_parts()
	_set_result_visible(false)
	_update_ui()
	_refresh_part_guides()
	_show_feedback("چالش ۹۰ ثانیه‌ای شروع شد — راهنمای قرمز خاموش است", Color(1.0, 0.72, 0.18), 1.8)

func select_scenario_manual() -> void:
	_select_scenario(Scenario.MANUAL)

func select_scenario_electric() -> void:
	_select_scenario(Scenario.ELECTRIC)

func select_scenario_sausage() -> void:
	_select_scenario(Scenario.SAUSAGE)

func _select_scenario(new_scenario: int) -> void:
	_configure_scenario(new_scenario)
	session_state = SessionState.MENU
	mode = Mode.TRAINING
	_reset_progress_and_parts()
	_set_result_visible(false)
	_update_ui()
	_refresh_part_guides()
	_show_feedback("سناریو انتخاب شد: %s" % scenario_name_fa(), Color(0.60, 0.90, 1.0))

func reset_assembly() -> void:
	if session_state == SessionState.MENU:
		_reset_progress_and_parts()
		_update_ui()
		_show_feedback("قطعات به جای اولیه برگشتند", Color(0.9, 0.9, 0.95))
	else:
		restart_current_mode()

func restart_current_mode() -> void:
	if scenario == Scenario.TIMED:
		start_timed_challenge()
		return
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
	if scenario == Scenario.TIMED:
		AssemblySettings.apply_difficulty(AssemblySettings.Difficulty.HARD)
	else:
		AssemblySettings.apply_difficulty(level)
	_update_ui()
	_refresh_part_guides()
	_show_feedback("سختی: %s   |   محدوده سبز: %d cm" % [AssemblySettings.difficulty_name_fa(), int(round(AssemblySettings.READY_RADIUS_M * 100.0))], Color(0.72, 0.90, 1.0))

func is_menu_action_selected(action: String) -> bool:
	match action:
		"training": return session_state == SessionState.RUNNING and mode == Mode.TRAINING and scenario != Scenario.TIMED
		"free_practice": return session_state == SessionState.RUNNING and mode == Mode.FREE_PRACTICE
		"difficulty_easy": return AssemblySettings.CURRENT_DIFFICULTY == AssemblySettings.Difficulty.EASY
		"difficulty_normal": return AssemblySettings.CURRENT_DIFFICULTY == AssemblySettings.Difficulty.NORMAL
		"difficulty_hard": return AssemblySettings.CURRENT_DIFFICULTY == AssemblySettings.Difficulty.HARD
		"scenario_manual": return scenario == Scenario.MANUAL
		"scenario_electric": return scenario == Scenario.ELECTRIC
		"scenario_sausage": return scenario == Scenario.SAUSAGE
		"timed_challenge": return scenario == Scenario.TIMED
	return false

func menu_haptic() -> void:
	_haptic_all(0.14, 0.040)

func scenario_name_fa() -> String:
	match scenario:
		Scenario.ELECTRIC: return "نسخه برقی"
		Scenario.SAUSAGE: return "اتصال سوسیس"
		Scenario.TIMED: return "چالش زمان‌دار"
		_: return "نسخه دستی"

func scenario_name_en() -> String:
	match scenario:
		Scenario.ELECTRIC: return "ELECTRIC"
		Scenario.SAUSAGE: return "SAUSAGE"
		Scenario.TIMED: return "TIMED"
		_: return "MANUAL"

func _configure_scenario(new_scenario: int) -> void:
	scenario = new_scenario
	match scenario:
		Scenario.ELECTRIC:
			sequence = ELECTRIC_SEQUENCE.duplicate()
		Scenario.SAUSAGE:
			sequence = SAUSAGE_SEQUENCE.duplicate()
		Scenario.TIMED:
			sequence = MANUAL_SEQUENCE.duplicate()
		_:
			sequence = MANUAL_SEQUENCE.duplicate()

func _reset_progress_and_parts() -> void:
	score = 0
	current_step = 1
	mistakes = 0
	first_try_count = 0
	timed_bonus = 0
	_step_errors = 0
	completed_parts.clear()
	focus_part_id = &""
	elapsed_time = 0.0
	for part in _parts():
		part.reset_part()
	_apply_scenario_part_visibility()
	for node in get_tree().get_nodes_in_group("assembly_sockets"):
		if node.has_method("reset_socket"):
			node.call("reset_socket")

func _finish_session() -> void:
	session_state = SessionState.COMPLETE
	focus_part_id = &""
	_play(_complete_audio)
	_haptic_all(0.55, 0.20)
	_show_feedback("✓ سناریو کامل شد", Color(0.35, 1.0, 0.58), 1.4)
	_update_ui()
	_refresh_part_guides()
	_set_result_visible(true)
	_update_result_panel()

func _fail_timed_session() -> void:
	if session_state != SessionState.RUNNING:
		return
	session_state = SessionState.FAILED
	focus_part_id = &""
	_play(_error_audio)
	_haptic_error()
	_show_feedback("⏱ زمان تمام شد", Color(1.0, 0.35, 0.28), 1.5)
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

func _apply_scenario_part_visibility() -> void:
	for part in _parts():
		if part.part_id not in OPTIONAL_IDS:
			continue
		var active := part.part_id in sequence
		part.visible = active
		part.freeze = true
		part.linear_velocity = Vector3.ZERO
		part.angular_velocity = Vector3.ZERO
		part.collision_layer = AssemblySettings.LAYER_PARTS if active else 0
		part.collision_mask = AssemblySettings.PART_NORMAL_MASK if active else 0
		if not active:
			part.set_guide_off()

func _refresh_part_guides() -> void:
	for part in _parts():
		if not is_part_enabled(part.part_id):
			part.set_guide_off()
		elif part.is_placed:
			part.set_guide_placed()
		elif session_state != SessionState.RUNNING:
			part.set_guide_off()
		elif mode == Mode.TRAINING and part.part_id == expected_part_id() and show_target_guides():
			part.set_guide_target()
		elif mode == Mode.FREE_PRACTICE and focus_part_id != &"" and part.part_id == focus_part_id:
			part.set_guide_target()
		else:
			part.set_guide_off()

func _update_ui() -> void:
	if difficulty_label:
		difficulty_label.text = "سختی  %s%s" % [AssemblySettings.difficulty_name_fa(), " • ۹۰ ثانیه" if scenario == Scenario.TIMED else ""]
	if score_label:
		if mode == Mode.FREE_PRACTICE and session_state != SessionState.MENU:
			score_label.text = "امتیاز  —"
		else:
			score_label.text = "امتیاز  %d / %d" % [score, _max_score()]
	if mistakes_label:
		mistakes_label.text = "خطا  %d" % mistakes
	if accuracy_label:
		accuracy_label.text = "دقت  —" if (mode == Mode.FREE_PRACTICE and session_state != SessionState.MENU) else "دقت  %d%%" % _accuracy_percent()
	if mode_label:
		var state_text := "منو" if session_state == SessionState.MENU else ("تمرین آزاد" if mode == Mode.FREE_PRACTICE else "آموزش")
		if scenario == Scenario.TIMED and session_state == SessionState.RUNNING:
			state_text = "چالش"
		mode_label.text = "%s • %s" % [scenario_name_fa(), state_text]
	if step_label:
		if session_state == SessionState.MENU:
			step_label.text = "%d قطعه در این سناریو" % sequence.size()
		elif session_state == SessionState.COMPLETE:
			step_label.text = "%d از %d — تکمیل" % [sequence.size(), sequence.size()]
		elif session_state == SessionState.FAILED:
			step_label.text = "%d از %d — زمان تمام شد" % [completed_parts.size(), sequence.size()]
		elif mode == Mode.TRAINING:
			step_label.text = "مرحله %d از %d" % [current_step, sequence.size()]
		else:
			step_label.text = "%d از %d قطعه" % [completed_parts.size(), sequence.size()]
	_update_time_label()
	_update_tutorial()

func _update_tutorial() -> void:
	if tutorial_label == null:
		return
	if session_state == SessionState.MENU:
		tutorial_label.text = "سناریو: %s\nاز پنل سمت راست سناریو را عوض کن؛ سپس آموزش یا تمرین آزاد را شروع کن." % scenario_name_fa()
	elif session_state == SessionState.COMPLETE:
		tutorial_label.text = "سناریو با موفقیت کامل شد. نتیجه روی پنل نمایش داده شده است."
	elif session_state == SessionState.FAILED:
		tutorial_label.text = "زمان چالش تمام شد. از «تکرار» برای تلاش دوباره استفاده کن."
	elif mode == Mode.FREE_PRACTICE:
		tutorial_label.text = "%s — تمرین آزاد\nهر قطعه فعال را بردار؛ Snap و Collision مکانیکی فعال است." % scenario_name_fa()
	elif scenario == Scenario.TIMED:
		tutorial_label.text = "چالش زمان‌دار\n۹۰ ثانیه فرصت داری. راهنمای قرمز خاموش است؛ فقط محدوده سبز تأیید اتصال را نشان می‌دهد."
	else:
		match expected_part_id():
			&"auger": tutorial_label.text = "مارپیچ را بردار و به دهانه نزدیک کن."
			&"blade": tutorial_label.text = "تیغه را روی محور جلوی مارپیچ قرار بده."
			&"plate": tutorial_label.text = "صفحه سوراخ‌دار را جلوی تیغه نصب کن."
			&"lock_ring": tutorial_label.text = "مهره قفل را روی مجموعه جلویی نصب کن؛ در سناریوی سوسیس، نازل بعد از مهره نصب می‌شود."
			&"handle": tutorial_label.text = "دسته دستی را به محور عقب دستگاه وصل کن."
			&"motor_unit": tutorial_label.text = "واحد موتور را به کوپلینگ عقب دستگاه متصل کن."
			&"sausage_attachment": tutorial_label.text = "نازل سوسیس را بعد از مهره قفل، روی خروجی جلویی نصب کن."
			&"hopper_tray": tutorial_label.text = "سینی ورودی را روی گلویی بالای دستگاه قرار بده."
			&"pusher": tutorial_label.text = "گوشت‌کوب را از بالا داخل ورودی سینی قرار بده."
			_: tutorial_label.text = "مونتاژ کامل شد"
	tutorial_changed.emit(tutorial_label.text)

func _update_time_label() -> void:
	if time_label == null:
		return
	if scenario == Scenario.TIMED and session_state == SessionState.RUNNING:
		var remaining: int = maxi(0, int(ceil(TIMED_LIMIT_S - elapsed_time)))
		time_label.text = "زمان باقی‌مانده  %02d:%02d" % [int(remaining / 60), remaining % 60]
	else:
		time_label.text = "زمان  %s" % _format_time(elapsed_time)

func _accuracy_percent() -> int:
	var good := completed_parts.size()
	var total := good + mistakes
	if total <= 0:
		return 100
	return int(round((float(good) / float(total)) * 100.0))

func _max_score() -> int:
	var base := sequence.size() * (AssemblySettings.CORRECT_PLACEMENT_SCORE + AssemblySettings.FIRST_TRY_BONUS) + AssemblySettings.COMPLETION_BONUS
	if scenario == Scenario.TIMED:
		base += int(TIMED_LIMIT_S)
	return base

func _format_time(value: float) -> String:
	var total := int(value)
	return "%02d:%02d" % [int(total / 60), total % 60]

func _set_result_visible(value: bool) -> void:
	if result_panel:
		result_panel.visible = value

func _update_result_panel() -> void:
	if result_body == null:
		return
	if session_state == SessionState.FAILED:
		result_body.text = "سناریو: %s\nزمان تمام شد\nپیشرفت: %d / %d قطعه\nامتیاز: %d\nخطا: %d" % [scenario_name_fa(), completed_parts.size(), sequence.size(), score, mistakes]
	elif mode == Mode.FREE_PRACTICE:
		result_body.text = "سناریو: %s\nتمرین آزاد کامل شد\nزمان: %s\nقطعات: %d / %d\nدر این حالت امتیاز و جریمه محاسبه نمی‌شود." % [scenario_name_fa(), _format_time(elapsed_time), completed_parts.size(), sequence.size()]
	else:
		var timed_line := "\nBonus زمان: +%d" % timed_bonus if scenario == Scenario.TIMED else ""
		result_body.text = "سناریو: %s\nامتیاز نهایی: %d / %d\nزمان: %s\nدقت: %d%%    |    خطا: %d\nاولین تلاش: %d / %d%s" % [scenario_name_fa(), score, _max_score(), _format_time(elapsed_time), _accuracy_percent(), mistakes, first_try_count, sequence.size(), timed_line]

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

func _ensure_scenario_panel() -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	var board := root.get_node_or_null("EnvironmentRoot/InstructionBoard") as Node3D
	if board == null or board.get_node_or_null("ScenarioPanel") != null:
		return
	var packed := load("res://scenes/ui/scenario_panel.tscn") as PackedScene
	if packed:
		var panel := packed.instantiate()
		panel.name = "ScenarioPanel"
		board.add_child(panel)

func _ensure_optional_parts_and_sockets() -> void:
	var assembly_root := get_parent() as Node3D
	if assembly_root == null:
		return
	var parts_spawn := assembly_root.get_node_or_null("PartsSpawn") as Node3D
	var sockets_root := assembly_root.get_node_or_null("SnapSockets") as Node3D
	if parts_spawn == null or sockets_root == null:
		return
	_ensure_optional_part(parts_spawn, "PartHandle", "res://scenes/grinder/parts/part_handle.tscn", Vector3(1.02, 0.13, 0.33))
	_ensure_optional_part(parts_spawn, "PartMotorUnit", "res://scenes/grinder/parts/part_motor_unit.tscn", Vector3(1.02, 0.14, 0.33))
	_ensure_optional_part(parts_spawn, "PartSausageAttachment", "res://scenes/grinder/parts/part_sausage_attachment.tscn", Vector3(-1.02, 0.13, 0.33))
	_ensure_socket(sockets_root, "SocketHandle", &"handle", Vector3(-0.205, 0.34, 0), 0.0, Vector3(-1, 0, 0), 0.065, 1, 0.035, 0.047)
	_ensure_socket(sockets_root, "SocketMotorUnit", &"motor_unit", Vector3(-0.205, 0.34, 0), 0.0, Vector3(-1, 0, 0), 0.070, 1, 0.050, 0.065)
	_ensure_socket(sockets_root, "SocketSausageAttachment", &"sausage_attachment", Vector3(0.252, 0.34, 0), 180.0, Vector3(1, 0, 0), 0.055, 1, 0.037, 0.052)

func _ensure_optional_part(parent: Node3D, node_name: String, scene_path: String, spawn_position: Vector3) -> void:
	if parent.get_node_or_null(node_name) != null:
		return
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_warning("Phase 8 optional part missing: %s" % scene_path)
		return
	var part := packed.instantiate() as Node3D
	part.name = node_name
	part.position = spawn_position
	parent.add_child(part)

func _ensure_socket(parent: Node3D, node_name: String, part_id: StringName, pos: Vector3, yaw_deg: float, approach_axis: Vector3, approach_distance: float, guide_axis_value: int, inner: float, outer: float) -> void:
	if parent.get_node_or_null(node_name) != null:
		return
	var socket := SnapSocket.new()
	socket.name = node_name
	socket.position = pos
	socket.collision_layer = 0
	socket.collision_mask = AssemblySettings.LAYER_PARTS
	socket.monitoring = true
	socket.socket_id = StringName("socket_" + String(part_id))
	socket.expected_part_id = part_id
	socket.manager_path = NodePath("../../AssemblyManager")
	socket.approach_axis_local = approach_axis
	socket.approach_distance_m = approach_distance
	socket.guide_axis = guide_axis_value
	socket.guide_offset_m = 0.018
	socket.guide_inner_radius_m = inner
	socket.guide_outer_radius_m = outer
	var shape_node := CollisionShape3D.new()
	shape_node.name = "CollisionShape3D"
	var sphere := SphereShape3D.new()
	sphere.radius = AssemblySettings.READY_RADIUS_M
	shape_node.shape = sphere
	socket.add_child(shape_node)
	var snap := Node3D.new()
	snap.name = "SnapPoint"
	snap.rotation_degrees = Vector3(0, yaw_deg, 0)
	socket.add_child(snap)
	parent.add_child(socket)
