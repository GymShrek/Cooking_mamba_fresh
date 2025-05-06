# scripts/animals/fish.gd
extends Animal
class_name FishAnimal

var in_water = true
var snake_in_water = false
var move_counter = 0 # Counter for alternating movement

func _ready():
	super()
	type = "fish"
	movement_behavior = "water"
	
func setup_sprite():
	$Sprite2D.texture = load("res://assets/fish.png") # You'll need to create this asset

func move():
	# Placeholder for fish movement - basic implementation
	# This will be expanded later with proper water mechanics
	
	# For now, just alternate movement every other turn
	move_counter += 1
	if move_counter % 2 != 0:
		return # Only move every other turn
	
	# Get random direction
	var directions = [
		Vector2i(1, 0),   # Right
		Vector2i(-1, 0),  # Left
		Vector2i(0, 1),   # Down
		Vector2i(0, -1)   # Up
	]
	
	# Shuffle directions
	directions.shuffle()
	
	# Try each direction until we find a valid one
	for dir in directions:
		var new_pos = grid_pos + dir
		if is_position_valid(new_pos):
			# Update facing direction
			update_facing_direction(new_pos)
			
			# Update position
			grid_pos = new_pos
			position = grid.grid_to_world(new_pos)
			return
	
	# If no valid moves found, stay in place

# Check if a position is valid (must be in water)
func is_position_valid(pos, ignore_resource_type = ""):
	# Check if it's within the grid bounds and not a wall
	if not grid.is_cell_vacant(pos):
		return false
		
	# TODO: Check if the position is in water
	# This will be implemented with water mechanics later
	
	# For now, use standard validity check from parent class
	return super.is_position_valid(pos, ignore_resource_type)
