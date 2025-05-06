# scripts/snake_body.gd
extends Node2D

var resource_type = ""
var is_carrying_food = false
var is_double_front = false  # First half of a double-width segment
var is_double_back = false   # Second half of a double-width segment

# Standard textures
var standard_body_texture = preload("res://assets/mamba_mid_full.png")
var double_body_texture = preload("res://assets/mamba_mid_double.png")

# Resource textures dictionary - organized by resource types
var resource_textures = {
	# Static resources
	"wheat": preload("res://assets/wheat_snake.png"),
	"tomato": preload("res://assets/tomato_snake.png"),
	"lettuce": preload("res://assets/lettuce_snake.png"),
	"egg": preload("res://assets/egg_snake.png"),
	"milk": preload("res://assets/milk_snake.png"),
	
	# Animals - Front/Back pairs for double-width resources
	"cow_front": preload("res://assets/cow_snake_front.png"),
	"cow_back": preload("res://assets/cow_snake_back.png"),
	
	# Regular animal resources
	"mouse": preload("res://assets/mouse_snake.png"),
	"chicken": preload("res://assets/chicken_snake.png"),
	"pig": preload("res://assets/pig_snake.png")
}

func _ready():
	update_appearance()

func set_carrying_food(value, type = ""):
	is_carrying_food = value
	
	if value and type:
		resource_type = type
	
	update_appearance()

func set_is_double_front(value):
	is_double_front = value
	update_appearance()

func set_is_double_back(value):
	is_double_back = value
	update_appearance()

func update_appearance():
	# Choose the appropriate base texture for the segment
	if is_double_front or is_double_back:
		$Sprite2D.texture = double_body_texture
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
			
			# No region needed for the resource sprite - each has its own texture
			$ResourceSprite.region_enabled = false
		else:
			# If we don't have a texture for this resource, hide the sprite
			$ResourceSprite.visible = false
	elif has_node("ResourceSprite"):
		# If not carrying food, hide the resource sprite
		$ResourceSprite.visible = false
