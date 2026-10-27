extends SceneTree

## CityRenderer — offline build tool that bakes the illustrated 3D city background.
## Builds a low-poly 3D city from map.json (roads on every taxi/bus link, river through the
## ferry stations, parks, ponds, buildings, trees), renders it once with a tilted orthographic
## camera, and saves 2x2 background tiles that line up exactly with board coordinates.
##
## Run (needs a display; use xvfb-run on Linux):
##   godot --path . --rendering-driver opengl3 -s res://game/scripts/utils/CityRenderer.gd
## Optional user args: -- <map.json> <out_dir> <px_per_unit>
## Not part of the game at runtime: it only writes PNG files.

const PITCH_DEG := 58.0
## Area baked into the background, in board coordinates.
const AREA := Rect2(-400.0, -400.0, 3200.0, 2600.0)
const TILES_X := 2
const TILES_Y := 2

const TAXI_W := 11.0
const TAXI_WALK := 16.0
const BUS_W := 16.0
const BUS_STRIPE := 3.5
const BUS_WALK := 22.0
const RIVER_W := 64.0
const BANK_W := 80.0
## River runs this far below the ferry stations, so they sit on its north bank.
const RIVER_OFFSET := 52.0
## Buildings only grow this close to the road network; beyond is countryside.
const URBAN_REACH := 170.0

var map_path := "res://game/assets/data/map.json"
var out_dir := "res://game/assets/sprites/backgrounds/city"
var px_per_unit := 1.25

var S := sin(deg_to_rad(PITCH_DEG))
var rng := RandomNumberGenerator.new()
var stations := {}            # id -> Vector2
var station_list: Array[Vector2] = []
var road_segs: Array = []     # [a: Vector2, b: Vector2, half_width: float]
var river: PackedVector2Array
var ponds: Array = []         # [center: Vector2, radii: Vector2, angle]
var city_center := Vector2.ZERO
var world: Node3D
var noise := FastNoiseLite.new()
var park_noise := FastNoiseLite.new()

# Spatial hash of road segments and placed objects for fast distance checks.
const CELL := 80.0
var seg_grid := {}
var occ_grid := {}

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: map_path = args[0]
	if args.size() > 1: out_dir = args[1]
	if args.size() > 2: px_per_unit = float(args[2])
	rng.seed = 20261027
	noise.seed = 11
	noise.frequency = 0.004
	_run.call_deferred()

func _run() -> void:
	_load_map()
	_define_landscape()
	world = Node3D.new()
	world.scale = Vector3(1.0, 1.0, 1.0 / S) # ground compression undone by the tilted camera
	root.add_child(world)
	_build_environment()
	_build_ground()
	_build_water()
	_build_roads()
	_build_city()
	await _render()
	quit()

# ── Data ──────────────────────────────────────────────────────────────────

func _load_map() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(map_path))
	assert(data != null and data.has("stations"), "map.json missing")
	var sum := Vector2.ZERO
	for s in data["stations"]:
		var p := Vector2(float(s["x"]), float(s["y"]))
		stations[int(s["id"])] = p
		station_list.append(p)
		sum += p
	city_center = sum / station_list.size()
	var ferry_ids := {}
	for l in data["links"]:
		var a: Vector2 = stations[int(l["a"])]
		var b: Vector2 = stations[int(l["b"])]
		match str(l["type"]):
			"taxi": _add_seg(a, b, TAXI_WALK * 0.5)
			"bus": _add_seg(a, b, BUS_WALK * 0.5)
			"ferry":
				ferry_ids[int(l["a"])] = true
				ferry_ids[int(l["b"])] = true
	var fp: Array[Vector2] = []
	for id in ferry_ids: fp.append(stations[id])
	fp.sort_custom(func(p, q): return p.x < q.x)
	_build_river_spine(fp)

