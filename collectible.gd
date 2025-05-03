# scripts/Collectible.gd
extends Node2D

var resource_type = "wheat"  # Default resource type

func _ready():
	# Set up the collectible appearance
	$Sprite2D.texture = preload("res://assets/wheat.png")

func set_resource_type(type):
	resource_type = type
	# In the future, we can update the sprite based on the resource type
