# scripts/animal_controller.gd
extends Node2D

# References to game nodes
@onready var grid = get_parent().get_node("Grid") 
@onready var snake = get_parent().get_node("Snake")

# Animal movement timer
var turn_timer = 0
var turn_delay = 0.2  # Match with snake's game_speed

# Keep track of all animals
var animals = []

# Animal scenes - ALL animals are handled through these scenes
var mouse_scene = preload("res://scenes/animals/Mouse.tscn")
var chicken_scene = preload("res://scenes/animals/Chicken.tscn")
var pig_scene = preload("res://scenes/animals/Pig.tscn")
var cow_scene = preload("res://scenes/animals/Cow.tscn")
var fish_scene = preload("res://scenes/animals/Fish.tscn")

func _ready():
	# Initialize after a short delay to ensure other nodes are ready
	# We'll use await instead of call_deferred for more reliable initialization
	await get_tree().process_frame
	await get_tree().process_frame
	initialize()

func initialize():
	# Check if references are valid
	if grid == null:
		push_error("Grid reference is null in AnimalController")
		grid = get_parent().get_node_or_null("Grid")
		if grid == null:
			# Wait one more frame and try again
			await get_tree().process_frame
			initialize()
			return
	
	if snake == null:
		push_error("Snake reference is null in AnimalController")
		snake = get_parent().get_node_or_null("Snake")
		if snake == null:
			# Wait one more frame and try again
			await get_tree().process_frame
			initialize()
			return
	
	# Check if snake has segments before proceeding
	if snake.segments == null or snake.segments.size() == 0:
		# Wait one more frame and try again
		await get_tree().process_frame
		initialize()
		return
	
	# Now that everything is properly initialized, spawn animals
	await spawn_initial_animals()

func _process(delta):
	# Move animals based on turn timer (sync with snake movement)
	turn_timer += delta
	if turn_timer >= turn_delay:
		turn_timer = 0
		move_animals()

# Spawn initial animals for the level
func spawn_initial_animals():
	print("Spawning initial animals")
	await spawn_animals("mouse", 3)
	await spawn_animals("chicken", 2)
	await spawn_animals("pig", 1)
	await spawn_animals("cow", 1)
	# Fish will be spawned in water areas when they're implemented

# Spawn a specific number of a given animal type
func spawn_animals(type, count):
	for i in range(count):
		var animal
		match type:
			"mouse":
				animal = mouse_scene.instantiate()
			"chicken":
				animal = chicken_scene.instantiate()
			"pig":
				animal = pig_scene.instantiate()
			"cow":
				animal = cow_scene.instantiate()
			"fish":
				animal = fish_scene.instantiate()
			_:
				push_error("Unknown animal type: " + type)
				return
		
		# Find a valid position based on animal type - use await here
		var grid_pos = await find_valid_spawn_position(type)
		
		if grid_pos == Vector2i(-1, -1):
			# Couldn't find a valid position
			animal.queue_free()
			push_error("Couldn't find valid spawn position for " + type)
			continue
		
		# Set position based on grid
		animal.grid_pos = grid_pos
		
		# For multi-cell animals, the position is handled by their internal code
		# For single-cell animals, use the grid_pos directly
		animal.position = grid.grid_to_world(grid_pos)
		
		# Ensure the animal gets properly initialized
		animal.name = type.capitalize() + str(i)
		
		# Add to scene and track
		add_child(animal)
		animals.append(animal)
		
		# For multi-cell animals, ensure their parts are properly positioned
		if animal.is_multi_cell:
			# Wait a frame to make sure the animal is fully initialized
			await get_tree().process_frame
			if animal.has_method("update_part_positions"):
				animal.update_part_positions()

