shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform sampler2D paint : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 paint_scale = vec2(1.0);
uniform vec2 paint_offset = vec2(0.0);

uniform sampler2D dawn_paint : source_color;
uniform float dawn = 0.0;
uniform float sunrise = 0.0;
varying float sky_height;
void vertex() { sky_height = VERTEX.y / 180.0; }
void fragment() {
	// StandardMaterial3D clamps the GLB's mirrored-repeat sampler. V5 tiles its
	// sky 5 by 2.6 times, so fold both axes to retain every painted sky panel.
	vec2 uv = UV * paint_scale + paint_offset;
	uv = 1.0 - abs(mod(uv, 2.0) - 1.0);
	vec3 night = texture(paint, uv).rgb * tint.rgb;
 vec3 day = texture(dawn_paint, uv).rgb;
 float h = smoothstep(.10,.62,sky_height);
 vec3 dawn_tint = mix(vec3(.43,.22,.38),vec3(.16,.31,.58),h);
 float pigment = dot(day,vec3(.2126,.7152,.0722));
 vec3 rise_tint = mix(vec3(1.25,.42,.10),vec3(.48,.20,.22),h);
 float stroke = smoothstep(-.20,.18,day.r-day.b);
 vec3 rise = mix(rise_tint*(.18+1.15*pigment),vec3(1.60,.82,.22)*(.35+.80*pigment),.65*stroke);
 ALBEDO = mix(night,mix(day*dawn_tint,rise,sunrise),dawn);
}
