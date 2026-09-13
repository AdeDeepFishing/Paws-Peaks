shader_type canvas_item;
render_mode unshaded;

uniform vec2 button_size = vec2(212.0, 56.0);

float rounded_box(vec2 point, vec2 half_size, float radius) {
	vec2 q = abs(point) - half_size + radius;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

vec3 rainbow(float phase) {
	return 0.60 + 0.40 * cos(phase + vec3(0.0, 2.1, 4.2));
}

float sparkle(vec2 point, vec2 center, float strength) {
	vec2 q = abs(point - center);
	float cross_light = exp(-q.x * 2.0 - q.y * 0.27) + exp(-q.y * 2.0 - q.x * 0.27);
	return cross_light * strength;
}

void fragment() {
	vec2 extent = button_size + vec2(36.0);
	vec2 p = UV * extent - extent * 0.5;
	float distance = rounded_box(p, button_size * 0.5, 15.0);
	float fill = 1.0 - smoothstep(-0.8, 0.8, distance);
	float pulse = 0.5 + 0.5 * sin(TIME * 2.3);
	vec3 spectrum = rainbow(p.x * 0.031 + p.y * 0.047 - TIME * 1.3);
	float silk = 0.5 + 0.5 * sin(p.x * 0.025 - p.y * 0.07 + TIME * 1.1);
	vec3 pearl = mix(vec3(0.98, 0.99, 1.0), spectrum, 0.13 + 0.13 * silk);
	float edge = smoothstep(-4.0, -1.0, distance) * fill;
	pearl = mix(pearl, mix(vec3(1.0), spectrum, 0.55), edge * 0.85);
	float sweep_position = (fract(TIME * 0.27) * 2.0 - 1.0) * (button_size.x + 100.0);
	float sweep = exp(-pow((p.x - p.y * 1.4 - sweep_position) / 20.0, 2.0));
	pearl = mix(pearl, vec3(1.0), sweep * 0.9);
	float halo = exp(-max(distance, 0.0) / (5.0 + pulse * 2.0)) * (1.0 - fill) * (0.30 + pulse * 0.16);
	vec3 color = mix(spectrum, pearl, fill);
	float stars = sparkle(p, vec2(-button_size.x * 0.36, -button_size.y * 0.48), pow(0.5 + 0.5 * sin(TIME * 2.0), 4.0));
	stars += sparkle(p, vec2(button_size.x * 0.39, button_size.y * 0.46), pow(0.5 + 0.5 * sin(TIME * 2.0 + 2.5), 4.0));
	float alpha = clamp(fill + halo + stars * 0.7, 0.0, 1.0);
	color = mix(color, vec3(1.0), clamp(stars, 0.0, 1.0));
	COLOR = vec4(color, alpha);
}
