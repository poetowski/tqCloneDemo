class_name Stats
extends RefCounted
## An actor's numbers: base values plus modifiers from named sources (equipment
## slots, buffs). value(stat) = (base + flat + derived) × (1 + percent / 100).
## `derive` lets the owner add contributions that depend on other stats (the
## player's Might adds health), computed after modifiers are summed.

signal changed()

const MAX_HEALTH := &"max_health"
const MAX_ICHOR := &"max_ichor"
const HEALTH_REGEN := &"health_regen"
const ICHOR_REGEN := &"ichor_regen"
const ARMOR := &"armor"
const DAMAGE_MIN := &"damage_min"
const DAMAGE_MAX := &"damage_max"
const DAMAGE_PCT := &"damage_pct"
const SKILL_DAMAGE_PCT := &"skill_damage_pct"
const ATTACK_SPEED := &"attack_speed"
const CRIT_CHANCE := &"crit_chance"
const CRIT_MULTIPLIER := &"crit_multiplier"
const MOVE_SPEED := &"move_speed"
const LIFE_ON_HIT := &"life_on_hit"
const FIRE_DAMAGE := &"fire_damage"
const MIGHT := &"might"
const CUNNING := &"cunning"
const SPIRIT := &"spirit"
const ALL_ATTRIBUTES := &"all_attributes"
const MAGIC_FIND := &"magic_find"

var base: Dictionary = {}
## Optional: func(stat: StringName) -> float, added before the percent multiplier.
var derive: Callable

var _sources: Dictionary = {}
var _cache: Dictionary = {}


func set_base(stat: StringName, amount: float) -> void:
	base[stat] = amount
	_invalidate()


func set_bases(values: Dictionary) -> void:
	for stat: Variant in values:
		base[StringName(stat)] = float(values[stat])
	_invalidate()


## Replaces every modifier from `source`. `mods` is an Array of Dictionaries:
## {"stat": StringName, "flat": float, "pct": float}.
func set_source(source: StringName, mods: Array) -> void:
	if mods.is_empty():
		_sources.erase(source)
	else:
		_sources[source] = mods.duplicate()
	_invalidate()


func clear_source(source: StringName) -> void:
	if _sources.erase(source):
		_invalidate()


func has_source(source: StringName) -> bool:
	return _sources.has(source)


## Recomputes everything; call when something `derive` reads has changed (level).
func refresh() -> void:
	_invalidate()


func value(stat: StringName) -> float:
	if _cache.has(stat):
		return float(_cache[stat])
	var flat := float(base.get(stat, 0.0))
	var percent := 0.0
	for mods: Variant in _sources.values():
		for mod: Variant in mods:
			var entry := mod as Dictionary
			if StringName(entry.get("stat", &"")) == stat:
				flat += float(entry.get("flat", 0.0))
				percent += float(entry.get("pct", 0.0))
	if derive.is_valid():
		flat += float(derive.call(stat))
	var result := flat * (1.0 + percent / 100.0)
	_cache[stat] = result
	return result


func _invalidate() -> void:
	_cache.clear()
	changed.emit()


## Makes a modifier entry.
static func mod(stat: StringName, flat: float = 0.0, pct: float = 0.0) -> Dictionary:
	return {"stat": stat, "flat": flat, "pct": pct}
