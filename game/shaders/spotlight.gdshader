// The guided first run's dimming: darkens the whole screen except a rounded spotlight
// (hole, in the same pixels as area_size) with a soft edge.
shader_type canvas_item;

uniform vec2 area_size = vec2(640.0, 360.0);
uniform vec4 hole = vec4(0.0);
uniform float radius = 12.0;
uniform float feather = 8.0;
uniform float dim = 0.6;

void fragment() {
	vec2 p = UV * area_size;
	float a = dim;
	if (hole.z > 0.0 && hole.w > 0.0) {
		vec2 half_size = hole.zw * 0.5;
		float r = min(radius, min(half_size.x, half_size.y));
		vec2 q = abs(p - (hole.xy + half_size)) - (half_size - vec2(r));
		float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
		a = smoothstep(0.0, feather, d) * dim;
	}
	COLOR = vec4(0.02, 0.0, 0.06, a);
}
