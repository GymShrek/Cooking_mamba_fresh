# scripts/SnakeBody.gd
extends Node2D

var resource_type = ""

func _ready():
	$Sprite2D.texture = preload("res://assets/mamba_mid_full.png")

func set_carrying_food(value):
	# Always true, as we only use full mid-sections
	pass
