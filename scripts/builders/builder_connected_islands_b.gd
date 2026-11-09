extends RefCounted

const BuilderConnectedIslandsA = preload("res://scripts/builders/builder_connected_islands_a.gd")

## Builds the 12 additional 3D assets OBJ21 .. OBJ32 required for NODEVERSE_연결섬_전체지도.png:
## OBJ21_stack_tower_clean, OBJ22_queue_conveyor_gate, OBJ23_list_black_cube_node,
## OBJ24_list_cyan_beam_link, OBJ25_array_orange_pier, OBJ26_main_wooden_pier,
## OBJ27_cyan_beacon_pillar, OBJ28_stone_flower_planter, OBJ29_sql_query_core_hub,
## OBJ30_sql_gable_roof_hall, OBJ31_grand_arch_bridge_lamps, OBJ32_north_straight_causeway

# ---------------------------------------------------------------------------
# OBJ21: STACK 타워 (상단 화살표형 — 텍스트 간판 없는 클린 버전)
# ---------------------------------------------------------------------------
static func build_obj21_stack_tower_clean() -> Node3D:
	var root := BuilderDataStructs.build_stack_tower()
	root.name = "OBJ21_stack_tower_clean"
	var sign_node := root.get_node_or_null("StackSign")
	if sign_node != null:
		root.remove_child(sign_node)
		sign_node.free()
	return root

# ---------------------------------------------------------------------------
# OBJ22: QUEUE 컨베이어 게이트 일체형
# ---------------------------------------------------------------------------
static func build_obj22_queue_conveyor_gate() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ22_queue_conveyor_gate"

	var mat_chassis := MeshKit.mat_color("qcg_chassis", Color(0.16, 0.17, 0.20), 0.50, 0.48)
	var mat_slat := MeshKit.mat_color("qcg_slat", Color(0.24, 0.25, 0.27), 0.56, 0.28)
	var mat_rail := MeshKit.mat_color("qcg_rail", Color(0.76, 0.78, 0.82), 0.30, 0.72)
	var mat_steel := MeshKit.mat_color("qcg_steel", Color(0.84, 0.86, 0.90), 0.28, 0.68)
	var mat_cyan := MeshKit.mat_emissive("qcg_cyan", Color(0.28, 0.94, 1.0), Color(0.16, 0.86, 1.0), 2.8, 0.14)
	var mat_pad := MeshKit.mat_color("qcg_pad", Color(0.22, 0.28, 0.38), 0.36, 0.24)

	var len_z := 2.68
	var belt_w := 0.78
	var width_x := 0.98

	# Support legs
	for sz: float in [-1.05, 0.0, 1.05]:
		for sx: float in [-0.40, 0.40]:
			MeshKit.add_part(root, "Leg_%d_%d" % [int(sz * 10), int(sx * 10)],
				MeshKit.beveled_box(Vector3(0.12, 0.22, 0.14), 0.012, 1, false),
				mat_rail, Vector3(sx, 0.11, sz))

	# Belt Chassis & Side Rails
	MeshKit.add_part(root, "BeltChassis",
		MeshKit.beveled_box(Vector3(belt_w, 0.20, len_z), 0.014, 1, false),
		mat_chassis, Vector3(0.0, 0.28, 0.0))
	for sx: float in [-1.0, 1.0]:
		MeshKit.add_part(root, "SideRail_%d" % int(sx),
			MeshKit.beveled_box(Vector3(0.10, 0.24, len_z + 0.04), 0.016, 1, false),
			mat_rail, Vector3(sx * (width_x * 0.5 - 0.05), 0.29, 0.0))

	# Belt Slats
	for i in range(14):
		var zp := lerpf(-1.20, 1.20, float(i) / 13.0)
		MeshKit.add_part(root, "Slat_%d" % i,
			MeshKit.beveled_box(Vector3(belt_w - 0.04, 0.035, 0.14), 0.006, 1, false),
			mat_slat, Vector3(0.0, 0.39, zp))

	# Entry & Exit Glowing Arrow Pads
	for sz: float in [-1.06, 1.06]:
		MeshKit.add_part(root, "ArrowPad_%d" % int(sz * 10),
			MeshKit.beveled_box(Vector3(0.46, 0.04, 0.42), 0.008, 1, false),
			mat_pad, Vector3(0.0, 0.41, sz))
		MeshKit.add_part(root, "ArrowGlow_%d" % int(sz * 10),
			MeshKit.beveled_box(Vector3(0.26, 0.05, 0.24), 0.006, 1, false),
			mat_cyan, Vector3(0.0, 0.415, sz))

	# Central Steel Gantry Gate Arch
	for sx: float in [-1.0, 1.0]:
		MeshKit.add_part(root, "GatePillar_%d" % int(sx),
			MeshKit.beveled_box(Vector3(0.16, 1.18, 0.24), 0.018, 1, false),
			mat_steel, Vector3(sx * 0.56, 0.62, -0.08))
	MeshKit.add_part(root, "GateHeader",
		MeshKit.beveled_box(Vector3(1.28, 0.18, 0.26), 0.018, 1, false),
		mat_steel, Vector3(0.0, 1.24, -0.08))
	MeshKit.add_part(root, "GateScannerStrip",
		MeshKit.beveled_box(Vector3(0.92, 0.04, 0.08), 0.008, 1, false),
		mat_cyan, Vector3(0.0, 1.14, 0.04))

	# 3 Golden Crates riding the belt
	for c_idx in range(3):
		var cr := BuilderCharsProps.build_crate("gold_top")
		cr.name = "QueueCrate_%d" % c_idx
		cr.scale = Vector3(0.68, 0.68, 0.68)
		cr.position = Vector3(0.0, 0.40, -0.58 + float(c_idx) * 0.58)
		root.add_child(cr)

	return root

