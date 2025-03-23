extends Node2D

@onready var player = get_tree().get_nodes_in_group("Player")[0]
var botMar:float = 0.0


func player_entered(body: Node2D) -> void:
	player.enter_village("Zeyn Village")
	CameraManager.transition_to_mode(CameraManager.CameraMode.VILLAGE,1.0)
	botMar=CameraManager.bottom_margin
	CameraManager.bottom_margin = 10
	player.light_change(0.0,0.6)


func player_exited(body: Node2D) -> void:
	CameraManager.transition_to_mode(CameraManager.CameraMode.DEFAULT,2.0)
	CameraManager.bottom_margin=botMar
	player.light_change(1.5,0.6)
