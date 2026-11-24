// Glowing effects on the meshes of assets/models/vfx/vfx_kit (see tools/blender/props/vfx.py).
// mode: 0 flat, 1 ring (soft across v), 2 beam (fades upward), 3 arc (sweeps along u up to
// `progress`), 4 thread (bright core across u). Particle colours arrive in COLOR.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform float energy = 2.5;
uniform int mode = 0;

instance uniform float alpha = 1.0;
instance uniform float progress = 1.0;

void fragment() {
	vec4 c = color * COLOR;
	float a = alpha * c.a;
	if (mode == 1) {
		a *= sin(UV.y * 3.14159);
	} else if (mode == 2) {
		a *= (1.0 - UV.y) * smoothstep(0.0, 0.08, UV.y);
	} else if (mode == 3) {
		if (UV.x > progress) {
			discard;
		}
		a *= smoothstep(progress - 0.55, progress, UV.x) * sin(UV.y * 3.14159);
	} else if (mode == 4) {
		a *= pow(sin(UV.x * 3.14159), 2.0);
	}
	ALBEDO = c.rgb * energy;
	ALPHA = clamp(a, 0.0, 1.0);
}
