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

func _on_peer_connected(id: int) -> void:
	rpc_id(id, "display_stage_select")

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)

func start_server():
	var peer := ENetMultiplayerPeer.new()
	var error = peer.create_server(multiplayer_port, max_connections)
	if not error == OK: return
	peer.host.dtls_server_setup(TLSOptions.server(dtls_key, dtls_cert))

	multiplayer.set_multiplayer_peer(peer)

func join_server():
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var error = peer.create_client(server_IP_Address, multiplayer_port)

	if not error == OK: return error
	peer.host.dtls_client_setup(server_IP_Address, TLSOptions.client(dtls_cert))

	multiplayer.set_multiplayer_peer(peer)

func _switch_to_game() -> void:
	if not STAGE_SELECT_SCENE.can_instantiate(): return

	scene_root.add_child(STAGE_SELECT_SCENE.instantiate())

@rpc("any_peer", "reliable")
func display_stage_select() -> void:
	SignalBus.toggle_multiplayer_lobby.emit(false)
	_switch_to_game()

@rpc("any_peer", "reliable")
func receive_player_info(choosen_character: String, player_ready: bool, peer_id: int) -> void:
	players[peer_id] = {
		"character_name": choosen_character,
		"player_ready": player_ready
	}

	# Print statement to display ID and name of the character
	print("Player ID:", peer_id, ", Character Name:", choosen_character)

	var start_game: bool = true

	for existing_peer_id in players.keys():
		if players.size() != max_connections or not players[existing_peer_id].get("player_ready"):
			start_game = false

	if not start_game: return

	rpc("client_start_game", players)
	instance_world()

@rpc("any_peer", "reliable")
func client_start_game(players_info: Dictionary) -> void:
	players = players_info
	instance_world()

func instance_world() -> void:
	SignalBus.toggle_character_select.emit(false)
	if not KEN_STAGE_SCENE.can_instantiate(): return

	var stage_scene := KEN_STAGE_SCENE.instantiate()
	scene_root.add_child.call_deferred(stage_scene)
	stage_scene.instance_players()
