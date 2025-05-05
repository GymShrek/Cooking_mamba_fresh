# scripts/collectible.gd
extends Node2D

var resource_type = "wheat"  # Default resource type
var is_animal = false
var is_moving = false
var size_multiplier = 1
var current_step = 0
var movement_pattern = []  # For predetermined movement patterns
var target_position = Vector2i()
var is_flying = false  # For chicken animation states
var flying_cooldown = 0
var facing_direction = Vector2i(1, 0)  # Default facing right

# Resource textures dictionary
var resource_textures = {
	# Static resources
	"wheat": preload("res://assets/wheat.png"),
	"tomato": preload("res://assets/tomato.png"),
	"lettuce": preload("res://assets/lettuce.png"),
	"egg": preload("res://assets/egg.png"),
	"milk": preload("res://assets/milk.png"),
	
	# Animals - base sprites
	"mouse": preload("res://assets/mouse.png"),
	"chicken": preload("res://assets/chicken.png"),
	"chicken_mid": preload("res://assets/chicken_mid.png"),
	"chicken_flying": preload("res://assets/chicken_flying.png"),
	"pig": preload("res://assets/pig.png"),
	"cow": preload("res://assets/cow.png")
}

# Animal preferences for resource destruction
var resource_preferences = {
	"mouse": ["wheat", "tomato", "lettuce", "egg", "milk"],
	"pig": ["milk", "tomato", "lettuce", "wheat", "egg"]
}

# Reference to grid and main nodes
var grid
var main
var egg_spawn_chance = 0.05  # 5% chance to spawn an egg per chicken movement

func _ready():
	# Set up the collectible appearance based on resource type
	main = get_node("/root/Main")
	grid = main.get_node("Grid")
	
	update_appearance()
	
	# Set up initial state based on resource type
	if resource_type in ["mouse", "chicken", "pig", "cow"]:
		is_animal = true
		is_moving = true
		
		# Set size multiplier for cow
		if resource_type == "cow":
			size_multiplier = 2
			scale = Vector2(2, 2)  # Double the length and width

func set_resource_type(type):
	resource_type = type
	
	# Update animal status
	if resource_type in ["mouse", "chicken", "pig", "cow"]:
		is_animal = true
		is_moving = true
		
		# Set size multiplier for cow
		if resource_type == "cow":
			size_multiplier = 2
			scale = Vector2(2, 2)  # Make it 2x2 in size
	else:
		is_animal = false
		is_moving = false
		size_multiplier = 1
		scale = Vector2(1, 1)
		
	update_appearance()

func update_appearance():
	if resource_textures.has(resource_type):
		if resource_type == "chicken" and is_flying:
			if flying_cooldown == 2:
				$Sprite2D.texture = resource_textures["chicken_flying"]
			elif flying_cooldown == 1:
				$Sprite2D.texture = resource_textures["chicken_mid"]
			else:
				$Sprite2D.texture = resource_textures["chicken"]
		else:
			$Sprite2D.texture = resource_textures[resource_type]
		
		# Handle sprite rotation based on facing direction
		if is_animal:
			update_sprite_direction()

func update_sprite_direction():
	# Reset rotation and flip
	$Sprite2D.rotation = 0
	$Sprite2D.flip_h = false
	$Sprite2D.flip_v = false
	
	# Apply appropriate transform based on facing direction
	if facing_direction.x > 0:  # Right
		# Default sprite orientation is typically facing left, so flip it
		$Sprite2D.flip_h = true
	elif facing_direction.x < 0:  # Left
		# No change if sprite already faces left
		pass
	elif facing_direction.y > 0:  # Down
		$Sprite2D.rotation = deg_to_rad(90)
		# Depending on your sprites, you may need to flip as well
		$Sprite2D.flip_h = true  # This might need adjustment based on your sprites
	elif facing_direction.y < 0:  # Up
		$Sprite2D.rotation = deg_to_rad(-90)
		# Depending on your sprites, you may need to flip as well
		$Sprite2D.flip_h = true  # This might need adjustment based on your sprites

