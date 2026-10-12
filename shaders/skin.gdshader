shader_type canvas_item;
// A whole-screen art-style filter used by Settings > Art style ("Skins"). It restyles everything the
// world draws (not the HUD or menus). style: 1 pencil sketch, 2 watercolor, 3 pixel, 4 noir, 5 print.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform int style = 0;
uniform vec2 screen_size = vec2(1280.0, 720.0);
uniform float pixel_size = 3.0;

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
vec3 tap(vec2 uv) { return texture(screen_tex, uv).rgb; }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = 1.0 / screen_size;
	vec3 c = tap(uv);
	vec3 outc = c;
	if (style == 1) {
		// pencil sketch: graphite lines from edges, light cross-hatching in the shadows, cream paper
		float l0 = luma(c);
		float lx = luma(tap(uv + vec2(px.x * 1.5, 0.0))) - luma(tap(uv - vec2(px.x * 1.5, 0.0)));
		float ly = luma(tap(uv + vec2(0.0, px.y * 1.5))) - luma(tap(uv - vec2(0.0, px.y * 1.5)));
		float edge = clamp(length(vec2(lx, ly)) * 3.2, 0.0, 1.0);
		vec3 paper = vec3(0.95, 0.92, 0.84) * (0.94 + 0.06 * noise(uv * screen_size * 0.5));
		float hatch = 0.0;
		vec2 p = uv * screen_size;
		if (l0 < 0.62) hatch += smoothstep(0.45, 0.5, abs(sin((p.x + p.y) * 0.6))) * (0.62 - l0);
		if (l0 < 0.40) hatch += smoothstep(0.45, 0.5, abs(sin((p.x - p.y) * 0.6))) * (0.40 - l0);
		vec3 tint = mix(vec3(1.0), c / max(l0, 0.2), 0.25);   // whisper of the original colour
		outc = paper * tint * (0.75 + 0.25 * l0) - vec3(hatch * 0.9);
		outc = mix(outc, vec3(0.16, 0.16, 0.2), edge);
	} else if (style == 2) {
		// watercolor: soft blended washes, pooled edges, paper grain
		vec3 b = (tap(uv + px * vec2(2.0, 0.0)) + tap(uv - px * vec2(2.0, 0.0)) + tap(uv + px * vec2(0.0, 2.0)) + tap(uv - px * vec2(0.0, 2.0)) + c) * 0.2;
		float wob = noise(uv * screen_size * 0.04) - 0.5;
		b = mix(b, tap(uv + vec2(wob, wob) * px * 6.0), 0.5);
		float edge = clamp(length(vec2(luma(tap(uv + px * vec2(1.5, 0.0))) - luma(tap(uv - px * vec2(1.5, 0.0))), luma(tap(uv + px * vec2(0.0, 1.5))) - luma(tap(uv - px * vec2(0.0, 1.5))))) * 2.0, 0.0, 1.0);
		float g = luma(b);
		b = mix(vec3(g), b, 0.82);                    // slightly faded
		b = floor(b * 9.0 + 0.5) / 9.0;                // flat washes
		b = mix(b, b * vec3(0.55, 0.5, 0.6), edge * 0.7);   // pigment pools at edges
		float grain = noise(uv * screen_size * 0.9) * 0.08 + noise(uv * screen_size * 0.07) * 0.06;
		outc = mix(b, vec3(0.97, 0.95, 0.9), 0.14) - grain + 0.07;
	} else if (style == 3) {
		// pixel: chunky pixels and a small palette
		ivec2 ts = textureSize(screen_tex, 0);
		vec2 cell = floor(uv * vec2(ts) / pixel_size);
		vec3 q = texelFetch(screen_tex, ivec2((cell + 0.5) * pixel_size), 0).rgb;
		outc = floor(q * 5.0 + 0.5) / 5.0;
		outc = mix(outc, outc * outc * (3.0 - 2.0 * outc), 0.35);
	} else if (style == 4) {
		// noir: hard ink and paper, only the lantern light keeps its colour
		float l0 = luma(c);
		float k = smoothstep(0.30, 0.62, l0);
		vec3 ink = vec3(0.05, 0.05, 0.07);
		vec3 paper = vec3(0.93, 0.9, 0.82);
		outc = mix(ink, paper, k);
		float cy = max(c.b - c.r, 0.0) * max(c.g - c.r, 0.0);
		outc = mix(outc, c * 1.25, clamp(cy * 6.0, 0.0, 1.0));
	} else if (style == 5) {
		// print: halftone dots over flat inks, like an old picture book
		vec2 p = uv * screen_size;
		float s = 5.0;
		mat2 r = mat2(vec2(0.7071, -0.7071), vec2(0.7071, 0.7071));
		vec2 g = r * p / s;
		float d = length(fract(g) - 0.5);
		float dark = 1.0 - luma(c);
		float dots = smoothstep(0.55 * dark + 0.12, 0.55 * dark + 0.02, d);
		vec3 flat_c = floor(c * 6.0 + 0.5) / 6.0;
		vec3 paper = vec3(0.96, 0.93, 0.85);
		outc = mix(flat_c * 1.05, paper, 0.18);
		outc = mix(outc, outc * 0.55, dots * dark);
		outc *= 0.97 + 0.03 * noise(p * 0.8);
	}
	COLOR = vec4(clamp(outc, 0.0, 1.0), 1.0);
}
