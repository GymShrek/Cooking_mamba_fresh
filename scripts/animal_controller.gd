# scripts/animal_controller.gd
# This is a simplified version to ensure animals display correctly
extends Node2D

# References to game nodes
@onready var grid = get_parent().get_node("Grid") 
@onready var snake = get_parent().get_node("Snake")

# Animal movement timer
var turn_timer = 0
var turn_delay = 0.2  # Match with snake's game_speed

# Keep track of all animals
var animals = []

# Animal scenes
var mouse_scene = preload("res://scenes/animals/Mouse.tscn")
var chicken_scene = preload("res://scenes/animals/Chicken.tscn")
var pig_scene = preload("res://scenes/animals/Pig.tscn")
var cow_scene = preload("res://scenes/animals/Cow.tscn")
var fish_scene = preload("res://scenes/animals/Fish.tscn")

func _ready():
	# Initialize after a short delay to ensure other nodes are ready
	await get_tree().process_frame
	await get_tree().process_frame
	initialize()

func initialize():
	# Check if references are valid
	if grid == null:
		push_error("Grid reference is null in AnimalController")
		grid = get_parent().get_node_or_null("Grid")
		if grid == null:
			await get_tree().process_frame
			initialize()
			return
	
	if snake == null:
		push_error("Snake reference is null in AnimalController")
		snake = get_parent().get_node_or_null("Snake")
		if snake == null:
			await get_tree().process_frame
			initialize()
			return
	
	# Now that everything is initialized, spawn animals
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
	await spawn_animals("mouse", 2)
	await spawn_animals("chicken", 1)
	await spawn_animals("pig", 1)
	await spawn_animals("cow", 1)

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
		
		# Find a valid position
		var grid_pos = await find_valid_spawn_position(type)
		
		if grid_pos == Vector2i(-1, -1):
			# Couldn't find a valid position
			animal.queue_free()
			push_error("Couldn't find valid spawn position for " + type)
			continue
		
		# Set position based on grid
		animal.grid_pos = grid_pos
		animal.position = grid.grid_to_world(grid_pos)
		
		# Ensure proper name
		animal.name = type.capitalize() + str(i)
		
		# Add to scene and track
		add_child(animal)
		animals.append(animal)
		
		# Wait a frame to ensure animal is fully initialized
		await get_tree().process_frame

# Find a valid position for spawning an animal
func find_valid_spawn_position(type):
	var attempts = 30
	var grid_pos = Vector2i()
	
	for attempt in range(attempts):
		# Generate a random position away from walls
		grid_pos = Vector2i(
			randi_range(2, grid.grid_size.x - 3),
			randi_range(2, grid.grid_size.y - 3)
		)
		
		# Check if position is valid using grid
		if grid.is_cell_vacant(grid_pos):
			# For multi-cell animals, check additional spaces
			if type == "cow":
				# Check 2x2 area
				var valid = true
				for x in range(2):
					for y in range(2):
						if not grid.is_cell_vacant(Vector2i(grid_pos.x + x, grid_pos.y + y)):
							valid = false
							break
				if valid:
					return grid_pos
			elif type == "pig":
				# Check 2x1 area
				if grid.is_cell_vacant(Vector2i(grid_pos.x + 1, grid_pos.y)):
					return grid_pos
			else:
				# Single-cell animal
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
	animal.handle_part_eaten(pos)
	
	# Check if the animal should be removed completely - using property checks with 'in' operator
	if (animal.type == "cow" and "part_1_1_eaten" in animal and 
		animal.part_1_1_eaten and animal.part_1_2_eaten and 
		animal.part_2_1_eaten and animal.part_2_2_eaten):
		remove_animal(animal)
	elif (animal.type == "pig" and "front_part_eaten" in animal and 
		animal.front_part_eaten and animal.back_part_eaten):
		remove_animal(animal)
	elif (not "is_multi_cell" in animal or not animal.is_multi_cell):
		# For single-cell animals, just remove them
		remove_animal(animal)

# Remove an animal (when collected by snake)
func remove_animal(animal):
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

# Helper extension
func has_variable(object, variable_name):
	return variable_name in object
