# scripts/main.gd
extends Node2D

@onready var grid = $Grid
@onready var collectibles = $Collectibles
@onready var snake = $Snake
@onready var animal_controller = $AnimalController

var collectible_scene = preload("res://scenes/Collectible.tscn")

# All resource types
var static_resources = ["wheat", "tomato", "lettuce", "egg", "milk"]
var current_level = 1

func _ready():
	# Initialize the game
	randomize()  # Initialize the random number generator
	setup_level(current_level)

func setup_level(level_number):
	# Clear any existing collectibles
	for child in collectibles.get_children():
		child.queue_free()
	
	match level_number:
		1:
			# Level 1: Basic setup with static resources
			spawn_static_resources(3)  # 3 of each static resource
		_:
			# Default level setup
			spawn_static_resources(2)

func spawn_static_resources(count_per_type):
	for resource_type in static_resources:
		for i in range(count_per_type):
			spawn_single_collectible(resource_type)

func spawn_single_collectible(resource_type = ""):
	var collectible = collectible_scene.instantiate()
	
	# Choose a random resource type if none specified
	if resource_type == "":
		resource_type = static_resources[randi() % static_resources.size()]
	
	# Choose a random position that's not occupied by the snake, other collectibles, or walls
	var valid_position = false
	var grid_pos = Vector2i()
	
	# Find a valid position
	while not valid_position:
		# Generate a random position
		grid_pos = Vector2i(
			randi_range(1, grid.grid_size.x - 2),
			randi_range(1, grid.grid_size.y - 2)
		)
		
		# Check if it's a valid position
		valid_position = is_valid_collectible_position(grid_pos)
	
	# Set the position
	collectible.position = grid.grid_to_world(grid_pos)
	
	# Set the resource type
	collectible.set_resource_type(resource_type)
	
	# Add the collectible to the scene
	collectibles.add_child(collectible)
	
	return collectible

func is_valid_collectible_position(grid_pos):
	# Check if it collides with the grid
	if not grid.is_cell_vacant(grid_pos):
		return false
	
	# Check if it collides with the snake
	for segment in snake.segments:
		if segment.grid_pos == grid_pos:
			return false
	
	# Check if it collides with other collectibles
	for existing_collectible in collectibles.get_children():
		var existing_pos = grid.world_to_grid(existing_collectible.position)
		var existing_size = 2 if existing_collectible.resource_type == "cow" else 1
		
		# Check if the positions overlap
		for ex in range(existing_size):
			for ey in range(existing_size):
				if existing_pos + Vector2i(ex, ey) == grid_pos:
					return false
	
	return true

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
