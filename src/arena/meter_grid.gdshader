// World-space triplanar meter grid for greybox geometry (design §11).
// Thin lines every 1 m, bold lines every 5 m. Units are meters (spec: movement.md §1).
shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.58, 0.60, 0.62);
uniform vec3 line_color : source_color = vec3(0.22, 0.23, 0.25);
uniform vec3 major_color : source_color = vec3(0.95, 0.55, 0.12);
uniform float minor_period = 1.0;
uniform float major_period = 5.0;
uniform float minor_width = 0.015;
uniform float major_width = 0.04;
uniform float blend_sharpness = 4.0;
// Terrain: base colour from the mesh's vertex colours (linear) and softer lines.
uniform bool use_vertex_color = false;
uniform float line_strength = 1.0;

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// 1.0 on a grid line, 0.0 away from it (antialiased with fwidth).
float grid_line(vec2 p, float period, float half_width) {
	vec2 d = abs(fract(p / period + 0.5) - 0.5) * period;
	vec2 aa = fwidth(p) * 0.75;
	vec2 l = 1.0 - smoothstep(vec2(half_width) - aa, vec2(half_width) + aa, d);
	return max(l.x, l.y);
}

float plane_mask(vec2 p, float period, float half_width) {
	return grid_line(p, period, half_width);
}

void fragment() {
	vec3 w = pow(abs(world_nrm), vec3(blend_sharpness));
	w /= max(w.x + w.y + w.z, 1e-5);
	float minor = plane_mask(world_pos.zy, minor_period, minor_width) * w.x
			+ plane_mask(world_pos.xz, minor_period, minor_width) * w.y
			+ plane_mask(world_pos.xy, minor_period, minor_width) * w.z;
	float major = plane_mask(world_pos.zy, major_period, major_width) * w.x
			+ plane_mask(world_pos.xz, major_period, major_width) * w.y
			+ plane_mask(world_pos.xy, major_period, major_width) * w.z;
	vec3 base = use_vertex_color ? COLOR.rgb : base_color;
	vec3 c = mix(base, line_color, clamp(minor, 0.0, 1.0) * line_strength);
	c = mix(c, major_color, clamp(major, 0.0, 1.0) * line_strength);
	ALBEDO = c;
	ROUGHNESS = 0.9;
}
