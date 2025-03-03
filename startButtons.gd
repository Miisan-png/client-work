extends Control

func _ready() -> void:
	SignalBus.toggle_multiplayer_lobby.connect(_on_toggle_multiplayer_lobby)

func become_Host() -> void:
	MultiplayerManager.start_server()
	$CanvasLayer.visible = true
	$CanvasLayer/ColorRect/Label/AnimationPlayer.play("waiting message")

func join_as_player_2() -> void:
	MultiplayerManager.join_server()


func exit() -> void:
	print("Exiting the game...")
	get_tree().quit()

func _on_toggle_multiplayer_lobby(value: bool) -> void:
	visible = value
	$CanvasLayer.visible = value