func _add_seg(a: Vector2, b: Vector2, hw: float) -> void:
	var idx := road_segs.size()
	road_segs.append([a, b, hw])
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * (hw + 60.0)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * (hw + 60.0)
	for cx in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
		for cy in range(floori(lo.y / CELL), floori(hi.y / CELL) + 1):
			var k := Vector2i(cx, cy)
			if not seg_grid.has(k): seg_grid[k] = []
			seg_grid[k].append(idx)

func _build_river_spine(fp: Array[Vector2]) -> void:
	# River enters from the left edge, passes through every ferry station, leaves on the right,
	# with a gentle meander added between stations.
	var ctrl: Array[Vector2] = []
	if fp.is_empty():
		fp = [Vector2(600, 1060), Vector2(1800, 1060)]
	var o := Vector2(0.0, RIVER_OFFSET)
	ctrl.append(Vector2(AREA.position.x - 100.0, fp[0].y + 150.0))
	ctrl.append(Vector2(fp[0].x - 380.0, fp[0].y + 110.0))
	for p in fp: ctrl.append(p + o)
	ctrl.append(Vector2(fp[-1].x + 380.0, fp[-1].y + 10.0))
	ctrl.append(Vector2(AREA.end.x + 100.0, fp[-1].y - 60.0))
	river = PackedVector2Array()
	for i in range(ctrl.size() - 1):
		var p0 := ctrl[maxi(i - 1, 0)]
		var p1 := ctrl[i]
		var p2 := ctrl[i + 1]
		var p3 := ctrl[mini(i + 2, ctrl.size() - 1)]
		var steps := maxi(8, int(p1.distance_to(p2) / 12.0))
		for t in range(steps):
			river.append(_catmull(p0, p1, p2, p3, float(t) / steps))
	river.append(ctrl[-1])

func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

func _define_landscape() -> void:
	park_noise.seed = 5
	park_noise.frequency = 0.0028
	# Ponds sit in the park spots farthest from any road.
	var best: Array = []
	var x := AREA.position.x + 200.0
	while x < AREA.end.x - 200.0:
		var y := AREA.position.y + 200.0
		while y < AREA.end.y - 200.0:
			var p := Vector2(x, y)
			if _in_park(p) and _dist_river(p) > 120.0:
				best.append([_dist_road(p), p])
			y += 20.0
		x += 20.0
	best.sort_custom(func(a, b): return a[0] > b[0])
	for c in best:
		if ponds.size() >= 3 or c[0] < 22.0: break
		var far := true
		for pd in ponds:
			if c[1].distance_to(pd[0]) < 400.0: far = false
		if far:
			var r: float = minf(c[0] * 0.8, 60.0)
			ponds.append([c[1], Vector2(r * 1.4, r), rng.randf_range(-0.4, 0.4)])

# ── Geometry queries ──────────────────────────────────────────────────────

func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

## Distance from p to the nearest road edge (negative = on a road).
func _dist_road(p: Vector2) -> float:
	var k := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	var best := 9999.0
	if seg_grid.has(k):
		for idx in seg_grid[k]:
			var s: Array = road_segs[idx]
			best = minf(best, _seg_dist(p, s[0], s[1]) - s[2])
	return best

func _road_dir(p: Vector2) -> float:
	var k := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	var best := 9999.0
	var ang := 0.0
	if seg_grid.has(k):
		for idx in seg_grid[k]:
			var s: Array = road_segs[idx]
			var d := _seg_dist(p, s[0], s[1])
			if d < best:
				best = d
				ang = (s[1] - s[0]).angle()
	return ang

func _dist_river(p: Vector2) -> float:
	var best := 9999.0
	for i in range(0, river.size() - 1):
		best = minf(best, _seg_dist(p, river[i], river[i + 1]))
	return best

func _dist_station(p: Vector2) -> float:
	var best := 9999.0
	for s in station_list:
		best = minf(best, p.distance_to(s))
	return best

func _in_ellipse(p: Vector2, c: Vector2, r: Vector2, ang := 0.0) -> float:
	var d := (p - c).rotated(-ang)
	return (d.x * d.x) / (r.x * r.x) + (d.y * d.y) / (r.y * r.y)

