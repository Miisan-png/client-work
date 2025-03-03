extends Node

const SERVER_IP = "localhost"
const SERVER_PORT = 10909

var cert = load("res://certs/authentication_server.crt")

@rpc("any_peer")
func spawn_player(position: Vector2, role: String):
	print("Spawning %s at %s" % [role, position])
	var character_scene = load("res://Character/%s/%s.tscn" % [role, role])
	if character_scene:
		var character_instance = character_scene.instantiate()
		character_instance.position = position
		add_child(character_instance)
	else:
		print("Error: Unable to load character scene")

func connect_to_server():
	var client_peer = ENetMultiplayerPeer.new()
	if client_peer.create_client(SERVER_IP, SERVER_PORT) == OK:
		client_peer.host.dtls_client_setup(SERVER_IP, TLSOptions.client(cert))
		print("Connected to server at %s:%d" % [SERVER_IP, SERVER_PORT])
		multiplayer.multiplayer_peer = client_peer
	else:
		print("Failed to connect to server. Ensure it is running.")
