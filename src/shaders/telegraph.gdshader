// Enemy attack warnings on the ground (docs/ART_BIBLE.md: red-orange, filling toward the
// moment of impact). shape 0 = Disc mesh (UV.x angle from the front, UV.y radius), with an
// optional sector (half_angle) and hole (inner); shape 1 = Lane mesh (UV.y along).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.36, 0.12, 1.0);
uniform int shape = 0;
uniform float half_angle = 180.0;
uniform float inner = 0.0;

instance uniform float fill = 0.0;
instance uniform float alpha = 1.0;

void fragment() {
	float along;
	float edge;
	if (shape == 0) {
		float angle = UV.x * 360.0;
		angle = angle > 180.0 ? 360.0 - angle : angle;
		if (angle > half_angle || UV.y < inner) {
			discard;
		}
		along = (UV.y - inner) / max(0.001, 1.0 - inner);
		float side = half_angle < 179.0 ? smoothstep(half_angle - 4.0, half_angle, angle) : 0.0;
		edge = max(smoothstep(0.94, 0.99, UV.y), side);
	} else {
		along = UV.y;
		edge = max(smoothstep(0.42, 0.49, abs(UV.x - 0.5)), smoothstep(0.97, 1.0, UV.y));
	}
	float filled = step(along, fill);
	float pulse = 0.85 + 0.15 * sin(TIME * 14.0);
	float a = 0.14 + filled * 0.32 + edge * 0.55;
	ALBEDO = color.rgb * (1.0 + filled * 0.6);
	ALPHA = clamp(a * alpha * pulse * color.a, 0.0, 1.0);
}
