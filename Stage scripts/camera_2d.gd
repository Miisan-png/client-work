extends Camera2D

var p1: CharacterBody2D


## Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if p1 != null:
		self.position=p1.position
