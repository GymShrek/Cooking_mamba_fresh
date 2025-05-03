# scripts/Main.gd
extends Node2D

@onready var grid = $Grid
@onready var collectibles = $Collectibles
@onready var snake = $Snake

var collectible_scene = preload("res://scenes/Collectible.tscn")
var resource_types = ["wheat"]  # For now, just wheat

func _ready():
	# Initialize the game
	spawn_collectibles(5)  # Spawn 5 collectibles to start

func spawn_collectibles(count):
	for i in range(count):
		spawn_single_collectible()

func spawn_single_collectible():
	var collectible = collectible_scene.instantiate()
	
	# Choose a random position that's not occupied by the snake or walls
	var valid_position = false
	var grid_pos = Vector2i()
	
	while not valid_position:
		# Generate a random position
		grid_pos = Vector2i(
			randi_range(1, grid.grid_size.x - 2),
			randi_range(1, grid.grid_size.y - 2)
		)
		
		# Check if it's a valid position
		valid_position = true
		
		# Check if it collides with the grid
		if not grid.is_cell_vacant(grid_pos):
			valid_position = false
			continue
		
		# Check if it collides with the snake
		for segment in snake.segments:
			if segment.grid_pos == grid_pos:
				valid_position = false
				break
				
		# Check if it collides with other collectibles
		for existing_collectible in collectibles.get_children():
			var existing_pos = grid.world_to_grid(existing_collectible.position)
			if existing_pos == grid_pos:
				valid_position = false
				break
	
	# Set the position
	collectible.position = grid.grid_to_world(grid_pos)
	
	# Set the resource type (for now just wheat)
	collectible.set_resource_type(resource_types[0])
	
	# Add the collectible to the scene
	collectibles.add_child(collectible)
