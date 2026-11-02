extends Node
## One bounded, cancellable attack per cast, with a harmless warning period.
var host: Node
var fields: Array[Dictionary]=[]
const WARNING := 0.48
const ACTIVE := 0.18
const LIFETIME := 1.02

func cast(owner_id: int, at: Vector2, direction: int) -> void:
	if fields.size()>=6: return
	fields.append({"owner":owner_id,"pos":Vector2(clampf(at.x,90,1190),640),"direction":direction,"age":0.0,"dealt":false,"fired":false})

func cancel(owner_id: int) -> void:
	for i in range(fields.size()-1,-1,-1):
		if fields[i].owner==owner_id: fields.remove_at(i)

func clear() -> void:
	fields.clear()

func _physics_process(dt: float) -> void:
	if not host.playing() or host.hitstop>0: return
	advance(dt)

func advance(dt: float) -> void:
	for i in range(fields.size()-1,-1,-1):
		var field: Dictionary=fields[i]
		field.age+=dt
		if field.age>=WARNING and not field.fired:
			field.fired=true
			host.enemy_fx.field_burst(field,"spore")
			host.fx("spore_burst",field.pos,field.direction,0.65)
			host.play_sound("heavy",-25,1.6)
		if field.age>=WARNING and field.age<WARNING+ACTIVE and not field.dealt:
			var area := Rect2(field.pos+Vector2(-66,-132),Vector2(132,132))
			if is_instance_valid(host.player) and area.intersects(host.player.hurtbox()):
				# Dash contact consumes the cast, so protection cannot expire into a repeat hit.
				field.dealt=true
				host.player.take_hit(host.scaled_enemy_damage(21) if host.has_method("scaled_enemy_damage") else 21,int(field.direction))
				# A fatal hit clears the collection through finish(); stop this iteration.
				if not host.playing(): return
		if field.age>=LIFETIME: fields.remove_at(i)
