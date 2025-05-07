# scripts/animals/cow.gd
extends Animal
class_name CowAnimal

var milk_proximity_range = 8 # Tiles to stay within milk
var move_counter = 0 # For moving every other turn

# Part-specific damage flags
var part_1_1_eaten = false  # Bottom-left
var part_1_2_eaten = false  # Top-left
var part_2_1_eaten = false  # Bottom-right
var part_2_2_eaten = false  # Top-right

# Textures for different parts
var texture_1_1  # Bottom-left
var texture_1_2  # Top-left
var texture_2_1  # Bottom-right
var texture_2_2  # Top-right

func _ready():
	super()
	type = "cow"
	movement_behavior = "wander"
	destroys = ["wheat", "tomato", "lettuce", "egg"] # Resources cow destroys (no milk!)
	
	# Set up as multi-cell animal
	is_multi_cell = true
	size = Vector2i(2, 2)  # 2x2 grid cells
	
	# Initialize multi-cell parameters
	part_positions = [
		Vector2i(0, 0),  # Bottom-left (1-1)
		Vector2i(0, 1),  # Top-left (1-2)
		Vector2i(1, 0),  # Bottom-right (2-1)
		Vector2i(1, 1)   # Top-right (2-2)
	]
	main_pivot = Vector2i(0, 0)  # Bottom-left is main pivot

func setup_sprite():
	# We use a custom sprite setup for multi-cell animals
	# Main node will have no sprite, instead we create child nodes
	
	# Load part textures
	texture_1_1 = load("res://assets/cow1-1.png")
	texture_1_2 = load("res://assets/cow1-2.png")
	texture_2_1 = load("res://assets/cow2-1.png")
	texture_2_2 = load("res://assets/cow2-2.png")
	
	# Create part nodes
	initialize_multi_cell()

func initialize_multi_cell():
	# Create part sprites
	parts.clear()
	
	# Create bottom-left part (1-1)
	var part_1_1 = Sprite2D.new()
	part_1_1.texture = texture_1_1
	part_1_1.name = "Cow1-1"
	part_1_1.position = Vector2(0, 0)  # Local position
	add_child(part_1_1)
	parts.append(part_1_1)
	
	# Create top-left part (1-2)
	var part_1_2 = Sprite2D.new()
	part_1_2.texture = texture_1_2
	part_1_2.name = "Cow1-2"
	part_1_2.position = Vector2(0, -grid.CELL_SIZE)  # Position above bottom-left
	add_child(part_1_2)
	parts.append(part_1_2)
	
	# Create bottom-right part (2-1)
	var part_2_1 = Sprite2D.new()
	part_2_1.texture = texture_2_1
	part_2_1.name = "Cow2-1"
	part_2_1.position = Vector2(grid.CELL_SIZE, 0)  # Position to right of bottom-left
	add_child(part_2_1)
	parts.append(part_2_1)
	
	# Create top-right part (2-2)
	var part_2_2 = Sprite2D.new()
	part_2_2.texture = texture_2_2
	part_2_2.name = "Cow2-2"
	part_2_2.position = Vector2(grid.CELL_SIZE, -grid.CELL_SIZE)  # Position diagonal from bottom-left
	add_child(part_2_2)
	parts.append(part_2_2)
	
	# Update initial appearance
	update_multi_cell_rotation()

func move():
	# Don't move if we've been eaten
	if not can_move:
		return
	
	# Apply movement pattern based on damage state
	var is_slow = (part_1_1_eaten or part_2_1_eaten) and not (part_1_1_eaten and part_2_1_eaten)
	var is_fast = (part_1_2_eaten or part_2_2_eaten) and not (part_1_1_eaten and part_2_1_eaten and part_1_2_eaten and part_2_2_eaten)
	
	# Count movement cycles
	move_counter += 1
	
	# Implement movement pattern based on damage
	if is_slow:
		# Move every 2nd turn (half speed)
		if move_counter % 2 != 0:
			return
	elif not is_fast:
		# Normal cow moves every other turn
		if move_counter % 2 != 0:
			return
	# Fast cow (when top parts are eaten) moves every turn, no counter check needed
	
	var snake_head_pos = snake.segments[0].grid_pos
	var new_pos = grid_pos
	
	# Determine movement based on damage state
	if (not part_1_2_eaten) and (not part_2_2_eaten):
		# Normal movement - follow milk
		new_pos = move_based_on_milk(grid_pos)
	else:
		# Fast reckless movement if top parts are eaten
		new_pos = move_recklessly(grid_pos, is_fast)
	
	# Update facing direction and position
	if new_pos != grid_pos:
		update_facing_direction(new_pos)
		
		# Check and destroy resources the cow steps on
		check_multi_cell_destroy_resources()
		
		grid_pos = new_pos
		update_part_positions()

# Update visual positions of all parts based on grid_pos and rotation
func update_part_positions():
	# Don't update parts that have been eaten
	if part_1_1_eaten and parts.size() > 0:
		parts[0].hide()
	if part_1_2_eaten and parts.size() > 1:
		parts[1].hide()
	if part_2_1_eaten and parts.size() > 2:
		parts[2].hide()
	if part_2_2_eaten and parts.size() > 3:
		parts[3].hide()
	
	# Update positions of remaining parts
	for i in range(parts.size()):
		if (i == 0 and part_1_1_eaten) or (i == 1 and part_1_2_eaten) or \
		   (i == 2 and part_2_1_eaten) or (i == 3 and part_2_2_eaten):
			continue
			
		var part_pos = part_positions[i]
		var world_part_pos = get_world_part_position(grid_pos, part_pos)
		var pixel_pos = grid.grid_to_world(world_part_pos)
		parts[i].position = pixel_pos - position  # Convert to local position