## Parks are low-frequency noise blobs; the dense core stays built up.
func _in_park(p: Vector2) -> bool:
	if p.distance_to(city_center) < 280.0: return false
	return park_noise.get_noise_2d(p.x, p.y) > 0.38

func _in_pond(p: Vector2, pad := 1.0) -> bool:
	for pd in ponds:
		if _in_ellipse(p, pd[0], pd[1] * pad, pd[2]) < 1.0: return true
	return false

func _occupied(p: Vector2, r: float) -> bool:
	var k := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var kk := k + Vector2i(dx, dy)
			if occ_grid.has(kk):
				for o in occ_grid[kk]:
					if p.distance_to(o[0]) < (r + o[1]) * 0.92: return true
	return false

func _occupy(p: Vector2, r: float) -> void:
	var k := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	if not occ_grid.has(k): occ_grid[k] = []
	occ_grid[k].append([p, r])

# ── Scene setup ───────────────────────────────────────────────────────────

func _mat(c: Color, rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _mesh_node(mesh: Mesh, mat: Material, shadow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mi)
	return mi

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.36, 0.55, 0.30)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.86, 0.89, 0.95)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.0
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.shadow_blur = 1.4
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 9000.0
	var dir := Vector3(0.42, -0.88, -0.2).normalized()
	sun.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3.ZERO)
	root.add_child(sun)
	RenderingServer.directional_shadow_atlas_set_size(16384, true)

func _build_ground() -> void:
	var w := 640
	var h := int(w * AREA.size.y / AREA.size.x)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var grass_a := Color(0.25, 0.40, 0.18)
	var grass_b := Color(0.31, 0.45, 0.20)
	var park_c := Color(0.20, 0.38, 0.15)
	var urban := Color(0.47, 0.50, 0.40)
	for py in h:
		for px in w:
			var p := AREA.position + Vector2(px + 0.5, py + 0.5) * AREA.size / Vector2(w, h)
			var n := noise.get_noise_2d(p.x, p.y) * 0.5 + 0.5
			var n2 := noise.get_noise_2d(p.x * 4.0, p.y * 4.0) * 0.5 + 0.5
			var c := grass_a.lerp(grass_b, n * 0.8 + n2 * 0.2)
			var urb := clampf(1.0 - p.distance_to(city_center) / 900.0, 0.0, 1.0)
			c = c.lerp(urban, urb * 0.45)
			if _in_park(p): c = park_c.lerp(grass_a, n2 * 0.4)
			elif _dist_road(p) > URBAN_REACH + 40.0:
				var cell := Vector2i((p.rotated(0.35) / Vector2(120.0, 80.0)).floor())
				var hsh := absi(hash(cell)) % 5
				var field: Color = [Color(0.30, 0.46, 0.20), Color(0.42, 0.50, 0.24), Color(0.36, 0.48, 0.22), Color(0.50, 0.52, 0.30), Color(0.27, 0.42, 0.19)][hsh]
				c = c.lerp(field, 0.55)
			img.set_pixel(px, py, c)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.roughness = 0.95
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var plane := PlaneMesh.new()
	plane.size = AREA.size + Vector2(800, 800)
	var mi := _mesh_node(plane, m)
	mi.position = Vector3(AREA.get_center().x, 0.0, AREA.get_center().y)
	# Ground texture covers AREA only; the extra skirt reuses the border pixels.
	m.uv1_scale = Vector3(plane.size.x / AREA.size.x, plane.size.y / AREA.size.y, 1.0)
	m.uv1_offset = Vector3(-400.0 / AREA.size.x, -400.0 / AREA.size.y, 0.0)
	m.texture_repeat = false

# ── Strips and discs ──────────────────────────────────────────────────────

func _strip(st: SurfaceTool, a: Vector2, b: Vector2, w: float, y: float) -> void:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x) * w * 0.5
	var v := [a + n, b + n, b - n, a - n]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(v[i].x, y, v[i].y))

