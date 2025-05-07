# scripts/animals/animal.gd
extends Node2D
class_name Animal

# Animal properties
var type = ""
var grid_pos = Vector2i()
var size = Vector2i(1, 1) # Default size is 1x1 (will be 2x2 for cow)
var speed = 1
var destroys = []  # Resources this animal destroys
var movement_behavior = "wander"
var facing_direction = Vector2i(1, 0) # Default facing right
var appearance_damaged = false

# Part information (for multi-cell animals)
var is_multi_cell = false  # Flag for multi-cell animals
var parts = []  # Will store parts for multi-cell animals
var part_positions = []  # Relative positions of parts
var main_pivot = Vector2i(0, 0)  # Pivot point for rotation (usually bottom-left)
var has_missing_parts = false  # Flag when animal has had parts eaten

# Movement tracking
var can_move = true
var last_move_time = 0
var move_cooldown = 0

# For chicken animation
var is_flying = false
var flying_cooldown = 0
var jump_pos = Vector2i() # Added to store the position of a jump

# References to other nodes
var grid
var main
var snake

func _ready():
	# IMPORTANT: Wait until the node is ready before accessing parent nodes
	call_deferred("initialize_references")
	
	# Setup sprite
	setup_sprite()

func initialize_references():
	# Initialize references safely after the node is ready
	main = get_node("/root/Main")
	if main:
		grid = main.get_node("Grid")
		snake = main.get_node("Snake")
		
	# Now that references are set up, initialize multi-cell if needed
	if is_multi_cell:
		initialize_multi_cell()

func setup_sprite():
	# Override in child classes to set up specific animal sprites
	pass

func initialize_multi_cell():
	# Override in child classes for specific multi-cell setup
	pass

func move():
	# Base movement logic - override in child classes
	pass

# Handle facing direction based on movement
func update_facing_direction(new_pos):
	if new_pos != grid_pos:
		facing_direction = new_pos - grid_pos
		update_sprite_direction()
		if is_multi_cell:
			update_multi_cell_rotation()

func update_sprite_direction():
	# Simple single cell animal rotation
	# Reset rotation and flip
	$Sprite2D.rotation = 0
	$Sprite2D.flip_h = false
	$Sprite2D.flip_v = false
	
	# Apply appropriate transform based on facing direction
	if facing_direction.x > 0:  # Right
		$Sprite2D.flip_h = true
	elif facing_direction.x < 0:  # Left
		# Default sprite orientation is typically facing left
		pass
	elif facing_direction.y > 0:  # Down
		$Sprite2D.rotation = deg_to_rad(-90)
	elif facing_direction.y < 0:  # Up
		$Sprite2D.rotation = deg_to_rad(90)

func update_multi_cell_rotation():
	# Override in child classes to handle multi-cell rotations
	pass

# Check if a position is valid (not occupied by other animals, snake, or walls)
func is_position_valid(pos, ignore_resource_type = ""):
	# Safety check - make sure grid is initialized
	if grid == null:
		push_error("Grid is null in is_position_valid check")
		return false
	
	# Check if it's within the grid bounds and not a wall
	if not grid.is_cell_vacant(pos):
		return false
	
	# Check for collision with snake
	if snake:
		for segment in snake.segments:
			if segment.grid_pos == pos:
				return false
	
	# Check for collision with other animals
	var collectibles_node = main.get_node("Collectibles") if main else null
	if collectibles_node:
		for collectible in collectibles_node.get_children():
			if collectible == self or collectible.resource_type == ignore_resource_type:
				continue
			
			if collectible.is_animal:
				var collectible_pos = grid.world_to_grid(collectible.position)
				
				# For regular animals
				if collectible.resource_type != "cow" and collectible.resource_type != "pig" and collectible_pos == pos:
					return false
				
				# For cow (2x2 size)
				if collectible.resource_type == "cow":
					for x in range(2):
						for y in range(2):
							if collectible_pos + Vector2i(x, y) == pos:
								return false
							
				# For pig (2x1 size)
				if collectible.resource_type == "pig":
					for x in range(2):
						if collectible_pos + Vector2i(x, 0) == pos:
							return false
	
	return true

# Multi-cell validity check (for entire animal footprint)
func is_multi_cell_position_valid(base_pos):
	# Safety check
	if grid == null:
		push_error("Grid is null in is_multi_cell_position_valid check")
		return false
		
	# For multi-cell animals, check every cell they would occupy
	for part_pos in part_positions:
		var world_part_pos = get_world_part_position(base_pos, part_pos)
		if not is_position_valid(world_part_pos):
			return false
	return true

