shader_type sky;

// Anime sky: gradient, soft-edged stylised cumulus that drift, a glowing sun
// (or moon), stars at night. Colours come from Atmosphere every frame.

uniform vec3 top_color : source_color = vec3(0.24, 0.56, 0.94);
uniform vec3 horizon_color : source_color = vec3(0.75, 0.89, 1.0);
uniform vec3 ground_color : source_color = vec3(0.45, 0.6, 0.55);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 cloud_light : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shadow : source_color = vec3(0.72, 0.8, 0.95);
uniform float cloud_cover = 0.48;
uniform float star_amount = 0.0;
uniform float sun_size = 0.035;
uniform float glow_amount = 0.6;
uniform vec3 celestial_dir = vec3(0.0, 0.5, -0.86);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;
	vec3 col = mix(horizon_color, top_color, pow(clamp(h, 0.0, 1.0), 0.55));
	if (h < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-h * 4.0, 0.0, 1.0));
	}
	vec3 cel = normalize(celestial_dir);
	float d = dot(dir, cel);
	// Wide warm glow around the sun, brighter near the horizon.
	col += sun_color * pow(max(d, 0.0), 8.0) * glow_amount * 0.55;
	col += sun_color * pow(max(d, 0.0), 64.0) * glow_amount;
	// Stars.
	if (star_amount > 0.0 && h > 0.0) {
		vec2 sp = dir.xz / (h + 0.3) * 180.0;
		float s = step(0.992, hash(floor(sp))) * smoothstep(0.0, 0.3, h);
		float tw = 0.6 + 0.4 * sin(TIME * 2.0 + hash(floor(sp)) * 40.0);
		col += vec3(s * tw * star_amount);
	}
	// Clouds on a flat layer projected onto the dome.
	if (h > 0.02) {
		vec2 uv = dir.xz / (h + 0.12) * 1.4 + vec2(TIME * 0.004, TIME * 0.0015);
		float n = fbm(uv);
		float base = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.08, n);
		float top = fbm(uv + vec2(0.06, 0.04) * cel.xz);
		float lit = clamp((n - top) * 6.0 + 0.6, 0.0, 1.0);
		vec3 cc = mix(cloud_shadow, cloud_light, lit);
		cc += sun_color * pow(max(d, 0.0), 6.0) * 0.5;   // silver lining near the sun
		float fade = smoothstep(0.02, 0.22, h);
		col = mix(col, cc, base * fade * 0.95);
	}
	// Sun / moon disc on top of everything.
	float disc = smoothstep(1.0 - sun_size * 0.04, 1.0 - sun_size * 0.03, d);
	col = mix(col, sun_color * 2.2, disc);
	COLOR = col;
}
