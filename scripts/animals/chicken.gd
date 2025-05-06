# scripts/animals/chicken.gd
extends Animal
class_name ChickenAnimal

var previous_pos = Vector2i()
var is_returning = false
var egg_spawn_chance = 0.05 # 5% chance to spawn an egg per movement

# Add a grounded timer to prevent continuous flying
@export var grounded_cooldown_time: int = 3  # Turns before it can fly again
var grounded_cooldown = 0  # Current cooldown counter

# Textures for different flight states
var normal_texture
var mid_texture
var flying_texture

func _ready():
	super()
	type = "chicken"
	movement_behavior = "random"
	previous_pos = grid_pos # Store initial position
	
func setup_sprite():
	normal_texture = load("res://assets/chicken.png")
	mid_texture = load("res://assets/chicken_mid.png")
	flying_texture = load("res://assets/chicken_flying.png")
	$Sprite2D.texture = normal_texture

func move():
	var snake_head_pos = snake.segments[0].grid_pos
	var new_pos = grid_pos
	
	# Decrease grounded cooldown if active
	if grounded_cooldown > 0:
		grounded_cooldown -= 1
	
	# Check if snake is within 1 square and can fly (cooldown expired)
	if not is_flying and grounded_cooldown <= 0 and snake_head_pos != Vector2i(-1, -1) and (snake_head_pos - grid_pos).length() <= 1.5:
		start_flying()
		return # Don't move while flying starts
	
	# Process flying state
	if is_flying:
		process_flying()
		return
	
	# Possibly spawn an egg
	try_spawn_egg()
	
	# New movement pattern: random movement with 50% chance to return to previous position
	new_pos = get_random_movement_with_return(snake_head_pos)
	
	# Update facing direction and position
	update_facing_direction(new_pos)
	
	if new_pos != grid_pos:
		# Remember previous position before moving
		previous_pos = grid_pos
		
		# Update to new position
		grid_pos = new_pos
		position = grid.grid_to_world(new_pos)

func start_flying():
	is_flying = true
	flying_cooldown = 2 # Will take 2 turns to land
	jump_pos = grid_pos # Remember where we jumped from
	$Sprite2D.texture = flying_texture

func process_flying():
	flying_cooldown -= 1
	
	if flying_cooldown == 1:
		$Sprite2D.texture = mid_texture
	elif flying_cooldown <= 0:
		land_after_flight()

func land_after_flight():
	is_flying = false
	$Sprite2D.texture = normal_texture
	
	# Set the grounded cooldown - chicken can't fly again until this expires
	grounded_cooldown = grounded_cooldown_time
	
	# Find a new landing spot different from where we jumped
	var landing_spots = []
	var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	
	# First try 1 space away
	for dir in directions:
		var landing_pos = jump_pos + dir
		if is_position_valid(landing_pos) and landing_pos != jump_pos:
			landing_spots.append(landing_pos)
	
	# If no valid spots 1 space away, try 2 spaces away
	if landing_spots.size() == 0:
		for dir in directions:
			var landing_pos = jump_pos + dir * 2
			if is_position_valid(landing_pos) and landing_pos != jump_pos:
				landing_spots.append(landing_pos)
	
	# If we found valid landing spots, pick one randomly
	if landing_spots.size() > 0:
		var new_pos = landing_spots[randi() % landing_spots.size()]
		grid_pos = new_pos
		position = grid.grid_to_world(new_pos)
	else:
		# If no valid landing spots, try to find any valid spot
		slide_to_nearest_valid_position()

# Slide to nearest valid position when no good landing spot is found
func slide_to_nearest_valid_position():
	var search_radius = 3
	var valid_positions = []
	
	for x in range(-search_radius, search_radius + 1):
		for y in range(-search_radius, search_radius + 1):
			var test_pos = jump_pos + Vector2i(x, y)
			if is_position_valid(test_pos) and test_pos != jump_pos:
				valid_positions.append(test_pos)
	
	if valid_positions.size() > 0:
		# Sort by distance from jump position
		valid_positions.sort_custom(func(a, b): 
			return (a - jump_pos).length() < (b - jump_pos).length()
		)
		grid_pos = valid_positions[0]
		position = grid.grid_to_world(grid_pos)
		update_facing_direction(grid_pos) # Update facing based on new position
	else:
		# If really no valid positions, just stay where we jumped from
		grid_pos = jump_pos
		position = grid.grid_to_world(grid_pos)

# Try to spawn an egg behind the chicken
func try_spawn_egg():
	if randf() <= egg_spawn_chance:
		# Calculate position behind the chicken (opposite of facing direction)
		var behind_pos = grid_pos - facing_direction
		
		# Check if position is valid
		if not is_position_valid(behind_pos):
			return
		
		# Check if there's already a collectible there
		if check_collectible_at_position(behind_pos):
			return
		
		# Create the egg
		var egg = load("res://scenes/Collectible.tscn").instantiate()
		egg.position = grid.grid_to_world(behind_pos)
		egg.set_resource_type("egg")
		
		# Add to the scene
		main.get_node("Collectibles").add_child(egg)

# New movement function - random with 50% chance to return to previous position
func get_random_movement_with_return(snake_head_pos):
	# 50% chance to return to the previous position if we've moved
	if grid_pos != previous_pos and randf() < 0.5:
		is_returning = true
		return previous_pos
	
	# Otherwise, choose a random direction
	is_returning = false
	var directions = [
		Vector2i(1, 0),   # Right
		Vector2i(-1, 0),  # Left
		Vector2i(0, 1),   # Down
		Vector2i(0, -1)   # Up
	]
	
	# Shuffle directions
	directions.shuffle()
	
	# Try each direction until we find a valid one
	for dir in directions:
		var new_pos = grid_pos + dir
		if is_position_valid(new_pos):
			return new_pos
	
	# If no valid directions, stay in place
	return grid_pos
