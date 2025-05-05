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

# Animal scenes
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
			
			if type == "cow":
				# Adjust position for center of 2x2 grid
				animal.position = grid.grid_to_world(grid_pos) - Vector2(grid.CELL_SIZE/2, grid.CELL_SIZE/2)
			else:
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
				# Cow needs a 2x2 area, so check differently
				grid_pos = Vector2i(
					randi_range(1, grid.grid_size.x - 3),  # -3 to account for 2x2 size
					randi_range(1, grid.grid_size.y - 3)
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
		
		# Check if position is valid using appropriate method
		if type == "cow":
			# Create a temporary cow to check validity
			var temp_cow = cow_scene.instantiate()
			temp_cow.grid_pos = grid_pos
			if temp_cow.is_position_valid(grid_pos):
				temp_cow.queue_free()
				return grid_pos
			temp_cow.queue_free()
		elif type == "fish":
			# TODO: Check if position is in water
			if is_position_valid_for_animal(grid_pos):
				return grid_pos
		else:
			if is_position_valid_for_animal(grid_pos):
				return grid_pos
	
	return Vector2i(-1, -1)  # No valid position found

# Check if a position is valid for an animal (standard check)
func is_position_valid_for_animal(pos):
	# Check if the cell is vacant
	if not grid.is_cell_vacant(pos):
		return false
	
	# Check for collision with snake
	for segment in snake.segments:
		if segment.grid_pos == pos:
			return false
	
	# Check for collision with existing animals
	for animal in animals:
		if animal.grid_pos == pos:
			return false
		
		# Special case for cow (2x2 size)
		if animal.type == "cow":
			for x in range(2):
				for y in range(2):
					if animal.grid_pos + Vector2i(x, y) == pos:
						return false
	
	return true

# Move all animals
func move_animals():
	for animal in animals:
		animal.move()

# Remove an animal (when collected by snake)
func remove_animal(animal):
	var index = animals.find(animal)
	if index != -1:
		animals.remove_at(index)
	animal.queue_free()