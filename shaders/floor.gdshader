shader_type spatial;
// The "living" playfield: printed art that shimmers, twinkles, sweeps with
// light and reacts to the ball and to hits.

uniform sampler2D art : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 tint = vec3(0.74);
uniform vec3 glow_a : source_color = vec3(0.2, 0.6, 1.0);
uniform vec3 glow_b : source_color = vec3(1.0, 0.4, 0.8);
uniform float ripple = 0.0;     // water-like wobble of the art
uniform float flow = 0.5;       // flowing bands of light
uniform float sparkle = 0.5;    // twinkling points
uniform float sweep = 0.5;      // travelling light bar
uniform float excite = 0.0;
uniform float fx = 1.0;
uniform vec2 aspect = vec2(1.0, 2.0);
uniform vec4 ball[4];           // xy = uv, z = on
uniform vec4 hit[4];            // xy = uv, z = age (s), w = strength

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float caustic(vec2 p, float t) {
	float a = sin(p.x * 9.0 + t * 0.7 + sin(p.y * 7.0 - t * 0.5) * 1.6);
	float b = sin(p.y * 11.0 - t * 0.6 + sin(p.x * 8.0 + t * 0.4) * 1.7);
	float c = sin((p.x + p.y) * 6.0 + t * 0.9);
	return pow(clamp((a + b + c) / 3.0 * 0.5 + 0.5, 0.0, 1.0), 4.0);
}

void fragment() {
	vec2 uv = UV;
	vec2 p = uv * aspect;
	float t = TIME;
	uv += fx * ripple * 0.0022 * vec2(sin(p.y * 46.0 + t * 1.4), cos(p.x * 42.0 + t * 1.2));
	vec3 base = texture(art, uv).rgb;
	float lum = dot(base, vec3(0.3, 0.59, 0.11));
	vec3 glow = vec3(0.0);

	// flowing light, tinted between the two theme colours
	float ca = caustic(p * 1.6, t);
	vec3 mixc = mix(glow_a, glow_b, 0.5 + 0.5 * sin(p.y * 2.2 - t * 0.35));
	glow += mixc * ca * flow * (0.35 + lum);

	// twinkles
	vec2 g = p * 46.0;
	vec2 id = floor(g);
	float h = hash(id);
	vec2 off = vec2(hash(id + 3.1), hash(id + 7.7)) * 0.6 + 0.2;
	float d = length(fract(g) - off);
	float tw = pow(max(0.0, sin(t * (1.0 + h * 3.0) + h * 40.0)), 6.0);
	glow += mix(glow_a, vec3(1.0), 0.6) * step(0.82, h) * smoothstep(0.16, 0.0, d) * tw * sparkle * 2.2;

	// a bar of light that runs up the table every few seconds
	float bar = fract(t * 0.16);
	float sd = abs((1.0 - uv.y) + uv.x * 0.25 - bar * 1.5 + 0.12);
	glow += glow_b * smoothstep(0.07, 0.0, sd) * sweep * (0.25 + lum * 1.3);

	// halo under each ball
	for (int i = 0; i < 4; i++) {
		float bd = length((uv - ball[i].xy) * aspect);
		glow += glow_a * ball[i].z * (smoothstep(0.075, 0.0, bd) * 0.55
			+ smoothstep(0.012, 0.0, abs(bd - 0.05)) * 0.35);
	}
	// rings spreading from hits
	for (int i = 0; i < 4; i++) {
		float age = hit[i].z;
		float hd = length((uv - hit[i].xy) * aspect);
		float ring = smoothstep(0.022, 0.0, abs(hd - age * 0.38));
		glow += mix(glow_b, vec3(1.0), 0.3) * ring * hit[i].w * max(0.0, 1.0 - age * 1.5) * 1.6;
	}

	ALBEDO = base * tint;
	EMISSION = glow * fx * (1.0 + excite * 0.8);
	ROUGHNESS = 0.2;
	METALLIC = 0.0;
	SPECULAR = 0.5;
	CLEARCOAT = 0.5;
	CLEARCOAT_ROUGHNESS = 0.1;
}
