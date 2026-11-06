class_name StaticBatcher
extends RefCounted

## Merges every static MeshInstance3D under `root` into one mesh per material (static batching).
## The world is built from ~70 modular prefabs with many small parts, which means thousands of
## draw calls; WebGL (Compatibility renderer) chokes on that. After batching the whole map is a
## few hundred draw calls. Nodes under `exclude` (animated / moving things) are left untouched.
## Returns [meshes_before, meshes_after].

const CELL := 18.0
## 3차 최적화(낮음 단계)에서 합친 메쉬를 한 단계 단순화해서 사용
static var decimate := false

static func batch(root: Node3D, exclude: Array) -> Array:
	var excluded := {}
	for n in exclude:
		if n != null and is_instance_valid(n):
			excluded[n] = true

	var groups: Dictionary = {}   # key -> {"mat": Material, "items": [[mesh, surface, xform]]}
	var originals: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var cur: Node = stack.pop_back()
		if excluded.has(cur):
			continue
		if cur is CanvasLayer:
			continue
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if _batchable(mi):
				var xf := mi.global_transform
				var mesh := mi.mesh
				for s in range(mesh.get_surface_count()):
					var mat: Material = mi.material_override
					if mat == null:
						mat = mi.get_surface_override_material(s)
					if mat == null:
						mat = mesh.surface_get_material(s)
					var fmt: int = mesh.surface_get_format(s) & (Mesh.ARRAY_FORMAT_NORMAL | Mesh.ARRAY_FORMAT_TANGENT | Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_COLOR)
					# 최적화: 같은 재질이라도 공간 칸(CELL m)별로 나눠 합쳐서, 화면 밖 칸은 통째로 컬링되게 함
					var center: Vector3 = xf * mesh.get_aabb().get_center()
					var cell := Vector2i(floori(center.x / CELL), floori(center.z / CELL))
					var shadow: int = mi.cast_shadow
					# 최적화: 아주 납작한 것(돌기·잔디 윗면·길 등)은 그림자가 보이지 않으므로 그림자 계산에서 제외
					var h: float = (xf.basis * Vector3(0, mesh.get_aabb().size.y, 0)).length()
					if h < 0.12:
						shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					var key := "%d_%d_%d_%d_%d" % [mat.get_instance_id() if mat != null else 0, fmt, shadow, cell.x, cell.y]
					if not groups.has(key):
						groups[key] = {"mat": mat, "shadow": shadow, "items": []}
					(groups[key]["items"] as Array).append([mesh, s, xf])
				originals.append(mi)
		for ch in cur.get_children():
			stack.append(ch)

	var holder := Node3D.new()
	holder.name = "StaticBatches"
	root.add_child(holder)
	var made := 0
	var keys: Array = groups.keys()
	for i in keys.size():
		var g: Dictionary = groups[keys[i]]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for it: Array in g["items"]:
			st.append_from(it[0], it[1], it[2])
		var arrays: Array = st.commit_to_arrays()
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null or (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
			continue
		# 최적화: 자동 LOD(멀어질수록 단순한 메쉬) — 카메라 거리에 따라 렌더러가 알아서 고름
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, g["mat"])
		im.generate_lods(25.0, 60.0, [])
		if decimate and im.get_surface_lod_count(0) > 0:
			# 3차 최적화(낮음): 첫 번째 단순화 단계를 기본 모양으로 사용 → 가까이서도 가벼운 모양
			var lod_idx: PackedInt32Array = im.get_surface_lod_indices(0, 0)
			if lod_idx.size() >= 3:
				arrays[Mesh.ARRAY_INDEX] = lod_idx
				im = ImporterMesh.new()
				im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, g["mat"])
				im.generate_lods(25.0, 60.0, [])
		var am: ArrayMesh = im.get_mesh()
		var out := MeshInstance3D.new()
		out.name = "Batch_%d" % made
		out.mesh = am
		out.cast_shadow = g["shadow"]
		holder.add_child(out)
		made += 1

	for mi in originals:
		if mi.get_child_count() == 0:
			mi.queue_free()
		else:
			mi.visible = false
	return [originals.size(), made]

static func _batchable(mi: MeshInstance3D) -> bool:
	if not mi.is_visible_in_tree() or mi.mesh == null:
		return false
	if not (mi.mesh is ArrayMesh):
		return false
	if mi.skeleton != NodePath("") and mi.get_node_or_null(mi.skeleton) is Skeleton3D:
		return false
	var m := mi.mesh as ArrayMesh
	for s in range(m.get_surface_count()):
		if m.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			return false
		var mat := mi.get_active_material(s)
		if mat is ShaderMaterial:
			return false
	return true


## 최적화: node 바로 아래(또는 모든 하위)의 MeshInstance3D 를 node 기준 좌표로 재질별 한 덩어리로 합침.
## 움직이는 부위(피벗)별로 따로 부르면 애니메이션은 유지된 채 드로우콜만 줄어든다.
static func merge_children(node: Node3D, recursive: bool = false, vis_range_end: float = 0.0) -> int:
	var parts: Array[MeshInstance3D] = []
	var stack: Array[Node] = node.get_children()
	while not stack.is_empty():
		var ch: Node = stack.pop_back()
		if ch is MeshInstance3D and (ch as MeshInstance3D).mesh is ArrayMesh and ch.get_child_count() == 0 and (ch as MeshInstance3D).visible:
			parts.append(ch)
		elif recursive and ch is Node3D and not (ch is MeshInstance3D):
			stack.append_array(ch.get_children())
	if parts.size() < 2:
		return 0
	var groups := {}
	for mi in parts:
		var xf: Transform3D = node.global_transform.affine_inverse() * mi.global_transform if node.is_inside_tree() else _rel_xf(node, mi)
		for s in mi.mesh.get_surface_count():
			if mi.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var mat: Material = mi.get_active_material(s)
			var key: Variant = _mat_key(mat)
			if not groups.has(key):
				groups[key] = {"mat": mat, "items": []}
			(groups[key]["items"] as Array).append([mi.mesh, s, xf])
	var made := 0
	for key in groups:
		var g: Dictionary = groups[key]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for it: Array in g["items"]:
			st.append_from(it[0], it[1], it[2])
		var am := st.commit()
		if am == null or am.get_surface_count() == 0:
			continue
		if g["mat"] != null:
			am.surface_set_material(0, g["mat"])
		var out := MeshInstance3D.new()
		out.name = "Merged_%d" % made
		out.mesh = am
		if vis_range_end > 0.0:
			out.visibility_range_end = vis_range_end
			out.visibility_range_end_margin = 4.0
		node.add_child(out)
		made += 1
	for mi in parts:
		if node.is_inside_tree():
			mi.queue_free()
		else:
			mi.get_parent().remove_child(mi)
			mi.free()
	return parts.size()

static func _rel_xf(node: Node3D, mi: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = mi
	while cur != null and cur != node:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


## 겉모습이 같은 재질은 같은 키 (GLB 는 부품마다 재질 인스턴스가 따로라 인스턴스 ID 로는 합칠 수 없음)
static func _mat_key(mat: Material) -> Variant:
	if mat == null:
		return 0
	if mat is BaseMaterial3D:
		var m := mat as BaseMaterial3D
		var tex_id := m.albedo_texture.get_rid().get_id() if m.albedo_texture != null else 0
		return "%s|%d|%.3f|%.3f|%s|%s|%d|%d" % [m.albedo_color, tex_id, m.roughness, m.metallic,
			m.emission_enabled, m.emission, m.transparency, m.shading_mode]
	return mat.get_instance_id()