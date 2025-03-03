extends Node2D


func instance_players() -> void:
	var index := 1

	for peer_id in MultiplayerManager.players:
		var character_name: String = MultiplayerManager.players[peer_id].get("character_name")
		var character_scene := load("res://Character/" + character_name + '/' + character_name + ".tscn")

		if not character_scene.can_instantiate(): return

		var player = character_scene.instantiate()
		player.name = str(peer_id)
		player.scale = Vector2.ONE * 1.5
		get_node("Player" + str(index) + "Position").add_child(player, true)
		if index == MultiplayerManager.max_connections: player.initialize()
		index += 1