# ---------------------------------------------------------------------------
# OBJ23: LIST 블랙 큐브 노드 (숫자 없는 다크 메탈릭 + 시안 포트 큐브)
# ---------------------------------------------------------------------------
static func build_obj23_list_black_cube_node() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ23_list_black_cube_node"

	var mat_stone := MeshKit.mat_color("lbn_stone", Color(0.66, 0.65, 0.64), 0.72, 0.04, "stone_ashlar")
	var mat_body := MeshKit.mat_color("lbn_body", Color(0.11, 0.13, 0.17), 0.30, 0.58)
	var mat_dark := MeshKit.mat_color("lbn_dark", Color(0.05, 0.06, 0.08), 0.48, 0.45)
	var mat_cyan := MeshKit.mat_emissive("lbn_cyan", Color(0.20, 0.90, 1.0), Color(0.10, 0.82, 1.0), 2.8, 0.12)

	# Stepped Stone Plinth
	MeshKit.add_part(root, "StonePlinth",
		MeshKit.beveled_box(Vector3(0.96, 0.14, 0.96), 0.016, 1, false),
		mat_stone, Vector3(0.0, 0.07, 0.0))

	# Main Matte Black Bevelled Cube
	MeshKit.add_part(root, "BlackCube",
		MeshKit.beveled_box(Vector3(0.80, 0.76, 0.80), 0.032, 2, false),
		mat_body, Vector3(0.0, 0.51, 0.0))

	# 4 Side Glowing Cyan Square Frame Sockets
	for i in range(4):
		var a := float(i) * 90.0
		var rad := deg_to_rad(a)
		var sock := Node3D.new()
		sock.name = "CyanSocket_%d" % i
		sock.position = Vector3(sin(rad) * 0.40, 0.51, cos(rad) * 0.40)
		sock.rotation_degrees = Vector3(0.0, a, 0.0)
		root.add_child(sock)
		MeshKit.add_part(sock, "OuterGlowRing",
			MeshKit.beveled_box(Vector3(0.36, 0.36, 0.04), 0.01, 1, false),
			mat_cyan, Vector3.ZERO)
		MeshKit.add_part(sock, "InnerRecess",
			MeshKit.beveled_box(Vector3(0.24, 0.24, 0.05), 0.008, 1, false),
			mat_dark, Vector3(0.0, 0.0, 0.004))

	return root