func _disc(st: SurfaceTool, c: Vector2, r: float, y: float, seg := 18) -> void:
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		for p in [c, c + Vector2(cos(a1), sin(a1)) * r, c + Vector2(cos(a0), sin(a0)) * r]:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(p.x, y, p.y))

func _ellipse(st: SurfaceTool, c: Vector2, r: Vector2, ang: float, y: float, seg := 28) -> void:
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p1 := c + (Vector2(cos(a1), sin(a1)) * r).rotated(ang)
		var p0 := c + (Vector2(cos(a0), sin(a0)) * r).rotated(ang)
		for p in [c, p1, p0]:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(p.x, y, p.y))

func _polyline_strip(st: SurfaceTool, pts: PackedVector2Array, w: float, y: float) -> void:
	for i in range(pts.size() - 1):
		_strip(st, pts[i], pts[i + 1], w, y)
		_disc(st, pts[i + 1], w * 0.5, y, 12)

func _new_st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

func _build_water() -> void:
	var bank := _new_st()
	var water := _new_st()
	var deep := _new_st()
	_polyline_strip(bank, river, BANK_W, 0.15)
	_polyline_strip(water, river, RIVER_W, 0.3)
	_polyline_strip(deep, river, RIVER_W * 0.55, 0.32)
	for pd in ponds:
		_ellipse(bank, pd[0], pd[1] + Vector2(8, 8), pd[2], 0.15)
		_ellipse(water, pd[0], pd[1], pd[2], 0.3)
	_mesh_node(bank.commit(), _mat(Color(0.62, 0.70, 0.52)))
	var wm := _mat(Color(0.23, 0.56, 0.86), 0.12)
	wm.metallic_specular = 0.8
	_mesh_node(water.commit(), wm)
	var dm := _mat(Color(0.18, 0.47, 0.80), 0.1)
	dm.metallic_specular = 0.8
	_mesh_node(deep.commit(), dm)

func _build_roads() -> void:
	var walk := _new_st()
	var asphalt := _new_st()
	var stripe := _new_st()
	var marks := _new_st()
	var bridge := _new_st()
	var taxi_links: Array = []
	var bus_links: Array = []
	for s in road_segs:
		if is_equal_approx(s[2], BUS_WALK * 0.5): bus_links.append(s)
		else: taxi_links.append(s)
	for s in taxi_links:
		_strip(walk, s[0], s[1], TAXI_WALK, 0.4)
		_strip(asphalt, s[0], s[1], TAXI_W, 0.6)
	for s in bus_links:
		_strip(walk, s[0], s[1], BUS_WALK, 0.42)
		_strip(asphalt, s[0], s[1], BUS_W, 0.62)
		_strip(stripe, s[0], s[1], BUS_STRIPE, 0.75)
	for p in station_list:
		_disc(walk, p, 15.0, 0.43)
		_disc(asphalt, p, 10.5, 0.64)
	# Dashed lane markings on the taxi streets, kept clear of junctions.
	for s in taxi_links:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var L := a.distance_to(b)
		var d := (b - a) / L
		var t := 16.0
		while t < L - 20.0:
			_strip(marks, a + d * t, a + d * (t + 5.0), 0.9, 0.7)
			t += 11.0
	# Bridge decks and parapets where a road crosses the water.
	for s in taxi_links + bus_links:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x)
		var steps := int(a.distance_to(b) / 4.0)
		for i in steps:
			var p := a.lerp(b, float(i) / steps)
			var q := a.lerp(b, float(i + 1) / steps)
			if _dist_river(p.lerp(q, 0.5)) < RIVER_W * 0.5 + 3.0:
				_strip(bridge, p + n * (s[2] + 0.5), q + n * (s[2] + 0.5), 2.0, 2.4)
				_strip(bridge, p - n * (s[2] + 0.5), q - n * (s[2] + 0.5), 2.0, 2.4)
	_mesh_node(walk.commit(), _mat(Color(0.74, 0.73, 0.69)))
	_mesh_node(asphalt.commit(), _mat(Color(0.43, 0.43, 0.44), 0.9))
	var em := _mat(Color(1.0, 0.62, 0.10), 0.5)
	em.emission_enabled = true
	em.emission = Color(1.0, 0.55, 0.05)
	em.emission_energy_multiplier = 0.6
	_mesh_node(stripe.commit(), em)
	_mesh_node(marks.commit(), _mat(Color(0.86, 0.86, 0.84), 0.7))
	_mesh_node(bridge.commit(), _mat(Color(0.90, 0.89, 0.86)), true)

