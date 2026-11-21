// The backdrop: a Venetian carnival night of swirling silk in five tones, with
// Arlecchino's diamond seams, stage lights fanning down from above, gold dust
// rising and diamond confetti falling. It reacts to the game:
//   energy  0..1  how hot the show is (score near the target, last hand, Patron):
//                 brighter, faster, stronger lights, more dust and a little confetti
//   confetti 0..1 a burst of confetti for a won show or a big hand; Feel lets it fade
//   pulse   0..1  the danger heartbeat on the last hand, a red glow from the edges
//   gloom   0..1  colour drains away when the run is lost
//   flash         lights the whole sky on big moments
// It is drawn small off-screen and scaled up, which is cheap and soft. Feel drives
// `phase` (the swirl) and `clock` (dust and confetti); Reduce motion stops both.
shader_type canvas_item;

uniform vec4 c0 : source_color = vec4(0.118, 0.043, 0.239, 1.0);
uniform vec4 c1 : source_color = vec4(0.294, 0.102, 0.478, 1.0);
uniform vec4 c2 : source_color = vec4(0.631, 0.137, 0.478, 1.0);
uniform vec4 c3 : source_color = vec4(1.0, 0.31, 0.506, 1.0);
uniform vec4 c4 : source_color = vec4(0.161, 0.827, 0.776, 1.0);
uniform vec4 flash : source_color = vec4(1.0, 0.8, 0.4, 0.0);
uniform vec4 pulse_colour : source_color = vec4(0.95, 0.12, 0.2, 1.0);
uniform float phase = 0.0;
uniform float clock = 0.0;
uniform float twist = 3.0;
uniform float seams = 0.035;
uniform float sparkle = 1.0;
uniform float energy = 0.0;
uniform float confetti = 0.0;
uniform float pulse = 0.0;
uniform float gloom = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 palette_pick(float h) {
	if (h < 0.25) return c3.rgb;
	if (h < 0.5) return c4.rgb;
	if (h < 0.78) return vec3(1.0, 0.82, 0.36);
	return vec3(1.0, 0.97, 0.9);
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 uv = UV * vec2(aspect, 1.0);
	vec2 c = uv - vec2(aspect * 0.5, 0.5);
	float t = phase;
	float r = length(c);

	// Silk: a warped swirl blended through the five mood colours.
	float a = atan(c.y, c.x) + twist * r * (1.0 + 0.25 * sin(t * 0.5)) - t * 0.7;
	vec2 p = vec2(cos(a), sin(a)) * r * 4.0;
	for (int i = 1; i < 5; i++) {
		float n = float(i);
		p += vec2(sin(p.y * 0.8 * n + t * 1.0 * n), cos(p.x * 0.7 * n - t * 0.8 * n)) * (0.75 / n);
	}
	float v = 0.5 + 0.5 * sin(p.x * 1.2 + p.y * 0.9 + t * 1.5);
	float w = 0.5 + 0.5 * sin(p.x * 0.7 - p.y * 1.4 - t * 1.1 + r * 4.0);
	vec3 col = mix(c0.rgb, c1.rgb, smoothstep(0.1, 0.38, v));
	col = mix(col, c2.rgb, smoothstep(0.42, 0.66, v));
	col = mix(col, c3.rgb, smoothstep(0.74, 0.92, v) * 0.9);
	col = mix(col, c4.rgb, smoothstep(0.82, 0.97, w) * 0.8);
	// A sheen along the folds of the silk.
	col += vec3(1.0, 0.92, 0.8) * pow(smoothstep(0.86, 1.0, v), 3.0) * (0.12 + 0.1 * energy);

	// Arlecchino's diamonds, faintly stitched into the cloth.
	vec2 q = uv * vec2(1.0, 1.0 / 1.4) * 9.0;
	vec2 f = fract(vec2(q.x + q.y, q.x - q.y));
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	col += seams * (1.0 - smoothstep(0.0, 0.05, edge));

	// Stage lights fanning down from above the top edge; they sway and grow with energy.
	vec2 lamp = vec2(aspect * 0.5, -0.25);
	vec2 d = uv - lamp;
	float beam_angle = atan(d.x, d.y);
	float beams = pow(0.5 + 0.5 * sin(beam_angle * 9.0 + sin(t * 0.4) * 1.5), 5.0);
	beams *= smoothstep(1.6, 0.2, length(d));
	col += mix(c4.rgb, vec3(1.0, 0.9, 0.65), 0.5) * beams * (0.05 + 0.2 * energy);

	// Gold dust rising, twinkling; more of it when the show heats up.
	vec2 dust = uv * vec2(26.0, 16.0) + vec2(0.0, clock * (0.25 + 0.7 * energy));
	vec2 cell = floor(dust);
	float h = hash(cell);
	if (h > 0.975 - 0.05 * energy) {
		vec2 g = fract(dust) - 0.5 - vec2(hash(cell + 3.1) - 0.5, hash(cell + 7.7) - 0.5) * 0.4;
		float twinkle = pow(0.5 + 0.5 * sin(clock * 3.0 + h * 80.0), 3.0);
		float star = smoothstep(0.3, 0.0, abs(g.x) + abs(g.y));
		col += vec3(1.0, 0.88, 0.55) * star * twinkle * sparkle * (0.5 + 0.6 * energy);
	}

	// Diamond confetti tumbling down in three depths.
	float density = 0.025 * energy + 0.42 * confetti;
	if (density > 0.001) {
		for (int i = 0; i < 3; i++) {
			float layer = float(i);
			float scale = 7.0 + layer * 4.0;
			vec2 cq = uv * scale + vec2(sin(clock * 0.8 + layer * 2.1) * 0.6, -clock * (1.1 + layer * 0.45));
			vec2 cc = floor(cq);
			float ch = hash(cc + layer * 17.3);
			if (ch < density) {
				vec2 lp = fract(cq) - 0.5 - (vec2(hash(cc + 1.3), hash(cc + 4.7)) - 0.5) * 0.5;
				float spin = clock * (2.0 + ch * 9.0) + ch * 40.0;
				lp = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin))) * lp;
				lp.x *= 1.0 + 0.8 * abs(sin(spin * 1.3));
				float piece = smoothstep(0.02, -0.02, abs(lp.x) / 0.11 + abs(lp.y) / 0.17 - 1.0);
				vec3 tint = palette_pick(hash(cc + 9.1));
				col = mix(col, tint * (0.85 + 0.3 * sin(spin * 2.0)), piece * (0.95 - layer * 0.15));
			}
		}
	}

	// Saturate and lift, so the night reads as vivid rather than dark.
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, 1.2 + 0.25 * energy);
	col *= 1.0 + 0.18 * energy;

	// Soft vignette.
	col *= 1.0 - 0.28 * smoothstep(0.35, 0.95, r / max(aspect, 1.0) * 1.3);

	// Danger heartbeat: red light breathing in from the edges.
	float rim = smoothstep(0.2, 0.75, r / max(aspect * 0.5, 0.5));
	col = mix(col, pulse_colour.rgb, pulse * (0.18 + 0.5 * rim));

	// A lost run drains the colour.
	lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum) * vec3(0.62, 0.58, 0.66), gloom);

	col = mix(col, flash.rgb, flash.a);
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
