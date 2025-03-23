extends RichTextLabel

@export_group("Yazı Ayarları")
@export var type_speed: float = 0.1
@export var display_duration: float = 2.0
@export var fade_duration: float = 1.0

@export_group("Animasyon Ayarları")
@export var shake_strength: int = 5  # Titreşim şiddeti
@export var color_effect: Color = Color(1, 0.5, 0.5)  # Renk efekti

func _ready():
	self.visible=false

func start_typewriter_effect(text: String):
	self.text = ""
	self.visible_ratio = 0.0  # Görünürlük oranını sıfırla
	self.visible = true
	
	# Daktilo efekti
	var tween = create_tween()
	tween.tween_property(self, "visible_ratio", 1.0, text.length() * type_speed)
	
	# Her harf için BBcode ile animasyon ekle
	for i in text.length():
		var char = text.substr(i, 1)
		append_text("[shake rate=20 level=%d][color=#%s]%s[/color][/shake]" % [shake_strength, color_effect.to_html(), char])
		await get_tree().create_timer(type_speed).timeout
	
	# Bekle ve solarak kaybol
	await get_tree().create_timer(display_duration).timeout
	fade_out()

func fade_out():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(Callable(self, "hide_label"))

func hide_label():
	self.visible = false  # RichTextLabel'ı gizle
	self.modulate.a = 1.0  # Opaklığı sıfırla (yeniden kullanım için)
