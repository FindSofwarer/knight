shader_type canvas_item;

// SCREEN_TEXTURE'ü manuel olarak tanımlayın
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;

// Uniform değişkenler
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.2; // Çok hafif vignette
uniform float contrast : hint_range(0.5, 2.0) = 1.0; // Kontrastı nötr hale getir
uniform float grain_intensity : hint_range(0.0, 0.1) = 0.01; // Çok hafif gren
uniform vec4 shadow_color = vec4(0.8, 0.8, 0.9, 1.0); // Çok açık bir gölge rengi

// Gren (noise) fonksiyonu
float random(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// Orijinal renk
	vec4 color = texture(SCREEN_TEXTURE, SCREEN_UV);
	
	// Renkleri koyulaştır ve kontrast ekle
	color.rgb = (color.rgb - 0.5) * contrast + 0.5;
	color.rgb *= shadow_color.rgb; // Gölge rengini uygula
	
	// Vignette efekti
	vec2 uv = SCREEN_UV;
	float vignette = 1.0 - length(uv - 0.5) * vignette_strength;
	vignette = smoothstep(0.0, 1.0, vignette);
	color.rgb *= vignette;
	
	// Film greni (noise)
	float noise = random(uv * TIME) * grain_intensity;
	color.rgb += noise;
	
	COLOR = color;
}
