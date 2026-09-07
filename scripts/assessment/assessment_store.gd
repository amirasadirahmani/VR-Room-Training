class_name AssessmentStore
extends RefCounted

const SAVE_PATH: String = "user://phase9_assessment_records.cfg"

static func record_key(scenario_name: String, difficulty_name: String) -> String:
	return "%s_%s" % [scenario_name, difficulty_name]

static func load_record(section: String) -> Dictionary:
	var cfg: ConfigFile = ConfigFile.new()
	var load_result: int = cfg.load(SAVE_PATH)
	if load_result != OK:
		return _empty_record()
	return _read_record(cfg, section)

static func save_attempt(
	section: String,
	score: int,
	time_s: float,
	accuracy: int,
	grade: String,
	passed: bool
) -> Dictionary:
	var cfg: ConfigFile = ConfigFile.new()
	var load_result: int = cfg.load(SAVE_PATH)
	if load_result != OK:
		cfg = ConfigFile.new()

	var previous: Dictionary = _read_record(cfg, section)

	# The baseline is the first fully assessed run we can persist, regardless
	# of pass/fail. Older Phase 9 save files did not contain baseline fields;
	# the first run after this hotfix migrates them automatically.
	var baseline_score: int = int(previous.get("baseline_score", -1))
	var baseline_time: float = float(previous.get("baseline_time", -1.0))
	var baseline_accuracy: int = int(previous.get("baseline_accuracy", -1))
	var baseline_grade: String = String(previous.get("baseline_grade", ""))
	var baseline_passed: bool = bool(previous.get("baseline_passed", false))
	var baseline_created_now: bool = baseline_score < 0 or baseline_time < 0.0

	# Best records remain PASS-only, so a failed baseline never replaces a
	# genuine passing achievement.
	var best_score: int = int(previous.get("best_score", -1))
	var best_time: float = float(previous.get("best_time", -1.0))
	var best_accuracy: int = int(previous.get("best_accuracy", -1))
	var best_grade: String = String(previous.get("best_grade", ""))

	# Phase 9 v1 could store failed attempts without any baseline data. Those
	# attempts used the inflated drop-counting formula, so if there was never
	# a PASS record, start the v2 assessment history cleanly at Attempt 1.
	var previous_attempts: int = int(previous.get("attempts", 0))
	var previous_passes: int = int(previous.get("passes", 0))
	if baseline_created_now and best_score < 0 and previous_passes == 0:
		previous_attempts = 0
	var attempts: int = previous_attempts + 1
	var passes: int = previous_passes + (1 if passed else 0)

	if baseline_created_now:
		baseline_score = score
		baseline_time = time_s
		baseline_accuracy = accuracy
		baseline_grade = grade
		baseline_passed = passed

	var new_best_score: bool = false
	var new_best_time: bool = false
	var new_best_accuracy: bool = false
	var new_best_grade: bool = false

	if passed:
		if score > best_score:
			best_score = score
			new_best_score = true
		if best_time < 0.0 or time_s < best_time:
			best_time = time_s
			new_best_time = true
		if accuracy > best_accuracy:
			best_accuracy = accuracy
			new_best_accuracy = true
		if _grade_rank(grade) > _grade_rank(best_grade):
			best_grade = grade
			new_best_grade = true

	cfg.set_value(section, "attempts", attempts)
	cfg.set_value(section, "passes", passes)
	cfg.set_value(section, "baseline_score", baseline_score)
	cfg.set_value(section, "baseline_time", baseline_time)
	cfg.set_value(section, "baseline_accuracy", baseline_accuracy)
	cfg.set_value(section, "baseline_grade", baseline_grade)
	cfg.set_value(section, "baseline_passed", baseline_passed)
	cfg.set_value(section, "best_score", best_score)
	cfg.set_value(section, "best_time", best_time)
	cfg.set_value(section, "best_accuracy", best_accuracy)
	cfg.set_value(section, "best_grade", best_grade)

	var save_result: int = cfg.save(SAVE_PATH)
	if save_result != OK:
		push_warning("AssessmentStore: could not save records, error=%d" % save_result)

	return {
		"attempts": attempts,
		"passes": passes,
		"baseline_score": baseline_score,
		"baseline_time": baseline_time,
		"baseline_accuracy": baseline_accuracy,
		"baseline_grade": baseline_grade,
		"baseline_passed": baseline_passed,
		"baseline_created_now": baseline_created_now,
		"best_score": best_score,
		"best_time": best_time,
		"best_accuracy": best_accuracy,
		"best_grade": best_grade,
		"new_best_score": new_best_score,
		"new_best_time": new_best_time,
		"new_best_accuracy": new_best_accuracy,
		"new_best_grade": new_best_grade,
	}

static func _read_record(cfg: ConfigFile, section: String) -> Dictionary:
	if not cfg.has_section(section):
		return _empty_record()
	return {
		"attempts": int(cfg.get_value(section, "attempts", 0)),
		"passes": int(cfg.get_value(section, "passes", 0)),
		"baseline_score": int(cfg.get_value(section, "baseline_score", -1)),
		"baseline_time": float(cfg.get_value(section, "baseline_time", -1.0)),
		"baseline_accuracy": int(cfg.get_value(section, "baseline_accuracy", -1)),
		"baseline_grade": String(cfg.get_value(section, "baseline_grade", "")),
		"baseline_passed": bool(cfg.get_value(section, "baseline_passed", false)),
		"baseline_created_now": false,
		"best_score": int(cfg.get_value(section, "best_score", -1)),
		"best_time": float(cfg.get_value(section, "best_time", -1.0)),
		"best_accuracy": int(cfg.get_value(section, "best_accuracy", -1)),
		"best_grade": String(cfg.get_value(section, "best_grade", "")),
		"new_best_score": false,
		"new_best_time": false,
		"new_best_accuracy": false,
		"new_best_grade": false,
	}

static func _empty_record() -> Dictionary:
	return {
		"attempts": 0,
		"passes": 0,
		"baseline_score": -1,
		"baseline_time": -1.0,
		"baseline_accuracy": -1,
		"baseline_grade": "",
		"baseline_passed": false,
		"baseline_created_now": false,
		"best_score": -1,
		"best_time": -1.0,
		"best_accuracy": -1,
		"best_grade": "",
		"new_best_score": false,
		"new_best_time": false,
		"new_best_accuracy": false,
		"new_best_grade": false,
	}

static func _grade_rank(grade: String) -> int:
	match grade:
		"A": return 4
		"B": return 3
		"C": return 2
		"F": return 1
		_: return 0
