extends RefCounted

## Builds Connected-Island 3D assets OBJ01 .. OBJ20:
## OBJ01_house_blue, OBJ02_cottage_blue, OBJ03_crystal_beacon, OBJ04_quest_board, OBJ05_market_stall,
## OBJ06_round_plaza, OBJ07_sql_database, OBJ08_sql_archive, OBJ09_sql_library, OBJ10_sql_table,
## OBJ11_sql_query_y, OBJ12_sort_steps, OBJ13_graph_node, OBJ14_graph_edge, OBJ15_maze_garden,
## OBJ16_branch_path, OBJ17_sign_main, OBJ18_sign_ds, OBJ19_sign_sql, OBJ20_sign_algo

static func _add_gable_roof(
	parent: Node3D,
	prefix: String,
	center: Vector3,
	span_x: float,
	rise_y: float,
	len_z: float,
	mat_roof: Material,
	mat_wall: Material,
	mat_trim: Material,
	along_x: bool = false
) -> void:
	var grp := Node3D.new()
	grp.name = prefix
	grp.position = center
	if along_x:
		grp.rotation_degrees = Vector3(0.0, 90.0, 0.0)
	parent.add_child(grp)

	var w: float = span_x if not along_x else len_z
	var d: float = len_z if not along_x else span_x
	var hw := w * 0.5
	var slope_len := sqrt(hw * hw + rise_y * rise_y) + 0.14
	var ang := rad_to_deg(atan2(rise_y, hw))

	# Triangular gable walls (front/back)
	var gable_poly := PackedVector2Array([
		Vector2(-hw + 0.06, -0.02),
		Vector2(hw - 0.06, -0.02),
		Vector2(0.0, rise_y)
	])
	var gable_mesh := MeshKit.extrude_polygon_xz(gable_poly, d - 0.14)
	MeshKit.add_part(grp, "GableCore", gable_mesh, mat_wall, Vector3.ZERO, Vector3(90.0, 0.0, 0.0))

	# Left & Right sloped roof planes
	for sx: float in [-1.0, 1.0]:
		var mid_x := sx * (hw * 0.5 + 0.02)
		var mid_y := rise_y * 0.5 + 0.02
		MeshKit.add_part(grp, "RoofSlope_%d" % int(sx),
			MeshKit.beveled_box(Vector3(slope_len, 0.11, d + 0.16), 0.016, 1, false, 1.3),
			mat_roof, Vector3(mid_x, mid_y, 0.0), Vector3(0.0, 0.0, -sx * ang))

	# Ridge beam cap
	MeshKit.add_part(grp, "RidgeBeam",
		MeshKit.beveled_box(Vector3(0.16, 0.12, d + 0.20), 0.018, 1, false),
		mat_trim, Vector3(0.0, rise_y + 0.04, 0.0))

static func _add_warm_window(parent: Node3D, wname: String, pos: Vector3, rot_y: float, w: float = 0.28, h: float = 0.32) -> void:
	var mat_frame := MeshKit.mat_color("win_frame", Color(0.54, 0.34, 0.18), 0.60, 0.0, "wood_brown")
	var mat_glow := MeshKit.mat_emissive("win_glow", Color(1.0, 0.90, 0.52), Color(1.0, 0.80, 0.32), 2.4, 0.18)
	var win := Node3D.new()
	win.name = wname
	win.position = pos
	win.rotation_degrees = Vector3(0.0, rot_y, 0.0)
	parent.add_child(win)
	MeshKit.add_part(win, "Frame", MeshKit.beveled_box(Vector3(w, h, 0.06), 0.01, 1, false), mat_frame, Vector3.ZERO)
	MeshKit.add_part(win, "Glass", MeshKit.beveled_box(Vector3(w - 0.07, h - 0.07, 0.07), 0.006, 1, false), mat_glow, Vector3(0.0, 0.0, 0.005))
	MeshKit.add_part(win, "MullionV", MeshKit.beveled_box(Vector3(0.028, h - 0.05, 0.08), 0.004, 1, false), mat_frame, Vector3(0.0, 0.0, 0.008))
	MeshKit.add_part(win, "MullionH", MeshKit.beveled_box(Vector3(w - 0.05, 0.028, 0.08), 0.004, 1, false), mat_frame, Vector3(0.0, 0.0, 0.008))

# ---------------------------------------------------------------------------
# OBJ01: 파란 지붕 2층 주택 (Main Village House)
# ---------------------------------------------------------------------------
static func build_obj01_house_blue() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ01_house_blue"

	var mat_stone := MeshKit.mat_color("h_stone", Color(0.68, 0.66, 0.64), 0.75, 0.04, "stone_ashlar")
	var mat_plaster := MeshKit.mat_color("h_plaster", Color(0.96, 0.91, 0.80), 0.65, 0.02, "stone_ivory")
	var mat_timber := MeshKit.mat_color("h_timber", Color(0.54, 0.34, 0.18), 0.60, 0.0, "wood_brown")
	var mat_door := MeshKit.mat_color("h_door", Color(0.68, 0.44, 0.22), 0.56, 0.0, "wood_oak")
	var mat_roof := MeshKit.mat_color("h_roof_blue", Color(0.24, 0.50, 0.92), 0.46, 0.05, "roof_blue")
	var mat_chimney := MeshKit.mat_color("h_chimney", Color(0.78, 0.74, 0.70), 0.72, 0.03, "stone_ashlar")

	# Foundation
	MeshKit.add_part(root, "Foundation",
		MeshKit.beveled_box(Vector3(2.10, 0.18, 1.76), 0.02, 1, false),
		mat_stone, Vector3(0.0, 0.09, 0.0))

	# Main Rear/Right 2-story body + Front/Left Gable Wing
	MeshKit.add_part(root, "MainWalls",
		MeshKit.beveled_box(Vector3(1.92, 1.18, 1.48), 0.02, 1, false),
		mat_plaster, Vector3(0.0, 0.77, -0.04))
	MeshKit.add_part(root, "FrontWing",
		MeshKit.beveled_box(Vector3(1.12, 1.08, 0.42), 0.02, 1, false),
		mat_plaster, Vector3(0.26, 0.72, 0.74))

	# Timber Corner Posts & Horizontal Belt Beams
	for sx: float in [-0.93, 0.93]:
		for sz: float in [-0.75, 0.67]:
			MeshKit.add_part(root, "CornerPost_%d_%d" % [int(sx * 10), int(sz * 10)],
				MeshKit.beveled_box(Vector3(0.10, 1.20, 0.10), 0.01, 1, false),
				mat_timber, Vector3(sx, 0.77, sz))
	MeshKit.add_part(root, "BeltBeamMain",
		MeshKit.beveled_box(Vector3(1.98, 0.08, 1.54), 0.01, 1, false),
		mat_timber, Vector3(0.0, 0.78, -0.04))

	# Two intersecting Blue Pitched Roofs (Main along X, Front Gable along Z)
	_add_gable_roof(root, "MainRoof", Vector3(0.0, 1.36, -0.04), 1.58, 0.68, 2.04, mat_roof, mat_plaster, mat_timber, true)
	_add_gable_roof(root, "FrontGableRoof", Vector3(0.26, 1.26, 0.44), 1.22, 0.56, 1.12, mat_roof, mat_plaster, mat_timber, false)

	# Stone Chimney on left roof slope
	MeshKit.add_part(root, "ChimneyShaft",
		MeshKit.beveled_box(Vector3(0.30, 0.66, 0.30), 0.016, 1, false),
		mat_chimney, Vector3(-0.52, 1.72, -0.22))
	MeshKit.add_part(root, "ChimneyCap",
		MeshKit.beveled_box(Vector3(0.36, 0.08, 0.36), 0.014, 1, false),
		mat_stone, Vector3(-0.52, 2.07, -0.22))

	# Front Door + Stone Step on Front Wing (+Z)
	MeshKit.add_part(root, "DoorStep",
		MeshKit.beveled_box(Vector3(0.56, 0.12, 0.28), 0.014, 1, false),
		mat_stone, Vector3(0.26, 0.06, 1.04))
	MeshKit.add_part(root, "DoorFrame",
		MeshKit.beveled_box(Vector3(0.46, 0.64, 0.08), 0.012, 1, false),
		mat_timber, Vector3(0.26, 0.50, 0.94))
	MeshKit.add_part(root, "DoorLeaf",
		MeshKit.beveled_box(Vector3(0.36, 0.56, 0.09), 0.01, 1, false),
		mat_door, Vector3(0.26, 0.48, 0.95))

	# Warm Glowing Windows
	_add_warm_window(root, "WinFrontLeft", Vector3(-0.52, 0.54, 0.70), 0.0, 0.34, 0.36)
	_add_warm_window(root, "WinGableUpper", Vector3(0.26, 1.44, 0.95), 0.0, 0.26, 0.26)
	_add_warm_window(root, "WinRight1", Vector3(0.96, 0.54, -0.28), 90.0, 0.34, 0.36)
	_add_warm_window(root, "WinRight2", Vector3(0.96, 0.54, 0.28), 90.0, 0.34, 0.36)
	_add_warm_window(root, "WinLeft", Vector3(-0.96, 0.54, 0.0), -90.0, 0.36, 0.36)

	return root