func move(snake_segments):
	if not is_moving or not is_animal:
		return
		
	# If chicken is flying, it's uncollectible
	if resource_type == "chicken" and is_flying:
		flying_cooldown -= 1
		if flying_cooldown <= 0:
			is_flying = false
			# Check if we landed on the snake, if so, move to the nearest available position
			var grid_pos = grid.world_to_grid(position)
			for segment in snake_segments:
				if segment.grid_pos == grid_pos:
					slide_to_nearest_valid_position(grid_pos, segment.grid_pos)
					break
		update_appearance()
		return
		
	var grid_pos = grid.world_to_grid(position)
	var snake_head_pos = snake_segments[0].grid_pos if snake_segments.size() > 0 else Vector2i(-1, -1)
	var new_pos = grid_pos
	
	match resource_type:
		"mouse":
			new_pos = move_mouse(grid_pos, snake_head_pos, snake_segments)
		"chicken":
			new_pos = move_chicken(grid_pos, snake_head_pos, snake_segments)
			# Check for egg spawning chance
			if randf() <= egg_spawn_chance:
				spawn_egg_behind(grid_pos)
		"pig":
			new_pos = move_pig(grid_pos, snake_head_pos, snake_segments)
		"cow":
			new_pos = move_cow(grid_pos, snake_head_pos, snake_segments)
	
	# Update facing direction based on movement
	if new_pos != grid_pos:
		facing_direction = new_pos - grid_pos
		update_sprite_direction()
	
	# Update position if it changed and the new position is valid
	if new_pos != grid_pos and is_position_valid(new_pos, resource_type):
		# Check for collectible collision (for destroying resources)
		var collectible = check_collectible_at_position(new_pos)
		if collectible and can_destroy_resource(collectible):
			destroy_resource(collectible)
		
		position = grid.grid_to_world(new_pos)

# Slide to nearest valid position when chicken lands on the snake
func slide_to_nearest_valid_position(current_pos, snake_pos):
	var directions = [
		Vector2i(1, 0),   # Right
		Vector2i(-1, 0),  # Left
		Vector2i(0, 1),   # Down
		Vector2i(0, -1)   # Up
	]
	
	# Try each direction until we find a valid position
	for dir in directions:
		var test_pos = current_pos + dir
		if is_position_valid(test_pos) and test_pos != snake_pos:
			position = grid.grid_to_world(test_pos)
			facing_direction = dir
			update_sprite_direction()
			return

# Spawn an egg behind the chicken
func spawn_egg_behind(chicken_pos):
	# Calculate position behind the chicken (opposite of facing direction)
	var behind_pos = chicken_pos - facing_direction
	
	# Check if position is valid
	if not is_position_valid(behind_pos):
		return
	
	# Check if there's already a collectible there
	for collectible in main.get_node("Collectibles").get_children():
		if grid.world_to_grid(collectible.position) == behind_pos:
			return
	
	# Create the egg
	var egg = load("res://scenes/Collectible.tscn").instantiate()
	egg.position = grid.grid_to_world(behind_pos)
	egg.set_resource_type("egg")
	
	# Add to the scene
	main.get_node("Collectibles").add_child(egg)

# Check if a position is valid (not occupied by animals or snake and within grid)
func is_position_valid(pos, ignore_resource_type = ""):
	# Check if it's within the grid bounds and not a wall
	if not grid.is_cell_vacant(pos):
		return false
	
	# Check for collision with other animals
	var collectibles_node = main.get_node("Collectibles")
	for collectible in collectibles_node.get_children():
		if collectible == self or collectible.resource_type == ignore_resource_type:
			continue
		
		if collectible.is_animal:
			var collectible_pos = grid.world_to_grid(collectible.position)
			
			# For regular animals
			if collectible.resource_type != "cow" and collectible_pos == pos:
				return false
			
			# For cow (2x2 size)
			if collectible.resource_type == "cow":
				for x in range(2):
					for y in range(2):
						if collectible_pos + Vector2i(x, y) == pos:
							return false
	
	return true

