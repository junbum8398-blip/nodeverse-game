extends SceneTree
## Independent, editable solid-geometry SD NPCs. Front is +Z.
const IDS = ["NPC00_hub_guide", "NPC01_array_keeper", "NPC02_link_engineer", "NPC03_restore_artisan", "NPC04_receptionist", "NPC05_registry_clerk", "NPC06_tree_archivist", "NPC07_bst_warden", "NPC08_priority_dispatcher", "NPC09_graph_surveyor"]
const COATS = ["263e70", "4166a0", "657334", "762d3b", "293d63", "be8c32", "255b46", "617035", "df7028", "247d79"]
const HAIRS = ["633b2d", "75472e", "be581f", "d7d9df", "302b30", "30282a", "bfc0c9", "c79740", "3d2930", "453025"]
var actor_root: Node3D
var index: int
var skin = Color("f2bd91")
var gold = Color("dba84c")
var brown = Color("68452e")

func _init():
	call_deferred("build_all")

func pivot(parent: Node3D, title: String, pos: Vector3) -> Node3D:
	var n = Node3D.new()
	n.name = title
	n.position = pos
	parent.add_child(n)
	n.owner = actor_root
	return n

func rounded_box(size: Vector3, material: Material) -> ArrayMesh:
	var h = size * 0.5
	var bevel = minf(0.025, minf(size.x, minf(size.y, size.z)) * 0.18)
	var inner = h - Vector3.ONE * bevel
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		var u = (axis + 1) % 3
		var v = (axis + 2) % 3
		for sign_value in [-1.0, 1.0]:
			var us = [-h[u], -inner[u], inner[u], h[u]]
			var vs = [-h[v], -inner[v], inner[v], h[v]]
			for a in 3:
				for b in 3:
					var corners = [Vector2i(a,b),Vector2i(a+1,b),Vector2i(a+1,b+1),Vector2i(a,b+1)]
					var order = [0,2,1,0,3,2] if sign_value > 0 else [0,1,2,0,2,3]
					for k in order:
						var p = Vector3.ZERO
						p[axis] = h[axis] * sign_value
						p[u] = us[corners[k].x]
						p[v] = vs[corners[k].y]
						var nearest = p.clamp(-inner, inner)
						var normal = (p-nearest).normalized()
						st.set_normal(normal)
						st.add_vertex(nearest + normal * bevel)
	st.set_material(material)
	return st.commit()

