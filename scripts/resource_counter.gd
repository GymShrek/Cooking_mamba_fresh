# scripts/resource_counter.gd
extends Label

var resources = {}
var resource_counts = {}  # For tracking partial animal parts

# Dictionary to track the number of cells for each animal type
var animal_cell_counts = {
	"cow": 4,  # 2x2 grid
	"pig": 2,  # 2x1 grid
	# Add any future multi-cell animals here
}

func _ready():
	# Connect to the snake's resource_collected signal
	var snake = get_node("/root/Main/Snake")
	snake.connect("resource_collected", _on_resource_collected)
	update_display()

func _on_resource_collected(resource_type):
	# Get the base animal type (without part numbers)
	var base_type = get_base_type(resource_type)
	
	# Default increment is 1 for regular resources
	var increment = 1.0
	
	# For multi-cell animals, calculate the increment based on total cells
	if animal_cell_counts.has(base_type):
		increment = 1.0 / animal_cell_counts[base_type]
	
	# Initialize resource count if not present
	if not resource_counts.has(base_type):
		resource_counts[base_type] = 0.0
	
	# Track partial collection for multi-part resources
	resource_counts[base_type] += increment
	
	# Update the resources dictionary with appropriate formatting
	update_resource_display(base_type)
	
	# Update the display
	update_display()

# Helper function to extract the base animal type from a resource_type string
func get_base_type(resource_type):
	# Check for multi-cell animal parts (format: "animal1-1", "animal2-1", etc.)
	for animal in animal_cell_counts.keys():
		if resource_type.begins_with(animal):
			return animal
	
	# If not a multi-cell animal part, return the original type
	return resource_type

# Update the display format for a resource
func update_resource_display(base_type):
	var count = resource_counts[base_type]
	
	# Format the display string based on the value
	if count == int(count):
		# It's a whole number, display as integer
		resources[base_type] = str(int(count))
	elif count == 0.25 or count == 0.5 or count == 0.75:
		# Common fractions, display with single decimal if 0.5
		if count == 0.5:
			resources[base_type] = "0.5"
		else:
			# Use two decimal places for 0.25 and 0.75
			resources[base_type] = "%.2f" % count
	else:
		# Other values - display with up to 2 decimal places but trim zeros
		var formatted = "%.2f" % count
		# Trim trailing zeros and decimal point if needed
		if formatted.ends_with("0"):
			formatted = formatted.substr(0, formatted.length() - 1)
			if formatted.ends_with("0"):
				formatted = formatted.substr(0, formatted.length() - 1)
				if formatted.ends_with("."):
					formatted = formatted.substr(0, formatted.length() - 1)
		resources[base_type] = formatted

func update_display():
	# Build the text to display
	var text = "Resources:\n"
	
	# Sort the keys for consistent display order
	var sorted_keys = resources.keys()
	sorted_keys.sort()
	
	for type in sorted_keys:
		text += type + ": " + str(resources[type]) + "\n"
	
	# Set the text
	self.text = text
