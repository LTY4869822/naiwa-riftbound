extends RefCounted
const TITLES:={"thorn_matriarch":"万棘 · 森罗猎场","mirror_weaver":"千镜 · 蛛网折光","bell_colossus":"震霄 · 三叠天钟","molten_wheel":"锁轨 · 熔轮处刑"}
const HINTS:={"thorn_matriarch":"两翼棘柱先落，中线随后爆发 · 连续换位","mirror_weaver":"低束跃起，高束落地 · 看准两次镜光","bell_colossus":"三叠钟波 · 跃起越过地面冲击","molten_wheel":"锁轨冲锋后折返 · 跃起或闪避穿过轮刃"}

static func begin(e: Node) -> void:
	e.aim_at_player()
	e.ult_count+=1
	e.ult_cooldown=15.0 if e.combat_phase<3 else 12.0
	e.ult_data={"title":TITLES[e.kind],"hint":HINTS[e.kind],"target":e.target,"origin":e.position,"facing":e.facing,"emitted":[],"apex":true,"destination":clampf(e.target.x+e.facing*145,140,1140)}
	e.host.boss_fields.cancel(e.eid)
	for owner in [-100,-101,-102,-103]: e.host.boss_fields.cancel(owner)
	e.transition("ult_tell")
	if e.kind=="thorn_matriarch":
		for i in 3:
			e.host.boss_fields.cast(e.eid,Vector2(e.target.x+[-165.0,165.0,0.0][i],640),"apex_thorn_matriarch",1.5+[0.0,.25,.72][i],27,65)
	elif e.kind=="mirror_weaver":
		var body: Rect2=e.hurtbox()
		var left: float=body.end.x+25 if e.facing>0 else 70
		var right: float=1210 if e.facing>0 else body.position.x-25
		if right-left>100:
			e.host.boss_fields.cast_rect(e.eid,Rect2(left,570,right-left,62),"biome_mirror_low",1.5,27,e.facing)
			e.host.boss_fields.cast_rect(e.eid,Rect2(left,330,right-left,62),"biome_mirror_high",2.55,27,e.facing)
	e.host.toast(TITLES[e.kind]+" · "+HINTS[e.kind])
	e.host.play_sound("ultimate_charge",-19,.78)
	e.host.refresh_hud()

static func step(e: CharacterBody2D, dt: float) -> bool:
	if not TITLES.has(e.kind): return false
	if e.state not in ["ult_tell","ult_active","ult_recover"]:
		if e.state=="approach" and e.combat_age>6 and e.hp<e.maximum*.86 and e.ult_cooldown<=0 and e.host.attack_budget(e): begin(e)
		else: return false
	e.velocity.y+=1700*dt
	e.velocity.x=0
	if e.state=="ult_tell" and e.timer>=1.5:
		e.transition("ult_active")
		e.host.play_sound("ultimate_launch",-19,.8)
	elif e.state=="ult_active":
		if e.kind=="bell_colossus":
			for i in 3:
				if e.timer>=i*.65 and not i in e.ult_data.emitted:
					e.ult_data.emitted.append(i)
					for side in [-1,1]: e.host.projectiles.append({"pos":e.position+Vector2(side*105,-26),"velocity":Vector2(side*420,0),"life":3.0,"owner":e.eid,"style":"bell_colossus","damage":e.host.scaled_enemy_damage(25),"radius":13.0,"ground_wave":true})
					e.host.play_sound("heavy",-20,.7+i*.14)
		elif e.kind=="molten_wheel":
			var travel: float=float(e.ult_data.destination)-float(e.ult_data.origin.x)
			if e.timer<1.0: e.velocity.x=travel
			elif e.timer>=1.70 and e.timer<2.70: e.velocity.x=-travel
			var pass_id:=0 if e.timer<1.0 else 1
			if absf(e.velocity.x)>100 and not pass_id in e.ult_data.emitted:
				if e.hurtbox().grow(18).intersects(e.host.player.hurtbox()):
					e.ult_data.emitted.append(pass_id)
					e.host.player.take_hit(e.host.scaled_enemy_damage(31),int(signf(e.velocity.x)))
		if e.timer>(2.9 if e.kind=="molten_wheel" else 2.15): e.transition("ult_recover")
	elif e.state=="ult_recover" and e.timer>.80:
		e.ult_data.clear()
		e.cooldown=.5
		e.transition("approach")
	e.move_and_slide()
	e.position.x=clampf(e.position.x,140,1140)
	e.host.stage.sync(e,dt)
	return true
