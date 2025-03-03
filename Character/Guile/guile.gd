extends CharacterBody2D

@export var velocity_synchronizer: Vector2

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
@onready var animation_tree: AnimationTree = $AnimationTree

var sm

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func initialize() -> void:
	$AnimatedSprite2D.flip_h = true

func _ready() -> void:
	sm=$AnimationTree.get("parameters/playback")

	if not is_multiplayer_authority():
		return

	var camera = load("res://Camera/camera_2d.tscn")
	add_child(camera.instantiate())

func _physics_process(delta: float) -> void:
	animation_synchronization()
	if not is_multiplayer_authority():
		return

	velocity_synchronizer = velocity

	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		sm.travel("Jump")

	#Handle crouch
	if Input.is_action_just_pressed("Crouch") and is_on_floor():
		sm.travel("Crouch")

	var direction := Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()


func animation_synchronization() -> void:
	if(velocity_synchronizer.x>1):
		sm.travel("Walk_For")
	elif(velocity_synchronizer.x<0):
		sm.travel("Walk_Back")
	else:
		sm.travel("Idle")
