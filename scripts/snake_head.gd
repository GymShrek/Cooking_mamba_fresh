# scripts/snake/snake_head.gd
extends Node2D

func _ready():
	$Sprite2D.texture = preload("res://assets/mamba_head.png")