// The health and ichor orbs: liquid in a glass sphere with a bronze rim
// (docs/ART_BIBLE.md#ui). `fill` 0..1 sets the level; the surface wobbles.
shader_type canvas_item;

uniform vec4 liquid_dark : source_color = vec4(0.42, 0.04, 0.04, 1.0);
uniform vec4 liquid_light : source_color = vec4(0.92, 0.26, 0.18, 1.0);
uniform vec4 rim_color : source_color = vec4(0.69, 0.48, 0.23, 1.0);
uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float inner = 0.84;
	vec3 colour = vec3(0.05, 0.035, 0.03);
	float alpha = 0.94;
	if (r < inner) {
		float surface = inner - fill * 2.0 * inner;
		float wave = sin(p.x * 7.0 + TIME * 2.3) * 0.022 + sin(p.x * 13.0 - TIME * 1.7) * 0.011;
		wave *= step(0.02, fill) * step(fill, 0.98);
		if (p.y > surface + wave) {
			float depth = clamp((p.y - surface) / (2.0 * inner), 0.0, 1.0);
			float swirl = 0.5 + 0.5 * sin(p.x * 5.0 + p.y * 3.0 + TIME * 0.9);
			colour = mix(liquid_light.rgb, liquid_dark.rgb, depth * 0.9);
			colour += liquid_light.rgb * swirl * 0.12;
			colour += vec3(1.0) * smoothstep(0.03, 0.0, abs(p.y - (surface + wave))) * 0.35;
		}
		// Glass: a soft dark edge and a gloss highlight.
		colour *= 1.0 - smoothstep(0.55, inner, r) * 0.45;
		float gloss = smoothstep(0.42, 0.0, length(p - vec2(-0.3, -0.42)));
		colour += vec3(gloss * 0.42);
		colour += vec3(flash * 0.6);
	} else {
		float t = (r - inner) / (1.0 - inner);
		float light = 0.62 + 0.5 * (0.5 - p.y * 0.5) - abs(t - 0.5) * 0.6;
		colour = rim_color.rgb * light;
		colour = mix(colour, vec3(0.06, 0.04, 0.03), smoothstep(0.85, 1.0, t) + smoothstep(0.15, 0.0, t) * 0.8);
		alpha = 1.0;
	}
	COLOR = vec4(colour, alpha);
}
