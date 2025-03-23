extends Control

@export var health_bar: TextureProgressBar = null
@export var player: CharacterBody2D = null
@export var village_label: RichTextLabel = null

func _ready():
	# Karakterin sinyalini dinle
	player.connect("health_changed", Callable(self, "_on_health_changed"))  # Callable kullan
	player.connect("entered_village", Callable(self, "_on_entered_village"))
	health_bar.max_value = player.max_health
	health_bar.value = health_bar.max_value

# Can değiştiğinde çağrılacak fonksiyon
func _on_health_changed(new_health: int, max_health: int):
	health_bar.value = new_health
	health_bar.max_value = max_health
	
func _on_entered_village(village_name: String):
	# Label'ı güncelle ve daktilo efekti başlat
	village_label.start_typewriter_effect(village_name)
