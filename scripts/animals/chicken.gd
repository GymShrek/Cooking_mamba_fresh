# scripts/animals/chicken.gd
extends Animal
class_name ChickenAnimal

var movement_pattern = []
var target_position = Vector2i()
var jump_pos = Vector2i() # Store position from which the chicken jumped
var egg_spawn_chance = 0.05 # 5% chance to spawn an egg per movement

# Textures for different flight states
var normal_texture
var mid_texture
var flying_texture

func _ready():
	super()
	type = "chicken"
	movement_behavior = "flee"
	
func setup_sprite():
	normal_texture = load("res://assets/chicken.png")
	mid_texture = load("res://assets/chicken_mid.png")
	flying_texture = load("res://assets/chicken_flying.png")
	$Sprite2D.texture = normal_texture

func move():
	var snake_head_pos = snake.segments[0].grid_pos
	var new_pos = grid_pos
	
	# Check if snake is within 1 square - activate flying
	if not is_flying and snake_head_pos != Vector2i(-1, -1) and (snake_head_pos - grid_pos).length() <= 1.5:
		start_flying()
		return # Don't move while flying starts
	
	# Process flying state
	if is_flying:
		process_flying()
		return
	
	# Possibly spawn an egg
	try_spawn_egg()
	
	# Normal movement pattern
	new_pos = get_movement_position(snake_head_pos)
	
	# Update facing direction and position
	update_facing_direction(new_pos)
	
	if new_pos != grid_pos:
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

# Chicken movement pattern
func get_movement_position(snake_head_pos):
	# Initialize movement pattern if empty
	if movement_pattern.size() == 0:
		initialize_movement_pattern()
	
	# Move toward target position
	if grid_pos == target_position:
		# Switch target
		if target_position == movement_pattern[0]:
			target_position = movement_pattern[1]
		else:
			target_position = movement_pattern[0]
	
	# Move one step toward target
	return move_toward_pos(grid_pos, target_position)

# Initialize a back-and-forth movement pattern
func initialize_movement_pattern():
	# Create pattern (3-5 spaces in each direction)
	var start_pos = grid_pos
	var direction = Vector2i(1, 0)  # Default horizontal
	
	# Check which direction has more space
	var horizontal_space = min(grid_pos.x - 1, grid.grid_size.x - 2 - grid_pos.x)
	var vertical_space = min(grid_pos.y - 1, grid.grid_size.y - 2 - grid_pos.y)
	
	if vertical_space > horizontal_space:
		direction = Vector2i(0, 1)  # Vertical movement
	
	var pattern_length = 3 + randi() % 3
	var end_pos = Vector2i(
		grid_pos.x + direction.x * pattern_length,
		grid_pos.y + direction.y * pattern_length
	)
	
	# Ensure end position is valid
	end_pos.x = clamp(end_pos.x, 1, grid.grid_size.x - 2)
	end_pos.y = clamp(end_pos.y, 1, grid.grid_size.y - 2)
	
	movement_pattern = [start_pos, end_pos]
	target_position = end_pos
