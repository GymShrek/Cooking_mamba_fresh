# scripts/snake.gd
extends Node2D

# Basic movement directions
enum Direction { UP, RIGHT, DOWN, LEFT }

# References to scene nodes
@onready var grid = get_parent().get_node("Grid")

# Snake properties
var game_speed = 0.2
var current_direction = Direction.RIGHT
var next_direction = Direction.RIGHT
var segments = []
var turn_timer = 0
var turn_delay = game_speed  # 0.2 seconds per turn
var can_move = true

# Input buffer system
var input_buffer = []
var input_buffer_size = 3  # Store up to 3 inputs
var buffer_processing_time = game_speed/5  # Process buffer every 0.1 seconds
var buffer_timer = 0

# Snake body parts scenes
var head_scene = preload("res://scenes/SnakeHead.tscn")
var body_scene = preload("res://scenes/SnakeBody.tscn")
var tail_scene = preload("res://scenes/SnakeTail.tscn")

# Game state
var game_over = false
var resources_collected = []

# Reference to snake skin system
var snake_skin

signal resource_collected(resource_type)

func _ready():
	# Get the snake skin system
	snake_skin = get_node("/root/SnakeSkin")
	
	# Initialize the snake with just head and tail
	var head_pos = Vector2i(5, 7)
	var tail_pos = Vector2i(4, 7)
	
	# Create head
	var head = head_scene.instantiate()
	head.position = grid.grid_to_world(head_pos)
	add_child(head)
	
	# Create tail
	var tail = tail_scene.instantiate()
	tail.position = grid.grid_to_world(tail_pos)
	add_child(tail)
	
	# Store segments with their grid positions
	segments = [
		{
			"node": head,
			"grid_pos": head_pos,
			"carrying_food": false
		},
		{
			"node": tail,
			"grid_pos": tail_pos,
			"carrying_food": false
		}
	]
	
	# Update segment appearance
	update_segments_appearance()

func _process(delta):
	if game_over:
		return
		
	# Handle input and add to buffer
	handle_input()
	
	# Process the input buffer
	buffer_timer += delta
	if buffer_timer >= buffer_processing_time:
		buffer_timer = 0
		process_input_buffer()
	
	# Move snake based on turn timer
	turn_timer += delta
	if turn_timer >= turn_delay:
		turn_timer = 0
		move_snake()

# Input handling code
func handle_input():
	# Get input for direction change and add to buffer
	var new_direction = -1
	
	if Input.is_action_just_pressed("ui_up") and current_direction != Direction.DOWN:
		new_direction = Direction.UP
	elif Input.is_action_just_pressed("ui_right") and current_direction != Direction.LEFT:
		new_direction = Direction.RIGHT
	elif Input.is_action_just_pressed("ui_down") and current_direction != Direction.UP:
		new_direction = Direction.DOWN
	elif Input.is_action_just_pressed("ui_left") and current_direction != Direction.RIGHT:
		new_direction = Direction.LEFT
	
	# Add the new direction to the buffer if it's valid
	if new_direction != -1:
		# Don't add if it's the same as the last buffered input
		if input_buffer.size() == 0 or input_buffer.back() != new_direction:
			# Keep buffer at maximum size
			if input_buffer.size() >= input_buffer_size:
				input_buffer.pop_back()
			input_buffer.push_back(new_direction)

func process_input_buffer():
	if input_buffer.size() > 0:
		# Get the next input from the buffer
		next_direction = input_buffer.pop_front()

func move_snake():
	if not can_move:
		return
		
	# Set current direction to next direction
	current_direction = next_direction
	
	# Calculate new head position
	var head_pos = segments[0].grid_pos
	var new_head_pos = head_pos
	
	match current_direction:
		Direction.UP:
			new_head_pos = Vector2i(head_pos.x, head_pos.y - 1)
		Direction.RIGHT:
			new_head_pos = Vector2i(head_pos.x + 1, head_pos.y)
		Direction.DOWN:
			new_head_pos = Vector2i(head_pos.x, head_pos.y + 1)
		Direction.LEFT:
			new_head_pos = Vector2i(head_pos.x - 1, head_pos.y)
	
	# Check collision with walls
	if not grid.is_cell_vacant(new_head_pos):
		handle_collision()
		return
	
	# Check collision with self
	for segment in segments:
		if segment.grid_pos == new_head_pos:
			handle_collision()
			return
	
	# Check collision with collectibles
	var collectible = check_collectible_collision(new_head_pos)
	if collectible:
		collect_resource(collectible)
	
	# Move snake body
	move_body()
	
	# Update head position
	segments[0].grid_pos = new_head_pos
	segments[0].node.position = grid.grid_to_world(new_head_pos)
	
	# Update visual appearance
	update_segments_appearance()