# ---------------------------------------------------------------------------
# OBJ02: 파란 지붕 작은집 (Cozy Blue-Roof Cottage)
# ---------------------------------------------------------------------------
static func build_obj02_cottage_blue() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ02_cottage_blue"

	var mat_stone := MeshKit.mat_color("c_stone", Color(0.68, 0.66, 0.64), 0.75, 0.04, "stone_ashlar")
	var mat_plaster := MeshKit.mat_color("c_plaster", Color(0.96, 0.91, 0.80), 0.65, 0.02, "stone_ivory")
	var mat_timber := MeshKit.mat_color("c_timber", Color(0.54, 0.34, 0.18), 0.60, 0.0, "wood_brown")
	var mat_door := MeshKit.mat_color("c_door", Color(0.68, 0.44, 0.22), 0.56, 0.0, "wood_oak")
	var mat_roof := MeshKit.mat_color("c_roof_blue", Color(0.24, 0.50, 0.92), 0.46, 0.05, "roof_blue")

	MeshKit.add_part(root, "Foundation",
		MeshKit.beveled_box(Vector3(1.56, 0.16, 1.48), 0.02, 1, false),
		mat_stone, Vector3(0.0, 0.08, 0.0))
	MeshKit.add_part(root, "Walls",
		MeshKit.beveled_box(Vector3(1.40, 0.98, 1.32), 0.02, 1, false),
		mat_plaster, Vector3(0.0, 0.65, 0.0))

	for sx: float in [-0.68, 0.68]:
		for sz: float in [-0.64, 0.64]:
			MeshKit.add_part(root, "Post_%d_%d" % [int(sx * 10), int(sz * 10)],
				MeshKit.beveled_box(Vector3(0.09, 1.00, 0.09), 0.01, 1, false),
				mat_timber, Vector3(sx, 0.65, sz))

	_add_gable_roof(root, "Roof", Vector3(0.0, 1.14, 0.0), 1.50, 0.62, 1.46, mat_roof, mat_plaster, mat_timber, false)

	MeshKit.add_part(root, "Chimney",
		MeshKit.beveled_box(Vector3(0.26, 0.54, 0.26), 0.015, 1, false),
		mat_stone, Vector3(-0.38, 1.52, -0.26))
	MeshKit.add_part(root, "ChimneyCap",
		MeshKit.beveled_box(Vector3(0.32, 0.07, 0.32), 0.012, 1, false),
		mat_stone, Vector3(-0.38, 1.81, -0.26))

	MeshKit.add_part(root, "DoorStep",
		MeshKit.beveled_box(Vector3(0.52, 0.11, 0.26), 0.012, 1, false),
		mat_stone, Vector3(0.0, 0.055, 0.76))
	MeshKit.add_part(root, "DoorFrame",
		MeshKit.beveled_box(Vector3(0.44, 0.60, 0.08), 0.012, 1, false),
		mat_timber, Vector3(0.0, 0.46, 0.66))
	MeshKit.add_part(root, "DoorLeaf",
		MeshKit.beveled_box(Vector3(0.34, 0.52, 0.09), 0.01, 1, false),
		mat_door, Vector3(0.0, 0.44, 0.67))

	_add_warm_window(root, "WinGable", Vector3(0.0, 1.34, 0.66), 0.0, 0.24, 0.24)
	_add_warm_window(root, "WinRight", Vector3(0.70, 0.56, 0.0), 90.0, 0.36, 0.36)
	_add_warm_window(root, "WinLeft", Vector3(-0.70, 0.56, 0.0), -90.0, 0.36, 0.36)

	return root

