shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 base = tex.rgb;
	vec3 overlaid = mix(2.0 * base * tint.rgb, 1.0 - 2.0 * (1.0 - base) * (1.0 - tint.rgb), step(0.5, base));
	COLOR = vec4(overlaid, tex.a) * COLOR;
}
