# scripts/animals/cow.gd
extends Animal
class_name CowAnimal

var milk_proximity_range = 8 # Tiles to stay within milk
var move_counter = 0 # For moving every other turn

# Part-specific damage flags - declare at class level with default values
var part_1_1_eaten = false  # Bottom-left
var part_1_2_eaten = false  # Top-left
var part_2_1_eaten = false  # Bottom-right
var part_2_2_eaten = false  # Top-right

# Textures for different parts - declare at class level
var texture_1_1 = null  # Bottom-left
var texture_1_2 = null  # Top-left
var texture_2_1 = null  # Bottom-right
var texture_2_2 = null  # Top-right

# Previous facing direction to detect changes
var prev_facing_direction = Vector2i(0, 0)

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
	
	# Set initial facing direction
	facing_direction = Vector2i(-1, 0)  # Initially face left
	prev_facing_direction = facing_direction
	
	# Delay initialization to ensure proper setup
	call_deferred("manual_post_ready")

func manual_post_ready():
	# This is called after _ready to ensure proper initialization
	print("COW: Post-ready initialization")
	grid = get_node_or_null("/root/Main/Grid")
	if grid == null:
		print("COW: Grid reference still null!")
	else:
		print("COW: Grid reference valid")

func setup_sprite():
	# Load textures for each part with error handling
	texture_1_1 = load("res://assets/cow1-1.png")
	texture_1_2 = load("res://assets/cow1-2.png")
	texture_2_1 = load("res://assets/cow2-1.png")
	texture_2_2 = load("res://assets/cow2-2.png")
	
	print("COW: Textures loaded:", texture_1_1 != null, texture_1_2 != null, 
		  texture_2_1 != null, texture_2_2 != null)
	
	# Initially hide the main sprite since we'll use separate sprites for parts
	if has_node("Sprite2D"):
		$Sprite2D.visible = false
	
	# Try to force sprite creation here
	call_deferred("force_create_sprites")

func force_create_sprites():
	print("COW: Force creating sprites")
	
	# Remove any existing sprites first
	var to_remove = []
	for child in get_children():
		if child.name.begins_with("Part") or (child is Sprite2D and child.name != "Sprite2D"):
			to_remove.append(child)
	
	for child in to_remove:
		child.queue_free()
	
	# Create all four parts directly
	var part_1_1 = Sprite2D.new()
	part_1_1.texture = texture_1_1
	part_1_1.name = "Part1_1"
	part_1_1.position = Vector2(0, 0)  # Bottom-left
	add_child(part_1_1)
	
	var part_1_2 = Sprite2D.new()
	part_1_2.texture = texture_1_2
	part_1_2.name = "Part1_2"
	part_1_2.position = Vector2(0, -grid.CELL_SIZE)  # Top-left
	add_child(part_1_2)
	
	var part_2_1 = Sprite2D.new()
	part_2_1.texture = texture_2_1
	part_2_1.name = "Part2_1"
	part_2_1.position = Vector2(grid.CELL_SIZE, 0)  # Bottom-right
	add_child(part_2_1)
	
	var part_2_2 = Sprite2D.new()
	part_2_2.texture = texture_2_2
	part_2_2.name = "Part2_2"
	part_2_2.position = Vector2(grid.CELL_SIZE, -grid.CELL_SIZE)  # Top-right
	add_child(part_2_2)
	
	print("COW: Created parts directly")
	parts = [part_1_1, part_1_2, part_2_1, part_2_2]  # Store in parts array
	
	# Force initial orientation
	force_orientation()

func initialize_multi_cell():
	print("COW: initialize_multi_cell called")
	
	# Skip the normal initialization - we'll do it manually
	if parts.size() < 4:
		print("COW: Parts array is empty, will create sprites manually")
		force_create_sprites()
	else:
		print("COW: Parts already created, count:", parts.size())
		force_orientation()

# Force orientation based on facing_direction
func force_orientation():
	print("COW: Forcing orientation with facing direction:", facing_direction)
	
	# Ensure parts exist
	if parts.size() < 4:
		print("COW ERROR: Parts not initialized properly")
		return
	
	# Update visibility based on eaten state
	parts[0].visible = !part_1_1_eaten
	parts[1].visible = !part_1_2_eaten
	parts[2].visible = !part_2_1_eaten
	parts[3].visible = !part_2_2_eaten
	
	# Reset all transformations
	for part in parts:
		part.rotation = 0
		part.scale = Vector2(1, 1)
		part.flip_h = false
		part.flip_v = false
	
	# SWAP positions when facing right, similar to the pig
	if facing_direction.x > 0:  # Facing right
		# Flip all parts horizontally
		for part in parts:
			part.flip_h = true
		
		# Position the parts swapped left-to-right
		parts[0].position = Vector2(grid.CELL_SIZE, 0)       # Bottom-left becomes bottom-right
		parts[1].position = Vector2(grid.CELL_SIZE, -grid.CELL_SIZE)  # Top-left becomes top-right
		parts[2].position = Vector2(0, 0)                    # Bottom-right becomes bottom-left
		parts[3].position = Vector2(0, -grid.CELL_SIZE)      # Top-right becomes top-left
	else:  # Facing left (or any other direction)
		# Position the parts in normal layout
		parts[0].position = Vector2(0, 0)                    # Bottom-left
		parts[1].position = Vector2(0, -grid.CELL_SIZE)      # Top-left
		parts[2].position = Vector2(grid.CELL_SIZE, 0)       # Bottom-right
		parts[3].position = Vector2(grid.CELL_SIZE, -grid.CELL_SIZE)  # Top-right
	
	print("COW: Parts positioned based on facing direction:", facing_direction)
	print("COW: Part 0 position:", parts[0].position, "flip_h:", parts[0].flip_h)
	print("COW: Part 2 position:", parts[2].position, "flip_h:", parts[2].flip_h)