# ---------------------------------------------------------------------------
# OBJ03: 중앙 수정 비콘 (Main Plaza Crystal Beacon)
# ---------------------------------------------------------------------------
static func build_obj03_crystal_beacon() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ03_crystal_beacon"

	var mat_stone := MeshKit.mat_color("cb_stone", Color(0.76, 0.75, 0.73), 0.68, 0.05, "stone_ashlar")
	var mat_stone_d := MeshKit.mat_color("cb_stone_d", Color(0.56, 0.56, 0.59), 0.72, 0.08)
	var mat_cyan_ring := MeshKit.mat_emissive("cb_ring", Color(0.22, 0.90, 1.0), Color(0.12, 0.80, 1.0), 2.5, 0.15)
	var mat_crystal := MeshKit.mat_emissive("cb_crystal", Color(0.32, 0.95, 1.0), Color(0.16, 0.86, 1.0), 2.8, 0.12)
	var mat_crystal_tip := MeshKit.mat_emissive("cb_crystal_t", Color(0.68, 0.99, 1.0), Color(0.42, 0.94, 1.0), 3.2, 0.10)

	# Stepped Octagonal Pedestal Base
	MeshKit.add_part(root, "BaseOct1",
		MeshKit.beveled_cylinder(0.96, 0.92, 0.18, 8, 0.02, false),
		mat_stone_d, Vector3(0.0, 0.09, 0.0), Vector3(0.0, 22.5, 0.0))
	MeshKit.add_part(root, "BaseOct2",
		MeshKit.beveled_cylinder(0.78, 0.74, 0.20, 8, 0.02, false),
		mat_stone, Vector3(0.0, 0.28, 0.0), Vector3(0.0, 22.5, 0.0))
	MeshKit.add_part(root, "PedestalRing",
		MeshKit.beveled_cylinder(0.62, 0.58, 0.18, 8, 0.018, false),
		mat_stone_d, Vector3(0.0, 0.47, 0.0), Vector3(0.0, 22.5, 0.0))
	MeshKit.add_part(root, "GlowBasin",
		MeshKit.beveled_cylinder(0.48, 0.48, 0.06, 8, 0.01, false),
		mat_cyan_ring, Vector3(0.0, 0.57, 0.0), Vector3(0.0, 22.5, 0.0))

	# 4 small steps around pedestal
	for i in range(4):
		var ang := float(i) * 90.0
		var rad := deg_to_rad(ang)
		MeshKit.add_part(root, "StepButtress_%d" % i,
			MeshKit.beveled_box(Vector3(0.42, 0.26, 0.28), 0.016, 1, false),
			mat_stone, Vector3(sin(rad) * 0.80, 0.13, cos(rad) * 0.80), Vector3(0.0, ang, 0.0))

	# Central Tall Faceted Crystal (6-sided prism + pyramidal apex)
	MeshKit.add_part(root, "MainCrystalBody",
		MeshKit.beveled_cylinder(0.26, 0.30, 0.92, 6, 0.01, false),
		mat_crystal, Vector3(0.0, 1.02, 0.0), Vector3(0.0, 15.0, 0.0))
	MeshKit.add_part(root, "MainCrystalTip",
		MeshKit.beveled_cylinder(0.30, 0.01, 0.46, 6, 0.005, false),
		mat_crystal_tip, Vector3(0.0, 1.71, 0.0), Vector3(0.0, 15.0, 0.0))

	# 3 Companion Crystal Shards
	var shard_angles := [-115.0, 115.0, 0.0]
	for idx in range(3):
		var a_deg: float = shard_angles[idx]
		var a_rad := deg_to_rad(a_deg)
		var shard := Node3D.new()
		shard.name = "Shard_%d" % idx
		shard.position = Vector3(sin(a_rad) * 0.38, 0.58, cos(a_rad) * 0.38)
		shard.rotation_degrees = Vector3(cos(a_rad) * 18.0, a_deg, -sin(a_rad) * 18.0)
		root.add_child(shard)
		MeshKit.add_part(shard, "Body",
			MeshKit.beveled_cylinder(0.12, 0.14, 0.38, 6, 0.006, false),
			mat_crystal, Vector3(0.0, 0.19, 0.0))
		MeshKit.add_part(shard, "Tip",
			MeshKit.beveled_cylinder(0.14, 0.01, 0.22, 6, 0.004, false),
			mat_crystal_tip, Vector3(0.0, 0.49, 0.0))

	MeshKit.add_light(root, "BeaconOmniLight", Color(0.20, 0.90, 1.0), 1.6, 5.5, Vector3(0.0, 1.35, 0.0))
	return root

# ---------------------------------------------------------------------------
# OBJ04: 퀘스트 게시판 (Quest Notice Board)
# ---------------------------------------------------------------------------
static func build_obj04_quest_board() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ04_quest_board"

	var mat_stone := MeshKit.mat_color("qb_stone", Color(0.64, 0.63, 0.62), 0.74, 0.04, "stone_ashlar")
	var mat_wood := MeshKit.mat_color("qb_wood", Color(0.76, 0.52, 0.28), 0.58, 0.0, "wood_oak")
	var mat_wood_d := MeshKit.mat_color("qb_wood_d", Color(0.52, 0.33, 0.17), 0.64, 0.0, "wood_brown")
	var mat_paper := MeshKit.mat_color("qb_paper", Color(0.97, 0.93, 0.82), 0.48, 0.0)
	var mat_cyan := MeshKit.mat_emissive("qb_cyan", Color(0.25, 0.94, 1.0), Color(0.15, 0.85, 1.0), 2.4, 0.15)

	for sx: float in [-1.0, 1.0]:
		var px := sx * 0.54
		MeshKit.add_part(root, "Foot_%d" % int(sx),
			MeshKit.beveled_box(Vector3(0.28, 0.14, 0.30), 0.015, 1, false),
			mat_stone, Vector3(px, 0.07, 0.0))
		MeshKit.add_part(root, "Post_%d" % int(sx),
			MeshKit.beveled_box(Vector3(0.16, 1.24, 0.16), 0.014, 1, false),
			mat_wood_d, Vector3(px, 0.74, 0.0))

	# Backboard & Frame
	MeshKit.add_part(root, "BoardPanel",
		MeshKit.beveled_box(Vector3(1.12, 0.72, 0.10), 0.012, 1, false),
		mat_wood, Vector3(0.0, 0.88, 0.0))
	MeshKit.add_part(root, "FrameTop",
		MeshKit.beveled_box(Vector3(1.24, 0.09, 0.15), 0.012, 1, false),
		mat_wood_d, Vector3(0.0, 1.22, 0.0))
	MeshKit.add_part(root, "FrameBot",
		MeshKit.beveled_box(Vector3(1.24, 0.09, 0.15), 0.012, 1, false),
		mat_wood_d, Vector3(0.0, 0.52, 0.0))

	# Two Cream Parchment Notices
	MeshKit.add_part(root, "NoticeLeft",
		MeshKit.beveled_box(Vector3(0.36, 0.44, 0.03), 0.006, 1, false),
		mat_paper, Vector3(-0.24, 0.88, 0.055))
	MeshKit.add_part(root, "NoticeRight",
		MeshKit.beveled_box(Vector3(0.36, 0.40, 0.03), 0.006, 1, false),
		mat_paper, Vector3(0.24, 0.86, 0.055))

	# Pitched Wooden Canopy Roof
	for sx: float in [-1.0, 1.0]:
		MeshKit.add_part(root, "RoofSlope_%d" % int(sx),
			MeshKit.beveled_box(Vector3(0.84, 0.10, 0.48), 0.014, 1, false),
			mat_wood, Vector3(sx * 0.36, 1.44, 0.0), Vector3(0.0, 0.0, -sx * 24.0))
	MeshKit.add_part(root, "RoofRidge",
		MeshKit.beveled_box(Vector3(0.16, 0.11, 0.52), 0.014, 1, false),
		mat_wood_d, Vector3(0.0, 1.60, 0.0))
	MeshKit.add_part(root, "ApexGem",
		MeshKit.beveled_cylinder(0.075, 0.075, 0.06, 8, 0.008, true),
		mat_cyan, Vector3(0.0, 1.40, 0.12), Vector3(90.0, 0.0, 0.0))

	return root

