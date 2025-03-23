extends Node2D

@onready var player = get_tree().get_nodes_in_group("Player")[0]


func _on_village_body_entered(body: Node2D) -> void:
	player.enter_village("Zeyn Village")
