# scripts/animal_manager.gd
extends Node2D

# Animal scene path
var animal_scene = preload("res://scenes/Animal.tscn")

# Reference to parent nodes
@onready var grid = get_parent().get_node("Grid")
@onready var snake = get_parent().get_node("Snake")

# Animal movement timers
var turn_timer = 0
var turn_delay = 0.2  # Match snake's game_speed

# Keep track of all animals
var animals = []

# Animal types and their properties
var animal_types = {
	"mouse": {
		"texture": preload("res://assets/mouse.png"),
		"size": Vector2i(1, 1),  # 1x1 grid cells
		"speed": 1,              # 1 cell per turn
		"destroys": ["wheat", "tomato", "lettuce"],
		"movement": "perimeter"  # Special behavior flag
	},
	"chicken": {
		"texture": preload("res://assets/chicken.png"),
		"mid_texture": preload("res://assets/chicken_mid.png"),
		"flight_texture": preload("res://assets/chicken_flight.png"),
		"size": Vector2i(1, 1),
		"speed": 1,
		"destroys": [],
		"movement": "flee",      # Will jump when snake approaches
		"flight_state": 0        # 0=normal, 1=flight, 2=mid
	},
	"pig": {
		"texture": preload("res://assets/pig.png"),
		"size": Vector2i(1, 1),
		"speed": 1,
		"destroys": ["wheat", "tomato", "lettuce", "egg", "milk"],
		"movement": "linear"     # Moves in linear paths
	},
	"cow": {
		"texture": preload("res://assets/cow.png"),
		"size": Vector2i(2, 2),  # 2x2 grid cells (4x normal size)
		"speed": 2,              # 2 cells per turn
		"destroys": [],
		"movement": "wander"     # Random movement
	}
}

# Flag to track if the manager is initialized
var is_initialized = false

# Called when the node enters the scene tree for the first time
func _ready():
	# Delay the initialization until after the snake is fully set up
	call_deferred("initialize")

# Initialize after other nodes are ready
func initialize():
	# Make sure snake is ready and has segments
	if snake and snake.segments.size() > 0:
		is_initialized = true
		# Initial animal spawning
		spawn_animals()
	else:
		# Try again in the next frame
		call_deferred("initialize")

# Called every frame
func _process(delta):
	# Don't process until initialized
	if not is_initialized:
		return
		
	# Move animals based on turn timer (sync with snake movement)
	turn_timer += delta
	if turn_timer >= turn_delay:
		turn_timer = 0
		move_animals()

# Spawn initial animals
func spawn_animals():
	spawn_animal("mouse", 3)  # Spawn 3 mice
	spawn_animal("chicken", 2)  # Spawn 2 chickens
	spawn_animal("pig", 1)  # Spawn 1 pig
	spawn_animal("cow", 1)  # Spawn 1 cow

# Spawn a specific number of a given animal type
func spawn_animal(type, count):
	for i in range(count):
		var animal = animal_scene.instantiate()
		
		# Set animal type and properties
		animal.type = type
		animal.size = animal_types[type].size
		animal.speed = animal_types[type].speed
		animal.destroys = animal_types[type].destroys
		animal.movement_behavior = animal_types[type].movement
		animal.texture = animal_types[type].texture
		
		# For chickens, also set the additional textures
		if type == "chicken":
			animal.mid_texture = animal_types[type].mid_texture
			animal.flight_texture = animal_types[type].flight_texture
			animal.flight_state = animal_types[type].flight_state
		
		# Find a valid position
		var valid_position = false
		var grid_pos = Vector2i()
		
		while not valid_position:
			# Generate a random position
			if type == "mouse":
				# Mice spawn near the perimeter
				var perimeter_choice = randi() % 4
				if perimeter_choice == 0:  # Top row
					grid_pos = Vector2i(randi_range(1, grid.grid_size.x - 2), 1)
				elif perimeter_choice == 1:  # Right column
					grid_pos = Vector2i(grid.grid_size.x - 2, randi_range(1, grid.grid_size.y - 2))
				elif perimeter_choice == 2:  # Bottom row
					grid_pos = Vector2i(randi_range(1, grid.grid_size.x - 2), grid.grid_size.y - 2)
				else:  # Left column
					grid_pos = Vector2i(1, randi_range(1, grid.grid_size.y - 2))
			elif type == "cow":
				# Cow needs a 2x2 area, so check differently
				grid_pos = Vector2i(
					randi_range(1, grid.grid_size.x - 3),  # -3 to account for 2x2 size
					randi_range(1, grid.grid_size.y - 3)
				)
			else:
				# Other animals spawn anywhere valid
				grid_pos = Vector2i(
					randi_range(1, grid.grid_size.x - 2),
					randi_range(1, grid.grid_size.y - 2)
				)
			
			# Check if position is valid
			valid_position = is_position_valid_for_animal(grid_pos, type)
		
		# Set the position
		animal.grid_pos = grid_pos
		animal.position = grid.grid_to_world(grid_pos)
		
		# Special case for cow which is larger
		if type == "cow":
			animal.position -= Vector2(grid.CELL_SIZE/2, grid.CELL_SIZE/2)  # Adjust for center
		
		# Add the animal to the scene
		add_child(animal)
		animals.append(animal)

