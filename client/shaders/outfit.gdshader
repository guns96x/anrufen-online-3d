shader_type spatial;
render_mode diffuse_toon, specular_toon;

// Recolours a KayKit swatch atlas per character. The atlas is an 8x4 grid of
// colour swatches; `remap` holds one texel per swatch: rgb = target colour
// already divided by the category's reference luminance, a = mix amount
// (0..1) plus emission above 1. Gradients inside a swatch are kept, so cloth
// folds and metal highlights survive the recolour.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D remap : filter_nearest;
uniform vec2 grid = vec2(8.0, 4.0);
uniform float emission_energy = 1.6;
uniform float pulse = 0.0;
uniform float rim_amount = 0.6;
uniform float rim_tint = 0.55;
uniform float sheen = 0.0;

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	ivec2 cell = clamp(ivec2(floor(fract(UV) * grid)), ivec2(0), ivec2(grid) - 1);
	vec4 r = texelFetch(remap, cell, 0);
	float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
	vec3 rec = clamp(r.rgb * lum, 0.0, 1.0);
	vec3 col = mix(c, rec, clamp(r.a, 0.0, 1.0));
	ALBEDO = col;
	float glow = max(r.a - 1.0, 0.0);
	float beat = 1.0 + pulse * sin(TIME * 3.2 + UV.y * 9.0);
	EMISSION = col * glow * emission_energy * beat;
	ROUGHNESS = mix(0.72, 0.35, sheen);
	SPECULAR = mix(0.3, 0.7, sheen);
	RIM = rim_amount;
	RIM_TINT = rim_tint;
}
