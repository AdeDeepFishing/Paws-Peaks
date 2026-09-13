shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 paper_tint : source_color = vec4(0.96, 0.925, 0.83, 1.0);

float outside_page(vec2 point, float aspect) {
	return max(max(-point.x, point.x - aspect), max(-point.y, point.y - 1.0));
}

void fragment() {
	// Every scene uses the same bottom-right corner and physical fold angle.
	// Work in height units so resizing cannot rotate or stretch the crease.
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 point = UV * vec2(aspect, 1.0);
	vec2 normal = normalize(vec2(0.92, 0.62));
	float axis = mix(dot(vec2(aspect, 1.0), normal) + 0.015, -0.22, progress);
	float distance_to_fold = dot(point, normal) - axis;
	float aa = SCREEN_PIXEL_SIZE.y * 1.5;
	float front_alpha = 1.0 - smoothstep(-aa, aa, distance_to_fold);
	vec4 result = texture(TEXTURE, UV);
	result.a *= front_alpha;

	// Reflect the lifted corner across the crease. Its original page bounds
	// produce a triangular flap first, then a whole turning sheet, not a wipe.
	vec2 reflected = point - 2.0 * distance_to_fold * normal;
	float bounds = outside_page(reflected, aspect);
	float flap = (1.0 - smoothstep(-aa, aa, bounds)) * front_alpha;
	float depth = max(0.0, -distance_to_fold);
	float bend = exp(-depth / 0.09);
	float paper_shade = 0.79 + 0.21 * (1.0 - bend);
	float grain = fract(sin(dot(UV * 1500.0, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 paper = paper_tint.rgb * paper_shade * (0.986 + grain * 0.014);
	paper += vec3(0.035) * exp(-pow((depth - 0.022) / 0.012, 2.0));

	// The raised sheet casts a soft shadow onto the unturned page and reveal.
	vec2 shadow_point = point + normal * 0.028;
	float shadow_distance = dot(shadow_point, normal) - axis;
	vec2 shadow_reflected = shadow_point - 2.0 * shadow_distance * normal;
	float shadow = exp(-max(0.0, outside_page(shadow_reflected, aspect)) * 65.0);
	shadow *= (1.0 - smoothstep(0.0, 0.08, shadow_distance)) * 0.23;
	shadow *= sin(3.14159265 * progress);
	float alpha = result.a + shadow * (1.0 - result.a);
	result.rgb = (result.rgb * result.a * (1.0 - shadow) + vec3(0.12, 0.10, 0.09) * shadow) / max(alpha, 0.0001);
	result.a = alpha;
	result = mix(result, vec4(paper, 1.0), flap);
	if (progress < 0.001) { result = texture(TEXTURE, UV); }
	if (progress > 0.999) { result = vec4(0.0); }
	COLOR = result;
}
