# scripts/animals/fish.gd
extends Animal
class_name FishAnimal

var in_water = true
var snake_in_water = false
var move_counter = 0 # Counter for alternating movement
var last_snake_position = Vector2i(-1, -1)

func _ready():
	super()
	type = "fish"
	movement_behavior = "water"
	
func setup_sprite():
	$Sprite2D.texture = load("res://assets/fish.png")
	$Sprite2D.scale = Vector2(1, 1)

func move():
	# Get the snake's head position
	var snake_head_pos = snake.segments[0].grid_pos
	var new_pos = grid_pos
	
	# Check if snake entered water (would require water tile detection)
	# For now, we'll simulate this by checking if snake is within 3 tiles
	var snake_nearby = (snake_head_pos - grid_pos).length() <= 3
	var snake_just_entered = snake_nearby and not (last_snake_position - grid_pos).length() <= 3
	
	# Remember last snake position
	last_snake_position = snake_head_pos
	
	# Determine movement pattern based on snake position
	if snake_just_entered:
		# Snake just entered water, move 2 squares this turn
		new_pos = move_away_from_snake(snake_head_pos, 2)
	elif snake_nearby:
		# Snake is in water, move diagonally
		new_pos = move_diagonally()
	else:
		# Snake not in water, move every other turn
		move_counter += 1
		if move_counter % 2 != 0:
			return  # Skip this turn
		
		# Make a random move
		new_pos = move_randomly()
	
	# Update facing direction and position
	if new_pos != grid_pos:
		update_facing_direction(new_pos)
		grid_pos = new_pos
		position = grid.grid_to_world(new_pos)

# Move 1 or 2 steps away from the snake
func move_away_from_snake(snake_pos, steps = 1):
	# Calculate direction away from snake
	var dir = grid_pos - snake_pos
	if dir.x == 0 and dir.y == 0:
		dir = Vector2i(1, 0)  # Default direction if on top of snake
	else:
		# Normalize the direction
		if abs(dir.x) > abs(dir.y):
			dir.x = 1 if dir.x > 0 else -1
			dir.y = 0
		else:
			dir.y = 1 if dir.y > 0 else -1
			dir.x = 0
	
	# Try to move in that direction
	var new_pos = grid_pos + (dir * steps)
	
	# Check if move is valid
	if is_position_valid(new_pos):
		return new_pos
	
	# If not valid with full steps, try with fewer steps
	if steps > 1:
		return move_away_from_snake(snake_pos, steps - 1)
	
	# If still not valid, try adjacent directions
	var alternate_dirs = []
	if dir.x != 0:
		alternate_dirs.append(Vector2i(0, 1))
		alternate_dirs.append(Vector2i(0, -1))
	else:
		alternate_dirs.append(Vector2i(1, 0))
		alternate_dirs.append(Vector2i(-1, 0))
	
	# Try each alternate direction
	for alt_dir in alternate_dirs:
		new_pos = grid_pos + alt_dir
		if is_position_valid(new_pos):
			return new_pos
	
	# If no valid moves, stay in place
	return grid_pos

# Move diagonally (when snake in water)
func move_diagonally():
	# List of diagonal directions
	var diagonals = [
		Vector2i(1, 1),   # Down-right
		Vector2i(-1, 1),  # Down-left
		Vector2i(1, -1),  # Up-right
		Vector2i(-1, -1)  # Up-left
	]
	
	# Shuffle the directions for randomness
	diagonals.shuffle()
	
	# Try each diagonal direction
	for dir in diagonals:
		var new_pos = grid_pos + dir
		if is_position_valid(new_pos):
			return new_pos
	
	# If no diagonal move is valid, try orthogonal moves
	return move_randomly()

# Move randomly (when snake not in water)
func move_randomly():
	var directions = [
		Vector2i(1, 0),   # Right
		Vector2i(-1, 0),  # Left
		Vector2i(0, 1),   # Down
		Vector2i(0, -1)   # Up
	]
	
	# Shuffle the directions for randomness
	directions.shuffle()
	
	# Try each direction
	for dir in directions:
		var new_pos = grid_pos + dir
		if is_position_valid(new_pos):
			return new_pos
	
	# If no move is valid, stay in place
	return grid_pos

# Check if a position is valid (must be in water)
func is_position_valid(pos, ignore_resource_type = ""):
	# Check if it's within the grid bounds and not a wall
	if not grid.is_cell_vacant(pos):
		return false
		
	# TODO: Check if the position is in water
	# This will be implemented with water mechanics later
	
	# For now, use standard validity check from parent class
	return super.is_position_valid(pos, ignore_resource_type)
	
