# scripts/animal.gd
extends Node2D

# Animal properties
var type = ""
var grid_pos = Vector2i()
var size = Vector2i(1, 1)
var speed = 1
var destroys = []
var movement_behavior = "wander"

# For chicken animation
var flight_state = 0  # 0=normal, 1=flight, 2=mid
var texture = null
var mid_texture = null
var flight_texture = null

# For pig movement
var current_dir = Vector2i(0, 0)
var starting_pos = Vector2i()

func _ready():
	# Store starting position for animals that might return
	starting_pos = grid_pos
	
	# Set texture based on type
	if texture:
		$Sprite2D.texture = texture

func _draw():
	# Draw debug info if needed
	pass
