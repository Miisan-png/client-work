extends Node

# Constants for validation
const MAX_POSITION_CHANGE = 30.0  # Maximum acceptable position change per frame
const MAX_INPUTS_PER_SECOND = 15  # Maximum number of input events per second
const MAX_HEALTH_DECREASE = 50.0  # Maximum health decrease without special moves

# Tracking data structures
var input_history = {}  # Dictionary to store input history for each player
var position_history = {}  # Dictionary to store position history
var health_history = {}  # Dictionary to track health changes
var suspicious_activity = {}  # Track potentially cheating players

func _ready():
	# Initialize the timer for regular security checks
	var timer = Timer.new()
	timer.wait_time = 1.0  # Check once per second
	timer.autostart = true
	timer.timeout.connect(_on_security_check_timer)
	add_child(timer)

# Called when a player connects
func track_player(id: int) -> void:
	if not input_history.has(id):
		input_history[id] = []
	
	if not position_history.has(id):
		position_history[id] = []
	
	if not health_history.has(id):
		health_history[id] = []
	
	if not suspicious_activity.has(id):
		suspicious_activity[id] = 0
	
	print("Security: Tracking player ", id)

# Record player position for movement validation
func record_player_position(player_id: int, position: Vector2) -> void:
	if not position_history.has(player_id):
		track_player(player_id)
	
	var pos_data = {
		"position": position,
		"timestamp": Time.get_ticks_msec()
	}
	
	position_history[player_id].append(pos_data)
	if position_history[player_id].size() > 30:
		position_history[player_id].pop_front()

# Record player health for damage validation
func record_player_health(player_id: int, health: float) -> void:
	if not health_history.has(player_id):
		track_player(player_id)
	
	var health_data = {
		"health": health,
		"timestamp": Time.get_ticks_msec()
	}
	
	health_history[player_id].append(health_data)
	if health_history[player_id].size() > 30:
		health_history[player_id].pop_front()

# Record player input for validation
func record_player_input(player_id: int, input_data: Dictionary) -> void:
	if not input_history.has(player_id):
		track_player(player_id)
	
	# Add timestamp to input data
	input_data["timestamp"] = Time.get_ticks_msec()
	
	# Add to input history, keeping only the last 60 inputs
	input_history[player_id].append(input_data)
	if input_history[player_id].size() > 60:
		input_history[player_id].pop_front()

# Validate player movement to detect speed hacks
func validate_movement(player_id: int) -> bool:
	if not position_history.has(player_id) or position_history[player_id].size() < 2:
		return true
	
	var history = position_history[player_id]
	var current = history[-1]
	var previous = history[-2]
	
	var distance = current.position.distance_to(previous.position)
	var time_diff = (current.timestamp - previous.timestamp) / 1000.0  # Convert to seconds
	
	if time_diff > 0:
		var speed = distance / time_diff
		
		# Check if the speed exceeds our threshold
		if speed > MAX_POSITION_CHANGE:
			suspicious_activity[player_id] += 1
			print("Suspicious movement detected for player ", player_id)
			print("Speed: ", speed, " (max allowed: ", MAX_POSITION_CHANGE, ")")
			return false
	
	return true

# Validate input rate to prevent macro/automation cheating
func validate_input_rate(player_id: int) -> bool:
	if not input_history.has(player_id) or input_history[player_id].size() < 5:
		return true
	
	var history = input_history[player_id]
	var current_time = history[-1].timestamp
	var one_second_ago = current_time - 1000
	
	# Count inputs in the last second
	var inputs_in_last_second = 0
	for input_data in history:
		if input_data.timestamp > one_second_ago:
			inputs_in_last_second += 1
	
	if inputs_in_last_second > MAX_INPUTS_PER_SECOND:
		suspicious_activity[player_id] += 1
		print("Suspicious input rate detected for player ", player_id)
		print("Inputs in last second: ", inputs_in_last_second, " (max allowed: ", MAX_INPUTS_PER_SECOND, ")")
		return false
	
	return true

# Validate health changes to prevent damage hacking
func validate_health_changes(player_id: int) -> bool:
	if not health_history.has(player_id) or health_history[player_id].size() < 2:
		return true
	
	var history = health_history[player_id]
	var current = history[-1]
	var previous = history[-2]
	
	var health_diff = previous.health - current.health
	var time_diff = (current.timestamp - previous.timestamp) / 1000.0  # Convert to seconds
	
	if health_diff > 0 and time_diff > 0:
		var health_decrease_rate = health_diff / time_diff
		
		if health_decrease_rate > MAX_HEALTH_DECREASE:
			suspicious_activity[player_id] += 1
			print("Suspicious health decrease detected for player ", player_id)
			print("Health decrease rate: ", health_decrease_rate, " (max allowed: ", MAX_HEALTH_DECREASE, ")")
			return false
	
	return true

# Process and validate player input
func process_validated_input(player_id: int, input_data: Dictionary) -> Dictionary:
	record_player_input(player_id, input_data)
	
	# Validate the input
	if not validate_input_rate(player_id):
		input_data["modified"] = true
		
		# Apply restrictions to the suspicious input
		if input_data.has("direction"):
			input_data["direction"] = 0.0
	
	return input_data

# Run periodic security checks
func _on_security_check_timer():
	for player_id in suspicious_activity.keys():
		# If player has accumulated too many suspicious activities, take action
		if suspicious_activity[player_id] >= 3:
			handle_cheater(player_id)
			suspicious_activity[player_id] = 0  # Reset after taking action
		elif suspicious_activity[player_id] > 0:
			# Decrease suspicion over time if no new incidents
			suspicious_activity[player_id] = max(0, suspicious_activity[player_id] - 1)

# Handle detected cheaters
func handle_cheater(player_id: int) -> void:
	print("⚠️ Confirmed cheating detected for player ", player_id)
	
	# Notify MultiplayerManager to take action
	if get_node_or_null("/root/MultiplayerManager"):
		get_node("/root/MultiplayerManager").disconnect_player(player_id, "Security violation detected")
