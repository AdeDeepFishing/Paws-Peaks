shader_type spatial;
render_mode unshaded, cull_disabled;

// Godot's standard material has no mirrored-repeat sampler mode.
// Fold the authored UVs explicitly, including negative terrain coordinates.
uniform sampler2D paint : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 mirror_axes = vec2(1.0);
uniform bool flowing_water = false;
uniform bool drifting_sky = false;
uniform sampler2D reflection_texture : source_color, filter_linear, repeat_disable;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.0;
varying vec3 world_position;

vec2 paint_uv(vec2 uv) {
	return mix(clamp(uv, vec2(0.0), vec2(1.0)), 1.0 - abs(mod(uv, 2.0) - 1.0), mirror_axes);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV;
	if (drifting_sky) {
		uv.x += TIME * 0.001;
	}
	vec3 pigment = texture(paint, paint_uv(uv)).rgb;
	if (flowing_water) {
		vec2 primary = vec2(world_position.x / 19.0, (world_position.z - TIME * 0.48) / 24.0);
		vec2 secondary = vec2(world_position.x / 23.0 + 0.17, (world_position.z - TIME * 0.69) / 29.0);
		pigment = mix(texture(paint, paint_uv(primary)).rgb, texture(paint, paint_uv(secondary)).rgb, 0.28);
	}
	ALBEDO = pigment * tint.rgb * COLOR.rgb;
	if (flowing_water && reflection_strength > 0.0) {
		vec2 ripple = vec2(
			sin(world_position.z * 2.5 - TIME * 1.2) * 0.0018
				+ sin(world_position.z * 5.1 + world_position.x * 0.4 - TIME * 1.9) * 0.0007,
			sin(world_position.x * 1.5 + world_position.z * 0.6 - TIME * 0.8) * 0.0008
		);
		vec2 reflection_uv = vec2(SCREEN_UV.x, 1.0 - SCREEN_UV.y) + ripple;
		vec3 reflected = texture(reflection_texture, clamp(reflection_uv, vec2(0.001), vec2(0.999))).rgb;
		float grazing = 1.0 - clamp(abs(normalize(CAMERA_POSITION_WORLD - world_position).y), 0.0, 1.0);
		float weight = (0.29 + 0.22 * grazing * grazing) * reflection_strength;
		ALBEDO = mix(ALBEDO, reflected, weight);
	}
}