# Mouse movement: follows perimeter unless close to destroyable resources
func move_mouse(curr_pos, snake_head_pos, snake_segments):
	# Check if there are nearby resources to destroy
	var nearby_resource = find_nearest_destroyable_resource(curr_pos, 5, "mouse")
	if nearby_resource:
		# Move toward the resource
		var resource_pos = grid.world_to_grid(nearby_resource.position)
		# Move toward the resource
		return move_toward_pos(curr_pos, resource_pos, snake_segments)
	
	# Otherwise follow the perimeter
	var perimeter_moves = []
	
	# Check if at edge, if so follow edge
	if curr_pos.x <= 1 or curr_pos.x >= grid.grid_size.x - 2 or curr_pos.y <= 1 or curr_pos.y >= grid.grid_size.y - 2:
		# Add possible perimeter moves
		if curr_pos.x <= 1 and curr_pos.y > 1:
			perimeter_moves.append(Vector2i(curr_pos.x, curr_pos.y - 1))  # Move up
		if curr_pos.x <= 1 and curr_pos.y < grid.grid_size.y - 2:
			perimeter_moves.append(Vector2i(curr_pos.x, curr_pos.y + 1))  # Move down
		if curr_pos.y <= 1 and curr_pos.x < grid.grid_size.x - 2:
			perimeter_moves.append(Vector2i(curr_pos.x + 1, curr_pos.y))  # Move right
		if curr_pos.y >= grid.grid_size.y - 2 and curr_pos.x < grid.grid_size.x - 2:
			perimeter_moves.append(Vector2i(curr_pos.x + 1, curr_pos.y))  # Move right
		if curr_pos.y >= grid.grid_size.y - 2 and curr_pos.x > 1:
			perimeter_moves.append(Vector2i(curr_pos.x - 1, curr_pos.y))  # Move left
		if curr_pos.x >= grid.grid_size.x - 2 and curr_pos.y > 1:
			perimeter_moves.append(Vector2i(curr_pos.x, curr_pos.y - 1))  # Move up
		if curr_pos.x >= grid.grid_size.x - 2 and curr_pos.y < grid.grid_size.y - 2:
			perimeter_moves.append(Vector2i(curr_pos.x, curr_pos.y + 1))  # Move down
		if curr_pos.y <= 1 and curr_pos.x > 1:
			perimeter_moves.append(Vector2i(curr_pos.x - 1, curr_pos.y))  # Move left
	else:
		# Move toward nearest perimeter
		var distances = [
			{"edge": "left", "dist": curr_pos.x - 1},
			{"edge": "right", "dist": grid.grid_size.x - 2 - curr_pos.x},
			{"edge": "top", "dist": curr_pos.y - 1},
			{"edge": "bottom", "dist": grid.grid_size.y - 2 - curr_pos.y}
		]
		
		# Sort by distance
		distances.sort_custom(func(a, b): return a.dist < b.dist)
		
		# Move toward nearest edge
		match distances[0].edge:
			"left":
				perimeter_moves.append(Vector2i(curr_pos.x - 1, curr_pos.y))
			"right":
				perimeter_moves.append(Vector2i(curr_pos.x + 1, curr_pos.y))
			"top":
				perimeter_moves.append(Vector2i(curr_pos.x, curr_pos.y - 1))
			"bottom":
				perimeter_moves.append(Vector2i(curr_pos.x, curr_pos.y + 1))
	
	# Filter out invalid moves
	var valid_moves = []
	for move in perimeter_moves:
		if is_position_valid(move):
			# Check for snake collision
			var snake_collision = false
			for segment in snake_segments:
				if segment.grid_pos == move:
					snake_collision = true
					break
			
			if not snake_collision:
				valid_moves.append(move)
	
	if valid_moves.size() > 0:
		# Try to move away from snake if it's close
		if snake_head_pos != Vector2i(-1, -1) and (snake_head_pos - curr_pos).length() < 3:
			# Sort moves by distance from snake head (furthest first)
			valid_moves.sort_custom(func(a, b): 
				var dist_a = (a - snake_head_pos).length()
				var dist_b = (b - snake_head_pos).length()
				return dist_a > dist_b
			)
			return valid_moves[0]
		else:
			# Pick random valid move
			return valid_moves[randi() % valid_moves.size()]
	
	return curr_pos  # Stay in place if no valid moves

# Chicken movement: back and forth with jumping when snake approaches
func move_chicken(curr_pos, snake_head_pos, snake_segments):
	# Check if snake is within 1 square - activate flying
	if not is_flying and snake_head_pos != Vector2i(-1, -1) and (snake_head_pos - curr_pos).length() <= 1.5:
		is_flying = true
		flying_cooldown = 2  # Will take 2 turns to land
		update_appearance()
		return curr_pos  # Don't move while flying starts
	
	# 50% chance to move randomly, 50% chance to return to starting position
	if movement_pattern.size() == 0:
		# Initialize movement pattern (simple back and forth)
		var start_pos = curr_pos
		var direction = Vector2i(1, 0)  # Default horizontal
		
		# Check which direction has more space
		var horizontal_space = min(curr_pos.x - 1, grid.grid_size.x - 2 - curr_pos.x)
		var vertical_space = min(curr_pos.y - 1, grid.grid_size.y - 2 - curr_pos.y)
		
		if vertical_space > horizontal_space:
			direction = Vector2i(0, 1)  # Vertical movement
		
		# Create pattern (3-5 spaces in each direction)
		var pattern_length = 3 + randi() % 3
		var end_pos = Vector2i(
			curr_pos.x + direction.x * pattern_length,
			curr_pos.y + direction.y * pattern_length
		)
		
		# Ensure end position is valid
		end_pos.x = clamp(end_pos.x, 1, grid.grid_size.x - 2)
		end_pos.y = clamp(end_pos.y, 1, grid.grid_size.y - 2)
		
		movement_pattern = [start_pos, end_pos]
		target_position = end_pos
	
	# Move toward target position
	if curr_pos == target_position:
		# Switch target
		if target_position == movement_pattern[0]:
			target_position = movement_pattern[1]
		else:
			target_position = movement_pattern[0]
	
	# Move one step toward target
	return move_toward_pos(curr_pos, target_position, snake_segments)

