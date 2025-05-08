# scripts/animals/pig.gd
extends Animal
class_name PigAnimal

var current_dir = Vector2i(1, 0)
@export var detection_range: int = 8  # Detection range for resources

# Part-specific damage flags
var front_part_eaten = false
var back_part_eaten = false

# Textures for different parts - declare these at the class level
var front_texture = null
var back_texture = null

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
	
	# Delay the initialization until we're properly in the tree
	call_deferred("manual_post_ready")

func manual_post_ready():
	# This is called after _ready to ensure proper initialization
	print("PIG: Post-ready initialization")
	
	# Check all children for debugging
	print("PIG: Children before initialization: ", get_children().size())
	for child in get_children():
		print("PIG: Child:", child.name, child.get_class())
	
	# Let's manually see if grid has been initialized properly
	grid = get_node_or_null("/root/Main/Grid")
	if grid == null:
		print("PIG: Grid reference still null! This will cause problems.")
	else:
		print("PIG: Grid reference valid", grid)

func setup_sprite():
	# Load textures for each part - use proper error handling
	front_texture = load("res://assets/pig1-1.png")
	if front_texture == null:
		push_error("Failed to load pig1-1.png")
		
	back_texture = load("res://assets/pig2-1.png")
	if back_texture == null:
		push_error("Failed to load pig2-1.png")
	
	# Print confirmation when textures are loaded
	print("PIG: Textures loaded:", front_texture != null, back_texture != null)
	
	# Initially hide the main sprite since we'll use separate sprites for parts
	if has_node("Sprite2D"):
		$Sprite2D.visible = false
	
	# Try to force sprite creation here
	call_deferred("force_create_sprites")

func force_create_sprites():
	print("PIG: Force creating sprites")
	
	# Remove any existing sprites first
	var to_remove = []
	for child in get_children():
		if child.name == "Part0" or child.name == "Part1" or child is Sprite2D:
			to_remove.append(child)
	
	for child in to_remove:
		if child.name != "Sprite2D":  # Keep the original Sprite2D
			print("PIG: Removing existing child:", child.name)
			child.queue_free()
	
	# The simplest approach - one sprite with both parts
	var front_part = Sprite2D.new()
	front_part.texture = front_texture  # Use the front texture for the whole pig
	front_part.name = "FrontPart"
	add_child(front_part)
	
	# Create another sprite for the back part
	var back_part = Sprite2D.new()
	back_part.texture = back_texture
	back_part.name = "BackPart"
	back_part.position = Vector2(grid.CELL_SIZE, 0)
	add_child(back_part)
	
	print("PIG: Created simple sprites directly")
	parts = [front_part, back_part]  # Store in parts array for compatibility
	
	# Update orientation right away
	update_part_positions()

func initialize_multi_cell():
	print("PIG: initialize_multi_cell called")
	
	# Skip the normal initialization - we'll do it manually
	if parts.size() < 2:
		print("PIG: Parts array is empty, will create sprites manually")
		force_create_sprites()
	else:
		print("PIG: Parts already created, count:", parts.size())
		update_part_positions()

# Update visual positions of all parts based on grid_pos and facing direction
func update_part_positions():
	print("PIG: update_part_positions called, parts count:", parts.size())
	
	# Ensure parts exist
	if parts.size() < 2:
		print("PIG ERROR: Parts not initialized properly")
		return
		
	# Get references to the front and back parts
	var front_part = parts[0]
	var back_part = parts[1]
	
	# Ensure visibility
	if not front_part_eaten:
		front_part.visible = true
	if not back_part_eaten:
		back_part.visible = true
	
	# Reset rotations and flips
	front_part.rotation = 0
	back_part.rotation = 0
	front_part.flip_h = false
	back_part.flip_h = false
	
	# Apply transformations based on direction
	if facing_direction.x != 0:  # Horizontal orientation
		if facing_direction.x > 0:  # Facing right
			# Flip sprites horizontally
			front_part.flip_h = true
			back_part.flip_h = true
			
			# Swap positions
			front_part.position = Vector2(0, 0)
			back_part.position = Vector2(-grid.CELL_SIZE, 0)
		else:  # Facing left
			# Normal orientation
			front_part.position = Vector2(0, 0)
			back_part.position = Vector2(grid.CELL_SIZE, 0)
	else:  # Vertical orientation
		if facing_direction.y > 0:  # Facing down
			# Rotate both parts
			front_part.rotation = deg_to_rad(-90)
			back_part.rotation = deg_to_rad(-90)
			
			# Stack vertically
			front_part.position = Vector2(0, grid.CELL_SIZE)
			back_part.position = Vector2(0, 0)
		else:  # Facing up
			# Rotate both parts
			front_part.rotation = deg_to_rad(90)
			back_part.rotation = deg_to_rad(90)
			
			# Stack vertically
			front_part.position = Vector2(0, -grid.CELL_SIZE)
			back_part.position = Vector2(0, 0)
	
	print("PIG: Parts positioned - Front:", front_part.position, "visible:", front_part.visible)
	print("PIG: Parts positioned - Back:", back_part.position, "visible:", back_part.visible)

