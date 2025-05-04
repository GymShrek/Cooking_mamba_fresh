# scripts/SnakeBody.gd
extends Node2D

var resource_type = ""
var is_carrying_food = false

var resource_textures = {
	"wheat": preload("res://assets/wheat_snake.png"),
	"tomato": preload("res://assets/tomato_snake.png"),
	"lettuce": preload("res://assets/lettuce_snake.png")
}

func _ready():
	$Sprite2D.texture = preload("res://assets/mamba_mid_full.png")
	update_appearance()

func set_carrying_food(value, type = ""):
	is_carrying_food = value
	if value and type:
		resource_type = type
	update_appearance()

func update_appearance():
	# Base texture is always the mid-full segment
	$Sprite2D.texture = preload("res://assets/mamba_mid_full.png")
	
	# If carrying food, add resource sprite on top
	if is_carrying_food and resource_type != "" and resource_textures.has(resource_type):
		# Create resource sprite if it doesn't exist
		if not has_node("ResourceSprite"):
			var resource_sprite = Sprite2D.new()
			resource_sprite.name = "ResourceSprite"
			add_child(resource_sprite)
		
		# Update the resource sprite
		$ResourceSprite.texture = resource_textures[resource_type]
