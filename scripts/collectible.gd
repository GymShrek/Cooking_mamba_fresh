# scripts/collectible.gd
extends Node2D

var resource_type = "wheat"  # Default resource type
var is_animal = false
var is_moving = false
var size_multiplier = 1

# Resource textures dictionary - ONLY for static resources
var resource_textures = {
	# Static resources
	"wheat": preload("res://assets/wheat.png"),
	"tomato": preload("res://assets/tomato.png"),
	"lettuce": preload("res://assets/lettuce.png"),
	"egg": preload("res://assets/egg.png"),
	"milk": preload("res://assets/milk.png")
	
	# Animals are completely removed from this dictionary
	# All animals are now handled by their respective animal classes
}

# Reference to grid and main nodes
var grid
var main

func _ready():
	# Set up the collectible appearance based on resource type
	main = get_node("/root/Main")
	grid = main.get_node("Grid")
	
	update_appearance()

func set_resource_type(type):
	resource_type = type
	
	# Animal types shouldn't be set through this function anymore
	# Animals should be created using AnimalController
	is_animal = false
	is_moving = false
	size_multiplier = 1
	scale = Vector2(1, 1)
	
	update_appearance()

func update_appearance():
	if resource_textures.has(resource_type):
		$Sprite2D.texture = resource_textures[resource_type]
	else:
		print("Warning: No texture for resource type " + resource_type)
		visible = false

# This collectible class now ONLY handles static resources
# All animals (single-cell and multi-cell) are handled by the Animal class hierarchy
