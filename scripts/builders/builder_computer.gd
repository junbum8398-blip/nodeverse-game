class_name BuilderComputer
extends RefCounted

## 자료구조 섬 전용 3D 레트로 컴퓨터 워크스테이션 빌더
## 책상, CRT 모니터, 데스크탑 본체, 키보드, 마우스, 빛나는 사이버 스크린 및 상호작용 안내 라벨 포함

static func build_computer() -> Node3D:
	var root := Node3D.new()
	root.name = "ComputerTerminal"

	# 재질 정의
	var mat_desk := MeshKit.mat_color("desk_wood", Color(0.38, 0.24, 0.15), 0.7, 0.0, "wood_brown")
	var mat_legs := MeshKit.mat_color("desk_metal", Color(0.22, 0.24, 0.28), 0.4, 0.8)
	var mat_case := MeshKit.mat_color("pc_case", Color(0.82, 0.80, 0.73), 0.6, 0.1)
	var mat_dark := MeshKit.mat_color("pc_dark", Color(0.18, 0.19, 0.22), 0.7, 0.1)
	var mat_screen := MeshKit.mat_emissive("pc_screen", Color(0.08, 0.25, 0.35), Color(0.25, 0.90, 1.0), 3.0, 0.1)
	var mat_led := MeshKit.mat_emissive("pc_led", Color(0.1, 0.9, 0.3), Color(0.2, 1.0, 0.4), 4.0, 0.1)

	# 1. 책상 상판 (폭 1.4m x 깊이 0.85m x 두께 0.06m, 높이 Y=0.72m)
	MeshKit.add_part(root, "DeskTop", MeshKit.beveled_box(Vector3(1.4, 0.06, 0.85), 0.015), mat_desk, Vector3(0.0, 0.72, 0.0))

	# 2. 책상 다리 4개
	var leg_mesh := MeshKit.beveled_box(Vector3(0.06, 0.69, 0.06), 0.008)
	var leg_x: Array[float] = [-0.62, 0.62]
	var leg_z: Array[float] = [-0.34, 0.34]
	var leg_idx := 0
	for lx in leg_x:
		for lz in leg_z:
			MeshKit.add_part(root, "DeskLeg_%d" % leg_idx, leg_mesh, mat_legs, Vector3(lx, 0.345, lz))
			leg_idx += 1

	# 책상 보강 바
	MeshKit.add_part(root, "DeskBraceBack", MeshKit.beveled_box(Vector3(1.2, 0.04, 0.04), 0.005), mat_legs, Vector3(0.0, 0.35, -0.34))

	# 3. 본체 (데스크탑 타워 - 책상 위 오른쪽, 또는 책상 아래)
	# 책상 위 오른쪽에 웅장한 레트로 타워 배치
	var tower_pos := Vector3(0.48, 0.75 + 0.23, -0.1)
	MeshKit.add_part(root, "TowerCase", MeshKit.beveled_box(Vector3(0.22, 0.46, 0.46), 0.01), mat_case, tower_pos)
	# 플로피/CD 드라이브 슬롯
	MeshKit.add_part(root, "DriveBay", MeshKit.beveled_box(Vector3(0.16, 0.05, 0.02), 0.003), mat_dark, tower_pos + Vector3(0.0, 0.14, 0.232))
	MeshKit.add_part(root, "FloppyBay", MeshKit.beveled_box(Vector3(0.12, 0.03, 0.02), 0.002), mat_dark, tower_pos + Vector3(0.0, 0.06, 0.232))
	# 전원 LED
	MeshKit.add_part(root, "PowerLED", MeshKit.beveled_box(Vector3(0.02, 0.02, 0.01), 0.002), mat_led, tower_pos + Vector3(-0.06, -0.12, 0.232))

	# 4. CRT 모니터 (책상 중앙 약간 뒤쪽)
	var mon_pos := Vector3(-0.12, 0.75, -0.08)
	# 모니터 받침대
	MeshKit.add_part(root, "MonBase", MeshKit.beveled_box(Vector3(0.32, 0.03, 0.28), 0.008), mat_case, mon_pos + Vector3(0.0, 0.015, 0.0))
	MeshKit.add_part(root, "MonNeck", MeshKit.beveled_cylinder(0.08, 0.08, 0.05, 12, 0.005), mat_case, mon_pos + Vector3(0.0, 0.055, 0.0))
	# 모니터 하우징 (CRT 특유의 뒤로 갈수록 좁아지는 챔버)
	var mon_body_pos := mon_pos + Vector3(0.0, 0.26, 0.0)
	MeshKit.add_part(root, "MonHousing", MeshKit.beveled_box(Vector3(0.56, 0.42, 0.44), 0.02), mat_case, mon_body_pos)
	# 모니터 전면 베젤 프레임
	MeshKit.add_part(root, "MonBezel", MeshKit.beveled_box(Vector3(0.52, 0.38, 0.04), 0.01), mat_dark, mon_body_pos + Vector3(0.0, 0.0, 0.21))
	# 발광 CRT 화면 (청록빛 사이버 스크린)
	MeshKit.add_part(root, "MonScreen", MeshKit.beveled_box(Vector3(0.44, 0.31, 0.02), 0.008), mat_screen, mon_body_pos + Vector3(0.0, 0.0, 0.225))

	# 5. 키보드 & 마우스
	var kb_pos := Vector3(-0.12, 0.75 + 0.015, 0.22)
	MeshKit.add_part(root, "KeyboardBase", MeshKit.beveled_box(Vector3(0.44, 0.02, 0.16), 0.004), mat_case, kb_pos)
	MeshKit.add_part(root, "KeyboardKeys", MeshKit.beveled_box(Vector3(0.41, 0.015, 0.13), 0.002), mat_dark, kb_pos + Vector3(0.0, 0.012, 0.0))

	# 마우스패드 및 마우스
	MeshKit.add_part(root, "MousePad", MeshKit.beveled_box(Vector3(0.18, 0.004, 0.20), 0.002), mat_dark, Vector3(0.24, 0.75 + 0.002, 0.22))
	MeshKit.add_part(root, "Mouse", MeshKit.beveled_box(Vector3(0.07, 0.025, 0.11), 0.004), mat_case, Vector3(0.24, 0.75 + 0.015, 0.22))

	# 6. 머리 위 홀로그램 안내 Label3D
	var label := Label3D.new()
	label.name = "GuideLabel"
	label.text = "자료구조 2D 미니게임\n[E] 컴퓨터 터미널"
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 36
	label.outline_size = 8
	label.outline_modulate = Color(0.08, 0.08, 0.15)
	label.modulate = Color(1.0, 0.95, 0.35)
	label.position = Vector3(0.0, 1.48, 0.0)
	root.add_child(label)

	# 7. 모니터 빛 (부드러운 사이버 청록빛 옴니라이트)
	var light := OmniLight3D.new()
	light.name = "ScreenGlow"
	light.light_color = Color(0.3, 0.85, 1.0)
	light.light_energy = 1.2
	light.omni_range = 2.5
	light.position = mon_body_pos + Vector3(0.0, 0.0, 0.4)
	root.add_child(light)

	return root