# ---------------------------------------------------------------------------
# OBJ24: LIST 시안 광선 링크
# ---------------------------------------------------------------------------
static func build_obj24_list_cyan_beam_link() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ24_list_cyan_beam_link"

	var mat_collar := MeshKit.mat_color("lbl_collar", Color(0.88, 0.87, 0.85), 0.38, 0.25)
	var mat_dark := MeshKit.mat_color("lbl_dark", Color(0.14, 0.16, 0.20), 0.45, 0.55)
	var mat_cyan := MeshKit.mat_emissive("lbl_cyan", Color(0.24, 0.94, 1.0), Color(0.12, 0.86, 1.0), 3.0, 0.10)

	MeshKit.add_part(root, "EnergyBeam",
		MeshKit.beveled_box(Vector3(1.24, 0.16, 0.18), 0.022, 1, false),
		mat_cyan, Vector3(0.0, 0.22, 0.0))

	for sx: float in [-1.0, 1.0]:
		var cx := sx * 0.62
		MeshKit.add_part(root, "CollarWhite_%d" % int(sx),
			MeshKit.beveled_box(Vector3(0.22, 0.30, 0.30), 0.018, 1, false),
			mat_collar, Vector3(cx, 0.22, 0.0))
		MeshKit.add_part(root, "CollarBand_%d" % int(sx),
			MeshKit.beveled_box(Vector3(0.10, 0.32, 0.32), 0.014, 1, false),
			mat_dark, Vector3(cx - sx * 0.06, 0.22, 0.0))
		MeshKit.add_part(root, "SocketCore_%d" % int(sx),
			MeshKit.beveled_box(Vector3(0.24, 0.14, 0.14), 0.01, 1, false),
			mat_cyan, Vector3(cx, 0.22, 0.0))

	MeshKit.add_light(root, "BeamLight", Color(0.20, 0.90, 1.0), 0.8, 2.2, Vector3(0.0, 0.24, 0.0))
	return root

# ---------------------------------------------------------------------------
# OBJ25: ARRAY 오렌지 블록 부두 (5개 정렬 오렌지/골드 블록 + 목재 데크)
# ---------------------------------------------------------------------------
static func build_obj25_array_orange_pier() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ25_array_orange_pier"

	var mat_plank := MeshKit.mat_color("aop_plank", Color(0.88, 0.64, 0.36), 0.56, 0.0, "wood_oak")
	var mat_post := MeshKit.mat_color("aop_post", Color(0.62, 0.40, 0.20), 0.64, 0.0, "wood_brown")
	var mat_orange := MeshKit.mat_color("aop_orange", Color(0.98, 0.66, 0.16), 0.34, 0.06)

	var len_z := 3.60
	var wid_x := 1.16
	var deck_y := 0.36

	# 12 Wooden Planks along Z
	var plank_cnt := 16
	var pz_s := len_z / float(plank_cnt)
	for i in range(plank_cnt):
		var zp := -len_z * 0.5 + (float(i) + 0.5) * pz_s
		MeshKit.add_part(root, "Plank_%d" % i,
			MeshKit.beveled_box(Vector3(wid_x, 0.08, pz_s - 0.018), 0.01, 1, false),
			mat_plank, Vector3(0.0, deck_y, zp))

	# Support Beams & 10 Timber Posts
	for sx: float in [-0.46, 0.46]:
		MeshKit.add_part(root, "SideBeam_%d" % int(sx * 10),
			MeshKit.beveled_box(Vector3(0.10, 0.10, len_z - 0.10), 0.01, 1, false),
			mat_post, Vector3(sx, deck_y - 0.08, 0.0))
		for iz in range(5):
			var zp := lerpf(-len_z * 0.44, len_z * 0.44, float(iz) / 4.0)
			MeshKit.add_part(root, "Post_%d_%d" % [int(sx * 10), iz],
				MeshKit.beveled_box(Vector3(0.14, deck_y + 0.06, 0.14), 0.012, 1, false),
				mat_post, Vector3(sx, (deck_y + 0.06) * 0.5, zp))

	# 5 Vivid Orange Array Blocks (named Tile_0..Tile_4 so interactive pressing works!)
	for i in range(5):
		var tile := Node3D.new()
		tile.name = "Tile_%d" % i
		var zp := 1.28 - float(i) * 0.64
		tile.position = Vector3(0.0, deck_y + 0.04, zp)
		root.add_child(tile)
		MeshKit.add_part(tile, "OrangeCube",
			MeshKit.beveled_box(Vector3(0.54, 0.34, 0.52), 0.026, 1, false),
			mat_orange, Vector3(0.0, 0.17, 0.0))

	return root