func move_body():
	# Move each segment to the position of the one in front of it
	for i in range(segments.size() - 1, 0, -1):
		segments[i].grid_pos = segments[i-1].grid_pos
		segments[i].node.position = grid.grid_to_world(segments[i].grid_pos)

func handle_collision():
	game_over = true
	print("Game Over")
	# Implement game over logic here
	# For now, just stop the snake and print message
	can_move = false

func update_segments_appearance():
	# Update the rotation of each segment
	for i in range(segments.size()):
		update_segment_rotation(i)

func update_segment_rotation(index):
	var segment = segments[index]
	
	# Direction vector to next segment
	var dir_to_next = Vector2i(0, 0)
	if index < segments.size() - 1:
		dir_to_next = segments[index + 1].grid_pos - segment.grid_pos
	
	# Direction vector to previous segment
	var dir_from_prev = Vector2i(0, 0)
	if index > 0:
		dir_from_prev = segment.grid_pos - segments[index - 1].grid_pos
	
	# Handle head rotation
	if index == 0:
		# Rotate head based on direction
		match current_direction:
			Direction.UP:
				segment.node.rotation = deg_to_rad(270)
			Direction.RIGHT:
				segment.node.rotation = deg_to_rad(0)
			Direction.DOWN:
				segment.node.rotation = deg_to_rad(90)
			Direction.LEFT:
				segment.node.rotation = deg_to_rad(180)
	
	# Handle tail rotation
	elif index == segments.size() - 1:
		# Get direction from previous segment
		var direction = dir_from_prev
		
		# Rotate tail to face away from previous segment
		if direction == Vector2i(1, 0):  # Previous segment is to the right
			segment.node.rotation = deg_to_rad(180)
		elif direction == Vector2i(-1, 0):  # Previous segment is to the left
			segment.node.rotation = deg_to_rad(0)
		elif direction == Vector2i(0, 1):  # Previous segment is below
			segment.node.rotation = deg_to_rad(270)
		elif direction == Vector2i(0, -1):  # Previous segment is above
			segment.node.rotation = deg_to_rad(90)
	
	# Handle body segments rotation
	else:
		# Regular body segment - determine rotation based on neighboring segments
		if dir_from_prev.x == -dir_to_next.x and dir_from_prev.y == 0 and dir_to_next.y == 0:
			# Horizontal straight segment
			segment.node.rotation = deg_to_rad(0)
		elif dir_from_prev.y == -dir_to_next.y and dir_from_prev.x == 0 and dir_to_next.x == 0:
			# Vertical straight segment
			segment.node.rotation = deg_to_rad(90)
		# Corner segments
		elif (dir_from_prev.x == 0 and dir_to_next.y == 0) or (dir_from_prev.y == 0 and dir_to_next.x == 0):
			# Determine the specific corner type and set rotation
			if (dir_from_prev.y < 0 and dir_to_next.x > 0) or (dir_from_prev.x > 0 and dir_to_next.y < 0):
				# Top-right corner
				segment.node.rotation = deg_to_rad(0)
			elif (dir_from_prev.y < 0 and dir_to_next.x < 0) or (dir_from_prev.x < 0 and dir_to_next.y < 0):
				# Top-left corner
				segment.node.rotation = deg_to_rad(270)
			elif (dir_from_prev.y > 0 and dir_to_next.x > 0) or (dir_from_prev.x > 0 and dir_to_next.y > 0):
				# Bottom-right corner
				segment.node.rotation = deg_to_rad(90)
			elif (dir_from_prev.y > 0 and dir_to_next.x < 0) or (dir_from_prev.x < 0 and dir_to_next.y > 0):
				# Bottom-left corner
				segment.node.rotation = deg_to_rad(180)

