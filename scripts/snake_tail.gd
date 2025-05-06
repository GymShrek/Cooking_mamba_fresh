# scripts/snake/snake_tail.gd
extends Node2D

func _ready():
	$Sprite2D.texture = preload("res://assets/mamba_tail.png")