# ---------------------------------------------------------------------------
# OBJ26: 메인 섬 T자형 목재 선착장
# ---------------------------------------------------------------------------
static func build_obj26_main_wooden_pier() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ26_main_wooden_pier"

	var mat_plank := MeshKit.mat_color("mwp_plank", Color(0.86, 0.60, 0.34), 0.56, 0.0, "wood_oak")
	var mat_post := MeshKit.mat_color("mwp_post", Color(0.58, 0.36, 0.18), 0.64, 0.0, "wood_brown")
	var mat_iron := MeshKit.mat_color("mwp_iron", Color(0.36, 0.38, 0.42), 0.48, 0.55)

	# Transverse Main Deck (along X)
	MeshKit.add_part(root, "MainDeck",
		MeshKit.beveled_box(Vector3(2.80, 0.10, 1.24), 0.014, 1, false),
		mat_plank, Vector3(0.0, 0.42, -0.36))
	# Forward Boarding Jetty Ramp (along +Z)
	MeshKit.add_part(root, "FrontJetty",
		MeshKit.beveled_box(Vector3(1.06, 0.10, 1.44), 0.014, 1, false),
		mat_plank, Vector3(-0.36, 0.34, 0.88), Vector3(6.0, 0.0, 0.0))

	# Side Guard Rails on Jetty
	for sx: float in [-0.84, 0.12]:
		MeshKit.add_part(root, "JettyRail_%d" % int(sx * 10),
			MeshKit.beveled_box(Vector3(0.08, 0.08, 1.38), 0.01, 1, false),
			mat_post, Vector3(sx, 0.46, 0.88), Vector3(6.0, 0.0, 0.0))

	# Support Pilings & Mooring Bollards
	var post_pts: Array[Vector3] = [
		Vector3(-1.32, 0.0, -0.90), Vector3(0.0, 0.0, -0.90), Vector3(1.32, 0.0, -0.90),
		Vector3(-1.32, 0.0, 0.18), Vector3(1.32, 0.0, 0.18),
		Vector3(-0.84, 0.0, 1.52), Vector3(0.12, 0.0, 1.52)
	]
	for idx in range(post_pts.size()):
		var pt := post_pts[idx]
		MeshKit.add_part(root, "Piling_%d" % idx,
			MeshKit.beveled_box(Vector3(0.16, 0.62, 0.16), 0.014, 1, false),
			mat_post, Vector3(pt.x, 0.31, pt.z))

	# Grey Barrel + Stacked Wooden Crates on Deck
	MeshKit.add_part(root, "Barrel",
		MeshKit.beveled_cylinder(0.16, 0.16, 0.34, 14, 0.015, true),
		mat_iron, Vector3(-0.62, 0.64, -0.66))
	var c1 := BuilderCharsProps.build_crate("brown")
	c1.scale = Vector3(0.52, 0.52, 0.52)
	c1.position = Vector3(0.88, 0.47, -0.52)
	root.add_child(c1)
	var c2 := BuilderCharsProps.build_crate("gold_top")
	c2.scale = Vector3(0.46, 0.46, 0.46)
	c2.position = Vector3(0.92, 0.81, -0.50)
	root.add_child(c2)

	return root

