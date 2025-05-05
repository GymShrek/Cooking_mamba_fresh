# scripts/animals/fish.gd
extends Animal
class_name FishAnimal

var in_water = true
var snake_in_water = false

func _ready():
	super()
	type = "fish"
	movement_behavior = "water"
	
func setup_sprite():
	$Sprite2D.texture = load("res://assets/fish.png") # You'll need to create this asset

func move():
	# Placeholder for fish movement
	# This will be implemented later with water mechanics
	
	# Basic logic outline:
	# 1. Check if the snake is in water
	# 2. If snake is out of water, move slowly (every other turn)
	# 3. If snake enters water, move quickly (2 spaces) away from snake
	# 4. If snake is in water, move one space diagonally
	
	# For now, just stay in place
	pass

# Check if a position is valid (must be in water)
func is_position_valid(pos):
	# Check if it's within the grid bounds and not a wall
	if not grid.is_cell_vacant(pos):
		return false
		
	# TODO: Check if the position is in water
	# This will be implemented with water mechanics
	
	# For now, use standard validity check
	return super.is_position_valid(pos)
