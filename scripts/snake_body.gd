# scripts/snake_body.gd
extends Node2D

var resource_type = ""
var is_carrying_food = false
var is_multi = false  # A multi-cell segment

# Reference to snake skin system
var snake_skin

func _ready():
	# Get the snake skin system
	snake_skin = get_node_or_null("/root/SnakeSkin")
	
	# Debug output to verify loaded textures
	print("Snake body loaded for resource type: ", resource_type)
	update_appearance()

func set_carrying_food(value, type = ""):
	is_carrying_food = value
	
	if value and type:
		resource_type = type
		print("Snake body carrying food: ", type)
	
	update_appearance()

func set_is_multi(value):
	is_multi = value
	update_appearance()

func update_appearance():
	# Check if we have the snake skin system
	if snake_skin == null:
		snake_skin = get_node_or_null("/root/SnakeSkin")
		if snake_skin == null:
			# Fallback to hardcoded textures if skin system not available
			use_fallback_textures()
			return
	
	# Choose the appropriate base texture for the segment
	if is_multi:
		$Sprite2D.texture = snake_skin.get_multi_body_texture()
	else:
		$Sprite2D.texture = snake_skin.get_body_texture()
	
	# If carrying food, add resource sprite
	if is_carrying_food and resource_type != "":
		# Create resource sprite if it doesn't exist
		if not has_node("ResourceSprite"):
			var resource_sprite = Sprite2D.new()
			resource_sprite.name = "ResourceSprite"
			add_child(resource_sprite)
		
		# Get the texture from the skin system
		var resource_texture = snake_skin.get_resource_texture(resource_type)
		if resource_texture:
			$ResourceSprite.texture = resource_texture
			$ResourceSprite.visible = true
			
			# Print debug info 
			print("Setting resource sprite texture for: ", resource_type, 
				  " texture valid: ", $ResourceSprite.texture != null)
			
			# No region needed for the resource sprite - each has its own texture
			$ResourceSprite.region_enabled = false
		else:
			# If we don't have a texture for this resource, hide the sprite
			print("WARNING: No texture found for resource type: ", resource_type)
			$ResourceSprite.visible = false
	elif has_node("ResourceSprite"):
		# If not carrying food, hide the resource sprite
		$ResourceSprite.visible = false

# Fallback to hardcoded textures if skin system is not available
func use_fallback_textures():
	# Hardcoded standard textures as fallback
	var standard_body_texture = preload("res://assets/mamba_mid_full.png")
	var multi_body_texture = preload("res://assets/mamba_mid_multi.png")
	
	# Resource textures dictionary - organized by resource types
	var resource_textures = {
		# Static resources
		"wheat": preload("res://assets/wheat_snake.png"),
		"tomato": preload("res://assets/tomato_snake.png"),
		"lettuce": preload("res://assets/lettuce_snake.png"),
		"egg": preload("res://assets/egg_snake.png"),
		"milk": preload("res://assets/milk_snake.png"),
		
		# Cow parts - specific part textures
		"cow1-1": preload("res://assets/cow1-1_snake.png"),
		"cow1-2": preload("res://assets/cow1-2_snake.png"),
		"cow2-1": preload("res://assets/cow2-1_snake.png"),
		"cow2-2": preload("res://assets/cow2-2_snake.png"),
		
		# Pig parts - specific part textures
		"pig1-1": preload("res://assets/pig1-1_snake.png"),
		"pig2-1": preload("res://assets/pig2-1_snake.png"),
		
		# Regular animal resources
		"mouse": preload("res://assets/mouse_snake.png"),
		"chicken": preload("res://assets/chicken_snake.png"),
		"fish": preload("res://assets/fish_snake.png")
	}
	
	# Choose the appropriate base texture for the segment
	if is_multi:
		$Sprite2D.texture = multi_body_texture
	else:
		$Sprite2D.texture = standard_body_texture
	
	# If carrying food, add resource sprite
	if is_carrying_food and resource_type != "":
		# Create resource sprite if it doesn't exist
		if not has_node("ResourceSprite"):
			var resource_sprite = Sprite2D.new()
			resource_sprite.name = "ResourceSprite"
			add_child(resource_sprite)
		
		# Check if we have a texture for this resource type
		if resource_textures.has(resource_type):
			$ResourceSprite.texture = resource_textures[resource_type]
			$ResourceSprite.visible = true
			
			# Print debug info 
			print("Setting resource sprite texture for: ", resource_type, 
				  " texture valid: ", $ResourceSprite.texture != null)
			
			# No region needed for the resource sprite - each has its own texture
			$ResourceSprite.region_enabled = false
		else:
			# If we don't have a texture for this resource, hide the sprite
			print("WARNING: No texture found for resource type: ", resource_type)
			$ResourceSprite.visible = false
	elif has_node("ResourceSprite"):
		# If not carrying food, hide the resource sprite
		$ResourceSprite.visible = false
