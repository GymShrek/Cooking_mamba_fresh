# scripts/animals/mouse.gd
extends Animal
class_name MouseAnimal

# Make these properties exportable so they can be modified in the Godot UI
@export var detection_range: int = 3  # Detection range for resources
@export var flee_distance: int = 2    # Distance to flee from snake

func _ready():
	super()
	type = "mouse"
	movement_behavior = "perimeter"
	destroys = ["wheat", "tomato", "lettuce", "egg", "milk"] # Resources mouse can destroy
	
func setup_sprite():
	$Sprite2D.texture = load("res://assets/mouse.png")
	
func move():
	var snake_head_pos = snake.segments[0].grid_pos
	var new_pos = grid_pos
	
	# Check if there are nearby resources to destroy
	var nearby_resource = find_nearest_destroyable_resource(grid_pos, detection_range)
	if nearby_resource:
		# Move toward the resource
		var resource_pos = grid.world_to_grid(nearby_resource.position)
		new_pos = move_toward_pos(grid_pos, resource_pos)
	else:
		new_pos = follow_perimeter(grid_pos, snake_head_pos)
	
	# Update facing direction and position
	update_facing_direction(new_pos)
	
	if new_pos != grid_pos:
		# Check for collectible collision (for destroying resources)
		var collectible = check_collectible_at_position(new_pos)
		if collectible and can_destroy_resource(collectible):
			destroy_resource(collectible)
		
		grid_pos = new_pos
		position = grid.grid_to_world(new_pos)

# Mouse movement: follows perimeter unless close to destroyable resources
func follow_perimeter(curr_pos, snake_head_pos):
	var perimeter_moves = []
	
	# Check if at edge, if so follow edge
	if curr_pos.x <= 1 or curr_pos.x >= grid.grid_size.x - 2 or curr_pos.y <= 1 or curr_pos.y >= grid.grid_size.y - 2:
		# Add possible perimeter moves
		if curr_pos.x <= 1 and curr_pos.y > 1:
			perimeter_moves.append(Vector2i(curr_pos.x, curr_pos.y - 1))  # Move up
		if curr_pos.x <= 1 and curr_pos.y < grid.grid_size.y - 2:
			perimeter_moves.append(Vector2i(curr_pos.x, curr_pos.y + 1))  # Move down
		if curr_pos.y <= 1 and curr_pos.x < grid.grid_size.x - 2:
			perimeter_moves.append(Vector2i(curr_pos.x + 1, curr_pos.y))  # Move right
		if curr_pos.y >= grid.grid_size.y - 2 and curr_pos.x < grid.grid_size.x - 2:
			perimeter_moves.append(Vector2i(curr_pos.x + 1, curr_pos.y))  # Move right
		if curr_pos.y >= grid.grid_size.y - 2 and curr_pos.x > 1:
			perimeter_moves.append(Vector2i(curr_pos.x - 1, curr_pos.y))  # Move left
		if curr_pos.x >= grid.grid_size.x - 2 and curr_pos.y > 1:
			perimeter_moves.append(Vector2i(curr_pos.x, curr_pos.y - 1))  # Move up
		if curr_pos.x >= grid.grid_size.x - 2 and curr_pos.y < grid.grid_size.y - 2:
			perimeter_moves.append(Vector2i(curr_pos.x, curr_pos.y + 1))  # Move down
		if curr_pos.y <= 1 and curr_pos.x > 1:
			perimeter_moves.append(Vector2i(curr_pos.x - 1, curr_pos.y))  # Move left
	else:
		# Move toward nearest perimeter
		var distances = [
			{"edge": "left", "dist": curr_pos.x - 1},
			{"edge": "right", "dist": grid.grid_size.x - 2 - curr_pos.x},
			{"edge": "top", "dist": curr_pos.y - 1},
			{"edge": "bottom", "dist": grid.grid_size.y - 2 - curr_pos.y}
		]
		
		# Sort by distance
		distances.sort_custom(func(a, b): return a.dist < b.dist)
		
		# Move toward nearest edge
		match distances[0].edge:
			"left":
				perimeter_moves.append(Vector2i(curr_pos.x - 1, curr_pos.y))
			"right":
				perimeter_moves.append(Vector2i(curr_pos.x + 1, curr_pos.y))
			"top":
				perimeter_moves.append(Vector2i(curr_pos.x, curr_pos.y - 1))
			"bottom":
				perimeter_moves.append(Vector2i(curr_pos.x, curr_pos.y + 1))
	
	# Filter out invalid moves
	var valid_moves = []
	for move in perimeter_moves:
		if is_position_valid(move):
			valid_moves.append(move)
	
	if valid_moves.size() > 0:
		# Try to move away from snake if it's close
		if snake_head_pos != Vector2i(-1, -1) and (snake_head_pos - curr_pos).length() < flee_distance:
			# Sort moves by distance from snake head (furthest first)
			valid_moves.sort_custom(func(a, b): 
				var dist_a = (a - snake_head_pos).length()
				var dist_b = (b - snake_head_pos).length()
				return dist_a > dist_b
			)
			return valid_moves[0]
		else:
			# Pick random valid move
			return valid_moves[randi() % valid_moves.size()]
	
	return curr_pos  # Stay in place if no valid moves
