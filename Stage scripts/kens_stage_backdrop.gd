extends Sprite2D

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_tree_2: AnimationTree = $AnimationTree2
@onready var animation_tree_3: AnimationTree = $AnimationTree3
@onready var animation_tree_4: AnimationTree = $AnimationTree4
@onready var animation_tree_6: AnimationTree = $AnimationTree6
@onready var animation_tree_7: AnimationTree = $AnimationTree7

var state_machine
var sm2
var sm3
var sm4
var sm5
var sm6
var sm7

# Variables to control the bobbing effect
var amplitude= 3.0 # How high and low the ship will move
var speed=1.0     # How fast the ship bobs up and down

# Original Y position of the ship
var start_y: float
# Called when the node enters the scene tree for the first time.
#func _ready():
	## Store the initial Y position so it returns to this level while bobbing
	#start_y = position.y
	#state_machine=$AnimationTree.get("parameters/playback")
	#sm2=$AnimationTree2.get("parameters/playback")
	#sm3=$AnimationTree2.get("parameters/playback")
	#sm4=$AnimationTree2.get("parameters/playback")
	#sm5=$AnimationTree2.get("parameters/playback")
	#sm6=$AnimationTree2.get("parameters/playback")
	#sm7=$AnimationTree2.get("parameters/playback")
	#state_machine.travel("Cheer")
	#sm2.travel("Cheer2")
	#sm3.travel("Look")
	#sm4.travel("Snap")
	#sm5.travel("Cheer3")
	#sm6.travel("Wave2")
	#sm7.travel("Cheer4")

#func _process(_delta):
	## Apply a sine wave to the ship's Y position to create the bobbing effect
	#position.y = start_y + sin(Time.get_ticks_msec() / 400.0 * speed) * amplitude