# Find a valid position for spawning an animal
# This is now a coroutine function that uses await
func find_valid_spawn_position(type):
	var attempts = 30  # Increase the number of attempts
	var grid_pos = Vector2i()
	
	for attempt in range(attempts):
		match type:
			"mouse":
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
			
			"cow":
				# Cow needs a 2x2 area
				grid_pos = Vector2i(
					randi_range(1, grid.grid_size.x - 3),  # -3 to account for 2x2 size
					randi_range(1, grid.grid_size.y - 3)
				)
			
			"pig":
				# Pig needs a 2x1 area
				grid_pos = Vector2i(
					randi_range(1, grid.grid_size.x - 3),  # -3 to account for 2x1 size
					randi_range(1, grid.grid_size.y - 2)
				)
			
			"fish":
				# Fish will spawn in water areas when implemented
				# For now, use a random position
				grid_pos = Vector2i(
					randi_range(1, grid.grid_size.x - 2),
					randi_range(1, grid.grid_size.y - 2)
				)
			
			_:
				# Other animals spawn anywhere valid
				grid_pos = Vector2i(
					randi_range(1, grid.grid_size.x - 2),
					randi_range(1, grid.grid_size.y - 2)
				)
		
		# Create a temporary animal to check position validity
		var temp_animal
		match type:
			"cow":
				temp_animal = cow_scene.instantiate()
			"pig":
				temp_animal = pig_scene.instantiate()
			"mouse":
				temp_animal = mouse_scene.instantiate()
			"chicken":
				temp_animal = chicken_scene.instantiate()
			"fish":
				temp_animal = fish_scene.instantiate()
		
		# Set the grid position
		temp_animal.grid_pos = grid_pos
		
		# We need to add it to the scene to properly initialize it
		add_child(temp_animal)
		
		# Wait a frame to ensure it's initialized
		await get_tree().process_frame
		
		# Check if position is valid using the animal's own validation method
		var is_valid = false
		if temp_animal.is_multi_cell:
			is_valid = temp_animal.is_multi_cell_position_valid(grid_pos)
		else:
			is_valid = temp_animal.is_position_valid(grid_pos)
		
		# Clean up the temporary animal
		temp_animal.queue_free()
		
		if is_valid:
			return grid_pos
	
	return Vector2i(-1, -1)  # No valid position found

# Move all animals
func move_animals():
	# Create a copy of the animals array to avoid issues if the array changes during iteration
	var animals_to_move = animals.duplicate()
	
	for animal in animals_to_move:
		if is_instance_valid(animal) and animal.has_method("move"):
			animal.move()
		else:
			# Remove invalid animals from the list
			var index = animals.find(animal)
			if index >= 0:
				animals.remove_at(index)

# Handle animal part eaten by snake
func handle_animal_part_eaten(animal, pos):
	# Make sure the animal is valid
	if not is_instance_valid(animal):
		push_error("Invalid animal in handle_animal_part_eaten")
		return
	
	# Make sure animal has the right methods
	if not animal.has_method("handle_part_eaten"):
		push_error("Animal doesn't have handle_part_eaten method")
		return
	
	# Call the animal's specific handler for part eating
	if animal.is_multi_cell:
		animal.handle_part_eaten(pos)
		
		# Check if the animal still has any parts left
		var all_parts_eaten = false
		
		if animal.type == "cow":
			all_parts_eaten = animal.part_1_1_eaten and animal.part_1_2_eaten and animal.part_2_1_eaten and animal.part_2_2_eaten
		elif animal.type == "pig":
			all_parts_eaten = animal.front_part_eaten and animal.back_part_eaten
			
		# If all parts eaten, remove the animal
		if all_parts_eaten:
			remove_animal(animal)
	else:
		# For single-cell animals, just remove them
		remove_animal(animal)

# Remove an animal (when collected by snake)
func remove_animal(animal):
	# Make sure the animal is valid
	if not is_instance_valid(animal):
		push_error("Invalid animal in remove_animal")
		var index = animals.find(animal)
		if index != -1:
			animals.remove_at(index)
		return
	
	var index = animals.find(animal)
	if index != -1:
		animals.remove_at(index)
	
	animal.queue_free()
