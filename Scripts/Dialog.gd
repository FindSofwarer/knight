extends MarginContainer

@onready var label := $MarginContainer/Label
@onready var timer := $LetterDisplayTimer

const MAX_WIDTH := 50
const MAX_HEIGHT := 100

var text := ""
var letter_index := 0
var target_position: Vector2
var is_displaying := false
var can_advance := false

signal finished_displaying

func display_text(text_to_display: String, position: Vector2):
	text = text_to_display
	target_position = position
	letter_index = 0
	is_displaying = true
	can_advance = false
	
	# Label ayarları
	label.text = text
	label.visible_ratio = 0
	await get_tree().process_frame
	
	# Boyut hesaplamaları
	custom_minimum_size = Vector2(
		min(size.x, MAX_WIDTH),
		min(size.y, MAX_HEIGHT))
	
	# Pozisyon ayarı
	var final_position = target_position - Vector2(size.x / 2, size.y + 35)
	global_position = final_position
	
	# Animasyonu başlat
	label.visible_ratio = 0
	_display_next_character()

func skip_animation():
	timer.stop()
	label.visible_ratio = 1
	is_displaying = false
	finished_displaying.emit()

func _display_next_character():
	if letter_index >= text.length():
		is_displaying = false
		finished_displaying.emit()
		return
	
	# Görünürlüğü artır
	label.visible_ratio = float(letter_index + 1) / text.length()
	
	# Zamanlama ayarları
	var current_char = text[letter_index]
	var delay = 0.03
	
	match current_char:
		"!", ".", ",", "?": delay = 0.2
		" ": delay = 0.06
	
	timer.start(delay)
	letter_index += 1

func _on_letter_display_timer_timeout():
	_display_next_character()
