extends Node

@export_range(0, 4095, 1) var max_connections := 2
@export var multiplayer_port = 8910
@export var server_IP_Address: String = "localhost"

var dtls_key := load("res://certs/authentication_server.key")
var dtls_cert := load("res://certs/authentication_server.crt")

@onready var scene_root := get_tree().root

var players: Dictionary = {}

const STAGE_SELECT_SCENE := preload("res://Stage Select Scene/control.tscn")
const KEN_STAGE_SCENE := preload("res://Stage scenes/Ken's stage.tscn")

# Security manager reference (will be initialized in _ready)
var security_manager = null

func _on_peer_connected(id: int) -> void:
	print("Player connected with ID: ", id)
	
	# Register the new player with the security system
	if security_manager:
		security_manager.track_player(id)
	
	# Tell the new client to display the stage select screen
	rpc_id(id, "display_stage_select")

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	
	# Initialize security manager in a safe way
	call_deferred("_init_security_manager")

func _init_security_manager() -> void:
	# Add the security manager as a child node
	security_manager = load("res://AutoLoads/SecurityManager.gd").new()
	security_manager.name = "SecurityManager"
	get_tree().root.call_deferred("add_child", security_manager)

func start_server():
	print("Starting server...")
	var peer := ENetMultiplayerPeer.new()
	var error = peer.create_server(multiplayer_port, max_connections)
	if not error == OK: 
		print("Failed to create server: ", error)
		return
		
	peer.host.dtls_server_setup(TLSOptions.server(dtls_key, dtls_cert))
	multiplayer.set_multiplayer_peer(peer)
	
	# Register this server as player 1
	players[1] = {
		"character_name": "",
		"player_ready": false
	}
	print("Server started successfully")

func join_server():
	print("Joining server...")
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error = peer.create_client(server_IP_Address, multiplayer_port)

	if not error == OK: 
		print("Failed to connect to server: ", error)
		return error
		
	peer.host.dtls_client_setup(server_IP_Address, TLSOptions.client(dtls_cert))
	multiplayer.set_multiplayer_peer(peer)
	print("Connected to server")

func _switch_to_game() -> void:
	if not STAGE_SELECT_SCENE.can_instantiate(): 
		print("Failed to instantiate stage select scene")
		return

	var scene = STAGE_SELECT_SCENE.instantiate()
	scene_root.add_child(scene)

@rpc("any_peer", "reliable")
func display_stage_select() -> void:
	print("Displaying stage select")
	SignalBus.toggle_multiplayer_lobby.emit(false)
	_switch_to_game()

@rpc("any_peer", "reliable")
func receive_player_info(chosen_character: String, player_ready: bool, peer_id: int) -> void:
	print("Received player info - ID:", peer_id, ", Character:", chosen_character)
	
	# Server validates character selection
	if multiplayer.is_server():
		var valid_character = FileAccess.file_exists("res://Character/" + chosen_character + '/' + chosen_character + ".tscn")
		if not valid_character:
			print("Warning: Invalid character selection attempt: ", chosen_character)
			chosen_character = "Guile"  # Default to a known valid character
		
		# Save player info
		players[peer_id] = {
			"character_name": chosen_character,
			"player_ready": player_ready
		}
		
		print("Player ID:", peer_id, ", Character Name:", chosen_character)
		
		# Check if all players are ready to start
		var start_game: bool = true
		for existing_peer_id in players.keys():
			if players.size() != max_connections or not players[existing_peer_id].get("player_ready"):
				start_game = false
		
		if not start_game: return
		
		# Start the game for all clients
		print("All players ready, starting game")
		rpc("client_start_game", players)
		instance_world()
	else:
		# Forward the request to the server for validation
		rpc_id(1, "receive_player_info", chosen_character, player_ready, peer_id)

@rpc("any_peer", "reliable")
func client_start_game(players_info: Dictionary) -> void:
	print("Client starting game with players: ", players_info)
	players = players_info
	instance_world()

func instance_world() -> void:
	print("Instantiating world")
	SignalBus.toggle_character_select.emit(false)
	
	if not KEN_STAGE_SCENE.can_instantiate(): 
		print("Failed to instantiate stage scene")
		return

	print("Creating stage scene")
	var stage_scene := KEN_STAGE_SCENE.instantiate()
	
	# Use call_deferred to ensure the scene is added safely
	scene_root.call_deferred("add_child", stage_scene)
	
	# Schedule the instance_players call after the stage is fully added
	# This ensures that multiplayer is properly initialized when characters are spawned
	call_deferred("_defer_instance_players", stage_scene)

func _defer_instance_players(stage_scene) -> void:
	# Give a small delay to ensure everything is ready
	await get_tree().create_timer(0.1).timeout
	stage_scene.instance_players()

# Function to handle disconnection of cheating players
func disconnect_player(peer_id: int, reason: String = "Security violation") -> void:
	print("Attempting to disconnect player ", peer_id, " for reason: ", reason)
	
	if not multiplayer or not multiplayer.has_multiplayer_peer():
		print("No multiplayer peer to disconnect")
		return
		
	if not multiplayer.is_server():
		print("Only the server can disconnect players")
		return
	
	print("Disconnecting player ", peer_id, " for reason: ", reason)
	
	# Remove from players dictionary
	if players.has(peer_id):
		players.erase(peer_id)
	
	# Disconnect the peer
	var peer = multiplayer.get_multiplayer_peer()
	if peer and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		peer.disconnect_peer(peer_id)
		print("Player ", peer_id, " disconnected")