# Check if a position is valid for an animal
func is_position_valid_for_animal(pos, type):
	# Check if the cells are vacant
	if type == "cow":
		# Check 2x2 grid area for cow
		for x in range(2):
			for y in range(2):
				var check_pos = pos + Vector2i(x, y)
				if not grid.is_cell_vacant(check_pos):
					return false
		
		# Check for collision with snake
		for segment in snake.segments:
			for x in range(2):
				for y in range(2):
					if segment.grid_pos == pos + Vector2i(x, y):
						return false
		
		# Check for collision with other animals
		for animal in animals:
			if animal.type == "cow":
				# Check if cow 2x2 areas overlap
				var cow_area = Rect2(animal.grid_pos.x, animal.grid_pos.y, 2, 2)
				var new_cow_area = Rect2(pos.x, pos.y, 2, 2)
				if cow_area.intersects(new_cow_area):
					return false
			else:
				# Check if other animal is within the cow's 2x2 area
				for x in range(2):
					for y in range(2):
						if animal.grid_pos == pos + Vector2i(x, y):
							return false
		
		return true
	else:
		# Standard 1x1 cell check for other animals
		if not grid.is_cell_vacant(pos):
			return false
		
		# Check for collision with snake
		for segment in snake.segments:
			if segment.grid_pos == pos:
				return false
		
		# Check for collision with other animals
		for animal in animals:
			if animal.type == "cow":
				# Check if position is within cow's 2x2 area
				var cow_area = Rect2(animal.grid_pos.x, animal.grid_pos.y, 2, 2)
				if cow_area.has_point(pos):
					return false
			elif animal.grid_pos == pos:
				return false
		
		return true

# Move all animals according to their behavior
func move_animals():
	for animal in animals:
		if animal.type == "chicken":
			update_chicken_state(animal)
		
		if animal.flight_state == 1:  # Chicken in full flight - untouchable
			continue  # Skip movement for flying chickens
		
		move_animal(animal)

# Update chicken state based on snake proximity
func update_chicken_state(chicken_entity):
	if chicken_entity.flight_state > 0:
		# Already in flight, progress the animation
		chicken_entity.flight_state = (chicken_entity.flight_state + 1) % 3
		update_chicken_appearance(chicken_entity)
		return
	
	# Check if snake is within 1 cell
	var snake_head_pos = snake.segments[0].grid_pos
	var distance = abs(snake_head_pos.x - chicken_entity.grid_pos.x) + abs(snake_head_pos.y - chicken_entity.grid_pos.y)
	
	if distance <= 1:
		# Snake is close, start flight
		chicken_entity.flight_state = 1  # Full flight
		update_chicken_appearance(chicken_entity)

# Update chicken appearance based on flight state
func update_chicken_appearance(chicken_entity):
	match chicken_entity.flight_state:
		0:  # Normal
			chicken_entity.get_node("Sprite2D").texture = chicken_entity.texture
		1:  # Full flight
			chicken_entity.get_node("Sprite2D").texture = chicken_entity.flight_texture
		2:  # Mid flight
			chicken_entity.get_node("Sprite2D").texture = chicken_entity.mid_texture