# Helper to get the actual world position of a part based on rotation
func get_world_part_position(base_pos, relative_pos):
	var rotated_pos = rotate_point(relative_pos, facing_direction)
	return base_pos + rotated_pos

# Rotate a point around origin based on facing direction
func rotate_point(point, direction):
	var rotated = Vector2i()
	if direction == Vector2i(1, 0):  # Right
		rotated = Vector2i(point.x, point.y)
	elif direction == Vector2i(-1, 0):  # Left
		rotated = Vector2i(-point.x, point.y)
	elif direction == Vector2i(0, 1):  # Down
		rotated = Vector2i(point.y, point.x)
	elif direction == Vector2i(0, -1):  # Up
		rotated = Vector2i(point.y, -point.x)
	return rotated

# Helper function to move toward a target position
func move_toward_pos(curr_pos, target_pos):
	var diff = target_pos - curr_pos
	var move_dir = Vector2i()
	
	# Choose the primary direction (horizontal or vertical)
	if abs(diff.x) > abs(diff.y):
		move_dir.x = 1 if diff.x > 0 else -1
	else:
		move_dir.y = 1 if diff.y > 0 else -1
	
	var next_pos = Vector2i(curr_pos.x + move_dir.x, curr_pos.y + move_dir.y)
	
	# Safety check
	if grid == null:
		push_error("Grid is null in move_toward_pos")
		return curr_pos
	
	# For multi-cell animals, use the multi-cell validity check
	if is_multi_cell:
		if is_multi_cell_position_valid(next_pos):
			return next_pos
	else:
		# Check if the move is valid for single-cell
		if is_position_valid(next_pos):
			return next_pos
	
	# Try the other direction if primary is blocked
	move_dir = Vector2i()
	if abs(diff.x) <= abs(diff.y):
		move_dir.x = 1 if diff.x > 0 else -1
	else:
		move_dir.y = 1 if diff.y > 0 else -1
	
	next_pos = Vector2i(curr_pos.x + move_dir.x, curr_pos.y + move_dir.y)
	
	# For multi-cell animals, use the multi-cell validity check
	if is_multi_cell:
		if is_multi_cell_position_valid(next_pos):
			return next_pos
	else:
		# Check if the move is valid
		if is_position_valid(next_pos):
			return next_pos
	
	return curr_pos  # Stay in place if no valid moves

# Check if there's a collectible at a given position
func check_collectible_at_position(pos):
	# Safety check
	if main == null:
		push_error("Main is null in check_collectible_at_position")
		return null
		
	var collectibles_node = main.get_node("Collectibles")
	if collectibles_node == null:
		return null
	
	for collectible in collectibles_node.get_children():
		if collectible == self:
			continue
		
		if grid == null:
			continue
			
		var collectible_pos = grid.world_to_grid(collectible.position)
		if collectible_pos == pos:
			return collectible
	
	return null

# Check if this animal can destroy the given resource
func can_destroy_resource(collectible):
	# Check if the collectible is a static resource that this animal can destroy
	return not collectible.is_animal and collectible.resource_type in destroys

# Destroy a resource
func destroy_resource(collectible):
	# Safety check
	if main == null:
		return
		
	# Create sparkle effect
	main.create_sparkle_effect(collectible.position)
	
	# Remove the collectible
	collectible.queue_free()

# Find the nearest resource that this animal can destroy
func find_nearest_destroyable_resource(curr_pos, max_distance):
	# Safety check
	if main == null or grid == null:
		return null
		
	var collectibles_node = main.get_node("Collectibles")
	if collectibles_node == null:
		return null
		
	var nearest_resource = null
	var min_distance = max_distance + 1  # Beyond our search range
	
	# Check all collectibles
	for collectible in collectibles_node.get_children():
		# Skip if not a destroyable resource or if it's another animal
		if collectible.is_animal or not (collectible.resource_type in destroys):
			continue
		
		var resource_pos = grid.world_to_grid(collectible.position)
		var distance = (resource_pos - curr_pos).length()
		
		if distance < min_distance:
			min_distance = distance
			nearest_resource = collectible
	
	return nearest_resource
	
# For multi-cell animals - check if a part at a specific position was eaten
func handle_part_eaten(pos):
	# This will be overridden in subclasses
	pass

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
