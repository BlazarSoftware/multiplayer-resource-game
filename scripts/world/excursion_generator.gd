class_name ExcursionGenerator
extends RefCounted

## Procedural excursion arena generator using FastNoiseLite.
## All functions are static — deterministic from seed + season + offset.

const ARENA_SIZE: float = 80.0
const GRID_RESOLUTION: int = 80 # vertices per axis = GRID_RESOLUTION + 1
const HEIGHT_RANGE: float = 6.0
const SPAWN_FLATTEN_RADIUS: float = 8.0
const EXIT_FLATTEN_RADIUS: float = 6.0

enum Biome { GRASSLAND, DENSE_FOREST, ROCKY_OUTCROP, WATER_EDGE, FLOWER_FIELD, RARE_GROVE }

# --- Public API ---

static func generate_server(seed_val: int, season: String, offset: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "ExcursionInstance"
	root.position = offset

	var height_noise := _make_height_noise(seed_val)
	var detail_noise := _make_detail_noise(seed_val)
	var heightmap := _build_heightmap(height_noise, detail_noise)

	# Terrain collision (players walk on this)
	var terrain_body := _build_terrain_collision(heightmap)
	root.add_child(terrain_body)

	# Boundary walls
	_add_boundary_walls(root)

	# Encounter zones (TallGrass-like Area3Ds)
	var biome_noise := _make_biome_noise(seed_val)
	var rare_noise := _make_rare_noise(seed_val)
	var zones := get_encounter_zones(seed_val, season, Vector3.ZERO)
	for z_data in zones:
		var area := _create_encounter_area(z_data, height_noise, detail_noise)
		root.add_child(area)

	# Exit portal at spawn point
	var exit_portal := _create_exit_portal()
	root.add_child(exit_portal)

	return root


static func generate_client(seed_val: int, season: String, offset: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "ExcursionVisuals"
	root.position = offset

	var height_noise := _make_height_noise(seed_val)
	var detail_noise := _make_detail_noise(seed_val)
	var heightmap := _build_heightmap(height_noise, detail_noise)

	# Visual terrain mesh
	var terrain_mesh := _build_terrain_mesh(heightmap, season)
	root.add_child(terrain_mesh)

	# Terrain collision (client also needs physics for local prediction)
	var terrain_body := _build_terrain_collision(heightmap)
	root.add_child(terrain_body)

	# Boundary walls with visuals
	_add_boundary_walls(root, true)

	# Biome props (trees, rocks, flowers)
	var biome_noise := _make_biome_noise(seed_val)
	var resource_noise := _make_resource_noise(seed_val)
	_generate_props(root, biome_noise, height_noise, detail_noise, resource_noise, season)

	# Zone overlays
	var zones := get_encounter_zones(seed_val, season, Vector3.ZERO)
	_add_zone_overlays(root, zones, height_noise, detail_noise)

	# Rare zone glow
	for z_data in zones:
		if z_data.get("is_rare", false):
			_add_rare_zone_glow(root, z_data, height_noise, detail_noise)

	# Exit portal visual
	var exit_portal := _create_exit_portal_visual()
	root.add_child(exit_portal)

	# Ambient label
	var label := Label3D.new()
	UITheme.style_label3d(label, "Excursion Zone", "zone_sign")
	label.font_size = 48
	label.position = Vector3(40, 10, 40)
	root.add_child(label)

	return root


static func get_item_spawn_points(seed_val: int, season: String, _offset: Vector3) -> Array:
	var points: Array = []
	var resource_noise := _make_resource_noise(seed_val)
	var height_noise := _make_height_noise(seed_val)
	var detail_noise := _make_detail_noise(seed_val)

	# Scan grid for resource clusters
	var item_table := _get_excursion_item_table(season)
	var total_weight := 0
	for entry in item_table:
		total_weight += entry["weight"]

	# Use noise to place 15-25 items deterministically
	var item_seed := seed_val + 100
	var rng := RandomNumberGenerator.new()
	rng.seed = item_seed
	var num_items: int = rng.randi_range(15, 25)

	for i in range(num_items):
		# Spread items across the arena using golden angle
		var angle: float = i * 2.399
		var radius: float = rng.randf_range(8.0, 35.0)
		var cx: float = 40.0 + cos(angle) * radius
		var cz: float = 40.0 + sin(angle) * radius
		cx = clampf(cx, 4.0, 76.0)
		cz = clampf(cz, 4.0, 72.0) # Keep away from spawn edge

		var y: float = _height_at(height_noise, detail_noise, cx, cz) + 0.5

		# Pick item from weighted table
		var roll: int = rng.randi() % total_weight
		var cumulative := 0
		var chosen_id: String = item_table[0]["item_id"]
		for entry in item_table:
			cumulative += entry["weight"]
			if roll < cumulative:
				chosen_id = entry["item_id"]
				break

		points.append({
			"position": Vector3(cx, y, cz),
			"item_id": chosen_id,
			"amount": 1,
		})

	return points


static func get_encounter_zones(seed_val: int, season: String, _offset: Vector3) -> Array:
	var zones: Array = []
	var rare_noise := _make_rare_noise(seed_val)
	var height_noise := _make_height_noise(seed_val)
	var detail_noise := _make_detail_noise(seed_val)

	# Place 3-5 common encounter zones in valleys/clearings
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val + 200
	var num_zones: int = rng.randi_range(3, 5)

	# Predefined zone placement anchors (spread across arena)
	var anchors: Array[Vector2] = [
		Vector2(20, 25), Vector2(60, 25), Vector2(40, 45),
		Vector2(15, 50), Vector2(65, 50),
	]

	for i in range(num_zones):
		var anchor: Vector2 = anchors[i]
		var jx: float = rng.randf_range(-5.0, 5.0)
		var jz: float = rng.randf_range(-5.0, 5.0)
		var zx: float = clampf(anchor.x + jx, 6.0, 74.0)
		var zz: float = clampf(anchor.y + jz, 6.0, 70.0)
		var zy: float = _height_at(height_noise, detail_noise, zx, zz)
		zones.append({
			"position": Vector3(zx, zy, zz),
			"radius": rng.randf_range(5.0, 8.0),
			"table_id": "excursion_common",
			"is_rare": false,
		})

	# Place 1 rare grove zone at highest rare_noise peak
	var best_val: float = -999.0
	var best_pos := Vector2(40, 30)
	for gx in range(2, 18):
		for gz in range(2, 16):
			var wx: float = gx * 4.0 + 2.0
			var wz: float = gz * 4.0 + 2.0
			var n: float = rare_noise.get_noise_2d(wx, wz)
			if n > best_val:
				best_val = n
				best_pos = Vector2(wx, wz)
	var rare_y: float = _height_at(height_noise, detail_noise, best_pos.x, best_pos.y)
	zones.append({
		"position": Vector3(best_pos.x, rare_y, best_pos.y),
		"radius": 6.0,
		"table_id": "excursion_rare",
		"is_rare": true,
	})

	return zones


static func get_harvestable_spawn_points(seed_val: int, season: String, _offset: Vector3) -> Array:
	## Returns array of {position: Vector3, type: String, drops: Array} for excursion harvestables.
	var points: Array = []
	var biome_noise := _make_biome_noise(seed_val)
	var resource_noise := _make_resource_noise(seed_val)
	var height_noise := _make_height_noise(seed_val)
	var detail_noise := _make_detail_noise(seed_val)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val + 300

	var cell_size: float = 4.0
	var grid_count: int = int(ARENA_SIZE / cell_size)

	for gz in range(grid_count):
		for gx in range(grid_count):
			var cx: float = gx * cell_size + cell_size / 2.0
			var cz: float = gz * cell_size + cell_size / 2.0

			# Skip spawn area
			if Vector2(cx, cz).distance_to(Vector2(40, 75)) < SPAWN_FLATTEN_RADIUS + 4.0:
				continue
			# Skip exit portal area
			if Vector2(cx, cz).distance_to(Vector2(40, 77)) < 5.0:
				continue

			var biome_val: float = biome_noise.get_noise_2d(cx, cz)
			var height_val: float = _height_at(height_noise, detail_noise, cx, cz)
			var density_val: float = resource_noise.get_noise_2d(cx, cz)
			var biome: Biome = _classify_biome(biome_val, height_val, season)

			# Only place harvestables in specific biomes at specific density thresholds
			var harvestable_type: String = ""
			var threshold: float = 0.0

			match biome:
				Biome.DENSE_FOREST:
					harvestable_type = "tree"
					threshold = 0.35
				Biome.ROCKY_OUTCROP:
					harvestable_type = "rock"
					threshold = 0.25
				Biome.GRASSLAND:
					harvestable_type = "bush"
					threshold = 0.5
				Biome.FLOWER_FIELD:
					harvestable_type = "bush"
					threshold = 0.55
				_:
					continue

			if density_val < threshold:
				continue

			# Additional RNG thinning to hit target of ~8-12 per instance
			if rng.randf() > 0.35:
				continue

			var y: float = _height_at(height_noise, detail_noise, cx, cz)
			var drop_list: Array = _get_harvestable_drops(harvestable_type, season)

			points.append({
				"position": Vector3(cx, y, cz),
				"type": harvestable_type,
				"drops": drop_list,
			})

	return points


static func get_dig_spot_points(seed_val: int, _season: String, _offset: Vector3) -> Array:
	## Returns array of {position: Vector3, spot_id: String, loot_table: Array} for excursion dig spots.
	var points: Array = []
	var height_noise := _make_height_noise(seed_val)
	var detail_noise := _make_detail_noise(seed_val)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val + 400
	var num_spots: int = rng.randi_range(3, 5)

	# Find low-height candidate positions across the arena
	var candidates: Array = [] # {position, height}
	var cell_size: float = 8.0
	var grid_count: int = int(ARENA_SIZE / cell_size)

	for gz in range(grid_count):
		for gx in range(grid_count):
			var cx: float = gx * cell_size + cell_size / 2.0
			var cz: float = gz * cell_size + cell_size / 2.0
			# Skip spawn/exit area
			if Vector2(cx, cz).distance_to(Vector2(40, 75)) < SPAWN_FLATTEN_RADIUS + 4.0:
				continue
			var h: float = _height_at(height_noise, detail_noise, cx, cz)
			if h < 2.5: # Valley/low areas
				candidates.append({"x": cx, "z": cz, "h": h})

	# Sort by height ascending, pick lowest spots with spacing
	candidates.sort_custom(func(a, b): return a["h"] < b["h"])

	var min_spacing: float = 12.0
	for c in candidates:
		if points.size() >= num_spots:
			break
		var too_close := false
		for existing in points:
			if Vector2(c["x"], c["z"]).distance_to(Vector2(existing["position"].x, existing["position"].z)) < min_spacing:
				too_close = true
				break
		if too_close:
			continue

		var spot_index: int = points.size()
		points.append({
			"position": Vector3(c["x"], c["h"], c["z"]),
			"spot_id": "excursion_%d_%d" % [seed_val, spot_index],
			"loot_table": _get_dig_spot_loot_table(),
		})

	return points


static func _get_harvestable_drops(harvestable_type: String, _season: String) -> Array:
	## Returns drop table for excursion harvestables (richer than overworld).
	match harvestable_type:
		"tree":
			return [
				{"item_id": "wood", "min": 1, "max": 3, "weight": 1.0},
				{"item_id": "herb_basil", "min": 1, "max": 1, "weight": 0.3},
				{"item_id": "mystic_herb", "min": 1, "max": 1, "weight": 0.1},
			]
		"rock":
			return [
				{"item_id": "stone", "min": 1, "max": 2, "weight": 1.0},
				{"item_id": "chili_powder", "min": 1, "max": 1, "weight": 0.15},
				{"item_id": "sugar", "min": 1, "max": 1, "weight": 0.1},
			]
		"bush":
			return [
				{"item_id": "berry", "min": 1, "max": 2, "weight": 1.0},
				{"item_id": "wild_honey", "min": 1, "max": 1, "weight": 0.2},
			]
	return []


static func _get_dig_spot_loot_table() -> Array:
	## Returns loot table for excursion dig spots (rare excursion ingredients).
	return [
		{"item_id": "golden_seed", "min": 1, "max": 1, "weight": 0.2},
		{"item_id": "ancient_grain_seed", "min": 1, "max": 1, "weight": 0.15},
		{"item_id": "starfruit", "min": 1, "max": 1, "weight": 0.15},
		{"item_id": "truffle_shaving", "min": 1, "max": 2, "weight": 0.25},
		{"item_id": "mystic_herb", "min": 1, "max": 1, "weight": 0.2},
		{"item_id": "stone", "min": 1, "max": 3, "weight": 0.5},
		{"item_id": "wild_honey", "min": 1, "max": 1, "weight": 0.3},
	]


static func get_spawn_point(_offset: Vector3) -> Vector3:
	# South edge, flattened area
	return Vector3(40, 1, 75)


# --- Noise Generators (deterministic from seed) ---

static func _make_height_noise(seed_val: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_val + 1
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	return noise


static func _make_detail_noise(seed_val: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_val + 2
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.08
	noise.fractal_octaves = 2
	return noise


static func _make_biome_noise(seed_val: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.04
	noise.fractal_octaves = 2
	return noise


static func _make_resource_noise(seed_val: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_val + 3
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.05
	return noise


static func _make_rare_noise(seed_val: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_val + 4
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.03
	return noise


# --- Heightmap ---

static func _build_heightmap(height_noise: FastNoiseLite, detail_noise: FastNoiseLite) -> PackedFloat32Array:
	var verts_per_axis: int = GRID_RESOLUTION + 1 # 81
	var heightmap := PackedFloat32Array()
	heightmap.resize(verts_per_axis * verts_per_axis)

	var spawn_center := Vector2(40, 75) # spawn area south edge
	var exit_center := Vector2(40, 75)  # exit portal co-located with spawn

	for z_idx in range(verts_per_axis):
		for x_idx in range(verts_per_axis):
			var wx: float = x_idx * (ARENA_SIZE / GRID_RESOLUTION)
			var wz: float = z_idx * (ARENA_SIZE / GRID_RESOLUTION)

			var h: float = height_noise.get_noise_2d(wx, wz) # [-1, 1]
			h = (h + 1.0) * 0.5 * HEIGHT_RANGE # [0, HEIGHT_RANGE]

			# Add micro-detail
			var detail: float = detail_noise.get_noise_2d(wx, wz) * 0.5
			h += detail

			# Flatten spawn area
			var dist_to_spawn: float = Vector2(wx, wz).distance_to(spawn_center)
			if dist_to_spawn < SPAWN_FLATTEN_RADIUS:
				var blend: float = dist_to_spawn / SPAWN_FLATTEN_RADIUS
				blend = blend * blend # ease in
				h = lerpf(0.0, h, blend)

			h = clampf(h, 0.0, HEIGHT_RANGE)
			heightmap[z_idx * verts_per_axis + x_idx] = h

	return heightmap


static func _height_at(height_noise: FastNoiseLite, detail_noise: FastNoiseLite, x: float, z: float) -> float:
	var h: float = height_noise.get_noise_2d(x, z)
	h = (h + 1.0) * 0.5 * HEIGHT_RANGE
	h += detail_noise.get_noise_2d(x, z) * 0.5

	# Flatten spawn area
	var dist_to_spawn: float = Vector2(x, z).distance_to(Vector2(40, 75))
	if dist_to_spawn < SPAWN_FLATTEN_RADIUS:
		var blend: float = dist_to_spawn / SPAWN_FLATTEN_RADIUS
		blend = blend * blend
		h = lerpf(0.0, h, blend)

	return clampf(h, 0.0, HEIGHT_RANGE)


# --- Terrain Construction ---

static func _build_terrain_collision(heightmap: PackedFloat32Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"

	var verts_per_axis: int = GRID_RESOLUTION + 1
	var cell_size: float = ARENA_SIZE / GRID_RESOLUTION

	# Build triangle mesh for ConcavePolygonShape3D
	var faces := PackedVector3Array()

	for z_idx in range(GRID_RESOLUTION):
		for x_idx in range(GRID_RESOLUTION):
			var i00: int = z_idx * verts_per_axis + x_idx
			var i10: int = z_idx * verts_per_axis + (x_idx + 1)
			var i01: int = (z_idx + 1) * verts_per_axis + x_idx
			var i11: int = (z_idx + 1) * verts_per_axis + (x_idx + 1)

			var v00 := Vector3(x_idx * cell_size, heightmap[i00], z_idx * cell_size)
			var v10 := Vector3((x_idx + 1) * cell_size, heightmap[i10], z_idx * cell_size)
			var v01 := Vector3(x_idx * cell_size, heightmap[i01], (z_idx + 1) * cell_size)
			var v11 := Vector3((x_idx + 1) * cell_size, heightmap[i11], (z_idx + 1) * cell_size)

			# Triangle 1
			faces.append(v00)
			faces.append(v10)
			faces.append(v01)
			# Triangle 2
			faces.append(v10)
			faces.append(v11)
			faces.append(v01)

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var coll := CollisionShape3D.new()
	coll.shape = shape
	body.add_child(coll)

	return body


static func _build_terrain_mesh(heightmap: PackedFloat32Array, season: String) -> MeshInstance3D:
	var verts_per_axis: int = GRID_RESOLUTION + 1
	var cell_size: float = ARENA_SIZE / GRID_RESOLUTION

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Season-based ground colors
	var base_color: Color
	match season:
		"spring":
			base_color = Color(0.3, 0.55, 0.2)
		"summer":
			base_color = Color(0.35, 0.5, 0.15)
		"autumn":
			base_color = Color(0.5, 0.4, 0.2)
		"winter":
			base_color = Color(0.6, 0.65, 0.7)
		_:
			base_color = Color(0.3, 0.5, 0.2)

	for z_idx in range(GRID_RESOLUTION):
		for x_idx in range(GRID_RESOLUTION):
			var i00: int = z_idx * verts_per_axis + x_idx
			var i10: int = z_idx * verts_per_axis + (x_idx + 1)
			var i01: int = (z_idx + 1) * verts_per_axis + x_idx
			var i11: int = (z_idx + 1) * verts_per_axis + (x_idx + 1)

			var v00 := Vector3(x_idx * cell_size, heightmap[i00], z_idx * cell_size)
			var v10 := Vector3((x_idx + 1) * cell_size, heightmap[i10], z_idx * cell_size)
			var v01 := Vector3(x_idx * cell_size, heightmap[i01], (z_idx + 1) * cell_size)
			var v11 := Vector3((x_idx + 1) * cell_size, heightmap[i11], (z_idx + 1) * cell_size)

			# Color varies by height
			var h_avg: float = (heightmap[i00] + heightmap[i10] + heightmap[i01] + heightmap[i11]) * 0.25
			var height_blend: float = h_avg / HEIGHT_RANGE
			var low_color: Color = base_color
			var high_color: Color = base_color.lerp(Color(0.5, 0.45, 0.35), 0.6)
			if h_avg < 1.0:
				# Water edge — blueish
				low_color = Color(0.25, 0.35, 0.5)
			var vert_color: Color = low_color.lerp(high_color, height_blend)

			# Triangle 1
			var n1: Vector3 = (v10 - v00).cross(v01 - v00).normalized()
			st.set_color(vert_color)
			st.set_normal(n1)
			st.add_vertex(v00)
			st.set_color(vert_color)
			st.set_normal(n1)
			st.add_vertex(v10)
			st.set_color(vert_color)
			st.set_normal(n1)
			st.add_vertex(v01)

			# Triangle 2
			var n2: Vector3 = (v11 - v10).cross(v01 - v10).normalized()
			st.set_color(vert_color)
			st.set_normal(n2)
			st.add_vertex(v10)
			st.set_color(vert_color)
			st.set_normal(n2)
			st.add_vertex(v11)
			st.set_color(vert_color)
			st.set_normal(n2)
			st.add_vertex(v01)

	var mesh := st.commit()
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = "TerrainMesh"
	mesh_inst.mesh = mesh

	# Material with vertex colors
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	mesh_inst.set_surface_override_material(0, mat)

	return mesh_inst


# --- Boundary Walls ---

static func _add_boundary_walls(parent: Node3D, with_visuals: bool = false) -> void:
	var wall_height: float = 8.0
	var wall_thickness: float = 1.0

	var walls := [
		# North wall
		{"pos": Vector3(ARENA_SIZE / 2.0, wall_height / 2.0, -wall_thickness / 2.0),
		 "size": Vector3(ARENA_SIZE + wall_thickness * 2, wall_height, wall_thickness)},
		# South wall
		{"pos": Vector3(ARENA_SIZE / 2.0, wall_height / 2.0, ARENA_SIZE + wall_thickness / 2.0),
		 "size": Vector3(ARENA_SIZE + wall_thickness * 2, wall_height, wall_thickness)},
		# West wall
		{"pos": Vector3(-wall_thickness / 2.0, wall_height / 2.0, ARENA_SIZE / 2.0),
		 "size": Vector3(wall_thickness, wall_height, ARENA_SIZE)},
		# East wall
		{"pos": Vector3(ARENA_SIZE + wall_thickness / 2.0, wall_height / 2.0, ARENA_SIZE / 2.0),
		 "size": Vector3(wall_thickness, wall_height, ARENA_SIZE)},
	]

	for w in walls:
		var body := StaticBody3D.new()
		body.position = w["pos"]
		var shape := BoxShape3D.new()
		shape.size = w["size"]
		var coll := CollisionShape3D.new()
		coll.shape = shape
		body.add_child(coll)

		if with_visuals:
			var mesh := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = w["size"]
			mesh.mesh = box
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.35, 0.3, 0.25, 0.6)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh.set_surface_override_material(0, mat)
			body.add_child(mesh)

		parent.add_child(body)


# --- Encounter Areas ---

static func _create_encounter_area(zone_data: Dictionary, height_noise: FastNoiseLite, detail_noise: FastNoiseLite) -> Area3D:
	var area := Area3D.new()
	var pos: Vector3 = zone_data["position"]
	var radius: float = zone_data.get("radius", 6.0)
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 3 # Detect players on layer 2

	# Use cylinder shape for encounter zone
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 4.0
	var coll := CollisionShape3D.new()
	coll.shape = shape
	coll.position = Vector3(0, 2, 0) # Raise so bottom is at terrain level
	area.add_child(coll)

	# Attach script data via metadata
	area.set_meta("encounter_table_id", zone_data.get("table_id", "excursion_common"))
	area.set_meta("is_excursion_encounter", true)
	area.set_meta("is_rare", zone_data.get("is_rare", false))

	if zone_data.get("is_rare", false):
		area.name = "ExcursionRareZone"
	else:
		area.name = "ExcursionZone_" + str(randi() % 10000)

	return area


# --- Props (Client Only) ---

static func _generate_props(parent: Node3D, biome_noise: FastNoiseLite, height_noise: FastNoiseLite, detail_noise: FastNoiseLite, resource_noise: FastNoiseLite, season: String) -> void:
	var props_node := Node3D.new()
	props_node.name = "Props"
	parent.add_child(props_node)

	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.35, 0.2, 0.1)

	var canopy_color: Color
	match season:
		"spring": canopy_color = Color(0.2, 0.55, 0.2)
		"summer": canopy_color = Color(0.15, 0.45, 0.15)
		"autumn": canopy_color = Color(0.6, 0.35, 0.15)
		"winter": canopy_color = Color(0.3, 0.4, 0.3)
		_: canopy_color = Color(0.2, 0.5, 0.2)
	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color = canopy_color

	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.5, 0.48, 0.45)

	var flower_colors: Array[Color] = [
		Color(0.9, 0.3, 0.4), Color(0.9, 0.7, 0.2),
		Color(0.5, 0.3, 0.8), Color(0.3, 0.6, 0.9),
	]

	# Step through grid cells (4x4 unit cells)
	var cell_size: float = 4.0
	var grid_count: int = int(ARENA_SIZE / cell_size) # 20

	for gz in range(grid_count):
		for gx in range(grid_count):
			var cx: float = gx * cell_size + cell_size / 2.0
			var cz: float = gz * cell_size + cell_size / 2.0

			# Skip spawn area
			if Vector2(cx, cz).distance_to(Vector2(40, 75)) < SPAWN_FLATTEN_RADIUS + 2.0:
				continue

			var biome_val: float = biome_noise.get_noise_2d(cx, cz) # [-1, 1]
			var height_val: float = _height_at(height_noise, detail_noise, cx, cz)
			var density_val: float = resource_noise.get_noise_2d(cx, cz)

			var biome: Biome = _classify_biome(biome_val, height_val, season)

			# Skip low-density cells
			if density_val < -0.3:
				continue

			match biome:
				Biome.DENSE_FOREST:
					if density_val > -0.1:
						_add_tree(props_node, cx, cz, height_val, trunk_mat, canopy_mat)
					if density_val > 0.2:
						_add_tree(props_node, cx + 1.5, cz + 1.0, _height_at(height_noise, detail_noise, cx + 1.5, cz + 1.0), trunk_mat, canopy_mat)
				Biome.ROCKY_OUTCROP:
					_add_rock(props_node, cx, cz, height_val, rock_mat, density_val)
				Biome.FLOWER_FIELD:
					var fc: Color = flower_colors[(gx + gz) % flower_colors.size()]
					_add_flowers(props_node, cx, cz, height_val, fc)
				Biome.WATER_EDGE:
					_add_water_patch(props_node, cx, cz, height_val)
				Biome.GRASSLAND:
					if density_val > 0.3:
						_add_tree(props_node, cx, cz, height_val, trunk_mat, canopy_mat)


static func _classify_biome(biome_val: float, height_val: float, season: String) -> Biome:
	if height_val < 1.0:
		return Biome.WATER_EDGE
	if height_val > 4.5:
		return Biome.ROCKY_OUTCROP

	# Season-adjusted thresholds
	var forest_thresh: float = -0.1
	var flower_thresh: float = 0.3
	match season:
		"spring":
			flower_thresh = 0.15 # more flowers
		"winter":
			forest_thresh = -0.3 # fewer forests
			flower_thresh = 0.5  # fewer flowers

	if biome_val < forest_thresh:
		return Biome.DENSE_FOREST
	elif biome_val > flower_thresh:
		return Biome.FLOWER_FIELD
	else:
		return Biome.GRASSLAND


static func _add_tree(parent: Node3D, x: float, z: float, h: float, trunk_mat: StandardMaterial3D, canopy_mat: StandardMaterial3D) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.12
	trunk_mesh.bottom_radius = 0.18
	trunk_mesh.height = 2.0
	trunk.mesh = trunk_mesh
	trunk.set_surface_override_material(0, trunk_mat)
	trunk.position = Vector3(x, h + 1.0, z)
	parent.add_child(trunk)

	var canopy := MeshInstance3D.new()
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 1.0
	canopy_mesh.height = 1.6
	canopy.mesh = canopy_mesh
	canopy.set_surface_override_material(0, canopy_mat)
	canopy.position = Vector3(x, h + 2.5, z)
	parent.add_child(canopy)


static func _add_rock(parent: Node3D, x: float, z: float, h: float, rock_mat: StandardMaterial3D, density: float) -> void:
	var rock := MeshInstance3D.new()
	var rock_mesh := BoxMesh.new()
	var s: float = 0.5 + density * 0.8
	rock_mesh.size = Vector3(s, s * 0.6, s * 0.8)
	rock.mesh = rock_mesh
	rock.set_surface_override_material(0, rock_mat)
	rock.position = Vector3(x, h + s * 0.3, z)
	parent.add_child(rock)


static func _add_flowers(parent: Node3D, x: float, z: float, h: float, color: Color) -> void:
	var flower := MeshInstance3D.new()
	var flower_mesh := SphereMesh.new()
	flower_mesh.radius = 0.3
	flower_mesh.height = 0.4
	flower.mesh = flower_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color.lerp(Color.WHITE, 0.3)
	mat.emission_energy_multiplier = 0.3
	flower.set_surface_override_material(0, mat)
	flower.position = Vector3(x, h + 0.2, z)
	parent.add_child(flower)


static func _add_water_patch(parent: Node3D, x: float, z: float, h: float) -> void:
	var water := MeshInstance3D.new()
	var water_mesh := BoxMesh.new()
	water_mesh.size = Vector3(3.0, 0.05, 3.0)
	water.mesh = water_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.35, 0.6, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.3
	mat.roughness = 0.2
	water.set_surface_override_material(0, mat)
	water.position = Vector3(x, h + 0.02, z)
	parent.add_child(water)


# --- Zone Overlays (Client) ---

static func _add_zone_overlays(parent: Node3D, zones: Array, height_noise: FastNoiseLite, detail_noise: FastNoiseLite) -> void:
	for z_data in zones:
		var pos: Vector3 = z_data["position"]
		var radius: float = z_data.get("radius", 6.0)

		var overlay := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(radius * 2, 0.02, radius * 2)
		overlay.mesh = box
		var mat := StandardMaterial3D.new()
		if z_data.get("is_rare", false):
			mat.albedo_color = Color(0.6, 0.4, 0.8, 0.25)
		else:
			mat.albedo_color = Color(0.2, 0.5, 0.2, 0.2)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		overlay.set_surface_override_material(0, mat)
		overlay.position = Vector3(pos.x, pos.y + 0.01, pos.z)
		parent.add_child(overlay)


static func _add_rare_zone_glow(parent: Node3D, zone_data: Dictionary, _height_noise: FastNoiseLite, _detail_noise: FastNoiseLite) -> void:
	var pos: Vector3 = zone_data["position"]
	var glow := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.5
	sphere.height = 3.0
	glow.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.6, 1.0, 0.3)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.7, 0.5, 0.9)
	mat.emission_energy_multiplier = 2.0
	glow.set_surface_override_material(0, mat)
	glow.position = Vector3(pos.x, pos.y + 2.0, pos.z)
	parent.add_child(glow)

	var label := Label3D.new()
	UITheme.style_label3d(label, "Rare Grove", "landmark")
	label.font_size = 32
	label.outline_size = 6
	label.position = Vector3(pos.x, pos.y + 5.0, pos.z)
	parent.add_child(label)


# --- Exit Portal ---

static func _create_exit_portal() -> Area3D:
	var area := Area3D.new()
	area.name = "ExcursionExitPortal"
	area.position = Vector3(40, 0, 77) # Just past spawn point at south edge
	area.collision_layer = 0
	area.collision_mask = 3

	var shape := CylinderShape3D.new()
	shape.radius = 3.0
	shape.height = 4.0
	var coll := CollisionShape3D.new()
	coll.shape = shape
	coll.position = Vector3(0, 2, 0)
	area.add_child(coll)

	area.set_meta("is_excursion_exit", true)
	return area


static func _create_exit_portal_visual() -> Node3D:
	var portal := Node3D.new()
	portal.name = "ExitPortalVisual"
	portal.position = Vector3(40, 0, 77)

	# Glowing ring
	var ring := MeshInstance3D.new()
	var torus := CylinderMesh.new()
	torus.top_radius = 2.5
	torus.bottom_radius = 2.5
	torus.height = 0.3
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.7, 1.0, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.6, 1.0)
	mat.emission_energy_multiplier = 3.0
	ring.set_surface_override_material(0, mat)
	ring.position = Vector3(0, 0.2, 0)
	portal.add_child(ring)

	# Label
	var label := Label3D.new()
	UITheme.style_label3d(label, "Exit Portal", "zone_sign")
	label.font_size = 36
	label.outline_size = 6
	label.position = Vector3(0, 3.0, 0)
	portal.add_child(label)

	return portal


# --- Item Spawn Table ---

static func _get_excursion_item_table(season: String) -> Array:
	var table: Array = [
		{"item_id": "golden_seed", "weight": 5},
		{"item_id": "mystic_herb", "weight": 8},
		{"item_id": "starfruit", "weight": 6},
		{"item_id": "truffle_shaving", "weight": 10},
		{"item_id": "rainbow_creature", "weight": 4},
		{"item_id": "excursion_berry", "weight": 12},
		{"item_id": "ancient_grain_seed", "weight": 5},
		{"item_id": "wild_honey", "weight": 15},
		{"item_id": "herb_basil", "weight": 15},
		{"item_id": "sugar", "weight": 10},
		{"item_id": "vinegar", "weight": 10},
	]

	# Season modifiers
	match season:
		"spring":
			# Boost seeds
			for entry in table:
				if entry["item_id"] in ["golden_seed", "ancient_grain_seed"]:
					entry["weight"] += 5
		"summer":
			# Boost fruits/essences
			for entry in table:
				if entry["item_id"] in ["starfruit", "excursion_berry"]:
					entry["weight"] += 5
		"autumn":
			# Boost mushroom-like ingredients
			for entry in table:
				if entry["item_id"] in ["truffle_shaving", "mystic_herb"]:
					entry["weight"] += 5
		"winter":
			# Boost honey, herbs
			for entry in table:
				if entry["item_id"] in ["wild_honey", "herb_basil"]:
					entry["weight"] += 5

	return table
