extends CharacterBody2D

@export var velocity_synchronizer: Vector2
const SPEED = 300.0
const JUMP_VELOCITY = -400.0
@onready var animation_tree: AnimationTree = $AnimationTree
var sm

# Security-related variables
var last_position: Vector2
var input_buffer = []
var server_corrections = 0
var health = 100.0

# Reference to the security manager (will be found at runtime)
var security_manager = null

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func initialize() -> void:
	# Different characters might have different sprite nodes
	if has_node("Sprite2D"):
		$Sprite2D.flip_h = true
	elif has_node("AnimatedSprite2D"):
		$AnimatedSprite2D.flip_h = true
	
	last_position = position

func _ready() -> void:
	# Find the security manager (should be created by MultiplayerManager)
	security_manager = get_node_or_null("/root/SecurityManager")
	
	# Initialize animation state machine
	sm = $AnimationTree.get("parameters/playback")
	
	if not is_multiplayer_authority():
		return
		
	# Add camera for the local player
	var camera = load("res://Camera/camera_2d.tscn")
	add_child(camera.instantiate())
	
	# Initialize security tracking if available
	if security_manager and multiplayer_is_active():
		security_manager.record_player_position(multiplayer.get_unique_id(), position)
		security_manager.record_player_health(multiplayer.get_unique_id(), health)

# Helper function to check if multiplayer is properly active
func multiplayer_is_active() -> bool:
	return multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func _physics_process(delta: float) -> void:
	# Always update animation based on synchronized velocity
	animation_synchronization()
	
	# Only process inputs for the local player
	if not is_multiplayer_authority():
		return
	
	velocity_synchronizer = velocity
	
	# Gather input data
	var input_data = {
		"jump": Input.is_action_just_pressed("ui_accept") and is_on_floor(),
		"crouch": Input.is_action_just_pressed("Crouch") and is_on_floor(),
		"direction": Input.get_axis("ui_left", "ui_right"),
		"position": position,
		"health": health
	}
	
	# Buffer inputs
	input_buffer.append(input_data)
	if input_buffer.size() > 10:
		input_buffer.pop_front()
	
	# Process input based on server/client status
	if multiplayer_is_active():
		if multiplayer.is_server():
			# If we are the server, validate locally
			process_input(input_data, delta)
		else:
			# If we are a client, send to server for validation
			rpc_id(1, "server_validate_input", input_data)
	else:
		# Fallback for when multiplayer isn't active yet
		process_input(input_data, delta)
	
	# Track position for security checks
	if position != last_position and security_manager and multiplayer_is_active():
		security_manager.record_player_position(multiplayer.get_unique_id(), position)
		last_position = position

func process_input(input_data: Dictionary, delta: float) -> void:
	# Add gravity
	if not is_on_floor():
		velocity.y += get_gravity_value().y * delta
	
	# Process validated input
	if input_data.jump:
		velocity.y = JUMP_VELOCITY
		sm.travel("Jump")
	
	if input_data.crouch:
		sm.travel("Crouch")
	
	var direction = input_data.direction
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	move_and_slide()
	
	# Update synchronized velocity for animations
	velocity_synchronizer = velocity

@rpc("any_peer", "reliable")
func server_validate_input(input_data: Dictionary) -> void:
	# Only the server should process this
	if not multiplayer_is_active() or not multiplayer.is_server():
		return
	
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Validate the input using the security manager
	if security_manager:
		input_data = security_manager.process_validated_input(sender_id, input_data)
		
		# Record health for security tracking
		if input_data.has("health"):
			security_manager.record_player_health(sender_id, input_data.health)
	
	# Send the validated input back to the client
	rpc_id(sender_id, "client_receive_validated_input", input_data)
	
	# Broadcast the validated movement to all other clients
	if multiplayer.get_peers().size() > 0:
		for peer_id in multiplayer.get_peers():
			if peer_id != sender_id:
				rpc_id(peer_id, "receive_player_update", sender_id, input_data.position, velocity_synchronizer)

@rpc("any_peer", "reliable")
func client_receive_validated_input(validated_input: Dictionary) -> void:
	# Client receives the server-validated input
	
	# Check if the input was modified by the server (potential cheating detected)
	if validated_input.has("modified") and validated_input.modified:
		print("Server modified input due to potential security violation")
		server_corrections += 1
	
	# Process the validated input
	process_input(validated_input, get_physics_process_delta_time())

@rpc("any_peer", "unreliable")
func receive_player_update(player_id: int, player_position: Vector2, player_velocity: Vector2) -> void:
	# Only process updates for other players
	if str(player_id) != name:
		return
	
	# Update remote player position and velocity
	position = player_position
	velocity_synchronizer = player_velocity

func animation_synchronization() -> void:
	if(velocity_synchronizer.x > 1):
		sm.travel("Walk_For")
	elif(velocity_synchronizer.x < 0):
		sm.travel("Walk_Back")
	else:
		sm.travel("Idle")

func get_gravity_value() -> Vector2:
	var gravity = ProjectSettings.get_setting("physics/2d/default_gravity", 980)
	return Vector2(0, gravity)

# Called when the player takes damage
func take_damage(amount: float, attack_source_id: int) -> void:
	# Server must validate all damage
	if multiplayer_is_active() and multiplayer.is_server():
		# Apply validated damage
		health -= amount
		health = max(0, health)
		
		# Broadcast health update to all clients
		rpc("sync_health", health)
		
		# Record health change for security monitoring
		if security_manager:
			security_manager.record_player_health(name.to_int(), health)
	elif multiplayer_is_active():
		# Client requests damage validation from server
		rpc_id(1, "server_validate_damage", amount, attack_source_id)

@rpc("any_peer", "reliable")
func server_validate_damage(amount: float, attack_source_id: int) -> void:
	# Only the server should validate damage
	if not multiplayer_is_active() or not multiplayer.is_server():
		return
		
	var sender_id = multiplayer.get_remote_sender_id()
	
	# Validate that the sender is the one taking damage
	if str(sender_id) != name:
		print("Invalid damage request from player ", sender_id)
		return
	
	# Validate damage amount (could add more logic here)
	var validated_amount = min(amount, 25.0)  # Cap damage per hit
	
	# Apply damage
	health -= validated_amount
	health = max(0, health)
	
	# Broadcast health update to all clients
	rpc("sync_health", health)
	
	# Record health change for security monitoring
	if security_manager:
		security_manager.record_player_health(name.to_int(), health)

@rpc("any_peer", "reliable")
func sync_health(new_health: float) -> void:
	# Update local health value with server-validated value
	health = new_health