# ---------------------------------------------------------------------------
# OBJ27: 시안 크리스탈 등불 기둥 (Cyan Beacon Pillar)
# ---------------------------------------------------------------------------
static func build_obj27_cyan_beacon_pillar() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ27_cyan_beacon_pillar"

	var mat_stone := MeshKit.mat_color("cbp_stone", Color(0.84, 0.84, 0.86), 0.62, 0.05, "stone_ashlar")
	var mat_stone_d := MeshKit.mat_color("cbp_stone_d", Color(0.68, 0.69, 0.72), 0.68, 0.06)
	var mat_cyan := MeshKit.mat_emissive("cbp_cyan", Color(0.24, 0.94, 1.0), Color(0.12, 0.86, 1.0), 3.0, 0.12)

	MeshKit.add_part(root, "BasePlinth",
		MeshKit.beveled_box(Vector3(0.68, 0.18, 0.68), 0.018, 1, false),
		mat_stone_d, Vector3(0.0, 0.09, 0.0))
	MeshKit.add_part(root, "BaseStep",
		MeshKit.beveled_box(Vector3(0.56, 0.14, 0.56), 0.016, 1, false),
		mat_stone, Vector3(0.0, 0.25, 0.0))

	# Glowing Cyan Crystal Core Cube
	MeshKit.add_part(root, "CyanCore",
		MeshKit.beveled_box(Vector3(0.38, 0.42, 0.38), 0.02, 1, false),
		mat_cyan, Vector3(0.0, 0.53, 0.0))

	# 4 Corner Stone Struts
	for sx: float in [-0.22, 0.22]:
		for sz: float in [-0.22, 0.22]:
			MeshKit.add_part(root, "CornerStrut_%d_%d" % [int(sx * 10), int(sz * 10)],
				MeshKit.beveled_box(Vector3(0.11, 0.44, 0.11), 0.012, 1, false),
				mat_stone_d, Vector3(sx, 0.53, sz))

	# Top Stone Cap
	MeshKit.add_part(root, "TopNeck",
		MeshKit.beveled_box(Vector3(0.56, 0.12, 0.56), 0.014, 1, false),
		mat_stone_d, Vector3(0.0, 0.80, 0.0))
	MeshKit.add_part(root, "TopCap",
		MeshKit.beveled_box(Vector3(0.64, 0.16, 0.64), 0.02, 1, false),
		mat_stone, Vector3(0.0, 0.94, 0.0))

	MeshKit.add_light(root, "PillarLight", Color(0.20, 0.90, 1.0), 0.85, 2.6, Vector3(0.0, 0.55, 0.0))
	return root

# ---------------------------------------------------------------------------
# OBJ28: 돌 화단 (꽃 정원 블록 — Stone Flower Planter)
# ---------------------------------------------------------------------------
static func build_obj28_stone_flower_planter() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ28_stone_flower_planter"

	var mat_stone := MeshKit.mat_color("sfp_stone", Color(0.76, 0.75, 0.74), 0.70, 0.04, "stone_ashlar")
	var mat_leaf_a := MeshKit.mat_color("sfp_la", Color(0.34, 0.74, 0.16), 0.52, 0.0)
	var mat_leaf_b := MeshKit.mat_color("sfp_lb", Color(0.48, 0.84, 0.20), 0.48, 0.0)
	var mat_white := MeshKit.mat_color("sfp_fw", Color(0.98, 0.98, 0.95), 0.35, 0.0)
	var mat_yellow := MeshKit.mat_emissive("sfp_fy", Color(1.0, 0.88, 0.22), Color(1.0, 0.80, 0.15), 0.8, 0.3)

	MeshKit.add_part(root, "StoneCurb",
		MeshKit.beveled_box(Vector3(1.42, 0.18, 1.42), 0.02, 1, false),
		mat_stone, Vector3(0.0, 0.09, 0.0))

	# 3x3 Grid of Bush Blocks + Blossoms
	for r in range(3):
		for c in range(3):
			var px := (float(c) - 1.0) * 0.38
			var pz := (float(r) - 1.0) * 0.38
			var m := mat_leaf_a if ((r + c) % 2 == 0) else mat_leaf_b
			MeshKit.add_part(root, "Bush_%d_%d" % [r, c],
				MeshKit.beveled_box(Vector3(0.36, 0.24, 0.36), 0.024, 1, false),
				m, Vector3(px, 0.28, pz))
			# Little flower on top
			var fm := mat_white if ((r * 3 + c) % 2 == 0) else mat_yellow
			MeshKit.add_part(root, "Flower_%d_%d" % [r, c],
				MeshKit.beveled_cylinder(0.065, 0.065, 0.04, 8, 0.008, true),
				fm, Vector3(px, 0.41, pz))

	return root