# ── Buildings and trees ───────────────────────────────────────────────────

func _facade_texture() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	img.fill(Color(0.97, 0.97, 0.96))
	for fy in 2:
		for fx in 2:
			var r := Rect2i(fx * 32 + 7, fy * 32 + 9, 18, 15)
			img.fill_rect(r, Color(0.42, 0.52, 0.62))
			img.fill_rect(Rect2i(r.position, Vector2i(18, 4)), Color(0.58, 0.68, 0.78))
	return ImageTexture.create_from_image(img)

func _facade_mat(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.vertex_color_use_as_albedo = true
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(1.0 / 11.0, 1.0 / 9.0, 1.0 / 11.0)
	m.roughness = 0.75
	return m

func _vc_mat(rough := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	return m

func _multimesh(mesh: Mesh, mat: Material, items: Array, shadow := true) -> void:
	if items.is_empty(): return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(mmi)

func _xf(p: Vector2, y: float, size: Vector3, ang: float) -> Transform3D:
	var b := Basis(Vector3.UP, -ang) * Basis.from_scale(size)
	return Transform3D(b, Vector3(p.x, y, p.y))

func _build_city() -> void:
	var walls: Array = []
	var glass: Array = []
	var roofs: Array = []
	var house_walls: Array = []
	var house_roofs: Array = []
	var details: Array = []
	var trees: Array = []
	var blobs: Array = []

	var facade_cols := [Color(0.97, 0.97, 0.96), Color(0.90, 0.91, 0.93), Color(0.93, 0.89, 0.82), Color(0.84, 0.86, 0.88), Color(0.95, 0.93, 0.88)]
	var roof_cols := [Color(0.62, 0.64, 0.67), Color(0.50, 0.52, 0.56), Color(0.74, 0.75, 0.77), Color(0.56, 0.60, 0.55)]
	var house_roof_cols := [Color(0.52, 0.32, 0.26), Color(0.42, 0.42, 0.44), Color(0.36, 0.36, 0.38), Color(0.58, 0.44, 0.36), Color(0.45, 0.47, 0.50)]
	var tree_cols := [Color(0.13, 0.33, 0.12), Color(0.18, 0.40, 0.14), Color(0.11, 0.28, 0.11), Color(0.22, 0.44, 0.16)]

	# Buildings on a jittered grid, aligned with the nearest street; footprints shrink to fit.
	var step := 18.0
	var y0 := AREA.position.y
	while y0 < AREA.end.y:
		var x0 := AREA.position.x
		while x0 < AREA.end.x:
			var p := Vector2(x0, y0) + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6))
			x0 += step
			var droad := _dist_road(p)
			if droad > URBAN_REACH or droad < 4.0: continue
			if _dist_river(p) < BANK_W * 0.5 + 6.0 or _in_pond(p, 1.3) or _in_park(p): continue
			var rc := p.distance_to(city_center)
			var zone := 0 if rc < 430.0 else (1 if rc < 880.0 else 2)
			if droad > 60.0: zone = 2
			var fill := noise.get_noise_2d(p.x * 2.0 + 500.0, p.y * 2.0) * 0.5 + 0.5
			var chance: float = [0.97, 0.9, 0.55][zone] * (0.6 + 0.5 * fill) * clampf(1.4 - droad / URBAN_REACH, 0.0, 1.0)
			if rng.randf() > chance: continue
			var dst := _dist_station(p)
			var ang := _road_dir(p)
			var placed := false
			for shrink in [1.0, 0.8, 0.64]:
				var w: float
				var d: float
				var h: float
				match zone:
					0:
						w = rng.randf_range(15, 24); d = rng.randf_range(13, 20)
						h = rng.randf_range(22, 48) * (1.0 + 0.6 * clampf(1.0 - rc / 430.0, 0, 1))
						if rng.randf() < 0.1: h *= 1.6
					1:
						w = rng.randf_range(13, 20); d = rng.randf_range(11, 17); h = rng.randf_range(11, 28)
					_:
						w = rng.randf_range(10, 14); d = rng.randf_range(8, 11); h = rng.randf_range(6, 8)
				w *= shrink
				d *= shrink
				var r := Vector2(w, d).length() * 0.5
				if droad < r * 0.62 + 1.5 or dst < 20.0 + r * 0.6 or _occupied(p, r): continue
				_occupy(p, r)
				placed = true
				blobs.append([_xf(p, 0.9, Vector3(w * 1.8, 1, d * 1.8), ang), Color(0, 0, 0, 0.42)])
				if zone == 2:
					house_walls.append([_xf(p, h * 0.5, Vector3(w, h, d), ang), facade_cols[rng.randi() % facade_cols.size()]])
					house_roofs.append([_xf(p, h + 2.6, Vector3(w + 2.0, 5.2, d + 1.6), ang), house_roof_cols[rng.randi() % house_roof_cols.size()]])
				else:
					var is_glass := zone == 0 and rng.randf() < 0.28
					var col: Color = Color(0.68, 0.80, 0.90) if is_glass else facade_cols[rng.randi() % facade_cols.size()]
					(glass if is_glass else walls).append([_xf(p, h * 0.5, Vector3(w, h, d), ang), col])
					roofs.append([_xf(p, h + 0.5, Vector3(w + 1.0, 1.0, d + 1.0), ang), roof_cols[rng.randi() % roof_cols.size()]])
					if h > 20.0:
						for k in rng.randi_range(1, 2):
							var off := Vector2(rng.randf_range(-w, w) * 0.28, rng.randf_range(-d, d) * 0.28).rotated(ang)
							var ds := Vector3(rng.randf_range(2.5, 4.5), rng.randf_range(1.5, 3), rng.randf_range(2.5, 4.5))
							details.append([_xf(p + off, h + 1.0 + ds.y * 0.5, ds, ang), Color(0.80, 0.81, 0.82)])
				break
			if not placed and zone != 0 and rng.randf() < 0.5:
				_try_tree(p, rng.randf_range(3.5, 5.0), trees, blobs, tree_cols)
		y0 += step

	# Street trees along the roads outside the dense core.
	for s in road_segs:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var L := a.distance_to(b)
		var dd := (b - a) / L
		var n := Vector2(-dd.y, dd.x)
		var t := 30.0
		while t < L - 30.0:
			for side in [-1.0, 1.0]:
				var p: Vector2 = a + dd * t + n * side * (s[2] + 5.0)
				if p.distance_to(city_center) < 380.0 or rng.randf() < 0.45: continue
				_try_tree(p, rng.randf_range(3.5, 5.0), trees, blobs, tree_cols)
			t += rng.randf_range(16, 24)

	# Parks, river banks and leftover gaps get clustered trees.
	var ty := AREA.position.y
	while ty < AREA.end.y:
		var tx := AREA.position.x
		while tx < AREA.end.x:
			var p := Vector2(tx, ty) + Vector2(rng.randf_range(-7, 7), rng.randf_range(-7, 7))
			tx += 15.0
			var cluster := noise.get_noise_2d(p.x * 3.0 - 300.0, p.y * 3.0) * 0.5 + 0.5
			var prob := 0.0
			var dr := _dist_river(p)
			if _in_park(p): prob = 0.3 + cluster * 0.6
			elif dr > BANK_W * 0.5 and dr < BANK_W * 0.5 + 18.0: prob = 0.6
			elif _dist_road(p) > URBAN_REACH: prob = 0.04 + pow(cluster, 3.0) * 1.6
			else: prob = 0.06 + cluster * cluster * 0.4
			if p.distance_to(city_center) < 360.0: prob *= 0.25
			if rng.randf() < prob:
				_try_tree(p, rng.randf_range(4.0, 7.0), trees, blobs, tree_cols)
		ty += 15.0

	var box := BoxMesh.new()
	var tex := _facade_texture()
	_multimesh(box, _facade_mat(tex), walls)
	var gm := _facade_mat(tex)
	gm.roughness = 0.25
	gm.metallic_specular = 0.9
	_multimesh(box, gm, glass)
	_multimesh(box, _facade_mat(tex), house_walls)
	_multimesh(box, _vc_mat(), roofs)
	_multimesh(box, _vc_mat(), details)
	var prism := PrismMesh.new()
	_multimesh(prism, _vc_mat(), house_roofs)
	var sphere := SphereMesh.new()
	sphere.radial_segments = 10
	sphere.rings = 6
	sphere.radius = 0.5
	sphere.height = 1.0
	_multimesh(sphere, _vc_mat(0.95), trees)
	var quad := QuadMesh.new()
	quad.orientation = PlaneMesh.FACE_Y
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.vertex_color_use_as_albedo = true
	bm.albedo_texture = _blob_texture()
	_multimesh(quad, bm, blobs, false)
	print("buildings=", walls.size() + glass.size(), " houses=", house_walls.size(), " trees=", trees.size(), " ponds=", ponds.size())