# ---------------------------------------------------------------------------
# OBJ05: 시장 가판대 (Blue-and-White Striped Market Stall)
# ---------------------------------------------------------------------------
static func build_obj05_market_stall() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ05_market_stall"

	var mat_stone := MeshKit.mat_color("ms_stone", Color(0.68, 0.66, 0.64), 0.74, 0.04)
	var mat_wood := MeshKit.mat_color("ms_wood", Color(0.82, 0.56, 0.30), 0.56, 0.0, "wood_oak")
	var mat_wood_d := MeshKit.mat_color("ms_wood_d", Color(0.56, 0.36, 0.18), 0.62, 0.0, "wood_brown")
	var mat_blue := MeshKit.mat_color("ms_blue", Color(0.20, 0.52, 0.94), 0.45, 0.02)
	var mat_white := MeshKit.mat_color("ms_white", Color(0.96, 0.97, 0.99), 0.45, 0.02)

	MeshKit.add_part(root, "BasePlinth",
		MeshKit.beveled_box(Vector3(1.48, 0.12, 1.18), 0.016, 1, false),
		mat_stone, Vector3(0.0, 0.06, 0.0))

	# Counter Base & Top
	MeshKit.add_part(root, "CounterBody",
		MeshKit.beveled_box(Vector3(1.36, 0.52, 1.02), 0.016, 1, false),
		mat_wood_d, Vector3(0.0, 0.38, 0.0))
	MeshKit.add_part(root, "CounterTop",
		MeshKit.beveled_box(Vector3(1.44, 0.08, 1.10), 0.014, 1, false),
		mat_wood, Vector3(0.0, 0.68, 0.0))

	# 2 Small crates under counter
	for sx: float in [-0.34, 0.34]:
		var cr := BuilderCharsProps.build_crate("brown")
		cr.scale = Vector3(0.46, 0.46, 0.46)
		cr.position = Vector3(sx, 0.14, 0.32)
		root.add_child(cr)

	# 4 Corner Posts
	for sx: float in [-0.62, 0.62]:
		for sz: float in [-0.46, 0.46]:
			MeshKit.add_part(root, "Post_%d_%d" % [int(sx * 10), int(sz * 10)],
				MeshKit.beveled_box(Vector3(0.10, 1.32, 0.10), 0.012, 1, false),
				mat_wood_d, Vector3(sx, 0.78, sz))

	# Striped Blue & White Awning (5 stripes across X)
	var stripes := 5
	var sw := 1.52 / float(stripes)
	for i in range(stripes):
		var sx := -0.76 + (float(i) + 0.5) * sw
		var m := mat_blue if (i % 2 == 0) else mat_white
		for sz: float in [-1.0, 1.0]:
			MeshKit.add_part(root, "AwningSlope_%d_%d" % [i, int(sz)],
				MeshKit.beveled_box(Vector3(sw + 0.01, 0.09, 0.72), 0.014, 1, false),
				m, Vector3(sx, 1.54, sz * 0.28), Vector3(sz * 22.0, 0.0, 0.0))
			MeshKit.add_part(root, "Valance_%d_%d" % [i, int(sz)],
				MeshKit.beveled_box(Vector3(sw - 0.01, 0.14, 0.07), 0.012, 1, false),
				m, Vector3(sx, 1.36, sz * 0.60))

	return root

# ---------------------------------------------------------------------------
# OBJ06: 원형 광장 (Circular Gray Stone Plaza)
# ---------------------------------------------------------------------------
static func build_obj06_round_plaza() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ06_round_plaza"
	var h1 := BuilderTerrainNature.build_plaza_half()
	h1.name = "HalfA"
	root.add_child(h1)
	var h2 := BuilderTerrainNature.build_plaza_half()
	h2.name = "HalfB"
	h2.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	root.add_child(h2)
	return root

# ---------------------------------------------------------------------------
# OBJ07: SQL 데이터베이스 탑 (Cylindrical Stacked-Disk Database Landmark)
# ---------------------------------------------------------------------------
static func build_obj07_sql_database() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ07_sql_database"

	var mat_stone := MeshKit.mat_color("db_stone", Color(0.76, 0.75, 0.73), 0.68, 0.05, "stone_ashlar")
	var mat_ivory := MeshKit.mat_color("db_ivory", Color(0.95, 0.93, 0.88), 0.42, 0.08, "stone_ivory")
	var mat_cap := MeshKit.mat_color("db_cap", Color(0.84, 0.85, 0.88), 0.38, 0.15)
	var mat_cyan := MeshKit.mat_emissive("db_cyan", Color(0.22, 0.90, 1.0), Color(0.10, 0.82, 1.0), 2.8, 0.14)
	var mat_dark := MeshKit.mat_color("db_dark", Color(0.18, 0.22, 0.28), 0.50, 0.35)

	# Broad Octagonal Base with 8 Cyan Indicator Nodes
	MeshKit.add_part(root, "OctBase1",
		MeshKit.beveled_cylinder(1.32, 1.26, 0.22, 8, 0.022, false),
		mat_stone, Vector3(0.0, 0.11, 0.0), Vector3(0.0, 22.5, 0.0))
	MeshKit.add_part(root, "OctBase2",
		MeshKit.beveled_cylinder(1.12, 1.08, 0.24, 8, 0.02, false),
		mat_ivory, Vector3(0.0, 0.34, 0.0), Vector3(0.0, 22.5, 0.0))

	for i in range(8):
		var a := TAU * float(i) / 8.0
		var bpos := Vector3(cos(a) * 1.12, 0.26, sin(a) * 1.12)
		MeshKit.add_part(root, "BaseBlock_%d" % i,
			MeshKit.beveled_box(Vector3(0.28, 0.28, 0.28), 0.016, 1, false),
			mat_stone, bpos, Vector3(0.0, -rad_to_deg(a), 0.0))
		MeshKit.add_part(root, "BaseNodeGlow_%d" % i,
			MeshKit.beveled_box(Vector3(0.14, 0.12, 0.30), 0.01, 1, false),
			mat_cyan, bpos, Vector3(0.0, -rad_to_deg(a), 0.0))

	# 4 Stacked Thick Ivory Disk Storeys + Glowing Cyan Ring Bands
	var base_y := 0.46
	var storey_h := 0.42
	var gap_h := 0.13
	for s in range(4):
		var y_ring := base_y + float(s) * (storey_h + gap_h)
		MeshKit.add_part(root, "CyanRing_%d" % s,
			MeshKit.beveled_cylinder(0.84, 0.84, gap_h + 0.02, 28, 0.01, true),
			mat_cyan, Vector3(0.0, y_ring + gap_h * 0.5, 0.0))
		var y_disk := y_ring + gap_h + storey_h * 0.5
		MeshKit.add_part(root, "DiskStorey_%d" % s,
			MeshKit.beveled_cylinder(0.92, 0.92, storey_h, 32, 0.03, true),
			mat_ivory, Vector3(0.0, y_disk, 0.0))

	# Top Bevelled Cap Dome
	var top_y := base_y + 4.0 * (storey_h + gap_h)
	MeshKit.add_part(root, "TopRim",
		MeshKit.beveled_cylinder(0.94, 0.90, 0.12, 32, 0.02, true),
		mat_cap, Vector3(0.0, top_y + 0.06, 0.0))
	MeshKit.add_part(root, "TopPlate",
		MeshKit.beveled_cylinder(0.76, 0.74, 0.08, 32, 0.015, true),
		mat_ivory, Vector3(0.0, top_y + 0.14, 0.0))

	# Base Front Port Entrance (+Z)
	MeshKit.add_part(root, "FrontPortFrame",
		MeshKit.beveled_box(Vector3(0.46, 0.36, 0.24), 0.016, 1, false),
		mat_stone, Vector3(0.0, 0.32, 1.04))
	MeshKit.add_part(root, "FrontPortCore",
		MeshKit.beveled_box(Vector3(0.30, 0.24, 0.26), 0.01, 1, false),
		mat_dark, Vector3(0.0, 0.30, 1.05))

	MeshKit.add_light(root, "DBLight", Color(0.20, 0.88, 1.0), 1.4, 5.0, Vector3(0.0, 1.6, 0.0))
	return root