# Cow movement: follows milk if top parts intact, moves recklessly if top parts eaten
func move_based_on_milk(curr_pos):
	# Find nearest milk
	var nearest_milk = find_nearest_milk()
	var min_distance = 999999
	
	if nearest_milk:
		var milk_pos = grid.world_to_grid(nearest_milk.position)
		min_distance = (milk_pos - curr_pos).length()
		
		# If too far from milk, move toward it
		if min_distance > milk_proximity_range:
			# Calculate the direction vector
			var diff = milk_pos - curr_pos
			var move_dir = Vector2i()
			
			# Choose the primary direction (horizontal or vertical)
			if abs(diff.x) > abs(diff.y):
				move_dir.x = 1 if diff.x > 0 else -1
			else:
				move_dir.y = 1 if diff.y > 0 else -1
			
			# Try to move in the chosen direction
			var next_pos = curr_pos + move_dir
			if is_multi_cell_position_valid(next_pos):
				return next_pos
			
			# If primary direction fails, try the secondary
			move_dir = Vector2i()
			if abs(diff.x) <= abs(diff.y):
				move_dir.x = 1 if diff.x > 0 else -1
			else:
				move_dir.y = 1 if diff.y > 0 else -1
				
			next_pos = curr_pos + move_dir
			if is_multi_cell_position_valid(next_pos):
				return next_pos
		else:
			# If close enough to milk, move randomly but stay in range
			var directions = [
				Vector2i(1, 0),   # Right
				Vector2i(-1, 0),  # Left
				Vector2i(0, 1),   # Down
				Vector2i(0, -1)   # Up
			]
			
			# Shuffle directions
			directions.shuffle()
			
			# Choose first direction that keeps cow within range of milk
			for dir in directions:
				var new_pos = curr_pos + dir
				if is_multi_cell_position_valid(new_pos):
					# Check if the new position is still within range of milk
					var new_distance = (new_pos - milk_pos).length()
					if new_distance <= milk_proximity_range:
						return new_pos
	
	# If no milk found or can't move toward milk, move randomly
	return move_recklessly(curr_pos, false)

# When top parts are eaten, cow moves recklessly in a random valid direction
func move_recklessly(curr_pos, is_fast):
	var directions = [
		Vector2i(1, 0),   # Right
		Vector2i(-1, 0),  # Left
		Vector2i(0, 1),   # Down
		Vector2i(0, -1)   # Up
	]
	
	# Shuffle directions
	directions.shuffle()
	
	# For fast movement (top parts eaten), try to move multiple steps
	var steps = 4 if is_fast else 1
	
	# Try each direction with the specified number of steps
	for dir in directions:
		var new_pos = curr_pos + (dir * steps)
		if is_multi_cell_position_valid(new_pos):
			return new_pos
		
		# If we can't move the full distance, try a shorter one
		if steps > 1:
			new_pos = curr_pos + (dir * (steps / 2))
			if is_multi_cell_position_valid(new_pos):
				return new_pos
				
			# Try a single step as last resort
			new_pos = curr_pos + dir
			if is_multi_cell_position_valid(new_pos):
				return new_pos
	
	# If all else fails, just stay put
	return curr_pos

# Find the nearest milk resource
func find_nearest_milk():
	var collectibles_node = main.get_node("Collectibles")
	var nearest_milk = null
	var min_distance = 999999
	
	for collectible in collectibles_node.get_children():
		if collectible.resource_type == "milk":
			var milk_pos = grid.world_to_grid(collectible.position)
			var distance = (milk_pos - grid_pos).length()
			if distance < min_distance:
				min_distance = distance
				nearest_milk = collectible
	
	return nearest_milk

# Override to handle multi-cell rotation
func update_multi_cell_rotation():
	# Cow only rotates for left/right, not up/down (as specified)
	# This makes it always appear as a 2x2 square regardless of facing direction
	
	# Reset all rotations and flips
	for part in parts:
		part.rotation = 0
		part.flip_h = false
		part.flip_v = false
	
	if facing_direction.x > 0:  # Right
		# Flip horizontally
		for part in parts:
			part.flip_h = true
	elif facing_direction.x < 0:  # Left
		# Default cow orientation is facing left - no change needed
		pass
	
	# For up/down, we keep the same visual appearance but update part positions
	# to account for the direction of movement
	
	# Update positions of parts
	update_part_positions()

# Handle part eaten
func handle_part_eaten(pos):
	var world_part_pos = get_world_part_position(grid_pos, Vector2i(0, 0))
	var offset = pos - world_part_pos
	
	# Check which part was eaten based on its relative position
	if offset == Vector2i(0, 0):  # Bottom-left (1-1)
		part_1_1_eaten = true
		parts[0].visible = false
		has_missing_parts = true
	elif offset == Vector2i(0, -1) or offset == Vector2i(0, 1):  # Top-left (1-2)
		part_1_2_eaten = true
		parts[1].visible = false
		has_missing_parts = true
	elif offset == Vector2i(1, 0):  # Bottom-right (2-1)
		part_2_1_eaten = true
		parts[2].visible = false
		has_missing_parts = true
	elif offset == Vector2i(1, -1) or offset == Vector2i(1, 1):  # Top-right (2-2)
		part_2_2_eaten = true
		parts[3].visible = false
		has_missing_parts = true
	
	# If all parts eaten, queue_free the whole animal
	if part_1_1_eaten and part_1_2_eaten and part_2_1_eaten and part_2_2_eaten:
		queue_free()
		return
	
	# Apply appropriate behavior changes
	can_move = false  # Stop movement for the turn
	move_counter = 0  # Reset movement counter
