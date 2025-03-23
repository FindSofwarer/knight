extends CharacterBody2D


@export_group("Sprite Islemleri")
@export var spriteMain: AnimatedSprite2D = null
@export var sprite_X_Cevir: bool = false

@export_group("Dialog Islemleri")
@export var lines: Array[String]=[]
@onready var pressLabel = $pressLabel
var is_player_in_zone=false

func _ready() -> void:
	if sprite_X_Cevir:
		spriteMain.flip_h=sprite_X_Cevir
		


func body_entered(body: Node2D) -> void:
	pressLabel.visible=true
	is_player_in_zone=true
	CameraManager.start_cinematic_mode(self,2.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("advance_dialog") and is_player_in_zone and pressLabel.visible:
		# Eğer oyuncu etkileşim alanındaysa ve "advance_dialog" aksiyonuna basıldıysa
		if(pressLabel.visible):
			pressLabel.visible=false
		DialogManager.start_dialog(global_position, lines)
	

func body_exited(body: Node2D) -> void:
	pressLabel.visible=false
	is_player_in_zone=false
	DialogManager.end_dialog()  # Oyuncu alandan çıkınca diyalogu bitir
	CameraManager.stop_cinematic_mode(1.0)
