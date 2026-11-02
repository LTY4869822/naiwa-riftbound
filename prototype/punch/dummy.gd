extends Node
## Preview-only sparring target: no AI or movement, but normal visual recovery.
var host: Node
var target: WeakRef
func _process(dt: float) -> void:
	var e: Node=target.get_ref()
	if not is_instance_valid(e) or e.dead: queue_free(); return
	if not host.playing() or host.hitstop>0: return
	e.flash=maxf(0,e.flash-dt*6)
	e.timer+=dt
	if e.state=="stunned" and e.timer>.32: e.transition("approach")
	e.velocity=Vector2.ZERO
	host.stage.sync(e,dt)
