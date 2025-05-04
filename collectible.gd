# scripts/Collectible.gd
extends Node2D

var resource_type = "wheat"  # Default resource type
var resource_textures = {
	"wheat": preload("res://assets/wheat.png"),
	"tomato": preload("res://assets/tomato.png"),
	"lettuce": preload("res://assets/lettuce.png")
}

func _ready():
	# Set up the collectible appearance based on resource type
	update_appearance()

func set_resource_type(type):
	resource_type = type
	update_appearance()

func update_appearance():
	if resource_textures.has(resource_type):
		$Sprite2D.texture = resource_textures[resource_type]
