extends Sprite2D
@onready var animation_tree: AnimationTree = $AnimationTree
var sm

# Called when the node enters the scene tree for the first time.
func _ready():
	sm=$AnimationTree.get("parameters/playback")
	sm.travel("Wave")
