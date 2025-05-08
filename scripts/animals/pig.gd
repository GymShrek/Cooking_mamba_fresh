# scripts/animals/pig.gd
extends Node2D

class_name PigAnimal

# Basic properties - mirrors what Animal class would have
var type = "pig"
var grid_pos = Vector2i()
var facing_direction = Vector2i(1, 0)
var movement_behavior = "linear"
var current_dir = Vector2i(1, 0)
var destroys = ["milk", "tomato", "lettuce", "wheat", "egg"]
var detection_range = 8

# Multi-cell specific properties
var is_multi_cell = true
var size = Vector2i(2, 1)  # 2 cells wide, 1 cell high
var part_positions = []
var parts = []
var main_pivot = Vector2i(0, 0)
var has_missing_parts = false
var can_move = true
var move_cooldown = 0
var front_part_eaten = false
var back_part_eaten = false

# The property that was causing the error
var animals = []

# For flying state (chicken compatibility)
var is_flying = false

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
		Vector2i(0, 0),  # Front part
		Vector2i(1, 0)   # Back part
	]
	
	# Create sprite parts
	create_sprites()
	
	# Debug info
	print("Pig initialized, parts:", parts.size())

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
	
	# Create front part
	var front_sprite = Sprite2D.new()
	front_sprite.texture = load("res://assets/pig1-1.png")
	front_sprite.name = "Part0"
	add_child(front_sprite)
	parts.append(front_sprite)
	
	# Create back part
	var back_sprite = Sprite2D.new()
	back_sprite.texture = load("res://assets/pig2-1.png")
	back_sprite.name = "Part1"
	add_child(back_sprite)
	parts.append(back_sprite)
	
	# Update positions
	update_part_positions()
	
	# Debug info
	print("Pig sprites created:", parts.size())
	print("Front texture:", parts[0].texture != null)
	print("Back texture:", parts[1].texture != null)

func move():
	# Don't move if we've been eaten or can't move
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
		var nearest_resource = find_nearest_destroyable_resource()
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
			check_destroy_resources()
		
		grid_pos = new_pos
		position = grid.grid_to_world(grid_pos)
		update_part_positions()

func update_part_positions():
	# Safety check
	if parts.size() < 2:
		print("Warning: Not enough parts for pig:", parts.size())
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
	if front_part_eaten:
		parts[0].visible = false
	else:
		parts[0].visible = true
		
	if back_part_eaten:
		parts[1].visible = false
	else:
		parts[1].visible = true
	
	# Position the parts based on facing direction
	if facing_direction.x != 0:  # Horizontal orientation
		parts[0].position = Vector2(0, 0)
		parts[0].rotation = 0
		parts[1].position = Vector2(cell_size, 0)
		parts[1].rotation = 0
		
		# Apply horizontal flipping if facing right
		for part in parts:
			part.flip_h = (facing_direction.x > 0)
			part.flip_v = false
	else:  # Vertical orientation
		parts[0].position = Vector2(0, 0)
		parts[0].rotation = deg_to_rad(90) if facing_direction.y > 0 else deg_to_rad(-90)
		parts[1].position = Vector2(0, cell_size) if facing_direction.y > 0 else Vector2(0, -cell_size)
		parts[1].rotation = deg_to_rad(90) if facing_direction.y > 0 else deg_to_rad(-90)
		
		# Reset flips for vertical orientation
		for part in parts:
			part.flip_h = false
			part.flip_v = false

func update_facing_direction(new_pos):
	if new_pos != grid_pos:
		facing_direction = new_pos - grid_pos

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
	var world_pos = base_pos
	
	# For horizontal orientation
	if facing_direction.x != 0:
		world_pos += relative_pos
	else:  # For vertical orientation
		# When vertical, the pig is 1x2 instead of 2x1
		if relative_pos.x == 1:  # Back part
			world_pos += Vector2i(0, 1) if facing_direction.y > 0 else Vector2i(0, -1)
	
	return world_pos

# Helper function to move toward a target position
func move_toward_pos(curr_pos, target_pos):
	var diff = target_pos - curr_pos
	var move_dir = Vector2i()
	
	# Choose the primary direction (horizontal or vertical)
	if abs(diff.x) > abs(diff.y):
		move_dir.x = 1 if diff.x > 0 else -1
	else:
		move_dir.y = 1 if diff.y > 0 else -1
	
	var next_pos = curr_pos + move_dir
	
	# Check if the move is valid
	if is_multi_cell_position_valid(next_pos):
		return next_pos
	
	# Try the other direction if primary is blocked
	move_dir = Vector2i()
	if abs(diff.x) <= abs(diff.y):
		move_dir.x = 1 if diff.x > 0 else -1
	else:
		move_dir.y = 1 if diff.y > 0 else -1
	
	next_pos = curr_pos + move_dir
	
	# Check if the move is valid
	if is_multi_cell_position_valid(next_pos):
		return next_pos
	
	return curr_pos  # Stay in place if no valid moves

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
		
	var positions = [grid_pos]
	
	# Check the back position based on orientation
	if facing_direction.x != 0:
		positions.append(Vector2i(grid_pos.x + facing_direction.x, grid_pos.y))
	else:
		positions.append(Vector2i(grid_pos.x, grid_pos.y + facing_direction.y))
	
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
	# Convert global position to local position relative to pig
	var local_pos = pos - grid_pos
	
	print("Pig part eaten at local position:", local_pos)
	
	# For horizontal orientation
	if facing_direction.x != 0:
		if local_pos == Vector2i(0, 0):
			front_part_eaten = true
			if parts.size() > 0:
				parts[0].visible = false
		elif local_pos == Vector2i(1, 0) or local_pos == Vector2i(-1, 0):
			back_part_eaten = true
			if parts.size() > 1:
				parts[1].visible = false
	else:  # For vertical orientation
		if local_pos == Vector2i(0, 0):
			front_part_eaten = true
			if parts.size() > 0:
				parts[0].visible = false
		elif local_pos == Vector2i(0, 1) or local_pos == Vector2i(0, -1):
			back_part_eaten = true
			if parts.size() > 1:
				parts[1].visible = false
	
	# Set flags for damage state
	has_missing_parts = true
	can_move = false  # Stop movement for the current turn
	
	# Check if all parts are eaten
	if front_part_eaten and back_part_eaten:
		queue_free()
