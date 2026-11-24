// The one material every Blender-made model uses (assets/materials/palette.tres).
// Faces are UV-mapped to swatch cells of the palette textures (data/palette.json):
//   palette_albedo: sRGB colour; palette_params: R roughness, G metallic, B emission.
// Per-instance parameters (set_instance_shader_parameter) need no material copies:
//   flash     0..1  white hit flash
//   tint      rgb + strength in a, for champions and golden summons
//   fade      1 = solid; less dithers the model away (it blocks the camera)
//   dissolve  0..1  unravels the model into Styx-teal light (death of the Unthreaded)
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D palette_albedo : source_color, filter_nearest, repeat_disable;
uniform sampler2D palette_params : filter_nearest, repeat_disable;
uniform float emission_energy = 6.0;
uniform float rim_strength = 0.12;
uniform vec3 dissolve_color : source_color = vec3(0.37, 0.83, 0.78);

instance uniform float flash = 0.0;
instance uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);
instance uniform float fade = 1.0;
instance uniform float dissolve = 0.0;
// Hover: a coloured rim (red-orange on foes, gold on people and allies).
instance uniform vec4 highlight : source_color = vec4(0.0);

varying vec3 world_pos;

const float BAYER[16] = { 0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0 };

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (fade < 0.999) {
		ivec2 cell = ivec2(mod(FRAGCOORD.xy, 4.0));
		if (fade * 16.0 <= BAYER[cell.x + cell.y * 4] + 0.5) {
			discard;
		}
	}
	float edge = 0.0;
	if (dissolve > 0.0) {
		float n = noise3(world_pos * 7.0) * 0.75 + noise3(world_pos * 19.0) * 0.25;
		if (n < dissolve * 1.08) {
			discard;
		}
		edge = 1.0 - smoothstep(0.0, 0.08, n - dissolve * 1.08);
	}
	vec3 albedo = texture(palette_albedo, UV).rgb;
	vec3 params = texture(palette_params, UV).rgb;
	albedo = mix(albedo, albedo * tint.rgb * 1.5, tint.a);
	ALBEDO = albedo;
	ROUGHNESS = params.r;
	METALLIC = params.g;
	SPECULAR = 0.5;
	// A faint rim keeps silhouettes readable against the ground.
	float facing = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(facing, 3.0) * rim_strength;
	EMISSION = highlight.rgb * highlight.a * (0.25 + pow(facing, 2.0) * 2.5)
		+ albedo * params.b * emission_energy
		+ vec3(1.0, 0.94, 0.82) * flash * 1.2
		+ tint.rgb * tint.a * 0.25
		+ albedo * rim
		+ dissolve_color * edge * 5.0;
}
