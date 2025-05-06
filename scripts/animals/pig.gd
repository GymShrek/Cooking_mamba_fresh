# scripts/animals/pig.gd
extends Animal
class_name PigAnimal

var current_dir = Vector2i()
@export var detection_range: int = 5  # Changed from 8 to 5 as requested
var destroyable_resources = ["milk", "tomato", "lettuce", "wheat", "egg"] # Priority order

func _ready():
	super()
	type = "pig"
	movement_behavior = "linear"
	destroys = destroyable_resources

func setup_sprite():
	$Sprite2D.texture = load("res://assets/pig.png")

func move():
	var snake_head_pos = snake.segments[0].grid_pos
	var new_pos = grid_pos
	
	# Check for resources to destroy
	var nearest_resource = find_nearest_destroyable_resource(grid_pos, detection_range)
	if nearest_resource:
		var resource_pos = grid.world_to_grid(nearest_resource.position)
		new_pos = move_toward_pos(grid_pos, resource_pos)
	else:
		new_pos = move_linear(grid_pos)
	
	# Update facing direction and position
	update_facing_direction(new_pos)
	
	if new_pos != grid_pos:
		# Check for collectible collision (for destroying resources)
		var collectible = check_collectible_at_position(new_pos)
		if collectible and can_destroy_resource(collectible):
			destroy_resource(collectible)
		
		grid_pos = new_pos
		position = grid.grid_to_world(new_pos)

# Pig linear movement
func move_linear(curr_pos):
	# If no current direction, choose a random direction
	if current_dir == Vector2i():
		var directions = [
			Vector2i(1, 0),   # Right
			Vector2i(-1, 0),  # Left
			Vector2i(0, 1),   # Down
			Vector2i(0, -1)   # Up
		]
		current_dir = directions[randi() % directions.size()]
	
	# Try to move in current direction
	var next_pos = curr_pos + current_dir
	
	# Check if next position is valid
	if is_position_valid(next_pos):
		return next_pos
	else:
		# If blocked, choose new direction
		choose_new_direction()
		return curr_pos  # Stay in place this turn
	
func choose_new_direction():
	var directions = [
		Vector2i(1, 0),   # Right
		Vector2i(-1, 0),  # Left
		Vector2i(0, 1),   # Down
		Vector2i(0, -1)   # Up
	]
	
	# Remove current direction
	var current_index = -1
	for i in range(directions.size()):
		if directions[i] == current_dir:
			current_index = i
			break
	
	if current_index != -1:
		directions.remove_at(current_index)
	
	# Shuffle remaining directions
	directions.shuffle()
	
	# Choose first valid direction
	for dir in directions:
		var new_pos = grid_pos + dir
		if is_position_valid(new_pos):
			current_dir = dir
			return
	
	# If no valid direction, set to zero
	current_dir = Vector2i()
