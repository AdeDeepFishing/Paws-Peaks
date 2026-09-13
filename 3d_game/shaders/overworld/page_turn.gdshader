shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform bool backwards = false;
uniform vec4 paper_tint : source_color = vec4(0.96, 0.925, 0.83, 1.0);

void fragment() {
	vec2 uv = UV;
	if (backwards) { uv.x = 1.0 - uv.x; }
	// A diagonal cylindrical fold sweeps across the outgoing scene. The new
	// live scene is underneath; only the curled page and its shadow cover it.
	float axis = mix(1.22, -0.25, progress) + (uv.y - 0.5) * 0.16;
	float radius = 0.085 * sin(3.14159265 * progress);
	float distance_to_fold = uv.x - axis;
	vec4 result = vec4(0.0);
	if (progress < 0.001) {
		result = texture(TEXTURE, UV);
	} else if (distance_to_fold < -radius) {
		result = texture(TEXTURE, UV);
	} else if (distance_to_fold <= radius && radius > 0.0001) {
		float angle = acos(clamp(-distance_to_fold / radius, -1.0, 1.0));
		vec2 page_uv = vec2(axis - radius + angle * radius, uv.y);
		if (backwards) { page_uv.x = 1.0 - page_uv.x; }
		float shade = 0.72 + 0.28 * abs(cos(angle));
		vec3 front = texture(TEXTURE, clamp(page_uv, vec2(0.0), vec2(1.0))).rgb;
		float grain = fract(sin(dot(UV * 1500.0, vec2(12.9898, 78.233))) * 43758.5453);
		vec3 paper = paper_tint.rgb * (0.98 + grain * 0.02);
		result = vec4(mix(front, paper, smoothstep(1.3, 1.7, angle)) * shade, 1.0);
	} else {
		float shadow = exp(-max(0.0, distance_to_fold - radius) * 55.0) * 0.23;
		result = vec4(vec3(0.12, 0.10, 0.09), shadow * sin(3.14159265 * progress));
	}
	if (progress > 0.999) { result = vec4(0.0); }
	COLOR = result;
}
