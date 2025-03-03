extends Node2D

var security_manager = null

func _ready():
	# Find the security manager
	security_manager = get_node_or_null("/root/SecurityManager")
	if not security_manager:
		print("Warning: SecurityManager not found")

func instance_players() -> void:
	print("Attempting to instance players")
	
	if multiplayer and not multiplayer.is_server():
		print("Client not spawning players - waiting for server")
		return
	
	if not MultiplayerManager.players or MultiplayerManager.players.size() == 0:
		push_error("No players found in MultiplayerManager.players")
		return
	
	print("Found ", MultiplayerManager.players.size(), " players to instantiate")
	
	var index := 1
	for peer_id in MultiplayerManager.players:
		print("Processing player ", peer_id, " (index: ", index, ")")
		
		var character_name: String = MultiplayerManager.players[peer_id].get("character_name")
		print("Character name from players dict: ", character_name)
		
		var valid_path = "res://Character/" + character_name + '/' + character_name + ".tscn"
		if not FileAccess.file_exists(valid_path):
			print("Error: Invalid character path detected: ", valid_path)
			character_name = "Guile" 
			valid_path = "res://Character/Guile/Guile.tscn"
		
		print("Loading character scene from: ", valid_path)
		var character_scene = load(valid_path)
		
		if not character_scene:
			push_error("Failed to load character scene")
			continue
			
		if not character_scene.can_instantiate():
			print("Error: Could not instantiate character scene for: ", character_name)
			continue
		
		print("Instantiating character: ", character_name)
		var player = character_scene.instantiate()
		
		player.name = str(peer_id)
		
		var position_node = get_node_or_null("Player" + str(index) + "Position")
		if not position_node:
			push_error("Player position node not found: Player" + str(index) + "Position")
			continue
			
		var spawn_position = position_node.position
		print("Player spawn position: ", spawn_position)
		
		player.scale = Vector2.ONE * 1.5
		
		print("Adding player to scene: ", player.name)
		position_node.add_child(player, true)
		
		if index == MultiplayerManager.max_connections:
			print("Initializing player: ", peer_id)
			player.initialize()
		
		if security_manager:
			print("Recording player position in security manager")
			security_manager.record_player_position(peer_id, spawn_position)
		else:
			print("Warning: security_manager is null, not recording position")
		
		print("Broadcasting player spawn to clients")
		rpc("confirm_player_spawn", peer_id, character_name, spawn_position, index)
		
		index += 1
	
	print("Player instantiation completed")

@rpc("authority", "reliable")
func confirm_player_spawn(peer_id: int, character_name: String, spawn_position: Vector2, player_index: int) -> void:
	if multiplayer.is_server():
		return
	
	print("Client received spawn confirmation for player ", peer_id)
	
	var existing_player = get_node_or_null("Player" + str(player_index) + "Position/" + str(peer_id))
	if existing_player:
		print("Player already exists, skipping")
		return
	
	var valid_path = "res://Character/" + character_name + '/' + character_name + ".tscn"
	print("Loading character from: ", valid_path)
	
	if not FileAccess.file_exists(valid_path):
		print("Character file doesn't exist: ", valid_path)
		character_name = "Guile"  
		valid_path = "res://Character/Guile/Guile.tscn"
	
	var character_scene = load(valid_path)
	if not character_scene or not character_scene.can_instantiate():
		print("Error: Could not instantiate character scene for: ", character_name)
		return
	
	var player = character_scene.instantiate()
	
	player.name = str(peer_id)
	
	player.position = spawn_position
	
	player.scale = Vector2.ONE * 1.5
	
	var position_node = get_node_or_null("Player" + str(player_index) + "Position")
	if not position_node:
		print("Position node not found: Player", player_index, "Position")
		return
		
	position_node.add_child(player, true)
	
	if player_index == MultiplayerManager.max_connections:
		player.initialize()
		
	print("Client successfully spawned player ", peer_id)
