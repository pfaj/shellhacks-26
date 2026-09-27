shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0);
uniform float saturation : hint_range(0.0, 4.0) = 3.0;
uniform float contrast : hint_range(0.0, 2.0) = 1.0;
uniform float base_gain : hint_range(0.0, 1.5) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 base = clamp(tex.rgb * base_gain, 0.0, 1.0);
	vec3 overlaid = mix(2.0 * base * tint.rgb, 1.0 - 2.0 * (1.0 - base) * (1.0 - tint.rgb), step(0.5, base));
	float luma = dot(overlaid, vec3(0.2126, 0.7152, 0.0722));
	overlaid = mix(vec3(luma), overlaid, saturation);
	overlaid = clamp((overlaid - 0.5) * contrast + 0.5, 0.0, 1.0);
	COLOR = vec4(overlaid, tex.a) * COLOR;
}
