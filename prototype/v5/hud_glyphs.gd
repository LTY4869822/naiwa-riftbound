extends RefCounted
## Small, source-native heraldic glyphs for the Naiwa combat HUD.
## Geometry lives in a unit circle. A radius of 20 produces a 1.5px main stroke.
## Call only from a CanvasItem's draw callback; the canvas transform is restored.

const STROKE := 0.075

static func draw_icon(canvas: CanvasItem, kind: String, at: Vector2, radius: float, color: Color, fill: Color = Color.TRANSPARENT) -> void:
	if radius <= 0.0:
		canvas.draw_set_transform(Vector2.ZERO)
		return
	canvas.draw_set_transform(at, 0.0, Vector2.ONE * radius)
	match kind:
		"health", "heart", "life": _health(canvas, color, fill)
		"stamina", "bolt": _stamina(canvas, color, fill)
		"focus", "fragment": _focus(canvas, color, fill)
		"slash", "attack": _slash(canvas, color, fill)
		"heavy", "hammer": _heavy(canvas, color, fill)
		"dash", "feather": _dash(canvas, color, fill)
		"skill", "burst": _skill(canvas, color, fill)
		"crown", "boss": _crown(canvas, color, fill)
		"shield", "invulnerable": _shield(canvas, color, fill)
		"bag", "supply": _bag(canvas, color, fill)
		"pause": _pause(canvas, color, fill)
		"pet", "naiwa", "frog": _pet(canvas, color, fill)
		"leaf": _leaf(canvas, color, fill)
		_:
			_shape(canvas, PackedVector2Array([Vector2(0,-0.75),Vector2(0.53,0),Vector2(0,0.75),Vector2(-0.53,0)]), color, fill)
	canvas.draw_set_transform(Vector2.ZERO)

static func _line(canvas: CanvasItem, points: PackedVector2Array, color: Color, width: float = STROKE) -> void:
	if points.size() >= 2: canvas.draw_polyline(points, color, width, true)

static func _shape(canvas: CanvasItem, points: PackedVector2Array, color: Color, fill: Color, width: float = STROKE) -> void:
	if points.size() < 3: return
	var polygon := points.duplicate()
	if polygon[0].is_equal_approx(polygon[polygon.size()-1]): polygon.resize(polygon.size()-1)
	if fill.a > 0.0: canvas.draw_colored_polygon(polygon, fill)
	var closed := polygon.duplicate()
	closed.append(closed[0])
	_line(canvas, closed, color, width)

static func _bezier(a: Vector2, b: Vector2, c: Vector2, d: Vector2, segments: int = 10) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in range(segments + 1):
		var t := float(i) / segments
		var u := 1.0 - t
		result.append(a*u*u*u + b*3.0*u*u*t + c*3.0*u*t*t + d*t*t*t)
	return result

