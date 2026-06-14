// I know maybe it's not a perfect shader but it gets the job done in the easiest way without doing much.
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, cull_disabled, depth_draw_never;

uniform vec2 viewport_size = vec2(1920.0, 1080.0);

uniform float brightness : hint_range(0.0, 5.0) = 0.1;
uniform int flare_count : hint_range(0, 7) = 4;
uniform float chain_spacing : hint_range(0.3, 3.0) = 1.0;
uniform bool starburst_on = true;
uniform vec2 uv_nudge = vec2(0.0, 0.0);

varying vec2 v_light_uv;
varying float v_visibility;

// These values are lens flare halo values, most of their names are self explainatory. 
// Try changing the radii values, you'll see the halo radius will increase or decrease.
const float T_POS [7] = float[7](0.12,0.30,0.50,0.65,0.80,1.02,1.28);
const float RADII [7] = float[7](0.028,0.068,0.036,0.092,0.022,0.055,0.040);
const float ALPHAS[7] = float[7](0.80,0.42,0.62,0.30,0.55,0.36,0.50);
const int SHAPES[7] = int[7](1,1,1,1,1,1,1);

// These are color values, if you want, you can export them to the inspector to change the colors.
vec3 ghost_col(int i) {
    if (i == 0) return vec3(0.50, 0.82, 1.00);
    else if (i == 1) return vec3(1.00, 0.63, 0.22);
    else if (i == 2) return vec3(0.38, 1.00, 0.56);
    else if (i == 3) return vec3(0.35, 0.46, 1.00);
    else if (i == 4) return vec3(1.00, 0.36, 0.56);
    else if (i == 5) return vec3(0.62, 1.00, 0.92);
    else return vec3(1.00, 0.90, 0.42);
}

float gauss(float d, float s) { return exp(-(d*d)/(2.0*s*s)); }
float soft_disk(float d, float r) { return 1.0 - smoothstep(r*0.55, r, d); }
float thin_ring(float d, float r) { return 1.0 - smoothstep(r*0.04, r*0.40, abs(d-r)); }
float starburst(vec2 dv, float scale) {
    return pow(abs(cos(atan(dv.y, dv.x) * 3.0)), 5.0) * exp(-length(dv) / scale);
}

void vertex() {
    POSITION = vec4(sign(VERTEX.xy), 0.9999, 1.0);
    vec4 clip = PROJECTION_MATRIX * VIEW_MATRIX * vec4(NODE_POSITION_WORLD, 1.0);

    if (clip.w <= 0.0) {
        v_light_uv   = vec2(0.5);
        v_visibility = 1.0;
        //return;
    }

    vec3 ndc = clip.xyz / clip.w;

    v_light_uv = vec2(
        ndc.x * 0.5 + 0.5,
        1.0 - (ndc.y * 0.5 + 0.5)
    );

	v_light_uv.y = 1.0 - (ndc.y * 0.5 + 0.5);

	v_light_uv.y = ndc.y * 0.5 + 0.5;
	v_light_uv += uv_nudge;

    vec3 light_fwd = normalize((MODEL_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
    vec3 to_cam    = normalize(CAMERA_POSITION_WORLD - NODE_POSITION_WORLD);
    float vis      = pow(clamp(dot(light_fwd, to_cam), 0.0, 1.0), 4.0);

    float edge = max(abs(v_light_uv.x - 0.5), abs(v_light_uv.y - 0.5)) * 2.0;
    vis *= 1.0 - clamp((edge - 0.80) / 0.20, 0.0, 1.0);

    v_visibility = vis;
}

void fragment() {
	float h = viewport_size.y;
	vec2 base_px = v_light_uv * viewport_size;
	vec2 light_px = base_px - uv_nudge * viewport_size;
	vec2 axis_px = (viewport_size * 0.5 - base_px) * chain_spacing;
	vec2 frag_px = SCREEN_UV  * viewport_size;
	vec2 dv_l = frag_px - light_px;
	float dl = length(dv_l);

	vec3 col = vec3(0.0);

	// Primary glow
	col += vec3(1.00, 0.97, 0.85) * gauss(dl, h * 0.025) * 2.2;
	col += vec3(1.00, 0.91, 0.76) * gauss(dl, h * 0.070) * 0.65;
	col += vec3(0.90, 0.95, 1.00) * gauss(dl, h * 0.160) * 0.22;

    if (starburst_on)
        col += vec3(1.00, 0.99, 0.95) * starburst(dv_l, h * 0.05) * 1.1;

    // Ghost chain
    for (int i = 0; i < 7; i++) {
        float active = step(float(i) + 0.5, float(flare_count));
        vec2 ep = light_px + axis_px * T_POS[i];
        float d_i = length(frag_px - ep);
        float r = RADII[i] * h;
        float mask = (SHAPES[i] == 0) ? soft_disk(d_i, r) : thin_ring(d_i, r);
        col += ghost_col(i) * mask * ALPHAS[i] * active;
    }

	col *= brightness * v_visibility;
	float lum = max(max(col.r, col.g), col.b);
	ALBEDO = lum > 0.001 ? col / lum : vec3(0.0);
	ALPHA  = min(lum, 1.0);
}