# ---------------------------------------------------------------------------
# OBJ08: SQL 기록 보관소 (Classical Ivory Archive Hall)
# ---------------------------------------------------------------------------
static func build_obj08_sql_archive() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ08_sql_archive"

	var mat_stone := MeshKit.mat_color("ar_stone", Color(0.74, 0.73, 0.70), 0.72, 0.04, "stone_ashlar")
	var mat_ivory := MeshKit.mat_color("ar_ivory", Color(0.96, 0.92, 0.83), 0.56, 0.03, "stone_ivory")
	var mat_gold := MeshKit.mat_color("ar_gold", Color(0.88, 0.70, 0.32), 0.42, 0.35)
	var mat_roof := MeshKit.mat_color("ar_roof", Color(0.22, 0.48, 0.90), 0.44, 0.06, "roof_blue")
	var mat_door := MeshKit.mat_color("ar_door", Color(0.58, 0.38, 0.20), 0.58, 0.0, "wood_brown")

	MeshKit.add_part(root, "Plinth",
		MeshKit.beveled_box(Vector3(2.26, 0.22, 1.68), 0.02, 1, false),
		mat_stone, Vector3(0.0, 0.11, 0.0))
	MeshKit.add_part(root, "MainHall",
		MeshKit.beveled_box(Vector3(2.08, 1.08, 1.48), 0.02, 1, false),
		mat_ivory, Vector3(0.0, 0.76, 0.0))
	MeshKit.add_part(root, "Cornice",
		MeshKit.beveled_box(Vector3(2.20, 0.12, 1.60), 0.016, 1, false),
		mat_stone, Vector3(0.0, 1.34, 0.0))

	# Front Pilasters & Central Portico
	for px: float in [-0.88, -0.38, 0.38, 0.88]:
		MeshKit.add_part(root, "Pilaster_%d" % int(px * 100),
			MeshKit.beveled_box(Vector3(0.14, 1.06, 0.12), 0.012, 1, false),
			mat_stone, Vector3(px, 0.76, 0.74))

	# Front Doorway + Stairs
	MeshKit.add_part(root, "FrontStairs1",
		MeshKit.beveled_box(Vector3(0.76, 0.10, 0.36), 0.012, 1, false),
		mat_stone, Vector3(0.0, 0.05, 0.96))
	MeshKit.add_part(root, "FrontStairs2",
		MeshKit.beveled_box(Vector3(0.68, 0.10, 0.22), 0.012, 1, false),
		mat_stone, Vector3(0.0, 0.15, 0.88))
	MeshKit.add_part(root, "DoorArchFrame",
		MeshKit.beveled_box(Vector3(0.56, 0.76, 0.14), 0.016, 1, false),
		mat_gold, Vector3(0.0, 0.60, 0.74))
	MeshKit.add_part(root, "DoorPanel",
		MeshKit.beveled_box(Vector3(0.42, 0.66, 0.16), 0.012, 1, false),
		mat_door, Vector3(0.0, 0.56, 0.75))

	# Blue Pitched Roof + Central Skylight Lantern
	_add_gable_roof(root, "ArchiveRoof", Vector3(0.0, 1.40, 0.0), 1.56, 0.48, 2.16, mat_roof, mat_ivory, mat_stone, true)
	MeshKit.add_part(root, "RoofLantern",
		MeshKit.beveled_box(Vector3(0.66, 0.22, 0.52), 0.016, 1, false),
		mat_ivory, Vector3(0.0, 1.84, 0.0))

	_add_warm_window(root, "WinFL", Vector3(-0.64, 0.74, 0.73), 0.0, 0.30, 0.42)
	_add_warm_window(root, "WinFR", Vector3(0.64, 0.74, 0.73), 0.0, 0.30, 0.42)
	_add_warm_window(root, "WinR1", Vector3(1.04, 0.74, -0.32), 90.0, 0.30, 0.42)
	_add_warm_window(root, "WinR2", Vector3(1.04, 0.74, 0.32), 90.0, 0.30, 0.42)

	return root

