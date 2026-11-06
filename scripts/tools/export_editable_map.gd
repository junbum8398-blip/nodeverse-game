extends SceneTree
## Run once to materialize the procedural map. Refuses to overwrite later edits.
const World = preload("res://scripts/nodeverse_world.gd")
const MAP = "res://scenes/NodeverseWorld.tscn"
const PARTS = "res://scenes/map_parts"
var world: Node3D
var output: Node3D
var sections: Dictionary = {}
var failed := false

func _init() -> void:
	call_deferred("run")

func mark(n: Node, key: String, slot: int) -> void:
	var bindings: Dictionary = n.get_meta("world_bindings", {})
	bindings[key] = slot
	n.set_meta("world_bindings", bindings)

func mark_references() -> void:
	for key in ["orb", "array_crane", "stack_tower", "stack_label", "queue_label", "sort_node", "sql_query"]:
		var n: Node = world.get(key)
		if is_instance_valid(n): mark(n, key, -1)
	for key in ["array_tiles", "array_labels", "list_nodes", "stack_crates", "queue_crates", "sort_columns"]:
		var nodes: Array = world.get(key)
		for i in nodes.size():
			if is_instance_valid(nodes[i]):
				mark(nodes[i], key, i)
				if key == "array_labels": nodes[i].set_meta("array_index", i)
	for n in world.get("computer_terminals"): n.set_meta("world_terminal", true)

func own_all(n: Node, scene_root: Node) -> void:
	for ch in n.get_children():
		ch.scene_file_path = ""
		ch.owner = scene_root
		own_all(ch, scene_root)

func attach_colliders(nodes: Array) -> void:
	# Separate generated collider boxes belong to their closest prop, so editing
	# the prop also edits its collision. Terrain/bridge colliders are already local.
	for n in nodes:
		if not (n is StaticBody3D) or n.get_parent() != world: continue
		var nearest: Node3D = null
		var distance := 2.0
		for other in nodes:
			if not (other is Node3D) or other is StaticBody3D or other is Label3D: continue
			if other.get_parent() != world or other.name.begins_with("Path_"): continue
			var d := Vector2(n.position.x - other.position.x, n.position.z - other.position.z).length()
			if d < distance:
				distance = d
				nearest = other
		if nearest != null: n.reparent(nearest, true)

func save_part(n: Node, group: Node3D, number: int) -> void:
	var title := str(n.name)
	if title.begins_with("@") or title.is_empty():
		title = "%s_%03d" % [n.get_class(), number]
	n.name = title
	var file := PARTS.path_join(str(group.name)).path_join("%03d_%s.scn" % [number, title.validate_filename()])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(file.get_base_dir()))
	var xf := (n as Node3D).transform if n is Node3D else Transform3D.IDENTITY
	world.remove_child(n)
	n.scene_file_path = ""
	own_all(n, n)
	var packed := PackedScene.new()
	var err := packed.pack(n)
	if err == OK: err = ResourceSaver.save(packed, file, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_error("Cannot save " + file + ": " + error_string(err))
		failed = true
		n.free()
		return
	var instance := packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	instance.scene_file_path = file
	group.add_child(instance)
	instance.owner = output
	if instance is Node3D: instance.transform = xf
	n.free()

func run() -> void:
	if FileAccess.get_file_as_string(MAP).contains("authored_map = true"):
		push_error("An editable map already exists. Export cancelled to preserve your edits.")
		quit(1)
		return
	world = World.new()
	world.map_export_mode = true
	world.name = "Generator"
	root.add_child(world)
	world.set_process(false)
	world.set_process_unhandled_input(false)
	MeshKit.detail = 1
	MeshKit.ensure_textures_generated()
	var steps := [
		["Environment", "_build_environment"], ["Ocean", "_build_ocean"],
		["Terrain", "_build_islands"], ["Bridges", "_build_bridges"],
		["MainIsland", "_build_main_island"], ["DataStructures", "_build_ds_island"],
		["Algorithms", "_build_algo_island"], ["SQL", "_build_sql_island"],
		["IntroIsland", "_build_intro_island"], ["DataIsland", "_build_data_island"],
		["ChallengeIsland", "_build_challenge_island"], ["Nature", "_build_nature"],
		["Effects", "_build_orb"], ["Computers", "_build_computer"], ["NPCs", "_build_npcs"]]
	for step in steps:
		var before := world.get_children()
		world.call(step[1])
		await process_frame
		var added: Array[Node] = []
		for n in world.get_children():
			if not before.has(n): added.append(n)
		attach_colliders(added)
		sections[step[0]] = added.filter(func(n): return n.get_parent() == world)
		print("MAP_BUILD ", step[0], " ", sections[step[0]].size())
	mark_references()
	world.call("_hide_floating_labels")
	output = World.new()
	output.name = "NodeverseWorld"
	output.authored_map = true
	for key in ["island_cells", "reserved", "array_values", "graph_nodes"]:
		output.authored_data[key] = var_to_str(world.get(key))
	for title in sections:
		var group := Node3D.new()
		group.name = title
		output.add_child(group)
		group.owner = output
		var count := 0
		for n in sections[title]:
			save_part(n, group, count)
			count += 1
		print("MAP_SAVE ", title, " ", count)
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(0, 2, 4.4)
	output.add_child(spawn)
	spawn.owner = output
	if failed:
		output.free()
		world.free()
		quit(1)
		return
	var packed := PackedScene.new()
	var err := packed.pack(output)
	if err == OK:
		var backup := "res://scenes/NodeverseWorldProcedural.tscn"
		if not FileAccess.file_exists(backup):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(MAP), ProjectSettings.globalize_path(backup))
		err = ResourceSaver.save(packed, MAP)
	print("EDITABLE_MAP_SAVED ", error_string(err))
	output.free()
	world.free()
	quit(0 if err == OK else 1)
