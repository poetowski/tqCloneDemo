// Styx mist creeping over the necropolis: soft drifting noise on flat discs (the vfx
// kit's Disc mesh), fading out at its rim and where it meets the ground.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 colour : source_color = vec4(0.37, 0.83, 0.78, 0.22);
uniform float drift = 0.05;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

varying vec3 world_pos;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = noise2(world_pos.xz * 0.18 + vec2(TIME * drift, TIME * drift * 0.6)) * 0.6
		+ noise2(world_pos.xz * 0.45 - vec2(TIME * drift * 1.7, 0.0)) * 0.4;
	float shape = (1.0 - smoothstep(0.35, 1.0, UV.y)) * smoothstep(0.4, 0.8, n);
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	float soft = clamp((VERTEX.z - view.z) / 0.5, 0.0, 1.0);
	ALBEDO = colour.rgb;
	ALPHA = shape * soft * colour.a;
}
