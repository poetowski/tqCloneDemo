class_name SkillBook
extends RefCounted
## The hero's ranks in each skill of the Loom (data/skills.json) and the points
## left to spend.

signal changed()

var points := 0
var _ranks: Dictionary = {}


func rank(id: StringName) -> int:
	return int(_ranks.get(id, 0))


func knows(id: StringName) -> bool:
	return rank(id) > 0


func can_learn(id: StringName, hero_level: int) -> bool:
	var data := DB.skill(id)
	if data.is_empty() or points <= 0:
		return false
	return hero_level >= int(data.get("unlock", 1)) and rank(id) < int(data.get("max_rank", 5))


func learn(id: StringName, hero_level: int) -> bool:
	if not can_learn(id, hero_level):
		return false
	_ranks[id] = rank(id) + 1
	points -= 1
	changed.emit()
	return true


## Gives a rank for free (the hero starts knowing Lunge).
func grant(id: StringName) -> void:
	_ranks[id] = maxi(1, rank(id))
	changed.emit()


## A skill parameter at the current rank (or `at_rank`).
func param(id: StringName, key: String, at_rank: int = -1) -> float:
	var data := DB.skill(id)
	var spec := (data.get("params", {}) as Dictionary).get(key, [0.0, 0.0]) as Array
	var r := maxi(1, rank(id) if at_rank < 0 else at_rank)
	return float(spec[0]) + float(spec[1]) * float(r - 1)


func cost(id: StringName) -> float:
	return float(DB.skill(id).get("cost", 0))


func cooldown(id: StringName) -> float:
	var spec := DB.skill(id).get("cooldown", [0.0, 0.0]) as Array
	return maxf(0.5, float(spec[0]) + float(spec[1]) * float(maxi(1, rank(id)) - 1)) if float(spec[0]) > 0.0 else 0.0


## The skill's description with its numbers filled in for a rank.
func describe(id: StringName, at_rank: int = -1) -> String:
	var data := DB.skill(id)
	var text := String(data.get("desc", ""))
	for key: Variant in (data.get("params", {}) as Dictionary):
		var value := param(id, String(key), at_rank)
		var shown := ""
		if String(key) == "damage":
			shown = str(int(round(value * 100.0)))
		elif String(key) == "count":
			shown = str(int(floor(value)))
		elif absf(value - round(value)) < 0.01:
			shown = str(int(round(value)))
		else:
			shown = "%.1f" % value
		text = text.replace("{%s}" % key, shown)
	return text


func to_dict() -> Dictionary:
	return {"points": points, "ranks": _ranks.duplicate()}
