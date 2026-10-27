extends RefCounted
class_name AwakeningState

signal changed(previous: int, current: int)

enum Mode { ERIK, AWAKENING, DALE420, RECOVERY }
var mode: Mode = Mode.ERIK
var meter: float = 0.0
var remaining: float = 0.0
var encounter: String = ""
var encounter_spent: bool = false
var source_credit: Dictionary = {}
var seen_attacks: Dictionary = {}
var config: GarageConfig

func _init(tuning: GarageConfig) -> void:
	config = tuning

func reset() -> void:
	meter = 0.0
	remaining = 0.0
	encounter = ""
	encounter_spent = false
	source_credit.clear()
	seen_attacks.clear()
	_set_mode(Mode.ERIK)

func begin_encounter(id: String) -> void:
	# Only mission transitions call this. Leaving and re-entering an arena does
	# not reset the budget. Each encounter permits one awakening.
	if id == encounter:
		return
	encounter = id
	encounter_spent = false
	meter = 0.0
	source_credit.clear()
	seen_attacks.clear()

func family_damage(amount: float, source: String, attack_id: int, major: bool) -> bool:
	if mode != Mode.ERIK or encounter_spent or encounter.is_empty() or amount <= 0:
		return false
	var key := "%s:%s" % [source, attack_id]
	if seen_attacks.has(key):
		return false
	seen_attacks[key] = true
	var credited := float(source_credit.get(source, 0.0))
	var gain := minf(amount, maxf(0.0, config.fury_per_attacker - credited))
	source_credit[source] = credited + gain
	meter = minf(config.fury_threshold, meter + gain)
	# A major cartoon impact is the final trigger, never a passive timer.
	if meter >= config.fury_threshold and major:
		encounter_spent = true
		remaining = config.transformation_intro
		_set_mode(Mode.AWAKENING)
		return true
	return false

func tick(delta: float) -> void:
	if mode == Mode.ERIK:
		return
	remaining = maxf(0.0, remaining - delta)
	if remaining > 0.0:
		return
	match mode:
		Mode.AWAKENING:
			remaining = config.transformation_seconds
			_set_mode(Mode.DALE420)
		Mode.DALE420:
			meter = 0.0
			remaining = config.recovery_seconds
			_set_mode(Mode.RECOVERY)
		Mode.RECOVERY:
			_set_mode(Mode.ERIK)

func is_dale() -> bool:
	return mode == Mode.DALE420

func _set_mode(next: Mode) -> void:
	if mode == next:
		return
	var previous := mode
	mode = next
	changed.emit(previous, mode)