# ---------------------------------------------------------------------------
# OBJ09: SQL 작은 도서관 (Small SQL Archive Pavilion)
# ---------------------------------------------------------------------------
static func build_obj09_sql_library() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ09_sql_library"

	var mat_stone := MeshKit.mat_color("lb_stone", Color(0.74, 0.73, 0.70), 0.72, 0.04, "stone_ashlar")
	var mat_ivory := MeshKit.mat_color("lb_ivory", Color(0.96, 0.92, 0.83), 0.56, 0.03, "stone_ivory")
	var mat_gold := MeshKit.mat_color("lb_gold", Color(0.88, 0.70, 0.32), 0.42, 0.35)
	var mat_roof := MeshKit.mat_color("lb_roof", Color(0.22, 0.48, 0.90), 0.44, 0.06, "roof_blue")
	var mat_door := MeshKit.mat_color("lb_door", Color(0.58, 0.38, 0.20), 0.58, 0.0, "wood_brown")

	MeshKit.add_part(root, "Plinth",
		MeshKit.beveled_box(Vector3(1.62, 0.20, 1.56), 0.02, 1, false),
		mat_stone, Vector3(0.0, 0.10, 0.0))
	MeshKit.add_part(root, "Walls",
		MeshKit.beveled_box(Vector3(1.44, 1.06, 1.38), 0.02, 1, false),
		mat_ivory, Vector3(0.0, 0.73, 0.0))
	MeshKit.add_part(root, "Cornice",
		MeshKit.beveled_box(Vector3(1.56, 0.10, 1.50), 0.015, 1, false),
		mat_stone, Vector3(0.0, 1.30, 0.0))

	_add_gable_roof(root, "LibraryRoof", Vector3(0.0, 1.35, 0.0), 1.52, 0.54, 1.50, mat_roof, mat_ivory, mat_stone, false)

	MeshKit.add_part(root, "Step",
		MeshKit.beveled_box(Vector3(0.68, 0.12, 0.30), 0.012, 1, false),
		mat_stone, Vector3(0.0, 0.06, 0.88))
	MeshKit.add_part(root, "ArchTrim",
		MeshKit.beveled_box(Vector3(0.54, 0.76, 0.12), 0.016, 1, false),
		mat_gold, Vector3(0.0, 0.58, 0.69))
	MeshKit.add_part(root, "Door",
		MeshKit.beveled_box(Vector3(0.40, 0.66, 0.14), 0.012, 1, false),
		mat_door, Vector3(0.0, 0.54, 0.70))

	_add_warm_window(root, "WinR", Vector3(0.72, 0.72, 0.0), 90.0, 0.42, 0.46)
	_add_warm_window(root, "WinL", Vector3(-0.72, 0.72, 0.0), -90.0, 0.42, 0.46)

	return root

# ---------------------------------------------------------------------------
# OBJ10: SQL 테이블 플랫폼 (4x4 Grid Table Platform)
# ---------------------------------------------------------------------------
static func build_obj10_sql_table() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ10_sql_table"

	var mat_stone := MeshKit.mat_color("tb_stone", Color(0.74, 0.73, 0.71), 0.70, 0.04, "stone_ashlar")
	var mat_ivory := MeshKit.mat_color("tb_ivory", Color(0.95, 0.92, 0.85), 0.52, 0.04, "stone_ivory")
	var mat_tile_b := MeshKit.mat_color("tb_blue", Color(0.30, 0.62, 0.96), 0.32, 0.08)
	var mat_tile_w := MeshKit.mat_color("tb_white", Color(0.92, 0.96, 1.0), 0.32, 0.06)
	var mat_cyan := MeshKit.mat_emissive("tb_cyan", Color(0.22, 0.90, 1.0), Color(0.12, 0.82, 1.0), 2.2, 0.18)

	# 4 Corner Feet + Main Frame
	for sx: float in [-0.92, 0.92]:
		for sz: float in [-0.92, 0.92]:
			MeshKit.add_part(root, "Foot_%d_%d" % [int(sx * 10), int(sz * 10)],
				MeshKit.beveled_box(Vector3(0.36, 0.14, 0.36), 0.015, 1, false),
				mat_stone, Vector3(sx, 0.07, sz))

	MeshKit.add_part(root, "PlatformBody",
		MeshKit.beveled_box(Vector3(2.24, 0.26, 2.24), 0.02, 1, false),
		mat_ivory, Vector3(0.0, 0.25, 0.0))

	# 4x4 Grid of Inset Blue & White Data Cells
	var cell_s := 0.42
	var pitch := 0.45
	for r in range(4):
		for c in range(4):
			var px := (float(c) - 1.5) * pitch
			var pz := (float(r) - 1.5) * pitch
			var is_header := (r == 0)
			var m := mat_tile_b if (is_header or (r + c) % 2 == 0) else mat_tile_w
			MeshKit.add_part(root, "Cell_%d_%d" % [r, c],
				MeshKit.beveled_box(Vector3(cell_s, 0.06, cell_s), 0.01, 1, false),
				m, Vector3(px, 0.39, pz))

	# Side Cyan Indicator Slots
	for side: float in [-0.55, 0.55]:
		MeshKit.add_part(root, "SidePortZ_%d" % int(side * 10),
			MeshKit.beveled_box(Vector3(0.22, 0.10, 2.26), 0.008, 1, false),
			mat_cyan, Vector3(side, 0.24, 0.0))
		MeshKit.add_part(root, "SidePortX_%d" % int(side * 10),
			MeshKit.beveled_box(Vector3(2.26, 0.10, 0.22), 0.008, 1, false),
			mat_cyan, Vector3(0.0, 0.24, side))

	return root

# ---------------------------------------------------------------------------
# OBJ11: SQL 합류 수로 (Y-Shaped Query Channel Junction)
# ---------------------------------------------------------------------------
static func build_obj11_sql_query_y() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ11_sql_query_y"

	var mat_ivory := MeshKit.mat_color("qy_ivory", Color(0.95, 0.91, 0.82), 0.56, 0.03, "stone_ivory")
	var mat_stone := MeshKit.mat_color("qy_stone", Color(0.72, 0.70, 0.68), 0.70, 0.04)
	var mat_cyan := MeshKit.mat_emissive("qy_cyan", Color(0.20, 0.88, 1.0), Color(0.10, 0.80, 1.0), 2.6, 0.12)

	var arm_defs := [
		["StemOut", Vector3(0.0, 0.0, 0.52), 0.0, 1.08],
		["BranchLeft", Vector3(-0.44, 0.0, -0.38), -45.0, 1.04],
		["BranchRight", Vector3(0.44, 0.0, -0.38), 45.0, 1.04]
	]
	for d: Array in arm_defs:
		var arm := Node3D.new()
		arm.name = d[0]
		arm.position = d[1]
		arm.rotation_degrees = Vector3(0.0, d[2], 0.0)
		root.add_child(arm)
		var l: float = d[3]
		MeshKit.add_part(arm, "Floor",
			MeshKit.beveled_box(Vector3(0.56, 0.14, l), 0.014, 1, false),
			mat_stone, Vector3(0.0, 0.07, 0.0))
		MeshKit.add_part(arm, "Stream",
			MeshKit.beveled_box(Vector3(0.32, 0.08, l + 0.04), 0.01, 1, false),
			mat_cyan, Vector3(0.0, 0.16, 0.0))
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_part(arm, "Wall_%d" % int(sx),
				MeshKit.beveled_box(Vector3(0.12, 0.22, l), 0.014, 1, false),
				mat_ivory, Vector3(sx * 0.22, 0.18, 0.0))

	MeshKit.add_part(root, "CenterPool",
		MeshKit.beveled_cylinder(0.28, 0.28, 0.18, 12, 0.012, true),
		mat_cyan, Vector3(0.0, 0.12, 0.0))

	return root

