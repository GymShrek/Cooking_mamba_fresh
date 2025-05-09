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
var grid_offset = Vector2i(0, 0) # Offset for rendering parts with different rotations

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

# Debug function to list all files in a directory
func list_files_in_dir(directory_path):
	var dir = DirAccess.open(directory_path)
	if dir:
		print("Contents of directory: " + directory_path)
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				print("- " + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		print("Could not open directory: " + directory_path)
		print("Error code: " + str(DirAccess.get_open_error()))



func _ready():
	# Wait until we're added to the scene before trying to access other nodes
	list_files_in_dir("res://assets")
	if not is_inside_tree():
		await ready
	
	# Initialize references correctly
	initialize_references()
	
	# Setup sprite
	setup_sprite()

func initialize_references():
	# Get references to necessary nodes
	# Use safe navigation to avoid errors
	main = get_tree().get_root().get_node_or_null("Main")
	if main:
		grid = main.get_node_or_null("Grid")
		snake = main.get_node_or_null("Snake")
		
		# Check if we got valid references
		if grid == null:
			push_error("Failed to get Grid reference in " + name)
		if snake == null:
			push_error("Failed to get Snake reference in " + name)
	else:
		push_error("Failed to get Main reference in " + name)
		return
	
	# Now that references are set up, initialize multi-cell if needed
	if is_multi_cell:
		initialize_multi_cell()
		
		
# Helper function to safely load textures with error handling
func safe_load_texture(path):
	var texture = load(path)
	if texture == null:
		push_error("Failed to load texture: " + path)
		# Check if the file exists
		var file = FileAccess.open(path, FileAccess.READ)
		if file == null:
			push_error("File does not exist: " + path)
			# Print the error code
			push_error("Error code: " + str(FileAccess.get_open_error()))
		return null
	return texture


func setup_sprite():
	# Override in child classes to set up specific animal sprites
	pass

func initialize_multi_cell():
	# Override in child classes for specific multi-cell setup
	pass

func initialize_multi_cell_sprites(textures, positions):
	# Clear existing parts
	for child in get_children():
		if child.name.begins_with("Part"):
			child.queue_free()
	
	parts.clear()
	
	# Debug output
	print(name + ": Initializing multi-cell sprites with " + str(textures.size()) + " textures")
	
	# Create part sprites based on provided textures and positions
	for i in range(textures.size()):
		var part = Sprite2D.new()
		
		# Check if the texture is valid
		if textures[i] == null:
			push_error(name + ": Texture " + str(i) + " is null!")
			part.texture = load("res://icon.svg")  # Use fallback texture
		else:
			part.texture = textures[i]
			
		part.name = "Part" + str(i)
		
		# Set initial position based on the grid layout
		if grid != null:
			var offset = Vector2(positions[i].x * grid.CELL_SIZE, positions[i].y * grid.CELL_SIZE)
			part.position = offset
		else:
			push_error(name + ": Grid reference is null during multi-cell sprite initialization")
			part.position = Vector2(i * 32, 0)  # Fallback for testing
		
		# Ensure the part is visible
		part.visible = true
		
		add_child(part)
		parts.append(part)
		
		print(name + ": Added part " + part.name + " at position " + str(part.position))
	
	# Update initial appearance
	update_multi_cell_rotation()

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
	# Simple single cell animal rotation - NO ROTATION, only horizontal flip
	# First check if Sprite2D exists
	if not has_node("Sprite2D"):
		return
		
	# Reset rotation and flip
	$Sprite2D.rotation = 0  # Always keep rotation at 0
	$Sprite2D.flip_h = false
	$Sprite2D.flip_v = false
	
	# Only apply horizontal flipping based on facing direction
	if facing_direction.x > 0:  # Right
		$Sprite2D.flip_h = true
	# We always keep the default sprite orientation for all other directions

func update_multi_cell_rotation():
	# Override in child classes to handle multi-cell rotations
	pass

# Check if a position is valid (not occupied by other animals, snake, or walls)
func is_position_valid(pos, ignore_resource_type = ""):
	# Safety check - make sure grid is initialized
	if grid == null:
		push_error("Grid is null in is_position_valid check for " + name)
		return false
	
	# Safety check - make sure main is initialized
	if main == null:
		push_error("Main is null in is_position_valid check for " + name)
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
	var collectibles_node = main.get_node_or_null("Collectibles")
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
		push_error("Grid is null in is_multi_cell_position_valid check for " + name)
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
	var rotated = Vector2i(point.x, point.y)
	
	# Apply rotation based on facing direction
	if direction == Vector2i(1, 0):  # Right
		# For right-facing, we keep the same coordinates but flip the sprite
		rotated = Vector2i(point.x, point.y)
	elif direction == Vector2i(-1, 0):  # Left
		# For left-facing, we use the original coordinates
		rotated = Vector2i(point.x, point.y)
	elif direction == Vector2i(0, 1):  # Down
		# For down-facing, we swap x and y (rotate 90 degrees)
		rotated = Vector2i(point.y, point.x)
	elif direction == Vector2i(0, -1):  # Up
		# For up-facing, we swap x and y and negate the new y (rotate -90 degrees)
		rotated = Vector2i(point.y, -point.x)
		
	return rotated

# Helper function to move toward a target position
func move_toward_pos(curr_pos, target_pos):
	# Check if grid is initialized
	if grid == null:
		push_error("Grid is null in move_toward_pos for " + name)
		return curr_pos
		
	var diff = target_pos - curr_pos
	var move_dir = Vector2i()
	
	# Choose the primary direction (horizontal or vertical)
	if abs(diff.x) > abs(diff.y):
		move_dir.x = 1 if diff.x > 0 else -1
	else:
		move_dir.y = 1 if diff.y > 0 else -1
	
	var next_pos = Vector2i(curr_pos.x + move_dir.x, curr_pos.y + move_dir.y)
	
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
		push_error("Main is null in check_collectible_at_position for " + name)
		return null
	
	if grid == null:
		push_error("Grid is null in check_collectible_at_position for " + name)
		return null
		
	var collectibles_node = main.get_node_or_null("Collectibles")
	if collectibles_node == null:
		return null
	
	for collectible in collectibles_node.get_children():
		if collectible == self:
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
		push_error("Main is null in destroy_resource for " + name)
		return
		
	# Create sparkle effect
	main.create_sparkle_effect(collectible.position)
	
	# Remove the collectible
	collectible.queue_free()

# Find the nearest resource that this animal can destroy
func find_nearest_destroyable_resource(curr_pos, max_distance):
	# Safety check
	if main == null or grid == null:
		push_error("Main or Grid is null in find_nearest_destroyable_resource for " + name)
		return null
		
	var collectibles_node = main.get_node_or_null("Collectibles")
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
	
func handle_part_eaten(pos):
	# This is a base implementation - specific animals will override
	
	# Set flags for damaged state
	has_missing_parts = true
	can_move = false  # Stop movement for CURRENT turn only
	
	# NEW: Add a single-frame timer to restore movement on the next frame
	var timer = Timer.new()
	timer.wait_time = 0.05  # Very short time
	timer.one_shot = true
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(func(): 
		can_move = true  # Restore movement ability
		timer.queue_free()
	)



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
