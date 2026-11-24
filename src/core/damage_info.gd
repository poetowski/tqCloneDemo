class_name DamageInfo
extends RefCounted
## One hit: who dealt it, how much, of what kind, and what else it does.

enum Kind { PHYSICAL, FIRE, STYX, TRUE }

var amount: float = 0.0
## What was actually taken after armour; set by Actor.take_damage.
var final_amount: float = 0.0
var kind: Kind = Kind.PHYSICAL
var is_crit := false
## Severed by Atropos' Mercy: killed outright.
var is_sever := false
var source: Node3D
var knockback := Vector3.ZERO
var stun := 0.0
var slow := 0.0
var slow_time := 0.0
var burn := 0.0
## Hit-stop and screen shake strength, 0..1.
var impact := 0.0


static func make(source_actor: Node3D, value: float, damage_kind: Kind = Kind.PHYSICAL) -> DamageInfo:
	var info := DamageInfo.new()
	info.source = source_actor
	info.amount = value
	info.kind = damage_kind
	return info
