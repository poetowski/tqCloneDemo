extends Node
## The global signal bus. Systems that don't know each other talk through it:
## combat announces hits and deaths, the HUD, quests, audio and loot listen.
## Signals are named in the past tense; they report what happened.

## Damage was applied. `info` is a DamageInfo.
signal damage_dealt(target: Node3D, info: RefCounted)
## An actor died. `killer` may be null.
signal actor_died(actor: Node3D, killer: Node3D)
## The player gained experience (after level scaling).
signal xp_gained(amount: int)
## The player reached a new level.
signal level_reached(level: int)
## An item went into the player's inventory, belt or purse.
signal item_picked_up(item: RefCounted)
## Drachmae changed hands; `total` is the new purse.
signal gold_changed(total: int)
## A quest advanced or finished.
signal quest_updated(quest_id: StringName)
## An NPC wants to talk to the player.
signal dialogue_requested(npc: Node3D)
## The player entered a named area (banner text).
signal area_entered(area_name: String)
## A boss noticed the player; the HUD shows its bar.
signal boss_engaged(boss: Node3D)
## The boss fell.
signal boss_defeated(boss: Node3D)
## The boss gave up the fight (the hero died or left) and went home to heal.
signal boss_reset(boss: Node3D)
## The player died / came back.
signal player_died()
signal player_respawned()
## A centre-screen message for the player.
signal notified(text: String, color: Color)
## A shrine (Hearth of Hestia) was lit.
signal shrine_lit(shrine: Node3D)
## The demo's last beat: the first blade was claimed.
signal demo_completed()
