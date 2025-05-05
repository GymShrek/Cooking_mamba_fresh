# scripts/Main.gd
extends Node2D

@onready var grid = $Grid
@onready var collectibles = $Collectibles
@onready var snake = $Snake

var collectible_scene = preload("res://scenes/Collectible.tscn")

# All resource types
var static_resources = ["wheat", "tomato", "lettuce", "egg", "milk"]
var animal_resources = ["mouse", "chicken", "pig", "cow"]
var current_level = 1

# Timer for animal movement
var animal_move_timer = 0
var animal_move_delay = 0.5  # Animals move every 0.5 seconds

func _ready():
	# Initialize the game
	randomize()  # Initialize the random number generator
	setup_level(current_level)

func _process(delta):
	# Handle animal movement
	animal_move_timer += delta
	if animal_move_timer >= animal_move_delay:
		animal_move_timer = 0
		move_animals()

func setup_level(level_number):
	# Clear any existing collectibles
	for child in collectibles.get_children():
		child.queue_free()
	
	match level_number:
		1:
			# Level 1: Basic setup with all resource types
			spawn_static_resources(3)  # 3 of each static resource
			spawn_animals(1)  # 1 of each animal type
		_:
			# Default level setup
			spawn_static_resources(2)
			spawn_animals(1)

func spawn_static_resources(count_per_type):
	for resource_type in static_resources:
		for i in range(count_per_type):
			spawn_single_collectible(resource_type)

func spawn_animals(count_per_type):
	for animal_type in animal_resources:
		for i in range(count_per_type):
			spawn_single_collectible(animal_type)

func spawn_single_collectible(resource_type = ""):
	var collectible = collectible_scene.instantiate()
	
	# Choose a random resource type if none specified
	if resource_type == "":
		var all_resources = static_resources + animal_resources
		resource_type = all_resources[randi() % all_resources.size()]
	
	# Choose a random position that's not occupied by the snake, other collectibles, or walls
	var valid_position = false
	var grid_pos = Vector2i()
	var size_multiplier = 1
	
	# Set size multiplier for cow
	if resource_type == "cow":
		size_multiplier = 2
	
	# Special positioning for mice (prefer perimeter)
	if resource_type == "mouse":
		grid_pos = get_perimeter_position()
		if grid_pos != Vector2i(-1, -1):
			valid_position = true
	
	# If not a mouse or no valid perimeter position found, find a random position
	if not valid_position:
		while not valid_position:
			# Generate a random position
			grid_pos = Vector2i(
				randi_range(1, grid.grid_size.x - 2 * size_multiplier),
				randi_range(1, grid.grid_size.y - 2 * size_multiplier)
			)
			
			# Check if it's a valid position
			valid_position = is_valid_collectible_position(grid_pos, size_multiplier)
	
	# Set the position
	collectible.position = grid.grid_to_world(grid_pos)
	
	# Set the resource type
	collectible.set_resource_type(resource_type)
	
	# Add the collectible to the scene
	collectibles.add_child(collectible)
	
	return collectible

func is_valid_collectible_position(grid_pos, size_multiplier = 1):
	# Check if all required cells are vacant
	for x in range(size_multiplier):
		for y in range(size_multiplier):
			var check_pos = Vector2i(grid_pos.x + x, grid_pos.y + y)
			
			# Check if it collides with the grid
			if not grid.is_cell_vacant(check_pos):
				return false
			
			# Check if it collides with the snake
			for segment in snake.segments:
				if segment.grid_pos == check_pos:
					return false
			
			# Check if it collides with other collectibles
			for existing_collectible in collectibles.get_children():
				var existing_pos = grid.world_to_grid(existing_collectible.position)
				var existing_size = 2 if existing_collectible.resource_type == "cow" else 1
				
				# Check if the positions overlap
				for ex in range(existing_size):
					for ey in range(existing_size):
						if existing_pos + Vector2i(ex, ey) == check_pos:
							return false
	
	return true

func get_perimeter_position():
	var attempts = 20  # Limit the number of attempts
	
	for i in range(attempts):
		var side = randi() % 4  # 0: top, 1: right, 2: bottom, 3: left
		var pos = Vector2i()
		
		match side:
			0:  # Top
				pos = Vector2i(randi_range(1, grid.grid_size.x - 2), 1)
			1:  # Right
				pos = Vector2i(grid.grid_size.x - 2, randi_range(1, grid.grid_size.y - 2))
			2:  # Bottom
				pos = Vector2i(randi_range(1, grid.grid_size.x - 2), grid.grid_size.y - 2)
			3:  # Left
				pos = Vector2i(1, randi_range(1, grid.grid_size.y - 2))
		
		if is_valid_collectible_position(pos):
			return pos
	
	return Vector2i(-1, -1)  # No valid position found

func move_animals():
	for collectible in collectibles.get_children():
		if collectible.is_animal and collectible.is_moving:
			collectible.move(snake.segments)

func create_sparkle_effect(position):
	# Create a CPUParticles2D node for the sparkle effect
	var particles = CPUParticles2D.new()
	particles.position = position
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.lifetime = 0.5
	particles.amount = 15
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.gravity = Vector2(0, 98)
	particles.initial_velocity_min = 50
	particles.initial_velocity_max = 100
	particles.scale_amount_min = 1
	particles.scale_amount_max = 2
	
	# Set colors for sparkles
	var color_ramp = Gradient.new()
	color_ramp.colors = [Color(1, 1, 0.5, 1), Color(1, 1, 1, 0)]  # Yellow to transparent white
	particles.color_ramp = color_ramp
	
	# Add to the scene and set to auto-free when finished
	add_child(particles)
	
	# Set up a timer to remove the particles after they finish
	var timer = Timer.new()
	timer.wait_time = 1.0  # Slightly longer than particle lifetime
	timer.one_shot = true
	timer.autostart = true
	add_child(timer)
	
	# Connect the timer to a function that removes the particles
	timer.timeout.connect(func(): particles.queue_free(); timer.queue_free())