# Move an animal based on its behavior
func move_animal(animal):
	var new_pos = animal.grid_pos
	
	match animal.movement_behavior:
		"perimeter":
			new_pos = move_perimeter(animal)
		"flee":
			new_pos = move_flee(animal)
		"linear":
			new_pos = move_linear(animal)
		"wander":
			new_pos = move_wander(animal)
	
	# Check if the new position is valid
	var valid_move = false
	
	if animal.type == "cow":
		# Check 2x2 area for cow
		valid_move = is_position_valid_for_animal(new_pos, "cow")
	else:
		# Standard check for other animals
		valid_move = grid.is_cell_vacant(new_pos)
		
		# Check for collision with snake
		for segment in snake.segments:
			if segment.grid_pos == new_pos:
				valid_move = false
		
		# Check for collision with other animals
		for other_animal in animals:
			if other_animal != animal:
				if other_animal.type == "cow":
					# Check if position is within cow's 2x2 area
					var cow_area = Rect2(other_animal.grid_pos.x, other_animal.grid_pos.y, 2, 2)
					if cow_area.has_point(new_pos):
						valid_move = false
				elif other_animal.grid_pos == new_pos:
					valid_move = false
	
	if valid_move:
		# Check for collectibles to destroy
		check_and_destroy_collectibles(animal, new_pos)
		
		# Move the animal
		animal.grid_pos = new_pos
		
		if animal.type == "cow":
			animal.position = grid.grid_to_world(new_pos) - Vector2(grid.CELL_SIZE/2, grid.CELL_SIZE/2)
		else:
			animal.position = grid.grid_to_world(new_pos)

# Mouse movement: follows perimeter unless near edible resources
func move_perimeter(animal):
	var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # Up, Right, Down, Left
	
	# First, check if any edible resources are within 5 tiles
	var collectibles_node = get_parent().get_node("Collectibles")
	var closest_resource = null
	var closest_distance = 6  # More than our threshold of 5
	
	for collectible in collectibles_node.get_children():
		if animal.destroys.has(collectible.resource_type):
			var collectible_grid_pos = grid.world_to_grid(collectible.position)
			var distance = abs(animal.grid_pos.x - collectible_grid_pos.x) + abs(animal.grid_pos.y - collectible_grid_pos.y)
			
			if distance < closest_distance:
				closest_resource = collectible
				closest_distance = distance
	
	# If there's an edible resource within range, move toward it
	if closest_resource and closest_distance <= 5:
		var target_pos = grid.world_to_grid(closest_resource.position)
		var best_dir = Vector2i(0, 0)
		var min_distance = 999
		
		for dir in directions:
			var new_pos = animal.grid_pos + dir
			var new_distance = abs(new_pos.x - target_pos.x) + abs(new_pos.y - target_pos.y)
			
			if new_distance < min_distance and grid.is_cell_vacant(new_pos):
				min_distance = new_distance
				best_dir = dir
		
		if best_dir != Vector2i(0, 0):
			return animal.grid_pos + best_dir
	
	# If no resources nearby or couldn't find a path, follow perimeter
	var perimeter_dirs = []
	
	for dir in directions:
		var new_pos = animal.grid_pos + dir
		
		# Is it near the perimeter?
		if new_pos.x == 1 or new_pos.x == grid.grid_size.x - 2 or new_pos.y == 1 or new_pos.y == grid.grid_size.y - 2:
			if grid.is_cell_vacant(new_pos):
				perimeter_dirs.append(dir)
	
	# If already on perimeter, prioritize staying on perimeter
	if animal.grid_pos.x == 1 or animal.grid_pos.x == grid.grid_size.x - 2 or animal.grid_pos.y == 1 or animal.grid_pos.y == grid.grid_size.y - 2:
		var filtered_perimeter_dirs = []
		for dir in perimeter_dirs:
			var new_pos = animal.grid_pos + dir
			if new_pos.x == 1 or new_pos.x == grid.grid_size.x - 2 or new_pos.y == 1 or new_pos.y == grid.grid_size.y - 2:
				filtered_perimeter_dirs.append(dir)
		
		if not filtered_perimeter_dirs.empty():
			perimeter_dirs = filtered_perimeter_dirs
	
	# If no perimeter directions available, move randomly inward
	if perimeter_dirs.empty():
		var valid_dirs = []
		for dir in directions:
			var new_pos = animal.grid_pos + dir
			if grid.is_cell_vacant(new_pos):
				valid_dirs.append(dir)
		
		if valid_dirs.empty():
			return animal.grid_pos  # Can't move
		
		return animal.grid_pos + valid_dirs[randi() % valid_dirs.size()]
	
	# Choose a random perimeter direction
	return animal.grid_pos + perimeter_dirs[randi() % perimeter_dirs.size()]