# ---------------------------------------------------------------------------
# OBJ29: SQL 쿼리 코어 허브 (SQL Query Core Hub)
# ---------------------------------------------------------------------------
static func build_obj29_sql_query_core_hub() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ29_sql_query_core_hub"

	var mat_stone := MeshKit.mat_color("qch_stone", Color(0.76, 0.75, 0.73), 0.68, 0.04, "stone_ashlar")
	var mat_ivory := MeshKit.mat_color("qch_ivory", Color(0.95, 0.92, 0.84), 0.52, 0.04, "stone_ivory")
	var mat_cyan := MeshKit.mat_emissive("qch_cyan", Color(0.22, 0.92, 1.0), Color(0.10, 0.84, 1.0), 2.8, 0.12)
	var mat_cyan_bright := MeshKit.mat_emissive("qch_cyan_b", Color(0.65, 0.98, 1.0), Color(0.38, 0.94, 1.0), 3.4, 0.08)

	MeshKit.add_part(root, "BaseStep1",
		MeshKit.beveled_box(Vector3(1.36, 0.16, 1.36), 0.018, 1, false),
		mat_stone, Vector3(0.0, 0.08, 0.0))
	MeshKit.add_part(root, "BaseStep2",
		MeshKit.beveled_box(Vector3(1.10, 0.16, 1.10), 0.016, 1, false),
		mat_ivory, Vector3(0.0, 0.24, 0.0))

	# Glowing Cyan Core Cube + Inner Energy Nucleus
	MeshKit.add_part(root, "CoreCube",
		MeshKit.beveled_box(Vector3(0.74, 0.68, 0.74), 0.03, 2, false),
		mat_cyan, Vector3(0.0, 0.66, 0.0))
	MeshKit.add_part(root, "InnerNucleus",
		MeshKit.beveled_box(Vector3(0.46, 0.42, 0.46), 0.02, 1, false),
		mat_cyan_bright, Vector3(0.0, 0.66, 0.0))

	# 4 Corner Ivory Stone Clamps
	for sx: float in [-0.44, 0.44]:
		for sz: float in [-0.44, 0.44]:
			MeshKit.add_part(root, "Clamp_%d_%d" % [int(sx * 10), int(sz * 10)],
				MeshKit.beveled_box(Vector3(0.16, 0.22, 0.16), 0.014, 1, false),
				mat_ivory, Vector3(sx, 0.40, sz))

	MeshKit.add_light(root, "CoreHubLight", Color(0.20, 0.90, 1.0), 1.4, 4.0, Vector3(0.0, 0.75, 0.0))
	return root

# ---------------------------------------------------------------------------
# OBJ30: SQL 박공지붕 기록관 (SQL Gable Roof Hall)
# ---------------------------------------------------------------------------
static func build_obj30_sql_gable_roof_hall() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ30_sql_gable_roof_hall"

	var mat_stone := MeshKit.mat_color("sgh_stone", Color(0.74, 0.73, 0.71), 0.70, 0.04, "stone_ashlar")
	var mat_ivory := MeshKit.mat_color("sgh_ivory", Color(0.96, 0.92, 0.83), 0.54, 0.03, "stone_ivory")
	var mat_roof := MeshKit.mat_color("sgh_roof", Color(0.20, 0.48, 0.92), 0.44, 0.06, "roof_blue")
	var mat_door := MeshKit.mat_color("sgh_door", Color(0.56, 0.36, 0.18), 0.58, 0.0, "wood_brown")

	MeshKit.add_part(root, "Plinth",
		MeshKit.beveled_box(Vector3(1.68, 0.20, 1.62), 0.02, 1, false),
		mat_stone, Vector3(0.0, 0.10, 0.0))
	MeshKit.add_part(root, "Walls",
		MeshKit.beveled_box(Vector3(1.52, 1.24, 1.46), 0.02, 1, false),
		mat_ivory, Vector3(0.0, 0.82, 0.0))
	MeshKit.add_part(root, "MidBelt",
		MeshKit.beveled_box(Vector3(1.58, 0.08, 1.52), 0.012, 1, false),
		mat_stone, Vector3(0.0, 0.84, 0.0))

	BuilderConnectedIslandsA._add_gable_roof(root, "GableRoof", Vector3(0.0, 1.44, 0.0), 1.60, 0.60, 1.56, mat_roof, mat_ivory, mat_stone, false)

	MeshKit.add_part(root, "DoorArch",
		MeshKit.beveled_box(Vector3(0.52, 0.66, 0.12), 0.016, 1, false),
		mat_stone, Vector3(0.0, 0.52, 0.73))
	MeshKit.add_part(root, "DoorWood",
		MeshKit.beveled_box(Vector3(0.38, 0.56, 0.14), 0.012, 1, false),
		mat_door, Vector3(0.0, 0.48, 0.74))

	BuilderConnectedIslandsA._add_warm_window(root, "WinFL", Vector3(-0.42, 1.12, 0.73), 0.0, 0.24, 0.28)
	BuilderConnectedIslandsA._add_warm_window(root, "WinFR", Vector3(0.42, 1.12, 0.73), 0.0, 0.24, 0.28)
	BuilderConnectedIslandsA._add_warm_window(root, "WinR1", Vector3(0.76, 0.54, -0.32), 90.0, 0.26, 0.30)
	BuilderConnectedIslandsA._add_warm_window(root, "WinR2", Vector3(0.76, 0.54, 0.32), 90.0, 0.26, 0.30)
	BuilderConnectedIslandsA._add_warm_window(root, "WinR3", Vector3(0.76, 1.12, -0.32), 90.0, 0.26, 0.30)
	BuilderConnectedIslandsA._add_warm_window(root, "WinR4", Vector3(0.76, 1.12, 0.32), 90.0, 0.26, 0.30)

	return root

