# scripts/animals/pig.gd
extends Animal
class_name PigAnimal

var current_dir = Vector2i(1, 0)
@export var detection_range: int = 8  # Detection range for resources

# Part-specific damage flags
var front_part_eaten = false
var back_part_eaten = false

# Textures for different parts
var front_texture
var back_texture

func _ready():
	super()
	type = "pig"
	movement_behavior = "linear"
	destroys = ["milk", "tomato", "lettuce", "wheat", "egg"] # Priority order
	
	# Set up as multi-cell animal
	is_multi_cell = true
	size = Vector2i(2, 1)  # 2 cells wide, 1 cell high
	
	# Initialize multi-cell parameters
	part_positions = [
		Vector2i(0, 0),  # Front part
		Vector2i(1, 0)   # Back part
	]
	main_pivot = Vector2i(0, 0)  # Front is main pivot

func setup_sprite():
	# Load textures for each part
	front_texture = load("res://assets/pig1-1.png")
	back_texture = load("res://assets/pig2-1.png")
	
	# Initially hide the main sprite since we'll use separate sprites for parts
	if has_node("Sprite2D"):
		$Sprite2D.visible = false

func initialize_multi_cell():
	# Create array of textures for the parts
	var textures = [front_texture, back_texture]
	
	# Create positions array for initialization - will be updated based on rotation
	var positions = [
		Vector2i(0, 0),  # Front part
		Vector2i(1, 0)   # Back part
	]
	
	# Initialize the multi-cell sprites
	initialize_multi_cell_sprites(textures, positions)
	
	# Update initial appearance
	update_part_positions()

func move():
	# Don't move if we've been eaten
	if not can_move:
		return
		
	# Apply movement slowdown if damaged
	if has_missing_parts:
		move_cooldown += 1
		if move_cooldown < 2:  # Move every other turn when damaged
			return
		move_cooldown = 0
	
	# Safety checks
	if grid == null or main == null or snake == null:
		return
		
	var snake_head_pos = snake.segments[0].grid_pos
	var new_pos = grid_pos
	
	# Check for resources to destroy (only if both parts are intact)
	if not front_part_eaten and not back_part_eaten:
		var nearest_resource = find_nearest_destroyable_resource(grid_pos, detection_range)
		if nearest_resource:
			var resource_pos = grid.world_to_grid(nearest_resource.position)
			new_pos = move_toward_pos(grid_pos, resource_pos)
		else:
			new_pos = move_linear(grid_pos)
	else:
		# If any part is eaten, just move linearly
		new_pos = move_linear(grid_pos)
	
	# Update facing direction and position
	if new_pos != grid_pos:
		update_facing_direction(new_pos)
		
		# Check for and destroy any collectibles at new positions
		if not front_part_eaten and not back_part_eaten:
			check_multi_cell_destroy_resources()
		
		grid_pos = new_pos
		position = grid.grid_to_world(grid_pos)
		update_part_positions()

# Update visual positions of all parts based on grid_pos and rotation
func update_part_positions():
	# Update part visibilities first
	if front_part_eaten and parts.size() > 0:
		parts[0].visible = false
	if back_part_eaten and parts.size() > 1:
		parts[1].visible = false
	
	# Position the parts based on facing direction
	if facing_direction.x != 0:  # Horizontal orientation
		if parts.size() > 0:
			parts[0].position = Vector2(0, 0)
			parts[0].rotation = 0
		if parts.size() > 1:
			parts[1].position = Vector2(grid.CELL_SIZE, 0)
			parts[1].rotation = 0
		
		# Apply horizontal flipping if facing right
		for part in parts:
			part.flip_h = (facing_direction.x > 0)
			part.flip_v = false
	else:  # Vertical orientation
		if parts.size() > 0:
			parts[0].position = Vector2(0, 0)
			parts[0].rotation = deg_to_rad(90) if facing_direction.y > 0 else deg_to_rad(-90)
		if parts.size() > 1:
			parts[1].position = Vector2(0, grid.CELL_SIZE) if facing_direction.y > 0 else Vector2(0, -grid.CELL_SIZE)
			parts[1].rotation = deg_to_rad(90) if facing_direction.y > 0 else deg_to_rad(-90)
		
		# Reset flips for vertical orientation
		for part in parts:
			part.flip_h = false
			part.flip_v = false

# Pig linear movement
func move_linear(curr_pos):
	# If no current direction, choose a random direction
	if current_dir == Vector2i():
		var directions = [
			Vector2i(1, 0),   # Right
			Vector2i(-1, 0),  # Left
			Vector2i(0, 1),   # Down
			Vector2i(0, -1)   # Up
		]
		current_dir = directions[randi() % directions.size()]
	
	# Try to move in current direction
	var next_pos = curr_pos + current_dir
	
	# Check if next position is valid for entire animal
	if is_multi_cell_position_valid(next_pos):
		return next_pos
	else:
		# If blocked, choose new direction
		choose_new_direction()
		return curr_pos  # Stay in place this turn
	
func choose_new_direction():
	var directions = [
		Vector2i(1, 0),   # Right
		Vector2i(-1, 0),  # Left
		Vector2i(0, 1),   # Down
		Vector2i(0, -1)   # Up
	]
	
	# Remove current direction
	var current_index = -1
	for i in range(directions.size()):
		if directions[i] == current_dir:
			current_index = i
			break
	
	if current_index != -1:
		directions.remove_at(current_index)
	
	# Shuffle remaining directions
	directions.shuffle()
	
	# Choose first valid direction
	for dir in directions:
		var new_pos = grid_pos + dir
		if is_multi_cell_position_valid(new_pos):
			current_dir = dir
			return
	
	# If no valid direction, set to zero
	current_dir = Vector2i()

# Override to handle multi-cell rotation
func update_multi_cell_rotation():
	# Update the positions of parts
	update_part_positions()

# Get world part position override to handle vertical orientation
func get_world_part_position(base_pos, relative_pos):
	var world_pos = base_pos
	
	# For horizontal orientation
	if facing_direction.x != 0:
		world_pos += relative_pos
	else:  # For vertical orientation
		# When vertical, the pig is 1x2 instead of 2x1
		if relative_pos.x == 1:  # Back part
			world_pos += Vector2i(0, 1) if facing_direction.y > 0 else Vector2i(0, -1)
	
	return world_pos

# Override handle_part_eaten to handle pig parts
func handle_part_eaten(pos):
	# Convert global position to local position relative to pig
	var local_pos = pos - grid_pos
	
	# For horizontal orientation
	if facing_direction.x != 0:
		if local_pos == Vector2i(0, 0):
			front_part_eaten = true
			if parts.size() > 0:
				parts[0].visible = false
		elif local_pos == Vector2i(1, 0):
			back_part_eaten = true
			if parts.size() > 1:
				parts[1].visible = false
	else:  # For vertical orientation
		if local_pos == Vector2i(0, 0):
			front_part_eaten = true
			if parts.size() > 0:
				parts[0].visible = false
		elif local_pos == Vector2i(0, 1) or local_pos == Vector2i(0, -1):
			# The second part is either below or above depending on direction
			back_part_eaten = true
			if parts.size() > 1:
				parts[1].visible = false
	
	# Set flags for damage state
	has_missing_parts = true
	can_move = false  # Stop movement for the current turn
	
	# Check if all parts are eaten
	if front_part_eaten and back_part_eaten:
		queue_free()
