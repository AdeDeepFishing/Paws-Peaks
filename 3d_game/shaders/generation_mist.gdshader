shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float halo = exp(-2.8 * dot(p, p));
	float edge = 1.0 - smoothstep(0.68, 1.0, length(p));
	float pulse = 0.92 + 0.08 * sin(TIME * 1.6);
	vec2 step_uv = SCREEN_PIXEL_SIZE * 2.8;
	vec3 blurred = vec3(0.0);
	float total = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			vec2 offset = vec2(float(x), float(y));
			float weight = exp(-0.45 * dot(offset, offset));
			blurred += texture(screen_texture, SCREEN_UV + offset * step_uv).rgb * weight;
			total += weight;
		}
	}
	blurred /= total;
	vec3 pearl = vec3(0.92, 0.97, 1.0) + 0.035 * sin(TIME * 0.7 + vec3(0.0, 2.1, 4.2) + p.x * 2.0);
	COLOR = vec4(mix(blurred, pearl, halo * 0.28 * pulse), edge * 0.88 * strength);
}