# ---------------------------------------------------------------------------
# OBJ31: 가로등 아치형 대교 (Grand Arch Bridge with 4 Lamps)
# ---------------------------------------------------------------------------
static func build_obj31_grand_arch_bridge_lamps() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ31_grand_arch_bridge_lamps"

	var base_bridge := BuilderStructures.build_bridge(false)
	base_bridge.name = "ArchCore"
	base_bridge.scale = Vector3(1.25, 1.05, 1.15)
	root.add_child(base_bridge)

	# 4 Corner Wrought-Iron Street Lamps on Bridge Piers
	for sx: float in [-1.05, 1.05]:
		for sz: float in [-0.68, 0.68]:
			var lmp := BuilderCharsProps.build_lamp()
			lmp.name = "BridgeLamp_%d_%d" % [int(sx * 10), int(sz * 10)]
			lmp.scale = Vector3(0.48, 0.48, 0.48)
			lmp.position = Vector3(sx, 0.96, sz)
			root.add_child(lmp)

	return root

# ---------------------------------------------------------------------------
# OBJ32: 북쪽 직선 석조 대교 (비콘형 — North Straight Causeway Bridge)
# ---------------------------------------------------------------------------
static func build_obj32_north_straight_causeway() -> Node3D:
	var root := Node3D.new()
	root.name = "OBJ32_north_straight_causeway"

	var mat_stone := MeshKit.mat_color("nsc_stone", Color(0.76, 0.74, 0.72), 0.72, 0.04, "stone_ashlar")
	var mat_pave := MeshKit.mat_color("nsc_pave", Color(0.92, 0.85, 0.72), 0.62, 0.02, "stone_ivory")

	var len_z := 2.80
	var wid_x := 1.56
	var deck_h := 0.56

	MeshKit.add_part(root, "BridgeBody",
		MeshKit.beveled_box(Vector3(wid_x, deck_h, len_z), 0.02, 1, false),
		mat_stone, Vector3(0.0, deck_h * 0.5, 0.0))
	MeshKit.add_part(root, "PavedDeck",
		MeshKit.beveled_box(Vector3(wid_x - 0.28, 0.06, len_z - 0.08), 0.01, 1, false),
		mat_pave, Vector3(0.0, deck_h + 0.02, 0.0))

	# Parapet curbs + 4 Mini Cyan Beacon Pillars
	for sx: float in [-1.0, 1.0]:
		var rx := sx * (wid_x * 0.5 - 0.09)
		MeshKit.add_part(root, "Parapet_%d" % int(sx),
			MeshKit.beveled_box(Vector3(0.16, 0.18, len_z), 0.014, 1, false),
			mat_stone, Vector3(rx, deck_h + 0.09, 0.0))
		for sz: float in [-0.88, 0.88]:
			var bp := build_obj27_cyan_beacon_pillar()
			bp.name = "CausewayBeacon_%d_%d" % [int(sx), int(sz * 10)]
			bp.scale = Vector3(0.36, 0.36, 0.36)
			bp.position = Vector3(rx, deck_h + 0.16, sz)
			root.add_child(bp)

	return root
