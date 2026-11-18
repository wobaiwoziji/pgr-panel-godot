shader_type canvas_item;
render_mode blend_premul_alpha;

// 逆单应矩阵的三列：把屏幕坐标映射回源图坐标
uniform vec3 h0;
uniform vec3 h1;
uniform vec3 h2;
uniform vec2 canvas = vec2(760.0, 892.0);

void fragment() {
	vec2 p = UV * canvas;
	vec3 s = h0 * p.x + h1 * p.y + h2;
	vec2 uv = s.xy / s.z;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		discard;
	}
	COLOR = texture(TEXTURE, uv);
}
