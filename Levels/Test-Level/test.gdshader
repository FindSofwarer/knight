shader_type canvas_item;

// Gren efekti için rastgele sayı üretme
float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

// Gren efekti
float grain(vec2 uv, float time) {
    return rand(uv + time) * 0.1; // Gren yoğunluğu
}

void fragment() {
    // Orijinal renk
    vec3 color = texture(TEXTURE, UV).rgb;
    
    // Sepya tonu için renk dönüşümü
    float gray = dot(color, vec3(0.299, 0.587, 0.114)); // Gri tonlama
    vec3 sepia = vec3(gray) * vec3(1.2, 1.0, 0.8); // Sepya tonu
    
    // Kontrast artırma
    sepia = (sepia - 0.5) * 1.2 + 0.5; // Kontrast ayarı
    
    // Gren efekti ekle
    float grain_value = grain(UV, TIME);
    sepia += grain_value;
    
    // Son renk
    COLOR = vec4(sepia, 1.0);
}