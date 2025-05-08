# scripts/snake_skin.gd
extends Node

# This singleton handles the snake skin system
# It provides a central place to get the correct snake skin textures

# Current skin name
var current_skin = "mamba"

# Dictionary of all skins and their textures
var skins = {
	"mamba": {
		"head": "res://assets/mamba_head.png",
		"body": "res://assets/mamba_mid_full.png",
		"tail": "res://assets/mamba_tail.png",
		"body_multi": "res://assets/mamba_mid_multi.png"  # Ensure this is used for multi-animal parts
	}
	# Additional skins can be added here
	# "other_skin": {
	#   "head": "res://assets/other_head.png",
	#   "body": "res://assets/other_mid_full.png",
	#   "tail": "res://assets/other_tail.png", 
	#   "body_multi": "res://assets/other_mid_multi.png"
	# }
}

# Resource textures for different resource types
var resource_textures = {
	# Static resources
	"wheat": "res://assets/wheat_snake.png",
	"tomato": "res://assets/tomato_snake.png",
	"lettuce": "res://assets/lettuce_snake.png",
	"egg": "res://assets/egg_snake.png",
	"milk": "res://assets/milk_snake.png",
	
	# Animals - Front/Back pairs for multi-cell resources
	"cow1-1": "res://assets/cow1-1_snake.png",
	"cow1-2": "res://assets/cow1-2_snake.png",
	"cow2-1": "res://assets/cow2-1_snake.png",
	"cow2-2": "res://assets/cow2-2_snake.png",
	
	"pig1-1": "res://assets/pig1-1_snake.png",
	"pig2-1": "res://assets/pig2-1_snake.png",
	
	# Regular animal resources
	"mouse": "res://assets/mouse_snake.png",
	"chicken": "res://assets/chicken_snake.png",
	"pig": "res://assets/pig_snake.png",
	"fish": "res://assets/fish_snake.png"
}

# Function to get the head texture for the current skin
func get_head_texture():
	return load(skins[current_skin]["head"])

# Function to get the body texture for the current skin
func get_body_texture():
	return load(skins[current_skin]["body"])

# Function to get the tail texture for the current skin
func get_tail_texture():
	return load(skins[current_skin]["tail"])

# Function to get the multi-width body texture for the current skin
func get_multi_body_texture():
	return load(skins[current_skin]["body_multi"])

# Function to get a resource texture
func get_resource_texture(resource_type):
	if resource_textures.has(resource_type):
		return load(resource_textures[resource_type])
	return null

# Function to change the current skin
func set_skin(skin_name):
	if skins.has(skin_name):
		current_skin = skin_name
		return true
	return false
