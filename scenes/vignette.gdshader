shader_type canvas_item;

uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 0.72);

void fragment() {
	float distance_from_center = distance(UV, vec2(0.5)) * 1.41421356;
	float edge = smoothstep(0.45, 1.05, distance_from_center);
	COLOR = vec4(vignette_color.rgb, vignette_color.a * edge * strength);
}