# This method just passes through to update_part_positions
func update_multi_cell_rotation():
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

# Get world part position override to handle vertical orientation
func get_world_part_position(base_pos, relative_pos):
	var world_pos = base_pos
	
	# For horizontal orientation
	if facing_direction.x != 0:
		if facing_direction.x > 0:  # Facing right (swapped positions)
			if relative_pos == Vector2i(0, 0):  # Front part
				world_pos += Vector2i(0, 0)
			elif relative_pos == Vector2i(1, 0):  # Back part
				world_pos += Vector2i(-1, 0)  # Back is now on the left
		else:  # Facing left (normal positions)
			world_pos += relative_pos
	else:  # For vertical orientation
		if facing_direction.y > 0:  # Facing down
			if relative_pos == Vector2i(1, 0):  # Back part
				world_pos += Vector2i(0, 1)
		else:  # Facing up
			if relative_pos == Vector2i(1, 0):  # Back part
				world_pos += Vector2i(0, -1)
	
	return world_pos

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

# Override handle_part_eaten to handle pig parts
func handle_part_eaten(pos):
	# Convert global position to local position relative to pig
	var local_pos = pos - grid_pos
	
	# Determine which part was eaten based on world position and orientation
	# This logic matches the get_world_part_position calculations
	if facing_direction.x != 0:  # Horizontal
		if facing_direction.x > 0:  # Facing right (positions swapped)
			if local_pos == Vector2i(0, 0):  # Front is on the left
				front_part_eaten = true
				if parts.size() > 0:
					parts[0].visible = false
			elif local_pos == Vector2i(-1, 0):  # Back is on the right
				back_part_eaten = true
				if parts.size() > 1:
					parts[1].visible = false
		else:  # Facing left (normal positions)
			if local_pos == Vector2i(0, 0):  # Front is on the left
				front_part_eaten = true
				if parts.size() > 0:
					parts[0].visible = false
			elif local_pos == Vector2i(1, 0):  # Back is on the right
				back_part_eaten = true
				if parts.size() > 1:
					parts[1].visible = false
	else:  # Vertical
		if facing_direction.y > 0:  # Facing down
			if local_pos == Vector2i(0, 0):  # Front is on top
				front_part_eaten = true
				if parts.size() > 0:
					parts[0].visible = false
			elif local_pos == Vector2i(0, 1):  # Back is on bottom
				back_part_eaten = true  
				if parts.size() > 1:
					parts[1].visible = false
		else:  # Facing up
			if local_pos == Vector2i(0, 0):  # Front is on bottom
				front_part_eaten = true
				if parts.size() > 0:
					parts[0].visible = false
			elif local_pos == Vector2i(0, -1):  # Back is on top
				back_part_eaten = true
				if parts.size() > 1:
					parts[1].visible = false
	
	# Set flags for damage state
	has_missing_parts = true
	can_move = false  # Stop movement for the current turn
	
	# Check if all parts are eaten
	if front_part_eaten and back_part_eaten:
		queue_free()
		
# Check all positions for resources to destroy (multi-cell animal)
func check_multi_cell_destroy_resources():
	# Safety check
	if grid == null or not is_multi_cell:
		return
		
	for part_pos in part_positions:
		var world_part_pos = get_world_part_position(grid_pos, part_pos)
		var collectible = check_collectible_at_position(world_part_pos)
		if collectible and can_destroy_resource(collectible):
			destroy_resource(collectible)
