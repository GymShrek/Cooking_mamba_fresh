# scripts/animals/cow.gd
extends Animal
class_name CowAnimal

var milk_proximity_range = 8 # Increased from 4 to 8

func _ready():
	super()
	type = "cow"
	movement_behavior = "wander"
	size = Vector2i(2, 2) # Cow is 2x2 grid cells
	scale = Vector2(2, 2) # Make visually 2x large

func setup_sprite():
	$Sprite2D.texture = load("res://assets/cow.png")
	# Adjust position of sprite for center of 2x2 grid
	$Sprite2D.position = Vector2(-grid.CELL_SIZE/4, -grid.CELL_SIZE/4)

func move():
	var snake_head_pos = snake.segments[0].grid_pos
	var new_pos = grid_pos
	
	# Cow movement based on milk proximity
	new_pos = move_based_on_milk(grid_pos)
	
	# Update facing direction and position
	update_facing_direction(new_pos)
	
	if new_pos != grid_pos:
		grid_pos = new_pos
		# Adjust position for center of 2x2 grid
		position = grid.grid_to_world(new_pos) - Vector2(grid.CELL_SIZE/2, grid.CELL_SIZE/2)

# Override position validity check for 2x2 size
# This function matches the parent signature with pos and an optional ignore_resource_type parameter
func is_position_valid(pos, ignore_resource_type = ""):
	# Check all 4 cells in the 2x2 area
	for x in range(2):
		for y in range(2):
			var check_pos = pos + Vector2i(x, y)
			if not grid.is_cell_vacant(check_pos):
				return false
			
			# Check for collision with snake
			for segment in snake.segments:
				if segment.grid_pos == check_pos:
					return false
			
			# Check for collision with other animals
			var collectibles_node = main.get_node("Collectibles")
			for collectible in collectibles_node.get_children():
				if collectible == self:
					continue
				
				if collectible.is_animal:
					var collectible_pos = grid.world_to_grid(collectible.position)
					
					# For regular animals
					if collectible.resource_type != "cow" and collectible_pos == check_pos:
						return false
					
					# For other cows
					if collectible.resource_type == "cow" and collectible != self:
						for cx in range(2):
							for cy in range(2):
								if collectible_pos + Vector2i(cx, cy) == check_pos:
									return false
	
	return true

# Cow movement: moves based on milk proximity
func move_based_on_milk(curr_pos):
	# Find nearest milk
	var nearest_milk = find_nearest_milk()
	var min_distance = 999999
	
	if nearest_milk:
		var milk_pos = grid.world_to_grid(nearest_milk.position)
		min_distance = (milk_pos - curr_pos).length()
		
		# If too far from milk, move toward it
		if min_distance > milk_proximity_range:
			# Calculate the direction vector
			var diff = milk_pos - curr_pos
			var move_dir = Vector2i()
			if abs(diff.x) > abs(diff.y):
				move_dir.x = 1 if diff.x > 0 else -1
			else:
				move_dir.y = 1 if diff.y > 0 else -1
			
			# Try to move 2 squares in the chosen direction
			var next_pos = Vector2i(curr_pos.x + move_dir.x * 2, curr_pos.y + move_dir.y * 2)
			if is_position_valid(next_pos):
				return next_pos
			
			# If can't move 2 squares, try 1 square
			next_pos = Vector2i(curr_pos.x + move_dir.x, curr_pos.y + move_dir.y)
			if is_position_valid(next_pos):
				return next_pos
		else:
			# If close enough to milk, move randomly but stay in range
			var directions = [
				Vector2i(1, 0),   # Right
				Vector2i(-1, 0),  # Left
				Vector2i(0, 1),   # Down
				Vector2i(0, -1)   # Up
			]
			
			# Shuffle directions
			directions.shuffle()
			
			# Choose first direction that keeps cow within range of milk
			for dir in directions:
				for steps in [2, 1]:  # Try 2 steps first, then 1
					var new_pos = Vector2i(curr_pos.x + dir.x * steps, curr_pos.y + dir.y * steps)
					if is_position_valid(new_pos):
						# Check if the new position is still within range of milk
						if (new_pos - milk_pos).length() <= milk_proximity_range:
							return new_pos
	else:
		# If no milk, move randomly
		var directions = [
			Vector2i(1, 0),   # Right
			Vector2i(-1, 0),  # Left
			Vector2i(0, 1),   # Down
			Vector2i(0, -1)   # Up
		]
		
		# Shuffle directions
		directions.shuffle()
		
		# Try each direction until we find a valid one
		for dir in directions:
			for steps in [2, 1]:  # Try 2 steps first, then 1
				var next_pos = Vector2i(curr_pos.x + dir.x * steps, curr_pos.y + dir.y * steps)
				if is_position_valid(next_pos):
					return next_pos
	
	return curr_pos  # Stay in place if no valid moves

# Find the nearest milk resource
func find_nearest_milk():
	var collectibles_node = main.get_node("Collectibles")
	var nearest_milk = null
	var min_distance = 999999
	
	for collectible in collectibles_node.get_children():
		if collectible.resource_type == "milk":
			var milk_pos = grid.world_to_grid(collectible.position)
			var distance = (milk_pos - grid_pos).length()
			if distance < min_distance:
				min_distance = distance
				nearest_milk = collectible
	
	return nearest_milk