# Pig movement: prefer linear paths, destroys resources in its path
func move_pig(curr_pos, snake_head_pos, snake_segments):
	# Check for resources to destroy
	var nearest_resource = find_nearest_destroyable_resource(curr_pos, 8, "pig")
	if nearest_resource:
		var resource_pos = grid.world_to_grid(nearest_resource.position)
		return move_toward_pos(curr_pos, resource_pos, snake_segments)
	
	# If no current direction, choose a random direction
	if movement_pattern.size() == 0:
		var directions = [
			Vector2i(1, 0),   # Right
			Vector2i(-1, 0),  # Left
			Vector2i(0, 1),   # Down
			Vector2i(0, -1)   # Up
		]
		
		# Shuffle directions
		for i in range(directions.size() - 1, 0, -1):
			var j = randi() % (i + 1)
			var temp = directions[i]
			directions[i] = directions[j]
			directions[j] = temp
		
		# Choose first valid direction
		for dir in directions:
			var steps = 3 + randi() % 4  # Move 3-6 steps in this direction
			var end_pos = Vector2i(curr_pos.x + dir.x * steps, curr_pos.y + dir.y * steps)
			
			# Check if end position is within bounds
			if end_pos.x >= 1 and end_pos.x < grid.grid_size.x - 1 and end_pos.y >= 1 and end_pos.y < grid.grid_size.y - 1:
				movement_pattern = [dir]
				target_position = end_pos
				break
	
	# If we have a direction but reached target, reset
	if movement_pattern.size() > 0 and curr_pos == target_position:
		movement_pattern = []
		return move_pig(curr_pos, snake_head_pos, snake_segments)  # Recursive call to choose new direction
	
	# Move in the chosen direction if possible
	if movement_pattern.size() > 0:
		var next_pos = Vector2i(curr_pos.x + movement_pattern[0].x, curr_pos.y + movement_pattern[0].y)
		
		# Check if next position is valid
		if is_position_valid(next_pos):
			return next_pos
		else:
			# If blocked, choose new direction
			movement_pattern = []
			return move_pig(curr_pos, snake_head_pos, snake_segments)  # Recursive call to choose new direction
	
	return curr_pos  # Stay in place if no valid moves

# Cow movement: moves 2 squares at a time, prefers to stay near milk
func move_cow(curr_pos, snake_head_pos, snake_segments):
	# Find nearest milk
	var nearest_milk = null
	var min_distance = 999999
	var collectibles_node = main.get_node("Collectibles")
	
	for collectible in collectibles_node.get_children():
		if collectible.resource_type == "milk":
			var milk_pos = grid.world_to_grid(collectible.position)
			var distance = (milk_pos - curr_pos).length()
			if distance < min_distance:
				min_distance = distance
				nearest_milk = collectible
	
	# Choose movement based on milk position
	var move_dir = Vector2i()
	
	if nearest_milk:
		var milk_pos = grid.world_to_grid(nearest_milk.position)
		
		# If too far from milk, move toward it
		if min_distance > 8:  # Increased from 4 to 8 as requested
			# Calculate the direction vector (avoid using normalized)
			var diff = milk_pos - curr_pos
			if abs(diff.x) > abs(diff.y):
				move_dir.x = 1 if diff.x > 0 else -1
			else:
				move_dir.y = 1 if diff.y > 0 else -1
		else:
			# If close enough to milk, move randomly but stay in range
			var directions = [
				Vector2i(1, 0),   # Right
				Vector2i(-1, 0),  # Left
				Vector2i(0, 1),   # Down
				Vector2i(0, -1)   # Up
			]
			
			# Shuffle directions
			for i in range(directions.size() - 1, 0, -1):
				var j = randi() % (i + 1)
				var temp = directions[i]
				directions[i] = directions[j]
				directions[j] = temp
			
			# Choose first direction that keeps cow within range of milk
			for dir in directions:
				var new_pos = Vector2i(curr_pos.x + dir.x * 2, curr_pos.y + dir.y * 2)
				if (new_pos - milk_pos).length() <= 8 and is_position_valid(new_pos):
					move_dir = dir
					break
	else:
		# If no milk, move randomly
		var directions = [
			Vector2i(1, 0),   # Right
			Vector2i(-1, 0),  # Left
			Vector2i(0, 1),   # Down
			Vector2i(0, -1)   # Up
		]
		move_dir = directions[randi() % directions.size()]
	
	# Move 2 squares in the chosen direction if possible
	if move_dir != Vector2i():
		var next_pos = Vector2i(curr_pos.x + move_dir.x * 2, curr_pos.y + move_dir.y * 2)
		
		# Make sure the position is valid
		if next_pos.x >= 1 and next_pos.x < grid.grid_size.x - 1 and next_pos.y >= 1 and next_pos.y < grid.grid_size.y - 1:
			if is_position_valid(next_pos):
				return next_pos
	
	return curr_pos  # Stay in place if no valid moves

