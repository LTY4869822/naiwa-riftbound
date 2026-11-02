extends RefCounted
## Ground casts stay beyond the caster's body and visible effect rim.
static func direction(e: Node) -> int:
	var dx: float=e.host.player.position.x-e.position.x
	return (1 if e.position.x<640 else -1) if absf(dx)<4 else (1 if dx>0 else -1)

static func project(e: Node, wanted_x: float, radius: float) -> float:
	var bounds: Rect2=e.hurtbox()
	# Boss paintings extend beyond their compact hurtboxes. Reserve their full
	# silhouette too, so a legal hitbox cannot still paint an explosion on the boss.
	if e.boss:
		var mythic: bool=bool(preload("res://combat/enemy_catalog.gd").DATA.get(e.kind,{}).get("mythic",false))
		var half: float=220 if mythic else 160
		bounds=bounds.merge(Rect2(e.position+Vector2(-half,-370 if mythic else -340),Vector2(half*2,370 if mythic else 340)))
	var low: float=70+radius
	var high: float=1210-radius
	var clearance: float=radius*1.25+28
	if e.facing>0: low=maxf(low,bounds.end.x+clearance)
	else: high=minf(high,bounds.position.x-clearance)
	if low>high: return NAN
	return clampf(wanted_x,low,high)