# Override update_facing_direction to track changes
func update_facing_direction(new_pos):
	print("COW: update_facing_direction called, old:", facing_direction, "new delta:", new_pos - grid_pos)
	
	prev_facing_direction = facing_direction
	
	# Call the parent method to update facing_direction
	super.update_facing_direction(new_pos)
	
	# Check if direction actually changed
	if prev_facing_direction != facing_direction:
		print("COW: Direction changed from", prev_facing_direction, "to", facing_direction)
		force_orientation()

# This method just forces our orientation
func update_multi_cell_rotation():
	print("COW: update_multi_cell_rotation called")
	force_orientation()

# This method ONLY affects what grid cells the cow occupies
func get_world_part_position(base_pos, relative_pos):
	# For cow's collision, we need to handle the flipped positions when facing right
	if facing_direction.x > 0:  # Facing right - we've swapped positions
		if relative_pos == Vector2i(0, 0):  # Bottom-left becomes bottom-right
			return base_pos + Vector2i(1, 0)
		elif relative_pos == Vector2i(0, -1):  # Top-left becomes top-right
			return base_pos + Vector2i(1, -1)
		elif relative_pos == Vector2i(1, 0):  # Bottom-right becomes bottom-left
			return base_pos + Vector2i(0, 0)
		elif relative_pos == Vector2i(1, -1):  # Top-right becomes top-left
			return base_pos + Vector2i(0, -1)
	
	# Default behavior for facing left (normal positions)
	return base_pos + relative_pos

# Modified movement function to call force_orientation() after position changes
func move():
	print("COW: move() called, current facing:", facing_direction)
	
	# Standard movement code from before
	if not can_move:
		return
		
	# Apply movement pattern based on damage state
	var is_slow = (self.part_1_1_eaten or self.part_2_1_eaten) and not (self.part_1_1_eaten and self.part_2_1_eaten)
	var is_fast = (self.part_1_2_eaten or self.part_2_2_eaten) and not (self.part_1_1_eaten and self.part_2_1_eaten and self.part_1_2_eaten and self.part_2_2_eaten)
	
	# Count movement cycles
	move_counter += 1
	
	# Implement movement pattern based on damage
	if is_slow:
		if move_counter % 2 != 0:
			return
	elif not is_fast:
		if move_counter % 2 != 0:
			return
	
	# Safety checks
	if grid == null or main == null or snake == null:
		return
		
	var snake_head_pos = snake.segments[0].grid_pos
	var new_pos = grid_pos
	
	# Determine movement based on damage state
	if (not self.part_1_2_eaten) and (not self.part_2_2_eaten):
		new_pos = move_based_on_milk(grid_pos)
	else:
		new_pos = move_recklessly(grid_pos, is_fast)
	
	# If about to move, log it
	if new_pos != grid_pos:
		print("COW: About to move from", grid_pos, "to", new_pos)
		
	# Update facing direction and position
	if new_pos != grid_pos:
		update_facing_direction(new_pos)
		check_multi_cell_destroy_resources()
		grid_pos = new_pos
		position = grid.grid_to_world(grid_pos)
		
		# Force orientation again to be absolutely sure
		force_orientation()

# Rest of the functions remain unchanged...
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
	
	# Determine which part was eaten based on facing direction
	if facing_direction.x > 0:  # Facing right - positions are swapped
		if local_pos == Vector2i(1, 0):  # Bottom-right position (visually bottom-left)
			self.part_1_1_eaten = true
			if parts.size() > 0:
				parts[0].visible = false
		elif local_pos == Vector2i(1, -1):  # Top-right position (visually top-left)
			self.part_1_2_eaten = true
			if parts.size() > 1:
				parts[1].visible = false
		elif local_pos == Vector2i(0, 0):  # Bottom-left position (visually bottom-right)
			self.part_2_1_eaten = true
			if parts.size() > 2:
				parts[2].visible = false
		elif local_pos == Vector2i(0, -1):  # Top-left position (visually top-right)
			self.part_2_2_eaten = true
			if parts.size() > 3:
				parts[3].visible = false
	else:  # Facing left - normal positions
		if local_pos == Vector2i(0, 0):  # Bottom-left
			self.part_1_1_eaten = true
			if parts.size() > 0:
				parts[0].visible = false
		elif local_pos == Vector2i(0, -1):  # Top-left
			self.part_1_2_eaten = true
			if parts.size() > 1:
				parts[1].visible = false
		elif local_pos == Vector2i(1, 0):  # Bottom-right
			self.part_2_1_eaten = true
			if parts.size() > 2:
				parts[2].visible = false
		elif local_pos == Vector2i(1, -1):  # Top-right
			self.part_2_2_eaten = true
			if parts.size() > 3:
				parts[3].visible = false
	
	# Set flags for damage state
	has_missing_parts = true
	can_move = false  # Stop movement for the current turn
	
	# Check if all parts are eaten
	if self.part_1_1_eaten and self.part_1_2_eaten and self.part_2_1_eaten and self.part_2_2_eaten:
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
