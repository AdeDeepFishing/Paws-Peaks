shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
#include "palette.gdshaderinc"
void fragment() {
	vec4 paint = pigment(UV, COLOR);
	ALBEDO = paint.rgb;
	ALPHA = paint.a;
}
