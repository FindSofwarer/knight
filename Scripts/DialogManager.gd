extends Node

@onready var text_box_scene = preload("res://GUI/Dialog/textbox.tscn")

var dialog_lines: Array[String] = []
var current_line_index := 0
var text_box = null  # Tür belirtmeyi kaldırdık
var is_dialog_active := false

func start_dialog(position: Vector2, lines: Array[String]):
	if is_dialog_active:
		return
	
	dialog_lines = lines
	current_line_index = 0
	is_dialog_active = true
	
	# Mevcut textbox varsa temizle
	if text_box:
		text_box.queue_free()
	
	text_box = text_box_scene.instantiate()
	get_tree().root.add_child(text_box)
	text_box.display_text(dialog_lines[current_line_index], position)
	text_box.finished_displaying.connect(_on_text_box_finished_displaying)

func _on_text_box_finished_displaying():
	text_box.can_advance = true

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("advance_dialog") && is_dialog_active:
		if text_box.is_displaying:
			# Hızlıca tüm metni göster
			text_box.skip_animation()
		elif text_box.can_advance:
			current_line_index += 1
			if current_line_index >= dialog_lines.size():
				end_dialog()
				return
			
			text_box.can_advance = false
			text_box.display_text(dialog_lines[current_line_index], text_box.target_position)

func end_dialog():
	is_dialog_active = false
	if text_box:
		text_box.queue_free()
		text_box = null
	dialog_lines = []
	current_line_index = 0