func box(parent: Node3D, title: String, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	n.name = title
	n.position = pos
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	n.mesh = rounded_box(size, mat)
	parent.add_child(n)
	n.owner = actor_root
	return n

func book(parent: Node3D, color: Color):
	box(parent, "BookPages", Vector3(0, -0.1, 0.13), Vector3(0.17, 0.22, 0.06), Color("eee0bc"))
	for z in [0.09, 0.17]:
		box(parent, "BookCover", Vector3(0,-0.1,z),Vector3(0.19,0.24,0.018),color)
	box(parent,"BookSpine",Vector3(-0.09,-0.1,0.13),Vector3(0.025,0.24,0.09),color)

func glasses(head: Node3D):
	for x in [-0.145, 0.145]:
		for y in [0.20, 0.34]:
			box(head,"GlassRim",Vector3(x,y,0.278),Vector3(0.21,0.025,0.028),gold if index != 5 else brown)
		for dx in [-0.10,0.10]:
			box(head,"GlassRim",Vector3(x+dx,0.27,0.278),Vector3(0.025,0.14,0.028),gold if index != 5 else brown)
	box(head,"Bridge",Vector3(0,0.28,0.285),Vector3(0.08,0.025,0.025),gold)

func character():
	var coat = Color(COATS[index])
	var hair = Color(HAIRS[index])
	var model = pivot(actor_root,"Model",Vector3.ZERO)
	var hips = pivot(model,"Hips",Vector3(0,0.25,0))
	for s in [-1,1]:
		var leg = pivot(hips,"LegL" if s<0 else "LegR",Vector3(s*0.105,0,0))
		box(leg,"Trousers",Vector3(0,-0.08,0),Vector3(0.16,0.18,0.18),Color("434348") if index<6 else brown)
		box(leg,"Boot",Vector3(0,-0.20,0.035),Vector3(0.19,0.10,0.27),brown)
		box(leg,"Sole",Vector3(0,-0.245,0.035),Vector3(0.20,0.025,0.28),Color("3c3030"))
		box(leg,"Buckle",Vector3(0,-0.17,0.177),Vector3(0.065,0.045,0.018),gold)
	var torso = pivot(hips,"Torso",Vector3.ZERO)
	box(torso,"Jacket",Vector3(0,0.18,0),Vector3(0.37,0.36,0.26),coat)
	box(torso,"Shirt",Vector3(0,0.21,0.139),Vector3(0.13,0.29,0.018),Color("f1e3c2"))
	for s in [-1,1]:
		box(torso,"Collar",Vector3(s*0.075,0.32,0.16),Vector3(0.11,0.065,0.04),Color("f1e3c2")).rotation.z=s*0.35
	box(torso,"Belt",Vector3(0,0.06,0.01),Vector3(0.39,0.055,0.28),brown)
	box(torso,"BeltBuckle",Vector3(0,0.06,0.16),Vector3(0.075,0.06,0.025),gold)
	if index==0:
		for s in [-1,1]:
			box(torso,"TealLapel",Vector3(s*0.125,0.22,0.16),Vector3(0.055,0.27,0.025),Color("278f92"))
			box(torso,"GoldTrim",Vector3(s*0.16,0.02,0.175),Vector3(0.02,0.27,0.02),gold)
		box(torso,"GuideBrooch",Vector3(0.12,0.31,0.19),Vector3(0.055,0.055,0.025),Color("39b7d0"))
	if index in [2,8,9]:
		for s in [-1,1]:
			box(torso,"JacketPocket",Vector3(s*0.12,0.22,0.16),Vector3(0.10,0.09,0.035),coat.lightened(0.09))
			box(torso,"PocketClasp",Vector3(s*0.12,0.24,0.184),Vector3(0.035,0.025,0.015),gold)
	if index in [7,8]:
		var watch=box(torso,"Compass" if index==7 else "PocketWatch",Vector3(0.12,0.10,0.19),Vector3(0.095,0.095,0.04),gold)
		watch.rotation.z=0.2
		box(torso,"Dial",Vector3(0.12,0.10,0.218),Vector3(0.065,0.065,0.015),Color("eee0bc"))
	if index==9:
		box(torso,"Satchel",Vector3(-0.19,0.02,0.14),Vector3(0.17,0.15,0.09),brown)
		box(torso,"SatchelStrap",Vector3(0,0.20,0.185),Vector3(0.035,0.42,0.025),brown).rotation.z=-0.65
	if index in [0,4,6]:
		box(torso,"Skirt",Vector3(0,-0.015,0),Vector3(0.43,0.17,0.30),Color("e9dab8") if index==4 else coat)
	if index in [1,3,5]:
		box(torso,"Apron",Vector3(0,0.12,0.155),Vector3(0.32,0.35,0.035),brown)
		box(torso,"ApronPocket",Vector3(0,0.10,0.184),Vector3(0.19,0.09,0.025),brown.lightened(0.12))
	if index==2:
		box(torso,"OverallBib",Vector3(0,0.20,0.16),Vector3(0.25,0.22,0.04),coat)
	if index in [4,6]:
		box(torso,"Scarf",Vector3(0,0.34,0.06),Vector3(0.40,0.075,0.31),Color("75b6e2") if index==4 else Color("303e72"))
	for s in [-1,1]:
		var arm = pivot(torso,"ArmL" if s<0 else "ArmR",Vector3(s*0.245,0.29,0))
		arm.rotation.z=s*0.16
		box(arm,"Sleeve",Vector3(0,-0.07,0),Vector3(0.15,0.21,0.17),Color("eee0c4") if index in [2,3,7] else coat)
		box(arm,"Hand",Vector3(0,-0.22,0.02),Vector3(0.14,0.13,0.15),skin)
		if s==1:
			if index in [0,5,6,7]: book(arm,Color("4a5284") if index!=5 else Color("674169"))
			if index in [2,3,9]:
				box(arm,"ToolHandle",Vector3(0,-0.10,0.15),Vector3(0.04,0.40,0.04),brown)
				if index==3: box(arm,"Mallet",Vector3(0,0.10,0.15),Vector3(0.24,0.11,0.11),gold)
				if index==2:
					for dx in [-0.055,0.055]: box(arm,"WrenchJaw",Vector3(dx,0.10,0.15),Vector3(0.04,0.12,0.07),gold)
				if index==9: box(arm,"SurveyFlag",Vector3(0.09,0.08,0.15),Vector3(0.18,0.12,0.02),Color("19a9df"))
			if index in [4,8]: box(arm,"Card" if index==4 else "PriorityBlock",Vector3(0,-0.08,0.16),Vector3(0.12,0.15,0.045),Color.WHITE if index==4 else Color("d93336"))
	if index==1:
		box(torso,"Crate",Vector3(0,0.10,0.35),Vector3(0.40,0.22,0.27),Color("a76c35"))
		for x in [-0.16,0.16]: box(torso,"CrateBand",Vector3(x,0.10,0.49),Vector3(0.035,0.23,0.025),gold)
	var head = pivot(torso,"Head",Vector3(0,0.36,0))
	box(head,"Face",Vector3(0,0.26,0),Vector3(0.58,0.51,0.49),skin)
	box(head,"HairBack",Vector3(0,0.30,-0.19),Vector3(0.65,0.56,0.20),hair)
	for s in [-1,1]:
		box(head,"Ear",Vector3(s*0.31,0.24,0),Vector3(0.09,0.12,0.12),skin)
		box(head,"Eye",Vector3(s*0.14,0.27,0.253),Vector3(0.065,0.105,0.018),Color("352821"))
		box(head,"EyeGlint",Vector3(s*0.14-0.012,0.30,0.265),Vector3(0.023,0.032,0.01),Color.WHITE)
		box(head,"Brow",Vector3(s*0.14,0.36,0.255),Vector3(0.10,0.025,0.025),hair)
		box(head,"Blush",Vector3(s*0.21,0.16,0.253),Vector3(0.065,0.028,0.014),Color("e89b82"))
	box(head,"Smile",Vector3(0,0.12,0.255),Vector3(0.085,0.035,0.018),Color("9e4f3b"))
	for x in range(-2,3):
		var lock = box(head,"HairLock",Vector3(x*0.125,0.51+0.025*(2-absi(x)),0.02),Vector3(0.18,0.15,0.53),hair.lightened(0.025*absi(x)))
		lock.rotation.z=x*0.08
	box(head,"Fringe",Vector3(-0.14,0.42,0.245),Vector3(0.29,0.16,0.08),hair).rotation.z=-0.15
	if index in [0,4,6,9]:
		for s in [-1,1]:
			box(head,"SideHair",Vector3(s*0.29,0.32,0.08),Vector3(0.11,0.30,0.33),hair)
	if index in [0,4,9]:
		for s in [-1,1]: box(head,"Earring",Vector3(s*0.32,0.16,0.08),Vector3(0.045,0.055,0.035),gold)
	if index in [3,5,6]: glasses(head)
	if index==3:
		box(head,"Beard",Vector3(0,0.04,0.25),Vector3(0.36,0.12,0.09),hair)
		box(head,"Moustache",Vector3(0,0.16,0.28),Vector3(0.24,0.04,0.04),hair)
	if index in [2,8,9]:
		for y in [0.39,0.23,0.07]: box(head,"Ponytail",Vector3(0.26,y,-0.34),Vector3(0.20,0.20,0.22),hair)
	if index==6: box(head,"HairBun",Vector3(0.12,0.58,-0.22),Vector3(0.28,0.23,0.26),hair)
	if index==0:
		for x in [0.29,0.40]: box(head,"TealBow",Vector3(x,0.44,-0.04),Vector3(0.13,0.13,0.09),Color("278f92")).rotation.z=0.5
	if index==2:
		box(head,"Cap",Vector3(0,0.58,0),Vector3(0.67,0.14,0.54),Color("e7d9b8"))
		box(head,"CapVisor",Vector3(0,0.51,0.22),Vector3(0.70,0.045,0.32),coat)
	if index==9:
		for x in [-0.15,0.15]:
			box(head,"GoggleRim",Vector3(x,0.51,0.30),Vector3(0.20,0.12,0.05),gold)
			box(head,"GoggleGlass",Vector3(x,0.51,0.33),Vector3(0.14,0.07,0.015),Color("6dabc6"))

func build_all():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://models/npc"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/npc_sd_v2"))
	for i in IDS.size():
		index=i
		actor_root=Node3D.new()
		actor_root.name=IDS[i]
		character()
		var doc=GLTFDocument.new()
		var state=GLTFState.new()
		var err=doc.append_from_scene(actor_root,state)
		if err==OK: err=doc.write_to_filesystem(state,ProjectSettings.globalize_path("res://models/npc/"+IDS[i]+".glb"))
		if err!=OK: push_error("GLB export failed: "+IDS[i]); quit(1); return
		actor_root.set_script(load("res://scripts/npc/npc_sd_actor.gd"))
		actor_root.set("npc_id",IDS[i])
		actor_root.set("display_name",IDS[i])
		var packed=PackedScene.new()
		packed.pack(actor_root)
		ResourceSaver.save(packed,"res://scenes/npc/"+IDS[i]+".tscn")
		actor_root.free()
		print("SD_V2_OK ",IDS[i])
	quit()

