# scripts/snake/snake.gd
extends Node2D

# Basic movement directions
enum Direction { UP, RIGHT, DOWN, LEFT }

# References to scene nodes
@onready var grid = get_parent().get_node("Grid")

# Dictionary of resources that should be treated as double-width
var double_width_resources = ["cow"]  # Add any future double-width resources here

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

signal resource_collected(resource_type)

func _ready():
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

# Input handling code remains the same
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

func check_collectible_collision(pos: Vector2i):
	# Check if any collectible is at the given position
	var collectibles_node = get_parent().get_node("Collectibles")
	for collectible in collectibles_node.get_children():
		# Skip chickens that are flying (uncollectible)
		if collectible.resource_type == "chicken" and collectible.is_flying:
			continue
			
		var collectible_grid_pos = grid.world_to_grid(collectible.position)
		
		# For regular collectibles
		if collectible_grid_pos == pos:
			return collectible
		
		# Special case for cow (2x2 size) - make entire cow collectible
		if collectible.resource_type == "cow":
			# Check if snake head collides with any part of the cow
			for x in range(2):
				for y in range(2):
					if collectible_grid_pos + Vector2i(x, y) == pos:
						return collectible
	
	return null

func collect_resource(collectible):
	# Get the resource type from the collectible
	var resource_type = collectible.resource_type
	
	# Add resource to collected list
	resources_collected.append(resource_type)
	
	# Signal that a resource was collected
	emit_signal("resource_collected", resource_type)
	
	# Create sparkle effect at the collectible's position
	get_parent().create_sparkle_effect(collectible.position)
	
	# Handle different resource types
	if resource_type in double_width_resources:
		# Special case for double-width resources
		grow_snake_with_double_segment(resource_type)
	else:
		# Regular resources add a regular body segment
		grow_snake_with_food(resource_type)
	
	# Remove the collectible
	collectible.queue_free()
	
	# Spawn a new collectible - but only for static resources
	if not collectible.is_animal:
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