func grow_snake_with_food(resource_type):
	# Create a new body segment carrying food
	var body = body_scene.instantiate()
	
	# Insert the new segment right behind the head (at position 1)
	body.position = grid.grid_to_world(segments[1].grid_pos)
	
	# Set it as carrying food with the specific resource type
	body.set_carrying_food(true, resource_type)
	
	# Insert the new segment after the head (position 1)
	add_child(body)
	segments.insert(1, {
		"node": body,
		"grid_pos": segments[1].grid_pos,
		"carrying_food": true,
		"resource_type": resource_type
	})
	
	# Update the segment appearances
	update_segments_appearance()

func check_collectible_collision(pos: Vector2i):
	# Check if any collectible is at the given position
	var collectibles_node = get_parent().get_node("Collectibles")
	
	# Check standard collectibles
	for collectible in collectibles_node.get_children():
		# Skip chickens that are flying (uncollectible)
		if collectible.resource_type == "chicken" and collectible.is_flying:
			continue
			
		var collectible_grid_pos = grid.world_to_grid(collectible.position)
		
		# For regular collectibles
		if collectible_grid_pos == pos:
			return collectible
	
	# Check for animal controllers' multi-cell animals
	var animal_controller = get_parent().get_node("AnimalController")
	if animal_controller:
		for animal in animal_controller.animals:
			# Skip chickens that are flying
			if animal.type == "chicken" and animal.is_flying:
				continue
				
			# For multi-cell animals, check all parts
			if animal.is_multi_cell:
				for part_pos in animal.part_positions:
					var world_part_pos = animal.get_world_part_position(animal.grid_pos, part_pos)
					if world_part_pos == pos:
						# Create a custom result that includes the animal and position
						return {
							"animal": animal,
							"part_pos": pos,
							"is_multi_part": true
						}
			# For regular animals
			elif animal.grid_pos == pos:
				return animal
	
	return null

func collect_resource(collectible):
	var resource_type = ""
	var is_animal = false
	var is_multi_part = false
	
	# Check if this is a multi-part animal part
	if typeof(collectible) == TYPE_DICTIONARY and collectible.has("is_multi_part"):
		is_multi_part = true
		var animal = collectible.animal
		var part_pos = collectible.part_pos
		
		# Handle multi-part animal collection
		var animal_controller = get_parent().get_node("AnimalController")
		if animal_controller:
			# Notify the animal controller that a part was eaten
			animal_controller.handle_animal_part_eaten(animal, part_pos)
		
		# Add the animal type to collected resources
		resource_type = animal.type
		is_animal = true
		
		# Create sparkle effect at the collision position
		get_parent().create_sparkle_effect(grid.grid_to_world(part_pos))
		
		# Signal that a resource was collected
		emit_signal("resource_collected", resource_type)
		
		# Add to resources collected list
		resources_collected.append(resource_type)
		
		# Grow snake with appropriate segment
		grow_snake_with_food(resource_type)
		
		return
	
	# Check if this is a regular animal from the AnimalController
	if collectible is Animal:
		resource_type = collectible.type
		is_animal = true
		
		# Remove the animal from the controller's list
		var animal_controller = get_parent().get_node("AnimalController")
		if animal_controller:
			animal_controller.remove_animal(collectible)
	else:
		# This is a regular collectible
		resource_type = collectible.resource_type
		is_animal = collectible.is_animal
	
	# Add resource to collected list
	resources_collected.append(resource_type)
	
	# Signal that a resource was collected
	emit_signal("resource_collected", resource_type)
	
	# Create sparkle effect at the collectible's position
	get_parent().create_sparkle_effect(collectible.position if collectible is Animal else collectible.position)
	
	# Grow the snake with a new segment
	grow_snake_with_food(resource_type)
	
	# Remove the collectible - Animals are removed by AnimalController.remove_animal
	if not (collectible is Animal):
		collectible.queue_free()
	
	# Spawn a new collectible - but only for static resources, not animals
	if not is_animal:
		get_parent().spawn_single_collectible()

func create_sparkle_effect(position):
	# Create a CPUParticles2D node for the sparkle effect
	var particles = CPUParticles2D.new()
	particles.position = position
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.lifetime = game_speed*2
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
	get_parent().add_child(particles)
	
	# Set up a timer to remove the particles after they finish
	var timer = Timer.new()
	timer.wait_time = 1.0  # Slightly longer than particle lifetime
	timer.one_shot = true
	timer.autostart = true
	get_parent().add_child(timer)
	
	# Connect the timer to a function that removes the particles
	timer.timeout.connect(func(): particles.queue_free(); timer.queue_free())
	
