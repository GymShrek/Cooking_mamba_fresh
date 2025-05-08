# scripts/animals/cow.gd
extends Node2D

class_name CowAnimal

# Basic properties - mirrors what Animal class would have
var type = "cow"
var grid_pos = Vector2i()
var facing_direction = Vector2i(1, 0)
var movement_behavior = "wander"
var current_dir = Vector2i(1, 0)
var destroys = ["wheat", "tomato", "lettuce", "egg"] # Resources cow destroys (no milk!)
var detection_range = 8
var milk_proximity_range = 8 # Tiles to stay within milk

# Multi-cell specific properties
var is_multi_cell = true
var size = Vector2i(2, 2)  # 2x2 grid cells
var part_positions = []
var parts = []
var main_pivot = Vector2i(0, 0)
var has_missing_parts = false
var can_move = true
var move_cooldown = 0
var move_counter = 0 # For moving every other turn

# Part-specific damage flags - declare at class level with default values
var part_1_1_eaten = false  # Bottom-left
var part_1_2_eaten = false  # Top-left
var part_2_1_eaten = false  # Bottom-right
var part_2_2_eaten = false  # Top-right

# The property that was causing the error in pig
var animals = []

# References to game nodes
var grid
var main
var snake

func _ready():
	# Initialize references
	main = get_tree().get_root().get_node("Main")
	if main:
		grid = main.get_node("Grid")
		snake = main.get_node("Snake")
	
	# Initialize part positions
	part_positions = [
		Vector2i(0, 0),  # Bottom-left (1-1)
		Vector2i(0, -1), # Top-left (1-2)
		Vector2i(1, 0),  # Bottom-right (2-1)
		Vector2i(1, -1)  # Top-right (2-2)
	]
	
	# Create sprite parts
	create_sprites()
	
	# Debug info
	print("Cow initialized, parts:", parts.size())

func create_sprites():
	# Clear any existing sprites
	for child in get_children():
		if child.name.begins_with("Part"):
			child.queue_free()
	
	parts.clear()
	
	# Create main sprite (for compatibility)
	if not has_node("Sprite2D"):
		var main_sprite = Sprite2D.new()
		main_sprite.name = "Sprite2D"
		main_sprite.visible = false
		add_child(main_sprite)
	else:
		$Sprite2D.visible = false
	
	# Create the four parts
	var part_1_1 = Sprite2D.new()
	part_1_1.texture = load("res://assets/cow1-1.png")
	part_1_1.name = "Part0"
	add_child(part_1_1)
	parts.append(part_1_1)
	
	var part_1_2 = Sprite2D.new()
	part_1_2.texture = load("res://assets/cow1-2.png")
	part_1_2.name = "Part1"
	add_child(part_1_2)
	parts.append(part_1_2)
	
	var part_2_1 = Sprite2D.new()
	part_2_1.texture = load("res://assets/cow2-1.png")
	part_2_1.name = "Part2"
	add_child(part_2_1)
	parts.append(part_2_1)
	
	var part_2_2 = Sprite2D.new()
	part_2_2.texture = load("res://assets/cow2-2.png")
	part_2_2.name = "Part3"
	add_child(part_2_2)
	parts.append(part_2_2)
	
	# Update positions
	update_part_positions()
	
	# Debug info
	print("Cow textures loaded:", 
		  parts[0].texture != null, 
		  parts[1].texture != null,
		  parts[2].texture != null,
		  parts[3].texture != null)

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
		new_pos = move_based_on_milk()
	else:
		# Fast reckless movement if top parts are eaten
		new_pos = move_recklessly(is_fast)
	
	# Update facing direction and position
	if new_pos != grid_pos:
		update_facing_direction(new_pos)
		
		# Check for and destroy any collectibles at new positions
		check_destroy_resources()
		
		grid_pos = new_pos
		position = grid.grid_to_world(grid_pos)
		update_part_positions()

# Update visual positions of all parts based on grid_pos
func update_part_positions():
	# Safety check
	if parts.size() < 4:
		print("Warning: Not enough parts for cow:", parts.size())
		return
		
	# Safety check for grid
	if grid == null:
		print("Warning: Grid is null in update_part_positions")
		return
	
	# Get cell size
	var cell_size = grid.CELL_SIZE
	if cell_size == 0:
		cell_size = 32  # Fallback value
	
	# Update part visibilities
	parts[0].visible = !part_1_1_eaten
	parts[1].visible = !part_1_2_eaten
	parts[2].visible = !part_2_1_eaten
	parts[3].visible = !part_2_2_eaten
	
	# Position each part
	parts[0].position = Vector2(0, 0)  # Bottom-left
	parts[1].position = Vector2(0, -cell_size)  # Top-left
	parts[2].position = Vector2(cell_size, 0)  # Bottom-right
	parts[3].position = Vector2(cell_size, -cell_size)  # Top-right
	
	# Apply horizontal flipping if facing right
	if facing_direction.x > 0:
		for part in parts:
			part.flip_h = true
	else:
		for part in parts:
			part.flip_h = false

func update_facing_direction(new_pos):
	if new_pos != grid_pos:
		facing_direction = new_pos - grid_pos