static func _append_curve(points: PackedVector2Array, a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> PackedVector2Array:
	var curve := _bezier(a,b,c,d)
	for i in range(1,curve.size()): points.append(curve[i])
	return points

static func _rotate(points: PackedVector2Array, angle: float, offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var rotated := PackedVector2Array()
	for point in points: rotated.append(point.rotated(angle) + offset)
	return rotated

static func _health(canvas: CanvasItem, color: Color, fill: Color) -> void:
	var p := PackedVector2Array([Vector2(0,-0.37)])
	p = _append_curve(p,Vector2(0,-0.37),Vector2(0.29,-0.92),Vector2(0.98,-0.69),Vector2(0.83,-0.12))
	p = _append_curve(p,Vector2(0.83,-0.12),Vector2(0.73,0.27),Vector2(0.26,0.63),Vector2(0,0.88))
	p = _append_curve(p,Vector2(0,0.88),Vector2(-0.26,0.63),Vector2(-0.73,0.27),Vector2(-0.83,-0.12))
	p = _append_curve(p,Vector2(-0.83,-0.12),Vector2(-0.98,-0.69),Vector2(-0.29,-0.92),Vector2(0,-0.37))
	_shape(canvas,p,color,fill)
	_line(canvas,PackedVector2Array([Vector2(-0.42,0.03),Vector2(-0.18,0.03),Vector2(-0.05,-0.17),Vector2(0.10,0.24),Vector2(0.22,0.03),Vector2(0.43,0.03)]),Color(color, color.a*0.72),0.055)

static func _stamina(canvas: CanvasItem, color: Color, fill: Color) -> void:
	_shape(canvas,PackedVector2Array([Vector2(0.14,-0.92),Vector2(-0.66,0.12),Vector2(-0.11,0.12),Vector2(-0.25,0.91),Vector2(0.69,-0.25),Vector2(0.16,-0.25)]),color,fill)

static func _focus(canvas: CanvasItem, color: Color, fill: Color) -> void:
	var shard := PackedVector2Array([Vector2(0,-0.96),Vector2(0.22,-0.49),Vector2(0,-0.23),Vector2(-0.22,-0.49)])
	for i in 4: _shape(canvas,_rotate(shard,i*PI*0.5),color,fill,0.06)
	canvas.draw_circle(Vector2.ZERO,0.065,color)

static func _slash(canvas: CanvasItem, color: Color, fill: Color) -> void:
	# Three separate tapered crescents, readable without a weapon silhouette.
	for i in 3:
		var shift := Vector2(-0.32 + i*0.32,-0.20 + i*0.20)
		var p := _bezier(Vector2(-0.42,0.67),Vector2(-0.40,-0.01),Vector2(-0.07,-0.62),Vector2(0.53,-0.77))
		p = _append_curve(p,Vector2(0.53,-0.77),Vector2(0.15,-0.37),Vector2(-0.04,0.18),Vector2(-0.42,0.67))
		_shape(canvas,_rotate(p,0.0,shift),color,fill,0.048)

static func _heavy(canvas: CanvasItem, color: Color, fill: Color) -> void:
	var head := PackedVector2Array([Vector2(-0.70,-0.67),Vector2(-0.49,-0.80),Vector2(0.49,-0.80),Vector2(0.70,-0.67),Vector2(0.70,-0.23),Vector2(0.49,-0.10),Vector2(-0.49,-0.10),Vector2(-0.70,-0.23)])
	_shape(canvas,_rotate(head,0.36),color,fill)
	var handle := PackedVector2Array([Vector2(-0.10,-0.08),Vector2(0.10,-0.08),Vector2(0.13,0.83),Vector2(-0.13,0.83)])
	_shape(canvas,_rotate(handle,0.36),color,fill,0.065)
	_line(canvas,PackedVector2Array([Vector2(0.51,0.51),Vector2(0.74,0.65)]),color,0.055)
	_line(canvas,PackedVector2Array([Vector2(0.62,0.29),Vector2(0.87,0.31)]),color,0.055)

static func _dash(canvas: CanvasItem, color: Color, fill: Color) -> void:
	var p := PackedVector2Array([Vector2(-0.59,0.67)])
	p = _append_curve(p,Vector2(-0.59,0.67),Vector2(-0.83,-0.14),Vector2(-0.09,-0.72),Vector2(0.78,-0.83))
	p = _append_curve(p,Vector2(0.78,-0.83),Vector2(0.85,-0.05),Vector2(0.39,0.54),Vector2(-0.59,0.67))
	_shape(canvas,p,color,fill)
	_line(canvas,PackedVector2Array([Vector2(-0.77,0.85),Vector2(0.57,-0.60)]),color,0.065)
	_line(canvas,PackedVector2Array([Vector2(-0.22,0.29),Vector2(-0.20,-0.17)]),Color(color,color.a*0.8),0.05)
	_line(canvas,PackedVector2Array([Vector2(0.06,-0.02),Vector2(0.46,0.02)]),Color(color,color.a*0.8),0.05)
	_line(canvas,PackedVector2Array([Vector2(-0.91,-0.07),Vector2(-0.64,-0.07)]),color,0.055)
	_line(canvas,PackedVector2Array([Vector2(-0.99,0.20),Vector2(-0.72,0.20)]),color,0.055)

static func _skill(canvas: CanvasItem, color: Color, fill: Color) -> void:
	var petal := PackedVector2Array([Vector2(0,-0.97)])
	petal = _append_curve(petal,Vector2(0,-0.97),Vector2(0.33,-0.71),Vector2(0.31,-0.36),Vector2(0,-0.22))
	petal = _append_curve(petal,Vector2(0,-0.22),Vector2(-0.31,-0.36),Vector2(-0.33,-0.71),Vector2(0,-0.97))
	for i in 4: _shape(canvas,_rotate(petal,i*PI*0.5),color,fill,0.06)
	canvas.draw_arc(Vector2.ZERO,0.14,0,TAU,20,color,0.065,true)
	for i in 4:
		var a := PI*0.25+i*PI*0.5
		canvas.draw_circle(Vector2(cos(a),sin(a))*0.66,0.035,color)

static func _crown(canvas: CanvasItem, color: Color, fill: Color) -> void:
	var p := PackedVector2Array([Vector2(-0.78,0.29),Vector2(-0.91,-0.49),Vector2(-0.39,-0.12),Vector2(0,-0.82),Vector2(0.39,-0.12),Vector2(0.91,-0.49),Vector2(0.78,0.29),Vector2(0.65,0.56),Vector2(-0.65,0.56)])
	_shape(canvas,p,color,fill)
	_line(canvas,PackedVector2Array([Vector2(-0.68,0.31),Vector2(0.68,0.31)]),color,0.055)
	canvas.draw_circle(Vector2(0,-0.82),0.07,color)
	canvas.draw_circle(Vector2(-0.91,-0.49),0.055,color)
	canvas.draw_circle(Vector2(0.91,-0.49),0.055,color)
	_shape(canvas,PackedVector2Array([Vector2(0,-0.16),Vector2(0.11,0.01),Vector2(0,0.17),Vector2(-0.11,0.01)]),color,fill,0.045)

static func _shield(canvas: CanvasItem, color: Color, fill: Color) -> void:
	var p := PackedVector2Array([Vector2(0,-0.88),Vector2(0.73,-0.58)])
	p = _append_curve(p,Vector2(0.73,-0.58),Vector2(0.77,0.15),Vector2(0.50,0.62),Vector2(0,0.93))
	p = _append_curve(p,Vector2(0,0.93),Vector2(-0.50,0.62),Vector2(-0.77,0.15),Vector2(-0.73,-0.58))
	_shape(canvas,p,color,fill)
	_shape(canvas,PackedVector2Array([Vector2(0,-0.43),Vector2(0.22,0.02),Vector2(0,0.40),Vector2(-0.22,0.02)]),color,fill,0.06)

static func _bag(canvas: CanvasItem, color: Color, fill: Color) -> void:
	var p := PackedVector2Array([Vector2(-0.31,-0.49),Vector2(0.31,-0.49)])
	p = _append_curve(p,Vector2(0.31,-0.49),Vector2(0.43,-0.24),Vector2(0.77,0.11),Vector2(0.68,0.57))
	p = _append_curve(p,Vector2(0.68,0.57),Vector2(0.62,0.88),Vector2(-0.62,0.88),Vector2(-0.68,0.57))
	p = _append_curve(p,Vector2(-0.68,0.57),Vector2(-0.77,0.11),Vector2(-0.43,-0.24),Vector2(-0.31,-0.49))
	_shape(canvas,p,color,fill)
	_shape(canvas,PackedVector2Array([Vector2(-0.31,-0.50),Vector2(-0.41,-0.84),Vector2(-0.08,-0.72),Vector2(0.15,-0.87),Vector2(0.40,-0.82),Vector2(0.31,-0.50)]),color,fill,0.06)
	_line(canvas,PackedVector2Array([Vector2(-0.37,-0.49),Vector2(0.39,-0.49)]),color,0.09)
	_shape(canvas,PackedVector2Array([Vector2(0,0.01),Vector2(0.20,0.25),Vector2(0,0.48),Vector2(-0.20,0.25)]),color,fill,0.055)

static func _pause(canvas: CanvasItem, color: Color, fill: Color) -> void:
	for x in [-0.42,0.42]:
		var p := PackedVector2Array([Vector2(x-0.11,-0.73),Vector2(x+0.11,-0.73),Vector2(x+0.15,-0.67),Vector2(x+0.15,0.67),Vector2(x+0.11,0.73),Vector2(x-0.11,0.73),Vector2(x-0.15,0.67),Vector2(x-0.15,-0.67)])
		_shape(canvas,p,color,fill)

static func _pet(canvas: CanvasItem, color: Color, fill: Color) -> void:
	var p := PackedVector2Array([Vector2(-0.79,-0.08)])
	p = _append_curve(p,Vector2(-0.79,-0.08),Vector2(-0.94,-0.73),Vector2(-0.18,-0.93),Vector2(-0.11,-0.40))
	p = _append_curve(p,Vector2(-0.11,-0.40),Vector2(-0.04,-0.44),Vector2(0.04,-0.44),Vector2(0.11,-0.40))
	p = _append_curve(p,Vector2(0.11,-0.40),Vector2(0.18,-0.93),Vector2(0.94,-0.73),Vector2(0.79,-0.08))
	p = _append_curve(p,Vector2(0.79,-0.08),Vector2(1.08,0.78),Vector2(-1.08,0.78),Vector2(-0.79,-0.08))
	_shape(canvas,p,color,fill)
	canvas.draw_circle(Vector2(-0.43,-0.44),0.10,color)
	canvas.draw_circle(Vector2(0.43,-0.44),0.10,color)
	canvas.draw_arc(Vector2(0,-0.01),0.33,PI*0.17,PI*0.83,18,color,0.065,true)

static func _leaf(canvas: CanvasItem, color: Color, fill: Color) -> void:
	var p := PackedVector2Array([Vector2(0.67,-0.86)])
	p = _append_curve(p,Vector2(0.67,-0.86),Vector2(0.88,0.30),Vector2(0.18,0.91),Vector2(-0.58,0.59))
	p = _append_curve(p,Vector2(-0.58,0.59),Vector2(-0.86,-0.23),Vector2(-0.17,-0.82),Vector2(0.67,-0.86))
	_shape(canvas,p,color,fill)
	_line(canvas,PackedVector2Array([Vector2(-0.75,0.84),Vector2(0.48,-0.59)]),color,0.065)
	_line(canvas,PackedVector2Array([Vector2(-0.26,0.27),Vector2(-0.28,-0.18)]),Color(color,color.a*0.8),0.05)
	_line(canvas,PackedVector2Array([Vector2(0.04,-0.07),Vector2(0.39,-0.04)]),Color(color,color.a*0.8),0.05)
