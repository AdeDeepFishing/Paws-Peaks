shader_type spatial;
render_mode unshaded, cull_disabled;
#include "palette.gdshaderinc"
void fragment() { ALBEDO = pigment(UV, COLOR).rgb; }
