shader_type canvas_item;
// "Living Parchment": aged paper grain, fibers, faint Old Script lines,
// and an edge vignette. Scrolls with the camera so the page feels like a
// physical surface under the player.

uniform vec2 scroll = vec2(0.0);          // camera position in pixels
uniform vec2 screen_size = vec2(1280.0, 720.0);
uniform vec4 paper_light : source_color = vec4(0.91, 0.84, 0.68, 1.0);
uniform vec4 paper_dark : source_color = vec4(0.72, 0.60, 0.40, 1.0);
uniform vec4 script_color : source_color = vec4(0.35, 0.25, 0.15, 1.0);
uniform float script_strength : hint_range(0.0, 1.0) = 0.12;
uniform float vignette : hint_range(0.0, 1.0) = 0.45;
// Driven by the Coherence system in Phase 3. 0 = stable, 1 = fully glitched.
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
// Graphics settings: 0 = grain only, 1 = + fibers, 2 = + handwriting lines.
uniform float detail = 2.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
			   mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 px = UV * screen_size + scroll;

	// Pixelation artifacts tearing through the page as glitch rises.
	if (glitch > 0.0) {
		float block = mix(1.0, 24.0, glitch);
		vec2 snapped = floor(px / block) * block;
		float tear = step(1.0 - glitch * 0.35, hash(vec2(floor(px.y / 18.0), floor(TIME * 6.0))));
		px = mix(px, snapped, tear);
	}

	float grain = fbm(px / 90.0);
	vec3 col = mix(paper_dark.rgb, paper_light.rgb, smoothstep(0.25, 0.75, grain));
	if (detail >= 1.0) {
		float fine = noise(px / 2.0);
		col *= 0.94 + 0.06 * fine;
		// Paper fibers: short streaks.
		float fiber = noise(vec2(px.x / 3.0, px.y / 60.0)) * noise(vec2(px.x / 60.0, px.y / 3.0));
		col -= fiber * 0.06;
	}
	if (detail >= 2.0) {
		// Old Script: faint illegible handwriting lines in the ground.
		float line_y = fract(px.y / 28.0);
		float line_mask = 1.0 - smoothstep(0.0, 0.2, abs(line_y - 0.5));
		float scribble = step(0.45, noise(vec2(px.x / 9.0, floor(px.y / 28.0) * 7.0)));
		float wob = noise(vec2(px.x / 5.0, px.y / 28.0));
		col = mix(col, script_color.rgb, line_mask * scribble * wob * script_strength * 0.6);
	}

	// Vignette
	vec2 d = UV - 0.5;
	col *= 1.0 - dot(d, d) * vignette * 2.0;

	COLOR = vec4(col, 1.0);
}