func _try_tree(p: Vector2, size: float, trees: Array, blobs: Array, cols: Array) -> void:
	if _dist_road(p) < size * 0.6 or _dist_station(p) < 30.0 or _dist_river(p) < BANK_W * 0.5 + 2.0 or _in_pond(p, 1.15): return
	if _occupied(p, size * 0.55): return
	_occupy(p, size * 0.55)
	var c: Color = cols[rng.randi() % cols.size()]
	c = c.lightened(rng.randf_range(-0.05, 0.08))
	trees.append([_xf(p, size * 0.9 + 1.5, Vector3(size * 2.0, size * 1.7, size * 2.0), rng.randf() * TAU), c])
	blobs.append([_xf(p, 0.95, Vector3(size * 2.6, 1, size * 2.6), 0.0), Color(0, 0, 0, 0.3)])

func _blob_texture() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)

# ── Render ────────────────────────────────────────────────────────────────

func _render() -> void:
	var size := Vector2i(int(AREA.size.x * px_per_unit), int(AREA.size.y * px_per_unit))
	var vp := SubViewport.new()
	vp.size = size
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = AREA.size.y
	cam.near = 1.0
	cam.far = 8000.0
	var th := deg_to_rad(PITCH_DEG)
	var c := AREA.get_center()
	var target := Vector3(c.x, 0.0, c.y / S)
	cam.position = target + Vector3(0.0, sin(th), cos(th)) * 3000.0
	cam.rotation = Vector3(-th, 0.0, 0.0)
	vp.add_child(cam)
	cam.current = true
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var abs_out := ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(abs_out)
	if not out_dir.begins_with("res://"):
		img.save_png(abs_out + "/_full.png") # preview only when rendering outside the project
	var tw := size.x / TILES_X
	var th_px := size.y / TILES_Y
	for ty in TILES_Y:
		for tx in TILES_X:
			var tile := img.get_region(Rect2i(tx * tw, ty * th_px, tw, th_px))
			tile.save_png(abs_out + "/City_%d_%d.png" % [tx, ty])
	print("rendered ", size, " tiles ", TILES_X, "x", TILES_Y, " -> ", abs_out)
