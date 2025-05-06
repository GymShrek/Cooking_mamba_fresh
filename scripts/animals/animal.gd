# scripts/animals/animal.gd
extends Node2D
class_name Animal

# Animal properties
var type = ""
var grid_pos = Vector2i()
var size = Vector2i(1, 1) # Default size is 1x1 (will be 2x2 for cow)
var speed = 1
var destroys = []
var movement_behavior = "wander"
var facing_direction = Vector2i(1, 0) # Default facing right

# For chicken animation
var is_flying = false
var flying_cooldown = 0
var jump_pos = Vector2i() # Added to store the position of a jump

# References to other nodes
var grid
var main
var snake

func _ready():
	# Initialize references
	main = get_node("/root/Main")
	grid = main.get_node("Grid")
	snake = main.get_node("Snake")
	
	# Store starting position
	var starting_pos = grid_pos
	
	# Setup sprite
	setup_sprite()
	
	# Connect to signals if needed
	# Example: snake.connect("moved", self, "_on_snake_moved")

func setup_sprite():
	# Override in child classes to set up specific animal sprites
	pass

func move():
	# Base movement logic - override in child classes
	pass

# Handle facing direction based on movement
func update_facing_direction(new_pos):
	if new_pos != grid_pos:
		facing_direction = new_pos - grid_pos
		update_sprite_direction()

func update_sprite_direction():
	# Reset rotation and flip
	$Sprite2D.rotation = 0
	$Sprite2D.flip_h = false
	$Sprite2D.flip_v = false
	
	# Apply appropriate transform based on facing direction
	if facing_direction.x > 0:  # Right
		$Sprite2D.flip_h = true
	elif facing_direction.x < 0:  # Left
		# Default sprite orientation is typically facing left
		pass
	elif facing_direction.y > 0:  # Down
		$Sprite2D.rotation = deg_to_rad(-90)
	elif facing_direction.y < 0:  # Up
		$Sprite2D.rotation = deg_to_rad(90)

# Check if a position is valid (not occupied by other animals, snake, or walls)
# The pos parameter is the position to check
# The ignore_resource_type parameter is an optional resource type to ignore in collision checks
func is_position_valid(pos, ignore_resource_type = ""):
	# Check if it's within the grid bounds and not a wall
	if not grid.is_cell_vacant(pos):
		return false
	
	# Check for collision with snake
	for segment in snake.segments:
		if segment.grid_pos == pos:
			return false
	
	# Check for collision with other animals
	var collectibles_node = main.get_node("Collectibles")
	for collectible in collectibles_node.get_children():
		if collectible == self or collectible.resource_type == ignore_resource_type:
			continue
		
		if collectible.is_animal:
			var collectible_pos = grid.world_to_grid(collectible.position)
			
			# For regular animals
			if collectible.resource_type != "cow" and collectible_pos == pos:
				return false
			
			# For cow (2x2 size)
			if collectible.resource_type == "cow":
				for x in range(2):
					for y in range(2):
						if collectible_pos + Vector2i(x, y) == pos:
							return false
	
	return true

# Helper function to move toward a target position
func move_toward_pos(curr_pos, target_pos):
	var diff = target_pos - curr_pos
	var move_dir = Vector2i()
	
	# Choose the primary direction (horizontal or vertical)
	if abs(diff.x) > abs(diff.y):
		move_dir.x = 1 if diff.x > 0 else -1
	else:
		move_dir.y = 1 if diff.y > 0 else -1
	
	var next_pos = Vector2i(curr_pos.x + move_dir.x, curr_pos.y + move_dir.y)
	
	# Check if the move is valid
	if is_position_valid(next_pos):
		return next_pos
	
	# Try the other direction if primary is blocked
	move_dir = Vector2i()
	if abs(diff.x) <= abs(diff.y):
		move_dir.x = 1 if diff.x > 0 else -1
	else:
		move_dir.y = 1 if diff.y > 0 else -1
	
	next_pos = Vector2i(curr_pos.x + move_dir.x, curr_pos.y + move_dir.y)
	
	# Check if the alternate move is valid
	if is_position_valid(next_pos):
		return next_pos
	
	return curr_pos  # Stay in place if no valid moves

# Check if there's a collectible at a given position
func check_collectible_at_position(pos):
	var collectibles_node = main.get_node("Collectibles")
	
	for collectible in collectibles_node.get_children():
		if collectible == self:
			continue
			
		var collectible_pos = grid.world_to_grid(collectible.position)
		if collectible_pos == pos:
			return collectible
	
	return null

# Check if this animal can destroy the given resource
func can_destroy_resource(collectible):
	# Check if the collectible is a static resource that this animal can destroy
	return not collectible.is_animal and collectible.resource_type in destroys

# Destroy a resource
func destroy_resource(collectible):
	# Create sparkle effect
	main.create_sparkle_effect(collectible.position)
	
	# Remove the collectible
	collectible.queue_free()

# Find the nearest resource that this animal can destroy
# This was missing from the base class and causing the error
func find_nearest_destroyable_resource(curr_pos, max_distance):
	var collectibles_node = main.get_node("Collectibles")
	var nearest_resource = null
	var min_distance = max_distance + 1  # Beyond our search range
	
	# Check all collectibles
	for collectible in collectibles_node.get_children():
		# Skip if not a destroyable resource or if it's another animal
		if collectible.is_animal or not (collectible.resource_type in destroys):
			continue
		
		var resource_pos = grid.world_to_grid(collectible.position)
		var distance = (resource_pos - curr_pos).length()
		
		if distance < min_distance:
			min_distance = distance
			nearest_resource = collectible
	
	return nearest_resource
