shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, depth_draw_never;
uniform sampler2D paint : source_color;
uniform sampler2D dawn_paint : source_color;
uniform vec4 tint : source_color;
uniform vec4 atlas_rect;
uniform float dawn = 0.0;
uniform float sunrise = 0.0;
void fragment() {
 vec4 night = texture(paint, UV) * tint;
 vec4 painted = texture(dawn_paint, atlas_rect.xy + UV * atlas_rect.zw);
 vec3 cool = painted.rgb * vec3(.67,.58,.88) + vec3(.025,.030,.058);
 float crest = smoothstep(-.02,.24,painted.r-painted.b);
 vec3 warm = mix(painted.rgb*vec3(.95,.70,1.10),painted.rgb*vec3(1.50,.95,.62),crest);
 ALBEDO = mix(night.rgb,mix(cool,warm,sunrise),dawn);
 ALPHA = mix(night.a,painted.a,dawn);
}
