extends SceneTree
## NPC 부품 미리 합치기 (드로우콜 최적화)
## models/npc/<id>.glb → models/npc/merged/<id>.scn
## 움직이는 부위(엉덩이·다리·몸통·팔·머리 피벗)는 그대로 두고, 각 피벗 바로 아래 메쉬들을 합친다.
## - 텍스처·발광·투명이 없는 단색 재질 부품: 색을 정점 색으로 구워서 피벗당 메쉬 1개로
## - 그 밖의 재질: 같은 겉모습끼리 합침 (StaticBatcher.merge_children)
## 실행: Godot_console.exe --headless --path . --script res://scripts/tools/merge_npc_parts.gd
## NPC 모델(GLB)을 교체한 뒤 이 스크립트 → python tools/write_npc_v2_scenes.py 순서로 실행.

const SRC := "res://models/npc"
const OUT := "res://models/npc/merged"
const PIVOTS := ["Model", "Model/Hips", "Model/Hips/LegL", "Model/Hips/LegR", "Model/Hips/Torso",
	"Model/Hips/Torso/ArmL", "Model/Hips/Torso/ArmR", "Model/Hips/Torso/Head"]

var vc_mat: StandardMaterial3D

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	vc_mat = StandardMaterial3D.new()
	vc_mat.vertex_color_use_as_albedo = true
	vc_mat.vertex_color_is_srgb = true
	vc_mat.roughness = 0.85
	vc_mat.resource_name = "npc_vertex_color"
	for f in DirAccess.get_files_at(SRC):
		if not f.ends_with(".glb"):
			continue
		var root: Node3D = (load(SRC + "/" + f) as PackedScene).instantiate()
		var before := root.find_children("*", "MeshInstance3D", true, false).size()
		for path in PIVOTS:
			var pv := root.get_node_or_null(path) as Node3D
			if pv != null:
				_merge_plain(pv)
				StaticBatcher.merge_children(pv)
		var after := root.find_children("*", "MeshInstance3D", true, false).size()
		root.scene_file_path = ""
		var stack: Array[Node] = root.get_children()
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			n.scene_file_path = ""
			n.owner = root
			stack.append_array(n.get_children())
		var ps := PackedScene.new()
		ps.pack(root)
		var out := OUT + "/" + f.get_basename() + ".scn"
		var err := ResourceSaver.save(ps, out, ResourceSaver.FLAG_COMPRESS)
		print("%s  meshes %d -> %d  %s" % [f, before, after, error_string(err)])
		root.free()
	quit()

func _plain(mat: Material) -> bool:
	if not (mat is BaseMaterial3D):
		return false
	var m := mat as BaseMaterial3D
	return m.albedo_texture == null and not m.emission_enabled and m.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED

## 피벗 바로 아래 단색 부품들을 정점 색 메쉬 1개로
func _merge_plain(pv: Node3D) -> void:
	var parts: Array[MeshInstance3D] = []
	for ch in pv.get_children():
		if ch is MeshInstance3D and ch.mesh is ArrayMesh and ch.get_child_count() == 0 and ch.visible:
			var ok := true
			for s in ch.mesh.get_surface_count():
				if not _plain(ch.get_active_material(s)) or ch.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
					ok = false
			if ok:
				parts.append(ch)
	if parts.size() < 2:
		return
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for mi in parts:
		var xf: Transform3D = mi.transform
		var nb := xf.basis.inverse().transposed()
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var col: Color = (mi.get_active_material(s) as BaseMaterial3D).albedo_color
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var base := verts.size()
			for k in v.size():
				verts.append(xf * v[k])
				norms.append((nb * n[k]).normalized() if k < n.size() else Vector3.UP)
				cols.append(col)
			var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if ix.is_empty():
				for k in v.size():
					idx.append(base + k)
			else:
				for k in ix:
					idx.append(base + k)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	am.surface_set_material(0, vc_mat)
	var out := MeshInstance3D.new()
	out.name = "MergedColor"
	out.mesh = am
	pv.add_child(out)
	for mi in parts:
		pv.remove_child(mi)
		mi.free()
