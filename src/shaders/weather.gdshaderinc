// The weather every outdoor material shares: wind that sways plants, and cloud
// shade drifting over the land. Driven by project-wide shader globals (project.godot
// [shader_globals]) that src/world/atmosphere.gd sets from data/atmosphere.json as
// the hero walks from one area's mood to the next.

global uniform float wind_strength;  // 0 still .. 1 a sea breeze .. 2 a gale
global uniform vec2 wind_direction;  // where the wind blows to, on the ground plane
global uniform float cloud_cover;    // 0 clear sky .. 1 heavy cloud shade

float weather_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float weather_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(weather_hash(i), weather_hash(i + vec2(1.0, 0.0)), f.x),
		mix(weather_hash(i + vec2(0.0, 1.0)), weather_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// How far a plant's vertex moves in the wind, in its model's space. Its height above
// the model's root decides how much it sways: grass tips nod, a cypress's crown leans,
// trunks stay planted. `model` is MODEL_MATRIX, `time` is TIME.
vec3 wind_offset(vec3 vertex, mat4 model, float time) {
	vec3 origin = model[3].xyz;
	float h = max(vertex.y, 0.0);
	float reach = min(0.1 * min(h, 1.0) + 0.025 * max(h - 1.0, 0.0), 0.35);
	float phase = dot(origin.xz, vec2(0.21, 0.17)) + h * 0.35;
	float gust = 0.6 + 0.4 * sin(time * 0.35 + origin.x * 0.05 + origin.z * 0.03);
	float sway = (sin(time * 1.6 + phase) * 0.7 + sin(time * 2.9 + phase * 1.7) * 0.3) * gust;
	vec3 to = normalize(vec3(wind_direction.x, 0.0, wind_direction.y) + vec3(0.0001));
	vec3 local_to = normalize(transpose(mat3(model)) * to);
	// Leaves flutter a little on their own.
	float flutter = sin(time * 7.0 + dot(vertex, vec3(3.1, 2.3, 1.7))) * 0.012 * step(0.8, h);
	return (local_to * sway * reach + vec3(flutter, 0.0, flutter)) * wind_strength;
}

// 0 in sunlight .. 1 under a cloud's shade, for a point on the ground plane.
float cloud_shade(vec2 p, float time) {
	if (cloud_cover <= 0.0) {
		return 0.0;
	}
	vec2 q = (p - wind_direction * time * 1.4) * 0.011;
	float n = weather_noise(q) * 0.62 + weather_noise(q * 2.3 + vec2(7.1, 3.7)) * 0.38;
	float edge = 1.0 - cloud_cover * 0.65;
	return smoothstep(edge - 0.12, edge + 0.12, n);
}

// Shade is cooler as well as darker: the sky's blue fills it.
vec3 cloud_tint(float shade) {
	return mix(vec3(1.0), vec3(0.74, 0.77, 0.86), shade * 0.85);
}
