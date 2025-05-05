# scripts/ResourceCounter.gd
extends Label

var resources = {}

func _ready():
	# Connect to the snake's resource_collected signal
	var snake = get_node("/root/Main/Snake")
	snake.connect("resource_collected", _on_resource_collected)
	update_display()

func _on_resource_collected(resource_type):
	# Increment the resource count
	if resources.has(resource_type):
		resources[resource_type] += 1
	else:
		resources[resource_type] = 1
	
	# Update the display
	update_display()

func update_display():
	# Build the text to display
	var text = "Resources:\n"
	for type in resources.keys():
		text += type + ": " + str(resources[type]) + "\n"
	
	# Set the text
	self.text = text
