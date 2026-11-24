// The Aegean: deep blue offshore, turquoise in the shallows, foam where it meets the
// land (from the depth buffer), slow swells.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 deep : source_color = vec3(0.12, 0.37, 0.55);
uniform vec3 shallow : source_color = vec3(0.25, 0.66, 0.71);
uniform vec3 foam_colour : source_color = vec3(0.96, 0.95, 0.9);
uniform float shore_depth = 3.5;
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
	VERTEX.y += sin(world_pos.x * 0.16 + TIME * 1.0) * 0.1 + sin(world_pos.z * 0.21 + TIME * 0.7) * 0.08;
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	float water_depth = max(0.0, VERTEX.z - view.z);
	float t = clamp(water_depth / shore_depth, 0.0, 1.0);
	vec3 colour = mix(shallow, deep, t);
	float ripple = noise2(world_pos.xz * 0.9 + vec2(TIME * 0.3, TIME * 0.2)) * 0.5 + noise2(world_pos.xz * 2.3 - vec2(TIME * 0.4, 0.0)) * 0.5;
	colour += vec3(0.04) * ripple;
	float foam = (1.0 - smoothstep(0.0, 0.55 + ripple * 0.5, water_depth)) * step(0.35, ripple + 0.3);
	colour = mix(colour, foam_colour, foam * 0.85);
	ALBEDO = colour;
	ALPHA = mix(0.6, 0.94, t) + foam * 0.1;
	ROUGHNESS = 0.06 + foam * 0.5;
	SPECULAR = 0.55;
}
