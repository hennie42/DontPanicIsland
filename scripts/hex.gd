class_name Hex
extends RefCounted
## Hex grid maths (director-written, tested in tests/test_hex.gd). Use these helpers; don't derive hex geometry.
## Axial coordinates Vector2i(q, r), pointy-top hexes matching the Kenney Hexagon Kit tiles (1.0 wide flat-to-flat
## along x, 1.155 tall point-to-point along z). World: x right, y up, z towards the camera; tile centres at y = 0.

const WIDTH := 1.0                      # flat-to-flat, world units (Kenney tile width)
const SIZE := WIDTH / sqrt(3.0)          # centre-to-corner
const ROW := SIZE * 1.5                  # z distance between rows (0.866)
## The six neighbours, in order around the hex (east, north-east, north-west, west, south-west, south-east).
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]


static func neighbors(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		out.append(c + d)
	return out


static func distance(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return (absi(d.x) + absi(d.y) + absi(d.x + d.y)) / 2


## Tile centre in world space (y = 0).
static func to_world(c: Vector2i) -> Vector3:
	return Vector3(WIDTH * (c.x + c.y * 0.5), 0.0, ROW * c.y)


## The hex containing a world point (y ignored): exact rounding in cube coordinates.
static func from_world(p: Vector3) -> Vector2i:
	var r := p.z / ROW
	var q := p.x / WIDTH - r * 0.5
	return round_axial(q, r)


static func round_axial(q: float, r: float) -> Vector2i:
	var s := -q - r
	var rq := roundf(q)
	var rr := roundf(r)
	var rs := roundf(s)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))


## All hexes within `radius` of `center` (radius 0 = the centre only), centre first, then ring by ring.
static func spiral(center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = [center]
	for k in range(1, radius + 1):
		out.append_array(ring(center, k))
	return out


static func ring(center: Vector2i, radius: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var c := center + DIRS[4] * radius
	for i in 6:
		for _j in radius:
			out.append(c)
			c += DIRS[i]
	return out


## Where a ray hits the ground plane y = height (null if it points away from it). For mouse picking:
##   var hit = Hex.ray_to_ground(cam.project_ray_origin(pos), cam.project_ray_normal(pos))
##   if hit != null: var cell := Hex.from_world(hit)
static func ray_to_ground(origin: Vector3, dir: Vector3, height: float = 0.0) -> Variant:
	if absf(dir.y) < 1e-6:
		return null
	var t := (height - origin.y) / dir.y
	if t < 0.0:
		return null
	return origin + dir * t
