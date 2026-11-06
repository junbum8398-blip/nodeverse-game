class_name QualityManager
extends Node
## PC 사양에 따라 그래픽 품질을 자동으로 맞춤.
## 1) 시작할 때: 그래픽카드 종류(외장/내장)와 CPU 코어 수로 초기 단계 결정
## 2) 플레이 중: 최근 FPS 를 보고 버벅이면 한 단계 내리고, 여유가 오래 지속되면 한 단계 올림
## 3) 사용자가 일시정지 메뉴에서 높음/중간/낮음을 고르면 그 단계로 고정 (자동 조절 끔)
## 선택은 user://graphics.cfg 에 저장되어 다음 실행에도 유지.

signal tier_changed(tier: int, reason: String)

enum Tier { LOW, MEDIUM, HIGH }
const TIER_NAMES := ["낮음", "중간", "높음"]
const CFG_PATH := "user://graphics.cfg"

const DOWN_FPS := 45.0        # 이보다 낮으면 단계 내림
const UP_FPS := 100.0         # 이보다 높게 오래 유지되면 단계 올림
const DOWN_HOLD := 4.0        # 초: 낮은 FPS 가 이만큼 지속되면 내림
const UP_HOLD := 15.0         # 초: 높은 FPS 가 이만큼 지속되면 올림
const COOLDOWN := 8.0         # 초: 바꾼 뒤 이만큼은 다시 바꾸지 않음

var tier: int = Tier.HIGH
var auto_mode := true
var hardware_tier: int = Tier.HIGH     # 사양으로 추정한 시작 단계 (실제 FPS 가 여유 있으면 자동으로 더 올라감)
var hardware_desc := ""
var active := false                    # 플레이 중에만 FPS 기반 조절
var built_level := 1                   # 이번 실행에서 월드를 만든 최적화 단계 (1차/2차/3차)

var _low_t := 0.0
var _high_t := 0.0
var _cool := 0.0
var _fps_avg := 60.0

func _ready() -> void:
	hardware_tier = _detect_hardware_tier()
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) == OK:
		auto_mode = cfg.get_value("graphics", "auto", true)
		tier = cfg.get_value("graphics", "tier", hardware_tier)
	else:
		tier = hardware_tier
	# 자동 모드는 지난번에 자리 잡은 단계에서 시작 (처음이면 사양 추정값)
	if not cfg.has_section_key("graphics", "tier"):
		tier = hardware_tier
	built_level = level_for(tier)
	apply(tier, "시작 (사양: %s)" % hardware_desc)

func _detect_hardware_tier() -> int:
	var adapter := RenderingServer.get_video_adapter_name()
	var dev_type := RenderingServer.get_video_adapter_type()
	var cores := OS.get_processor_count()
	hardware_desc = "%s, CPU %d코어" % [adapter, cores]
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return Tier.LOW
	if dev_type == RenderingDevice.DEVICE_TYPE_CPU or dev_type == RenderingDevice.DEVICE_TYPE_VIRTUAL_GPU:
		return Tier.LOW
	if dev_type == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
		return Tier.MEDIUM if cores >= 8 else Tier.LOW
	if cores < 4:
		return Tier.MEDIUM
	return Tier.HIGH

## 품질 단계 → 최적화 단계: 높음 = 1차, 중간 = 1차+2차, 낮음 = 1차+2차+3차
static func level_for(t: int) -> int:
	return [3, 2, 1][clampi(t, 0, 2)]

func set_manual(t: int) -> void:
	auto_mode = false
	apply(t, "직접 선택")
	_save()

func set_auto() -> void:
	auto_mode = true
	apply(hardware_tier, "자동")
	_save()

func label() -> String:
	return ("자동(%s)" if auto_mode else "%s") % TIER_NAMES[tier]

func level_label() -> String:
	var s := "%d차 최적화" % built_level
	if level_for(tier) != built_level:
		s += " → 다음 실행 %d차" % level_for(tier)
	return s

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("graphics", "auto", auto_mode)
	cfg.set_value("graphics", "tier", tier)
	cfg.save(CFG_PATH)

func _process(delta: float) -> void:
	var fps := float(Engine.get_frames_per_second())
	_fps_avg = lerpf(_fps_avg, fps, clampf(delta * 2.0, 0.0, 1.0))
	if not auto_mode or not active:
		_low_t = 0.0
		_high_t = 0.0
		return
	_cool = maxf(0.0, _cool - delta)
	if _cool > 0.0:
		return
	_low_t = _low_t + delta if _fps_avg < DOWN_FPS else 0.0
	_high_t = _high_t + delta if _fps_avg > UP_FPS else 0.0
	if _low_t >= DOWN_HOLD and tier > Tier.LOW:
		apply(tier - 1, "FPS %d → 한 단계 낮춤" % int(_fps_avg))
	elif _high_t >= UP_HOLD and tier < Tier.HIGH:
		apply(tier + 1, "FPS %d → 한 단계 높임" % int(_fps_avg))

## 단계별 설정 적용 (실행 중 바로 바뀜)
func apply(t: int, reason: String) -> void:
	tier = clampi(t, Tier.LOW, Tier.HIGH)
	_low_t = 0.0
	_high_t = 0.0
	_cool = COOLDOWN
	var vp := get_viewport()
	var sun := _find_sun()
	match tier:
		Tier.HIGH:
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
			if sun:
				sun.shadow_enabled = true
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
				sun.directional_shadow_max_distance = 70.0
			vp.mesh_lod_threshold = 1.0
			vp.msaa_3d = Viewport.MSAA_2X
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
		Tier.MEDIUM:
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
			if sun:
				sun.shadow_enabled = true
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
				sun.directional_shadow_max_distance = 50.0
			vp.mesh_lod_threshold = 2.0
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 1.0
		Tier.LOW:
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
			if sun:
				sun.shadow_enabled = true
				sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
				sun.directional_shadow_max_distance = 35.0
			vp.mesh_lod_threshold = 4.0
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.scaling_3d_scale = 0.8   # 3D 화면만 80% 해상도로 그려서 확대 (UI 글자는 원래 해상도)
	if level_for(tier) != built_level:
		reason += " · 모형 디테일(%d차 최적화)은 다음 실행부터 적용" % level_for(tier)
	_save()
	print("[그래픽 품질] %s — %s" % [TIER_NAMES[tier], reason])
	tier_changed.emit(tier, reason)

func _find_sun() -> DirectionalLight3D:
	var world := get_parent()
	if world == null:
		return null
	for n in world.find_children("*", "DirectionalLight3D", true, false):
		if n is DirectionalLight3D and (n as DirectionalLight3D).shadow_enabled:
			return n
	for n in world.find_children("*", "DirectionalLight3D", true, false):
		if n is DirectionalLight3D:
			return n
	return null
