// The ground of a level (tools/blender/level/*.py): flat-shaded faces painted with
// palette colours as vertex colours. Vertex alpha below 1 makes a face glow (the Styx
// seeping through the necropolis). A little world noise keeps big flats alive.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform float emission_energy = 4.0;
uniform float variation = 0.08;

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
	vec3 colour = COLOR.rgb;
	float n = noise2(world_pos.xz * 0.12) * 0.6 + noise2(world_pos.xz * 0.7) * 0.4;
	colour *= 1.0 - variation + n * variation * 2.0;
	ALBEDO = colour;
	ROUGHNESS = 0.96;
	SPECULAR = 0.25;
	float glow = clamp(1.0 - COLOR.a, 0.0, 1.0);
	EMISSION = colour * glow * emission_energy * (0.7 + 0.3 * sin(TIME * 1.7 + world_pos.x * 0.8 + world_pos.z * 0.5));
}
