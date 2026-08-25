extends Node
## Run-scoped state + persistent meta.
## meta carries stub fields so ships/upgrades bolt on at v1.1 without refactor.

signal xp_changed(xp: int, needed: int)
signal level_up(pending_levels: int)
signal hull_changed(hp: int, max_hp: int)
signal kills_changed(kills: int)
signal run_ended(won: bool)

const MAX_HP := 5
const SECTOR_END := 600.0   # Mercy jumps at 10:00
const BASE_XP_NEED := 6
const XP_NEED_PER_LEVEL := 4

var meta: Dictionary = {}
var run: Dictionary = {}


func _ready() -> void:
	reset_meta()


func reset_meta() -> void:
	meta = Storage.load_section("meta")
	if meta.is_empty():
		meta = {
			"version": 1,
			"runs": 0,
			"wins": 0,
			"best_time": 0.0,
			"best_kills": 0,
			# v1.1 stubs — do not build yet:
			# "ships": {}, "upgrades": {}, "credits": 0,
		}


func new_run() -> void:
	run = {
		"elapsed": 0.0,
		"hp": MAX_HP,
		"max_hp": MAX_HP,
		"kills": 0,
		"level": 1,
		"xp": 0,
		"xp_need": BASE_XP_NEED,
		"pending_levels": 0,
		"won": false,
	}
	hull_changed.emit(run.hp, run.max_hp)


func add_xp(n: int) -> void:
	run.xp += n
	while run.xp >= run.xp_need:
		run.xp -= run.xp_need
		run.level += 1
		run.xp_need = BASE_XP_NEED + run.level * XP_NEED_PER_LEVEL
		run.pending_levels += 1
	xp_changed.emit(run.xp, run.xp_need)
	if run.pending_levels > 0:
		level_up.emit(run.pending_levels)


func consume_pending_level() -> void:
	run.pending_levels = maxi(0, run.pending_levels - 1)


func damage(amount := 1) -> bool:
	run.hp -= amount
	hull_changed.emit(run.hp, run.max_hp)
	return run.hp <= 0


func heal(amount := 1) -> void:
	run.hp = mini(run.max_hp, run.hp + amount)
	hull_changed.emit(run.hp, run.max_hp)


func add_kill() -> void:
	run.kills += 1
	kills_changed.emit(run.kills)


func end_run(won: bool) -> void:
	run.won = won
	meta.runs += 1
	if won:
		meta.wins += 1
	meta.best_time = maxf(meta.best_time, float(run.elapsed))
	meta.best_kills = maxi(meta.best_kills, int(run.kills))
	Storage.save_section("meta", meta)
	run_ended.emit(won)
