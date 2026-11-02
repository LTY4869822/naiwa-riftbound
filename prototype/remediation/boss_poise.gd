extends RefCounted
## Light hits build a break. A break has a fixed duration and a protected recovery.
const LIMIT:=100.0
const PROTECTION:=2.3
const ULT_WINDOW:=0.45

static func hit(e: Node, heavy: bool) -> bool:
	if e.state=="stunned": return false
	e.stagger=minf(LIMIT,e.stagger+(42.0 if heavy else 12.0))
	if heavy and is_instance_valid(e.host.get("rift")): e.stagger=minf(LIMIT,e.stagger+e.host.rift.rank("edge")*9)
	var committed: bool=e.state=="ult_active" or e.state=="ult_tell" and e.timer>=ULT_WINDOW
	if e.break_guard>0 or committed: return false
	var counter: bool=heavy and (e.state=="tell" and e.timer<.28 or e.state=="ult_tell" and e.timer<ULT_WINDOW)
	if not counter and e.stagger<LIMIT: return false
	e.stagger=0
	e.break_guard=PROTECTION
	if e.state=="ult_tell":
		e.host.boss_fields.cancel(e.eid)
		if is_instance_valid(e.host.get("spectacle")): e.host.spectacle.cancel(e.eid)
		e.ult_data.clear()
		e.ult_cooldown=9.0
	e.host.float_number(e.position+Vector2(0,-230),"破势",Color("8bd9cd"))
	return true