# ---------------------------------------------------------------------------
# OBJ12: 정렬 계단 (Ascending 6-Color Algorithm Sorting Staircase)
# ---------------------------------------------------------------------------
static func build_obj12_sort_steps() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ12_sort_steps"

	var mat_stone := MeshKit.mat_color("ss_stone", Color(0.68, 0.66, 0.64), 0.72, 0.04, "stone_ashlar")
	var mat_stone_d := MeshKit.mat_color("ss_stone_d", Color(0.52, 0.50, 0.49), 0.76, 0.04)

	# Stepped Stone Plinth Base
	MeshKit.add_part(root, "PlinthBase",
		MeshKit.beveled_box(Vector3(2.44, 0.18, 1.08), 0.018, 1, false),
		mat_stone_d, Vector3(0.0, 0.09, 0.0))
	MeshKit.add_part(root, "PlinthUpper",
		MeshKit.beveled_box(Vector3(2.28, 0.16, 0.92), 0.016, 1, false),
		mat_stone, Vector3(0.0, 0.26, -0.04))

	# 6 Ascending Colored Bars (Blue, Cyan, Green, Yellow, Orange, Red)
	var colors: Array[Color] = [
		Color(0.18, 0.48, 0.95),
		Color(0.18, 0.80, 0.95),
		Color(0.32, 0.82, 0.24),
		Color(0.96, 0.84, 0.16),
		Color(0.96, 0.52, 0.14),
		Color(0.92, 0.22, 0.20)
	]
	for i in range(6):
		var h := 0.34 + float(i) * 0.22
		var px := -0.88 + float(i) * 0.352
		var m := MeshKit.mat_color("sort_bar_%d" % i, colors[i], 0.30, 0.06)
		var bar := MeshKit.add_part(root, "SortBar_%d" % i,
			MeshKit.beveled_box(Vector3(0.31, h, 0.48), 0.022, 1, false),
			m, Vector3(px, 0.34 + h * 0.5, -0.06))
		bar.set_meta("bar_index", i)

	return root

# ---------------------------------------------------------------------------
# OBJ13: 그래프 노드 (Algorithm Graph Node Pedestal)
# ---------------------------------------------------------------------------
static func build_obj13_graph_node() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ13_graph_node"

	var mat_stone := MeshKit.mat_color("gn_stone", Color(0.68, 0.67, 0.65), 0.72, 0.04)
	var mat_ivory := MeshKit.mat_color("gn_ivory", Color(0.94, 0.90, 0.80), 0.50, 0.04, "stone_ivory")
	var mat_top := MeshKit.mat_color("gn_top", Color(0.96, 0.97, 0.99), 0.32, 0.06)
	var mat_cyan := MeshKit.mat_emissive("gn_cyan", Color(0.22, 0.90, 1.0), Color(0.12, 0.82, 1.0), 2.5, 0.15)

	MeshKit.add_part(root, "OctFoot",
		MeshKit.beveled_cylinder(0.56, 0.52, 0.14, 8, 0.016, false),
		mat_stone, Vector3(0.0, 0.07, 0.0), Vector3(0.0, 22.5, 0.0))
	MeshKit.add_part(root, "CylinderBody",
		MeshKit.beveled_cylinder(0.46, 0.46, 0.48, 24, 0.018, true),
		mat_ivory, Vector3(0.0, 0.38, 0.0))
	MeshKit.add_part(root, "TopCap",
		MeshKit.beveled_cylinder(0.50, 0.48, 0.14, 24, 0.022, true),
		mat_top, Vector3(0.0, 0.68, 0.0))

	# 4 Directional Cyan Connection Sockets
	for i in range(4):
		var a := float(i) * 90.0
		var rad := deg_to_rad(a)
		MeshKit.add_part(root, "SocketFrame_%d" % i,
			MeshKit.beveled_box(Vector3(0.18, 0.18, 0.08), 0.012, 1, false),
			mat_stone, Vector3(sin(rad) * 0.45, 0.38, cos(rad) * 0.45), Vector3(0.0, a, 0.0))
		MeshKit.add_part(root, "SocketGlow_%d" % i,
			MeshKit.beveled_box(Vector3(0.11, 0.11, 0.10), 0.008, 1, false),
			mat_cyan, Vector3(sin(rad) * 0.46, 0.38, cos(rad) * 0.46), Vector3(0.0, a, 0.0))

	return root

# ---------------------------------------------------------------------------
# OBJ14: 그래프 연결선 (Straight Glowing Cyan Graph Edge Module)
# ---------------------------------------------------------------------------
static func build_obj14_graph_edge() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ14_graph_edge"

	var mat_ivory := MeshKit.mat_color("ge_ivory", Color(0.95, 0.90, 0.78), 0.48, 0.06, "stone_ivory")
	var mat_gold := MeshKit.mat_color("ge_gold", Color(0.86, 0.68, 0.32), 0.40, 0.35)
	var mat_cyan := MeshKit.mat_emissive("ge_cyan", Color(0.24, 0.92, 1.0), Color(0.12, 0.84, 1.0), 2.8, 0.12)

	MeshKit.add_part(root, "BeamBar",
		MeshKit.beveled_box(Vector3(1.36, 0.14, 0.16), 0.02, 1, false),
		mat_cyan, Vector3(0.0, 0.20, 0.0))

	for sx: float in [-1.0, 1.0]:
		var tx := sx * 0.68
		MeshKit.add_part(root, "TerminalBody_%d" % int(sx),
			MeshKit.beveled_box(Vector3(0.28, 0.34, 0.32), 0.018, 1, false),
			mat_ivory, Vector3(tx, 0.19, 0.0))
		MeshKit.add_part(root, "TerminalTrim_%d" % int(sx),
			MeshKit.beveled_box(Vector3(0.30, 0.24, 0.24), 0.014, 1, false),
			mat_gold, Vector3(tx, 0.19, 0.0))
		MeshKit.add_part(root, "TerminalCore_%d" % int(sx),
			MeshKit.beveled_box(Vector3(0.32, 0.12, 0.12), 0.01, 1, false),
			mat_cyan, Vector3(tx, 0.19, 0.0))

	return root

