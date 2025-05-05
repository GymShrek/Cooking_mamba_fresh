# scripts/snake_body.gd
extends Node2D

var resource_type = ""
var is_carrying_food = false
var is_double_front = false  # First half of a double-width segment
var is_double_back = false   # Second half of a double-width segment

var resource_textures = {
	# Static resources
	"wheat": preload("res://assets/wheat_snake.png"),
	"tomato": preload("res://assets/tomato_snake.png"),
	"lettuce": preload("res://assets/lettuce_snake.png"),
	"egg": preload("res://assets/egg_snake.png"),
	"milk": preload("res://assets/milk_snake.png"),
	
	# Animals
	"mouse": preload("res://assets/mouse_snake.png"),
	"chicken": preload("res://assets/chicken_snake.png"),
	"pig": preload("res://assets/pig_snake.png"),
	"cow": preload("res://assets/cow_snake.png")
}

func _ready():
	update_appearance()

func set_carrying_food(value, type = ""):
	is_carrying_food = value
	
	if value and type:
		resource_type = type
	
	update_appearance()

# Set this segment as the front half of a double-width resource
#func set_is_double_front(value):
#	is_double_front = value
#	update_appearance()

# Set this segment as the back half of a double-width resource
##	is_double_back = value
	#update_appearance()

func update_appearance():
	# Base resource type (remove "_back" suffix if present)
	var base_resource_type = resource_type
	if base_resource_type.ends_with("_back"):
		base_resource_type = base_resource_type.substr(0, base_resource_type.length() - 5)
	
	# Choose the appropriate base texture for the segment
	if is_double_front:
		# Front half of a double-width resource
		$Sprite2D.texture = preload("res://assets/mamba_mid_full.png")
		
		# Add the resource sprite (front half)
		if is_carrying_food and resource_textures.has(base_resource_type):
			# Create resource sprite if it doesn't exist
			if not has_node("ResourceSprite"):
				var resource_sprite = Sprite2D.new()
				resource_sprite.name = "ResourceSprite"
				add_child(resource_sprite)
			
			# Show the front half of the resource
			$ResourceSprite.texture = resource_textures[base_resource_type]
			$ResourceSprite.region_enabled = true
			$ResourceSprite.region_rect = Rect2(0, 0, $ResourceSprite.texture.get_width() / 2, $ResourceSprite.texture.get_height())
	
	elif is_double_back:
		# Back half of a double-width resource
		$Sprite2D.texture = preload("res://assets/mamba_mid_full.png")
		
		# Add the resource sprite (back half)
		if is_carrying_food and resource_textures.has(base_resource_type):
			# Create resource sprite if it doesn't exist
			if not has_node("ResourceSprite"):
				var resource_sprite = Sprite2D.new()
				resource_sprite.name = "ResourceSprite"
				add_child(resource_sprite)
			
			# Show the back half of the resource
			$ResourceSprite.texture = resource_textures[base_resource_type]
			$ResourceSprite.region_enabled = true
			$ResourceSprite.region_rect = Rect2($ResourceSprite.texture.get_width() / 2, 0, $ResourceSprite.texture.get_width() / 2, $ResourceSprite.texture.get_height())
	
	else:
		# Regular segment
		$Sprite2D.texture = preload("res://assets/mamba_mid_full.png")
		
		# If carrying food, add resource sprite on top
		if is_carrying_food and base_resource_type != "" and resource_textures.has(base_resource_type):
			# Create resource sprite if it doesn't exist
			if not has_node("ResourceSprite"):
				var resource_sprite = Sprite2D.new()
				resource_sprite.name = "ResourceSprite"
				add_child(resource_sprite)
			
			# Update the resource sprite
			$ResourceSprite.texture = resource_textures[base_resource_type]
			# Make sure region is disabled for regular sprites
			$ResourceSprite.region_enabled = false
