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
	
	# Initialize multi-cell parameters - define the relative positions of each part
	part_positions = [
		Vector2i(0, 0),  # Bottom-left (1-1)
		Vector2i(0, -1), # Top-left (1-2)
		Vector2i(1, 0),  # Bottom-right (2-1)
		Vector2i(1, -1)  # Top-right (2-2)
	]
	main_pivot = Vector2i(0, 0)  # Bottom-left is main pivot

func setup_sprite():
	# Load textures for each part
	texture_1_1 = load("res://assets/cow1-1.png")
	texture_1_2 = load("res://assets/cow1-2.png")
	texture_2_1 = load("res://assets/cow2-1.png")
	texture_2_2 = load("res://assets/cow2-2.png")
	
	# Initially hide the main sprite since we'll use separate sprites for parts
	if has_node("Sprite2D"):
		$Sprite2D.visible = false

func initialize_multi_cell():
	# Create array of textures for the parts
	var textures = [texture_1_1, texture_1_2, texture_2_1, texture_2_2]
	
	# Create positions array for initialization
	var positions = [
		Vector2i(0, 0),       # Bottom-left at (0,0)
		Vector2i(0, -1),      # Top-left at (0,-1)
		Vector2i(1, 0),       # Bottom-right at (1,0)
		Vector2i(1, -1)       # Top-right at (1,-1)
	]
	
	# Initialize the multi-cell sprites
	initialize_multi_cell_sprites(textures, positions)
	
	# Update initial appearance
	update_part_positions()

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
	
	# Safety checks
	if grid == null or main == null or snake == null:
		return
	
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
		position = grid.grid_to_world(grid_pos)
		update_part_positions()

# Update visual positions of all parts based on grid_pos and rotation
func update_part_positions():
	# First update the main position
	position = grid.grid_to_world(grid_pos)
	
	# Update part positions based on relative positions and facing direction
	for i in range(parts.size()):
		# Skip parts that have been eaten
		if (i == 0 and part_1_1_eaten) or \
		   (i == 1 and part_1_2_eaten) or \
		   (i == 2 and part_2_1_eaten) or \
		   (i == 3 and part_2_2_eaten):
			parts[i].visible = false
			continue
			
		parts[i].visible = true
		
		# Position each part relative to the main node
		var local_pos = Vector2.ZERO
		match i:
			0: # Bottom-left
				local_pos = Vector2(0, 0)
			1: # Top-left 
				local_pos = Vector2(0, -grid.CELL_SIZE)
			2: # Bottom-right
				local_pos = Vector2(grid.CELL_SIZE, 0)
			3: # Top-right
				local_pos = Vector2(grid.CELL_SIZE, -grid.CELL_SIZE)
		
		parts[i].position = local_pos

# Override to handle multi-cell rotation
func update_multi_cell_rotation():
	# Set all parts to correct visuals based on facing direction
	for part in parts:
		part.rotation = 0
		part.flip_h = false
		part.flip_v = false
	
	if facing_direction.x > 0:  # Right
		# Flip horizontally for all parts
		for part in parts:
			part.flip_h = true
	# For all other directions, we keep the default appearance
	
	# Update the positions of all parts
	update_part_positions()

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
	var steps = 2 if is_fast else 1
	
	# Try each direction with the specified number of steps
	for dir in directions:
		var new_pos = curr_pos + (dir * steps)
		if is_multi_cell_position_valid(new_pos):
			return new_pos
		
		# If we can't move the full distance, try a shorter one
		if steps > 1:
			new_pos = curr_pos + dir
			if is_multi_cell_position_valid(new_pos):
				return new_pos
	
	# If all else fails, just stay put
	return curr_pos

# Find the nearest milk resource
func find_nearest_milk():
	if main == null:
		return null
		
	var collectibles_node = main.get_node_or_null("Collectibles")
	if collectibles_node == null:
		return null
		
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

# Override handle_part_eaten to properly handle cow parts
func handle_part_eaten(pos):
	# Convert global position to local position relative to cow
	var local_pos = pos - grid_pos
	
	# Determine which part was eaten based on local position
	if local_pos == Vector2i(0, 0):
		part_1_1_eaten = true
		if parts.size() > 0:
			parts[0].visible = false
	elif local_pos == Vector2i(0, -1):
		part_1_2_eaten = true
		if parts.size() > 1:
			parts[1].visible = false
	elif local_pos == Vector2i(1, 0):
		part_2_1_eaten = true
		if parts.size() > 2:
			parts[2].visible = false
	elif local_pos == Vector2i(1, -1):
		part_2_2_eaten = true
		if parts.size() > 3:
			parts[3].visible = false
	
	# Set flags for damage state
	has_missing_parts = true
	can_move = false  # Stop movement for the current turn
	
	# Check if all parts are eaten
	if part_1_1_eaten and part_1_2_eaten and part_2_1_eaten and part_2_2_eaten:
		queue_free()
