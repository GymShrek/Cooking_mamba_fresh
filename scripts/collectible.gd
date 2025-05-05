# scripts/collectible.gd
extends Node2D

var resource_type = "wheat"  # Default resource type
var is_animal = false
var is_moving = false
var is_flying = false  # For chicken flying state
var size_multiplier = 1

# Resource textures dictionary
var resource_textures = {
	# Static resources
	"wheat": preload("res://assets/wheat.png"),
	"tomato": preload("res://assets/tomato.png"),
	"lettuce": preload("res://assets/lettuce.png"),
	"egg": preload("res://assets/egg.png"),
	"milk": preload("res://assets/milk.png"),
	
	# Animals - base sprites
	"mouse": preload("res://assets/mouse.png"),
	"chicken": preload("res://assets/chicken.png"),
	"pig": preload("res://assets/pig.png"),
	"cow": preload("res://assets/cow.png")
}

# Reference to grid and main nodes
var grid
var main

func _ready():
	# Set up the collectible appearance based on resource type
	main = get_node("/root/Main")
	grid = main.get_node("Grid")
	
	update_appearance()
	
	# Set up initial state based on resource type
	if resource_type in ["mouse", "chicken", "pig", "cow"]:
		is_animal = true
		is_moving = true
		
		# Set size multiplier for cow
		if resource_type == "cow":
			size_multiplier = 2
			scale = Vector2(2, 2)  # Double the sprite size

func set_resource_type(type):
	resource_type = type
	
	# Update animal status
	if resource_type in ["mouse", "chicken", "pig", "cow"]:
		is_animal = true
		is_moving = true
		
		# Set size multiplier for cow
		if resource_type == "cow":
			size_multiplier = 2
			scale = Vector2(2, 2)  # Make it 2x2 in size
	else:
		is_animal = false
		is_moving = false
		size_multiplier = 1
		scale = Vector2(1, 1)
		
	update_appearance()

func update_appearance():
	if resource_textures.has(resource_type):
		$Sprite2D.texture = resource_textures[resource_type]

# Note: This collectible script is now mostly a placeholder
# Most animal functionality has been moved to the specific animal scripts
# This script is kept for backward compatibility and for static resources
