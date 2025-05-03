# scripts/Snake.gd
extends Node2D

# Basic movement directions
enum Direction { UP, RIGHT, DOWN, LEFT }

# References to scene nodes
@onready var grid: TileMap = get_parent().get_node("Grid")

# Snake properties
var current_direction = Direction.RIGHT
var next_direction = Direction.RIGHT
var segments = []
var turn_timer = 0
var turn_delay = 0.5  # 0.5 seconds per turn
var can_move = true

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
		
	# Handle input
	handle_input()
	
	# Move snake based on turn timer
	turn_timer += delta
	if turn_timer >= turn_delay:
		turn_timer = 0
		move_snake()

func handle_input():
	# Get input for direction change
	if Input.is_action_just_pressed("ui_up") and current_direction != Direction.DOWN:
		next_direction = Direction.UP
	elif Input.is_action_just_pressed("ui_right") and current_direction != Direction.LEFT:
		next_direction = Direction.RIGHT
	elif Input.is_action_just_pressed("ui_down") and current_direction != Direction.UP:
		next_direction = Direction.DOWN
	elif Input.is_action_just_pressed("ui_left") and current_direction != Direction.RIGHT:
		next_direction = Direction.LEFT

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
	# Move each segment to the position of the segment in front of it
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
		var collectible_grid_pos = grid.world_to_grid(collectible.position)
		if collectible_grid_pos == pos:
			return collectible
	return null

func collect_resource(collectible):
	# Get the resource type from the collectible
	var resource_type = collectible.resource_type
	
	# Add resource to collected list
	resources_collected.append(resource_type)
	
	# Signal that a resource was collected
	emit_signal("resource_collected", resource_type)
	
	# Grow the snake by adding a full mid-section
	grow_snake_with_food(resource_type)
	
	# Remove the collectible
	collectible.queue_free()
	
	# Spawn a new collectible
	get_parent().spawn_single_collectible()

func grow_snake_with_food(resource_type):
	# Create a new body segment carrying food
	var body = body_scene.instantiate()
	
	# Add the new segment at the same position as the tail
	var tail_index = segments.size() - 1
	var tail_pos = segments[tail_index].grid_pos
	body.position = grid.grid_to_world(tail_pos)
	
	# Set it as carrying food
	body.set_carrying_food(true)
	
	# Insert the new segment before the tail (second to last position)
	add_child(body)
	segments.insert(tail_index, {
		"node": body,
		"grid_pos": tail_pos,
		"carrying_food": true,
		"resource_type": resource_type
	})
	
	# Update the tail position
	update_segments_appearance()

func update_segments_appearance():
	# Update the rotation and appearance of each segment
	for i in range(segments.size()):
		update_segment_rotation(i)

func update_segment_rotation(index):
	var segment = segments[index]
	
	# Handle head rotation
	if index == 0:
		# Rotate head based on direction
		# Head connects on the left side, so rotate accordingly
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
		# Get direction to previous segment
		var prev_pos = segments[index-1].grid_pos
		var curr_pos = segment.grid_pos
		var direction = prev_pos - curr_pos
		
		# Rotate tail based on direction to previous segment
		# Since tail connects on the right side, we need to rotate it accordingly
		if direction == Vector2i(1, 0):  # Previous segment is to the right
			segment.node.rotation = deg_to_rad(0)
		elif direction == Vector2i(-1, 0):  # Previous segment is to the left
			segment.node.rotation = deg_to_rad(180)
		elif direction == Vector2i(0, 1):  # Previous segment is below
			segment.node.rotation = deg_to_rad(90)
		elif direction == Vector2i(0, -1):  # Previous segment is above
			segment.node.rotation = deg_to_rad(270)
	
	# Handle body segments rotation
	# For now, we won't rotate body segments as they're flexible
	else:
		segment.node.rotation = 0
