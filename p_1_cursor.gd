extends Sprite2D

@export var player1text:Texture
@export var player2text:Texture
@export var portraitOffset:Vector2
@export var amountOfRows:int=2

var character=[]
var currentSelected=0
var currentColumnSpot=0
var currentRowSpot=0

@onready var gridContainer=get_parent().get_node("GridContainer")

func _on_toggle_character_select(value: bool) -> void:
	owner.visible = value
	if owner.has_node("Camera2D"): owner.get_node("Camera2D").enabled = value
	set_process(false)

func _ready():
	SignalBus.toggle_character_select.connect(_on_toggle_character_select)
	for char_name in get_tree().get_nodes_in_group("Characters"):
		character.append(char_name)

	if multiplayer.is_server():
		texture = player1text
	else:
		texture = player2text
		offset = Vector2(2, 5)

func _process(_delta):
	if(Input.is_action_just_pressed("ui_right")):
		currentSelected+=1
		currentColumnSpot+=1

		if (currentColumnSpot>gridContainer.columns-1 && currentSelected<character.size()-1):
			position.x-=(currentColumnSpot-1)*portraitOffset.x
			position.y+=portraitOffset.y

			currentColumnSpot=0
			currentRowSpot+=1

		elif(currentColumnSpot>gridContainer.columns-1 && currentSelected>character.size()-1):
			position.x-=(currentColumnSpot-1)*portraitOffset.x
			position.y-=currentRowSpot*portraitOffset.y

			currentColumnSpot=0
			currentRowSpot=0
			currentSelected=0
		else:
			position.x+=portraitOffset.x


	elif(Input.is_action_just_pressed("ui_left")):
		currentSelected-=1
		currentColumnSpot-=1

		if(currentColumnSpot<0 && currentSelected>0):
			position.x+=(gridContainer.columns-1)*portraitOffset.x
			position.y-=(amountOfRows-1)*portraitOffset.y

			currentColumnSpot=gridContainer.columns-1
			currentRowSpot-=1

		elif(currentColumnSpot<0 && currentSelected<0):
			position.x+=(gridContainer.columns-1)*portraitOffset.x
			position.y+=(amountOfRows-1)*portraitOffset.y

			currentColumnSpot=gridContainer.columns-1
			currentRowSpot=amountOfRows-1
			currentSelected=character.size()-1

		else:
			position.x-=portraitOffset.x



	elif(Input.is_action_just_pressed("ui_accept")):
		var selected_character_name = character[currentSelected].name
		var character_exist := FileAccess.file_exists("res://Character/" + selected_character_name + '/' + selected_character_name + ".tscn")

		if multiplayer.is_server():
			MultiplayerManager.receive_player_info(selected_character_name, character_exist, multiplayer.get_unique_id())
		else:
			MultiplayerManager.rpc_id(1, "receive_player_info", selected_character_name, character_exist, multiplayer.get_unique_id())