# Helper function to move toward a target position
func move_toward_pos(curr_pos, target_pos, snake_segments):
	var diff = target_pos - curr_pos
	var move_dir = Vector2i()
	
	# Choose the primary direction (horizontal or vertical)
	if abs(diff.x) > abs(diff.y):
		move_dir.x = 1 if diff.x > 0 else -1
	else:
		move_dir.y = 1 if diff.y > 0 else -1
	
	var next_pos = Vector2i(curr_pos.x + move_dir.x, curr_pos.y + move_dir.y)
	
	# Check if the move is valid
	if is_position_valid(next_pos):
		return next_pos
	
	# Try the other direction if primary is blocked
	move_dir = Vector2i()
	if abs(diff.x) <= abs(diff.y):
		move_dir.x = 1 if diff.x > 0 else -1
	else:
		move_dir.y = 1 if diff.y > 0 else -1
	
	next_pos = Vector2i(curr_pos.x + move_dir.x, curr_pos.y + move_dir.y)
	
	# Check if the alternate move is valid
	if is_position_valid(next_pos):
		return next_pos
	
	return curr_pos  # Stay in place if no valid moves

# Find the nearest resource that this animal can destroy
func find_nearest_destroyable_resource(curr_pos, max_distance, animal_type):
	var collectibles_node = main.get_node("Collectibles")
	var nearest_resource = null
	var min_distance = max_distance + 1  # Beyond our search range
	
	# Get preference list for this animal
	var preferences = resource_preferences.get(animal_type, [])
	
	# First pass: check for any destroyable resources in range
	for collectible in collectibles_node.get_children():
		# Skip if not a destroyable resource
		if collectible.is_animal or not (collectible.resource_type in preferences):
			continue
		
		var resource_pos = grid.world_to_grid(collectible.position)
		var distance = (resource_pos - curr_pos).length()
		
		if distance < min_distance:
			min_distance = distance
			nearest_resource = collectible
	
	# If we found a resource in range, check if there's a higher priority one
	if nearest_resource:
		var priority_index = preferences.find(nearest_resource.resource_type)
		
		# Second pass: look for higher priority resources
		for collectible in collectibles_node.get_children():
			if collectible.is_animal:
				continue
				
			var this_priority = preferences.find(collectible.resource_type)
			
			# If this resource is higher priority
			if this_priority != -1 and this_priority > priority_index:
				var resource_pos = grid.world_to_grid(collectible.position)
				var distance = (resource_pos - curr_pos).length()
				
				# Accept if it's within 1.5x the distance of our current nearest
				if distance <= min_distance * 1.5 and distance <= max_distance:
					min_distance = distance
					nearest_resource = collectible
					priority_index = this_priority
	
	return nearest_resource

# Check if there's a collectible at a given position
func check_collectible_at_position(pos):
	var collectibles_node = main.get_node("Collectibles")
	
	for collectible in collectibles_node.get_children():
		if collectible == self:
			continue
			
		var collectible_pos = grid.world_to_grid(collectible.position)
		if collectible_pos == pos:
			return collectible
	
	return null

# Check if this animal can destroy the given resource
func can_destroy_resource(collectible):
	if not is_animal:
		return false
		
	# Check if the collectible is a static resource that this animal can destroy
	var preferences = resource_preferences.get(resource_type, [])
	return not collectible.is_animal and collectible.resource_type in preferences

# Destroy a resource
func destroy_resource(collectible):
	# Create sparkle effect
	main.create_sparkle_effect(collectible.position)
	
	# Remove the collectible
	collectible.queue_free()
