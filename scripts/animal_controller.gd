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
	call_deferred("initialize")

func initialize():
	# This will run after the current frame is complete
	if snake and snake.segments.size() > 0:
		# Initial animal spawning
		spawn_initial_animals()
	else:
		# If snake isn't ready yet, try again in the next frame
		call_deferred("initialize")

func _process(delta):
	# Move animals based on turn timer (sync with snake movement)
	turn_timer += delta
	if turn_timer >= turn_delay:
		turn_timer = 0
		move_animals()

# Spawn initial animals for the level
func spawn_initial_animals():
	spawn_animals("mouse", 3)
	spawn_animals("chicken", 2)
	spawn_animals("pig", 1)
	spawn_animals("cow", 1)
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
		
		# Find a valid position based on animal type
		var grid_pos = find_valid_spawn_position(type)
		
		if grid_pos != Vector2i(-1, -1):
			# Set position based on grid
			animal.grid_pos = grid_pos
			
			# For multi-cell animals, the position is handled by their internal code
			# For single-cell animals, use the grid_pos directly
			animal.position = grid.grid_to_world(grid_pos)
			
			# Add to scene and track
			add_child(animal)
			animals.append(animal)

# Find a valid position for spawning an animal
func find_valid_spawn_position(type):
	var attempts = 20
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
	for animal in animals:
		animal.move()

# Handle animal part eaten by snake
func handle_animal_part_eaten(animal, pos):
	# Call the animal's specific handler
	if animal.is_multi_cell:
		animal.handle_part_eaten(pos)
	else:
		# For single-cell animals, just remove them
		remove_animal(animal)

# Remove an animal (when collected by snake)
func remove_animal(animal):
	var index = animals.find(animal)
	if index != -1:
		animals.remove_at(index)
	animal.queue_free()
