shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform sampler2D paint : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 paint_scale = vec2(1.0);
uniform vec2 paint_offset = vec2(0.0);

void fragment() {
	// StandardMaterial3D clamps the GLB's mirrored-repeat sampler. V5 tiles its
	// sky 5 by 2.6 times, so fold both axes to retain every painted sky panel.
	vec2 uv = UV * paint_scale + paint_offset;
	uv = 1.0 - abs(mod(uv, 2.0) - 1.0);
	ALBEDO = texture(paint, uv).rgb * tint.rgb;
}