# Cow movement: follows milk if top parts intact, moves recklessly if top parts eaten
func move_based_on_milk():
	# Find nearest milk
	var nearest_milk = find_nearest_milk()
	var min_distance = 999999
	
	if nearest_milk:
		var milk_pos = grid.world_to_grid(nearest_milk.position)
		min_distance = (milk_pos - grid_pos).length()
		
		# If too far from milk, move toward it
		if min_distance > milk_proximity_range:
			# Calculate the direction vector
			var diff = milk_pos - grid_pos
			var move_dir = Vector2i()
			
			# Choose the primary direction (horizontal or vertical)
			if abs(diff.x) > abs(diff.y):
				move_dir.x = 1 if diff.x > 0 else -1
			else:
				move_dir.y = 1 if diff.y > 0 else -1
			
			# Try to move in the chosen direction
			var next_pos = grid_pos + move_dir
			if is_multi_cell_position_valid(next_pos):
				return next_pos
			
			# If primary direction fails, try the secondary
			move_dir = Vector2i()
			if abs(diff.x) <= abs(diff.y):
				move_dir.x = 1 if diff.x > 0 else -1
			else:
				move_dir.y = 1 if diff.y > 0 else -1
				
			next_pos = grid_pos + move_dir
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
				var new_pos = grid_pos + dir
				if is_multi_cell_position_valid(new_pos):
					# Check if the new position is still within range of milk
					var new_distance = (new_pos - milk_pos).length()
					if new_distance <= milk_proximity_range:
						return new_pos
	
	# If no milk found or can't move toward milk, move randomly
	return move_recklessly(false)

# When top parts are eaten, cow moves recklessly in a random valid direction
func move_recklessly(is_fast):
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
		var new_pos = grid_pos + (dir * steps)
		if is_multi_cell_position_valid(new_pos):
			return new_pos
		
		# If we can't move the full distance, try a shorter one
		if steps > 1:
			new_pos = grid_pos + dir
			if is_multi_cell_position_valid(new_pos):
				return new_pos
	
	# If all else fails, just stay put
	return grid_pos

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
		if "resource_type" in collectible and collectible.resource_type == "milk":
			var milk_pos = grid.world_to_grid(collectible.position)
			var distance = (milk_pos - grid_pos).length()
			if distance < min_distance:
				min_distance = distance
				nearest_milk = collectible
	
	return nearest_milk

# Check if a position is valid for movement
func is_position_valid(pos):
	# Safety check
	if grid == null:
		return false
	
	# Check if within grid bounds and not a wall
	if not grid.is_cell_vacant(pos):
		return false
	
	# Check for collision with snake
	if snake:
		for segment in snake.segments:
			if segment.grid_pos == pos:
				return false
	
	return true

# Check if a multi-cell position is valid
func is_multi_cell_position_valid(base_pos):
	# For multi-cell animals, check every cell they would occupy
	for part_pos in part_positions:
		var world_part_pos = get_world_part_position(base_pos, part_pos)
		if not is_position_valid(world_part_pos):
			return false
	return true

# Get world part position 
func get_world_part_position(base_pos, relative_pos):
	return base_pos + relative_pos

# Find the nearest resource that this animal can destroy
func find_nearest_destroyable_resource():
	if main == null or grid == null:
		return null
		
	var collectibles_node = main.get_node_or_null("Collectibles")
	if collectibles_node == null:
		return null
		
	var nearest_resource = null
	var min_distance = detection_range + 1  # Beyond our search range
	
	# Check all collectibles
	for collectible in collectibles_node.get_children():
		# Skip if not a destroyable resource - use property check instead of has() method
		if not ("resource_type" in collectible) or not destroys.has(collectible.resource_type):
			continue
		
		var resource_pos = grid.world_to_grid(collectible.position)
		var distance = (resource_pos - grid_pos).length()
		
		if distance < min_distance:
			min_distance = distance
			nearest_resource = collectible
	
	return nearest_resource

# Check all positions for resources to destroy
func check_destroy_resources():
	if grid == null or main == null:
		return
		
	var positions = []
	for part_pos in part_positions:
		positions.append(grid_pos + part_pos)
	
	# Check each position for collectibles
	var collectibles_node = main.get_node_or_null("Collectibles")
	if collectibles_node:
		for collectible in collectibles_node.get_children():
			var collectible_pos = grid.world_to_grid(collectible.position)
			# Use property check instead of has() method
			if positions.has(collectible_pos) and "resource_type" in collectible and destroys.has(collectible.resource_type):
				# Create sparkle effect
				main.create_sparkle_effect(collectible.position)
				# Remove the collectible
				collectible.queue_free()

# Handle when part is eaten
func handle_part_eaten(pos):
	# Convert global position to local position relative to cow
	var local_pos = pos - grid_pos
	
	print("Cow part eaten at local position:", local_pos)
	
	# Determine which part was eaten based on local position
	if local_pos == Vector2i(0, 0):
		part_1_1_eaten = true
		parts[0].visible = false
	elif local_pos == Vector2i(0, -1):
		part_1_2_eaten = true
		parts[1].visible = false
	elif local_pos == Vector2i(1, 0):
		part_2_1_eaten = true
		parts[2].visible = false
	elif local_pos == Vector2i(1, -1):
		part_2_2_eaten = true
		parts[3].visible = false
	
	# Set flags for damage state
	has_missing_parts = true
	can_move = false  # Stop movement for the current turn
	
	# Check if all parts are eaten
	if part_1_1_eaten and part_1_2_eaten and part_2_1_eaten and part_2_2_eaten:
		queue_free()
