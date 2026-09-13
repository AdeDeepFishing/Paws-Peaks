shader_type canvas_item;
render_mode unshaded;

varying vec4 modulation;

void vertex() {
	modulation = COLOR;
}

void fragment() {
	vec4 scene = texture(TEXTURE, UV);
	float edge = smoothstep(0.0, 0.08, UV.x) * smoothstep(0.0, 0.08, 1.0 - UV.x);
	edge *= smoothstep(0.0, 0.055, UV.y) * smoothstep(0.0, 0.055, 1.0 - UV.y);
	// Feather the illustrated scene into its page like a printed keepsake.
	COLOR = vec4(mix(vec3(0.956, 0.925, 0.85), scene.rgb, edge * 0.96), 1.0) * modulation;
}