# ---------------------------------------------------------------------------
# OBJ15: 미로 정원 (Square Clipped Block Hedge Maze)
# ---------------------------------------------------------------------------
static func build_obj15_maze_garden() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ15_maze_garden"

	var mat_base := MeshKit.mat_color("mz_base", Color(0.38, 0.72, 0.18), 0.58, 0.0)
	var mat_sand := MeshKit.mat_color("mz_sand", Color(0.92, 0.86, 0.70), 0.65, 0.02)
	var mat_hedge_a := MeshKit.mat_color("mz_ha", Color(0.34, 0.74, 0.16), 0.52, 0.0)
	var mat_hedge_b := MeshKit.mat_color("mz_hb", Color(0.50, 0.86, 0.22), 0.48, 0.0)
	var stud := MeshKit.lego_stud(0.065, 0.035, 12)

	MeshKit.add_part(root, "GrassBase",
		MeshKit.beveled_box(Vector3(2.56, 0.10, 2.56), 0.016, 1, false),
		mat_base, Vector3(0.0, 0.05, 0.0))
	MeshKit.add_part(root, "SandFloor",
		MeshKit.beveled_box(Vector3(2.36, 0.06, 2.36), 0.01, 1, false),
		mat_sand, Vector3(0.0, 0.11, 0.0))

	# 7x7 Grid Labyrinth (1 = hedge block, 0 = sandy corridor)
	var grid := [
		[1, 1, 1, 0, 1, 1, 1],
		[1, 0, 0, 0, 1, 0, 1],
		[1, 0, 1, 1, 1, 0, 1],
		[1, 0, 1, 0, 0, 0, 1],
		[1, 0, 1, 0, 1, 1, 1],
		[1, 0, 0, 0, 0, 0, 1],
		[1, 1, 1, 0, 1, 1, 1]
	]
	var cell := 0.33
	for r in range(7):
		for c in range(7):
			if grid[r][c] == 1:
				var px := (float(c) - 3.0) * cell
				var pz := (float(r) - 3.0) * cell
				var m := mat_hedge_a if ((r + c) % 2 == 0) else mat_hedge_b
				var h := 0.34 + float((r * 3 + c) % 2) * 0.04
				MeshKit.add_part(root, "H_%d_%d" % [r, c],
					MeshKit.beveled_box(Vector3(cell + 0.01, h, cell + 0.01), 0.02, 1, false),
					m, Vector3(px, 0.13 + h * 0.5, pz))
				MeshKit.add_part(root, "S_%d_%d" % [r, c],
					stud, m, Vector3(px, 0.13 + h, pz))

	return root

# ---------------------------------------------------------------------------
# OBJ16: 분기 경로 모듈 (Three-Way Y-Fork Stone Footpath)
# ---------------------------------------------------------------------------
static func build_obj16_branch_path() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ16_branch_path"

	var mat_pave := MeshKit.mat_color("bp_pave", Color(0.90, 0.82, 0.66), 0.64, 0.02, "stone_ivory")
	var mat_curb := MeshKit.mat_color("bp_curb", Color(0.66, 0.64, 0.62), 0.72, 0.04, "stone_ashlar")

	var arms := [
		["Stem", Vector3(0.0, 0.0, 0.48), 0.0, 1.00],
		["ForkL", Vector3(-0.42, 0.0, -0.36), -45.0, 1.00],
		["ForkR", Vector3(0.42, 0.0, -0.36), 45.0, 1.00]
	]
	for d: Array in arms:
		var a := Node3D.new()
		a.name = d[0]
		a.position = d[1]
		a.rotation_degrees = Vector3(0.0, d[2], 0.0)
		root.add_child(a)
		var l: float = d[3]
		MeshKit.add_part(a, "Paving",
			MeshKit.beveled_box(Vector3(0.48, 0.08, l), 0.01, 1, false),
			mat_pave, Vector3(0.0, 0.04, 0.0))
		for sx: float in [-1.0, 1.0]:
			MeshKit.add_part(a, "Curb_%d" % int(sx),
				MeshKit.beveled_box(Vector3(0.09, 0.12, l), 0.012, 1, false),
				mat_curb, Vector3(sx * 0.26, 0.06, 0.0))

	MeshKit.add_part(root, "CenterHub",
		MeshKit.beveled_cylinder(0.32, 0.32, 0.085, 12, 0.01, true),
		mat_pave, Vector3(0.0, 0.042, 0.0))

	return root

# ---------------------------------------------------------------------------
# OBJ17 .. OBJ20: 4대 섬 한글 표지판 ("메인 섬", "자료구조 섬", "SQL 섬", "알고리즘 섬")
# ---------------------------------------------------------------------------
static func build_island_sign(id_name: String, label_kr: String) -> Node3D:
	var root := Node3D.new()
	root.name = id_name

	var mat_stone := MeshKit.mat_color("is_stone", Color(0.64, 0.63, 0.62), 0.74, 0.04, "stone_ashlar")
	var mat_post := MeshKit.mat_color("is_post", Color(0.78, 0.54, 0.30), 0.58, 0.0, "wood_oak")
	var mat_frame := MeshKit.mat_color("is_frame", Color(0.84, 0.58, 0.32), 0.54, 0.0, "wood_oak")
	var mat_board := MeshKit.mat_color("is_board", Color(0.46, 0.28, 0.14), 0.66, 0.02, "wood_dark")
	var mat_text := MeshKit.mat_emissive("is_text", Color(0.99, 0.99, 0.97), Color(0.95, 0.95, 0.90), 0.55, 0.25)

	for sx: float in [-1.0, 1.0]:
		var px := sx * 0.46
		MeshKit.add_part(root, "StoneFoot_%d" % int(sx),
			MeshKit.beveled_box(Vector3(0.26, 0.12, 0.26), 0.016, 1, false),
			mat_stone, Vector3(px, 0.06, 0.0))
		MeshKit.add_part(root, "WoodPost_%d" % int(sx),
			MeshKit.beveled_box(Vector3(0.14, 0.96, 0.14), 0.014, 1, false),
			mat_post, Vector3(px, 0.56, 0.0))

	var w := 1.48
	var h := 0.58
	var d := 0.13
	var cy := 0.76
	MeshKit.add_part(root, "BoardFace",
		MeshKit.beveled_box(Vector3(w - 0.12, h - 0.12, d * 0.75), 0.01, 1, false),
		mat_board, Vector3(0.0, cy, 0.0))
	MeshKit.add_part(root, "RailTop",
		MeshKit.beveled_box(Vector3(w, 0.085, d), 0.014, 1, false),
		mat_frame, Vector3(0.0, cy + h * 0.5 - 0.04, 0.0))
	MeshKit.add_part(root, "RailBottom",
		MeshKit.beveled_box(Vector3(w, 0.085, d), 0.014, 1, false),
		mat_frame, Vector3(0.0, cy - h * 0.5 + 0.04, 0.0))
	for sx: float in [-1.0, 1.0]:
		MeshKit.add_part(root, "RailSide_%d" % int(sx),
			MeshKit.beveled_box(Vector3(0.085, h, d), 0.014, 1, false),
			mat_frame, Vector3(sx * (w * 0.5 - 0.04), cy, 0.0))

	var px_sz := 0.0072 if label_kr.length() >= 5 else 0.0088
	MeshKit.add_part(root, "TextKR",
		MeshKit.text_mesh_3d(label_kr, 38, px_sz, 0.052),
		mat_text, Vector3(0.0, cy, d * 0.38 + 0.015))

	return root
