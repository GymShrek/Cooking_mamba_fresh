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
		Vector2i(0, 0),  # Front part (1-1)
		Vector2i(1, 0)   # Back part (2-1)
	]
	main_pivot = Vector2i(0, 0)  # Front is main pivot

func setup_sprite():
	# We use a custom sprite setup for multi-cell animals
	# Main node will have no sprite, instead we create child nodes
	
	# Load part textures
	front_texture = load("res://assets/pig1-1.png")
	back_texture = load("res://assets/pig2-1.png")
	
	# Create part nodes
	initialize_multi_cell()

func initialize_multi_cell():
	# Create part sprites
	parts.clear()
	
	# Create front part (1-1)
	var front_part = Sprite2D.new()
	front_part.texture = front_texture
	front_part.name = "PigFront"
	front_part.position = Vector2(0, 0)  # Local position
	add_child(front_part)
	parts.append(front_part)
	
	# Create back part (2-1)
	var back_part = Sprite2D.new()
	back_part.texture = back_texture
	back_part.name = "PigBack"
	back_part.position = Vector2(grid.CELL_SIZE, 0)  # Position to right of front
	add_child(back_part)
	parts.append(back_part)
	
	# Update initial appearance
	update_multi_cell_rotation()

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
		
	var snake_head_pos = snake.segments[0].grid_pos
	var new_pos = grid_pos
	
	# Check for resources to destroy (only if back part intact)
	if not front_part_eaten:
		var nearest_resource = find_nearest_destroyable_resource(grid_pos, detection_range)
		if nearest_resource:
			var resource_pos = grid.world_to_grid(nearest_resource.position)
			new_pos = move_toward_pos(grid_pos, resource_pos)
		else:
			new_pos = move_linear(grid_pos)
	else:
		# If front part is eaten, just move linearly without seeking resources
		new_pos = move_linear(grid_pos)
	
	# Update facing direction and position
	if new_pos != grid_pos:
		update_facing_direction(new_pos)
		
		# Check for and destroy any collectibles at new positions
		if not back_part_eaten:  # Only destroy resources if back part is intact
			check_multi_cell_destroy_resources()
		
		grid_pos = new_pos
		update_part_positions()

# Update visual positions of all parts based on grid_pos and rotation
func update_part_positions():
	# Don't update parts that have been eaten
	if front_part_eaten and parts.size() > 0:
		parts[0].hide()
	if back_part_eaten and parts.size() > 1:
		parts[1].hide()
		
	# Update positions of remaining parts
	for i in range(parts.size()):
		if (i == 0 and front_part_eaten) or (i == 1 and back_part_eaten):
			continue
			
		var part_pos = part_positions[i]
		var world_part_pos = get_world_part_position(grid_pos, part_pos)
		var pixel_pos = grid.grid_to_world(world_part_pos)
		parts[i].position = pixel_pos - position  # Convert to local position

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
	# Flip or rotate parts based on facing direction
	for part in parts:
		part.rotation = 0
		part.flip_h = false
		part.flip_v = false
	
	if facing_direction.x > 0:  # Right
		# Flip horizontally
		for part in parts:
			part.flip_h = true
	elif facing_direction.x < 0:  # Left
		# Default pig orientation is facing left - no change needed
		pass
	elif facing_direction.y > 0:  # Down
		# Rotate 90 degrees clockwise
		for part in parts:
			part.rotation = deg_to_rad(90)
	elif facing_direction.y < 0:  # Up
		# Rotate 90 degrees counter-clockwise
		for part in parts:
			part.rotation = deg_to_rad(-90)
	
	# Update positions of parts
	update_part_positions()

# Handle part eaten
func handle_part_eaten(pos):
	var relative_pos = pos - grid_pos
	
	# Check which part was eaten
	for i in range(part_positions.size()):
		var world_part_pos = get_world_part_position(grid_pos, part_positions[i])
		if world_part_pos == pos:
			if i == 0:  # Front part
				front_part_eaten = true
				parts[0].visible = false
				has_missing_parts = true
				# Behavior change: slow movement, no resource seeking
			elif i == 1:  # Back part
				back_part_eaten = true
				parts[1].visible = false
				has_missing_parts = true
				# Behavior change: slow movement, continue resource seeking
	
	# If both parts eaten, queue_free the whole animal
	if front_part_eaten and back_part_eaten:
		queue_free()
		return
	
	# Apply appropriate behavior changes
	can_move = false  # Stop movement for the turn
	move_cooldown = 0