# Chicken movement: flee from snake
func move_flee(animal_entity):
	var snake_head_pos = snake.segments[0].grid_pos
	var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # Up, Right, Down, Left
	
	# 50% chance to move randomly, 50% chance to return to starting position
	if randf() < 0.5:
		return animal_entity.grid_pos + directions[randi() % directions.size()]
	else:
		# Try to move away from the snake
		var best_dir = Vector2i(0, 0)
		var max_distance = -1
		
		for dir in directions:
			var new_pos = animal_entity.grid_pos + dir
			var distance = abs(new_pos.x - snake_head_pos.x) + abs(new_pos.y - snake_head_pos.y)
			
			if distance > max_distance and grid.is_cell_vacant(new_pos):
				max_distance = distance
				best_dir = dir
		
		return animal_entity.grid_pos + best_dir

# Pig movement: linear paths
func move_linear(animal_entity):
	# If pig doesn't have a current direction, choose one
	if not animal_entity.has("current_dir") or animal_entity.current_dir == Vector2i(0, 0):
		var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # Up, Right, Down, Left
		animal_entity.current_dir = directions[randi() % directions.size()]
	
	# Try to keep moving in current direction
	var new_pos = animal_entity.grid_pos + animal_entity.current_dir
	
	# If we can't move in that direction, choose a new one
	if not grid.is_cell_vacant(new_pos):
		# Find possible directions
		var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
		var valid_dirs = []
		
		for dir in directions:
			if grid.is_cell_vacant(animal_entity.grid_pos + dir):
				valid_dirs.append(dir)
		
		if valid_dirs.empty():
			return animal_entity.grid_pos  # No valid move
		
		animal_entity.current_dir = valid_dirs[randi() % valid_dirs.size()]
		new_pos = animal_entity.grid_pos + animal_entity.current_dir
	
	return new_pos

# Cow movement: wander 2 cells at a time
func move_wander(animal_entity):
	var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # Up, Right, Down, Left
	
	# Get valid directions for first step
	var valid_dirs = []
	for dir in directions:
		var new_pos = animal_entity.grid_pos + dir
		if is_position_valid_for_animal(new_pos, "cow"):
			valid_dirs.append(dir)
	
	if valid_dirs.empty():
		return animal_entity.grid_pos  # No valid move
	
	# Choose random direction
	var chosen_dir = valid_dirs[randi() % valid_dirs.size()]
	
	# For cows, move 2 steps in the same direction
	var final_pos = animal_entity.grid_pos + chosen_dir
	
	# Try to take second step if possible
	var second_pos = final_pos + chosen_dir
	if is_position_valid_for_animal(second_pos, "cow"):
		final_pos = second_pos
	
	return final_pos

# Check for and destroy collectibles
func check_and_destroy_collectibles(animal, position):
	var collectibles_node = get_parent().get_node("Collectibles")
	
	if animal.type == "cow":
		# Check all 4 spots of the cow's 2x2 area
		for x in range(2):
			for y in range(2):
				var check_pos = position + Vector2i(x, y)
				for collectible in collectibles_node.get_children():
					var collectible_grid_pos = grid.world_to_grid(collectible.position)
					if collectible_grid_pos == check_pos:
						destroy_collectible(animal, collectible)
	elif animal.destroys.size() > 0:
		# Check for collectibles at animal's position
		for collectible in collectibles_node.get_children():
			var collectible_grid_pos = grid.world_to_grid(collectible.position)
			if collectible_grid_pos == position and animal.destroys.has(collectible.resource_type):
				destroy_collectible(animal, collectible)

# Destroy a collectible
func destroy_collectible(animal, collectible):
	# Create sparkle effect
	snake.create_sparkle_effect(collectible.position)
	
	# Remove the collectible
	collectible.queue_free()
