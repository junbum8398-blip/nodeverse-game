shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

// 최적화: 파도 높이(0.028m)는 눈에 거의 안 보여서 정점 변형을 없애고,
// 물결 법선·색·반짝임을 모두 픽셀 단위로 계산 → 바다 메쉬는 삼각형 몇 개로 충분.
// pixel_size > 0 이면 마인크래프트풍 도트 블록 바다 (월드 좌표를 블록 단위로 끊고 색 단계를 줄임).

uniform vec4 shallow_color : source_color = vec4(0.18, 0.78, 0.84, 0.82);
uniform vec4 mid_color : source_color = vec4(0.09, 0.58, 0.72, 0.90);
uniform vec4 deep_color : source_color = vec4(0.05, 0.40, 0.58, 0.96);
uniform vec4 foam_color : source_color = vec4(0.88, 0.98, 1.00, 0.95);
uniform float wave_speed : hint_range(0.1, 4.0) = 1.15;
uniform float wave_height : hint_range(0.0, 0.15) = 0.028;
uniform float pixel_size : hint_range(0.0, 2.0) = 0.0;     // 0 = 부드러운 바다, 0.5 = 도트 블록
uniform float pixel_color_steps = 5.0;                     // 도트 모드 색 단계 수

varying vec3 world_pos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float wave_field(vec2 xz, float t) {
	float w1 = sin(xz.x * 1.45 + xz.y * 1.10 + t * 1.6) * 0.45;
	float w2 = cos(xz.x * 2.15 - xz.y * 1.85 + t * 1.25) * 0.35;
	float w3 = sin((xz.x - xz.y) * 3.40 - t * 2.1) * 0.20;
	return w1 + w2 + w3;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME * wave_speed;
	vec2 p = world_pos.xz;
	bool pixel = pixel_size > 0.0;
	if (pixel) {
		p = (floor(p / pixel_size) + 0.5) * pixel_size;   // 블록 단위로 끊기
		t = floor(t * 4.0) / 4.0;                         // 애니메이션도 뚝뚝 끊어지게
	}
	float dist = length(p);

	// 물결 법선 (픽셀 단위)
	float eps = 0.12;
	float h = wave_field(p, t) * wave_height;
	float hx = wave_field(p + vec2(eps, 0.0), t) * wave_height;
	float hz = wave_field(p + vec2(0.0, eps), t) * wave_height;
	vec3 n_world = normalize(vec3(h - hx, eps, h - hz));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	float near_island = 1.0 - smoothstep(6.0, 28.0, dist);
	float mid_band = 1.0 - smoothstep(14.0, 40.0, dist);

	float n1 = value_noise(p * 1.65 + vec2(t * 0.18, -t * 0.14));
	float n2 = value_noise(p * 3.80 - vec2(t * 0.24, t * 0.20));
	float caustic = clamp(n1 * 0.6 + n2 * 0.55, 0.0, 1.0);

	vec3 col = mix(deep_color.rgb, mid_color.rgb, mid_band);
	col = mix(col, shallow_color.rgb, near_island * (0.65 + 0.35 * caustic));

	float sparkle = smoothstep(0.79, 0.95, n1 * 0.52 + n2 * 0.58);
	if (pixel) {
		sparkle = step(0.86, n1 * 0.52 + n2 * 0.58);
		col = floor(col * pixel_color_steps + 0.5) / pixel_color_steps;
	}
	col = mix(col, foam_color.rgb, sparkle * 0.28);

	ALBEDO = col;
	ROUGHNESS = mix(0.09, 0.18, sparkle);
	METALLIC = 0.06;
	SPECULAR = 0.72;
	EMISSION = foam_color.rgb * (sparkle * 0.10);
	ALPHA = mix(deep_color.a, shallow_color.a, near_island * 0.85);
}
