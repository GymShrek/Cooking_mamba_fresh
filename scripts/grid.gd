# scripts/Grid.gd
extends TileMap

const CELL_SIZE = 32
var grid_size = Vector2i(20, 15)

func _ready():
	# Set up the grid
	tile_set = create_tileset()
	
	# Create walls around the edge
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			if x == 0 or y == 0 or x == grid_size.x - 1 or y == grid_size.y - 1:
				set_cell(0, Vector2i(x, y), 0, Vector2i(0, 0))

func create_tileset():
	var new_tileset = TileSet.new()
	new_tileset.tile_size = Vector2i(CELL_SIZE, CELL_SIZE)
	
	# Add a source
	var source_id = new_tileset.add_source(TileSetAtlasSource.new())
	var atlas_source = new_tileset.get_source(source_id) as TileSetAtlasSource
	
	# Load rock texture for boundaries
	var rock_texture = preload("res://assets/rock.png")
	atlas_source.texture = rock_texture
	
	# Create a tile with the full texture
	atlas_source.texture_region_size = Vector2i(CELL_SIZE, CELL_SIZE)
	atlas_source.create_tile(Vector2i(0, 0))
	
	return new_tileset

func is_cell_vacant(pos: Vector2i) -> bool:
	# Check if the cell is within bounds and not a wall
	if pos.x < 0 or pos.y < 0 or pos.x >= grid_size.x or pos.y >= grid_size.y:
		return false
	
	# Check if cell has a tile
	if get_cell_source_id(0, pos) != -1:
		return false
		
	return true

func world_to_grid(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.x / CELL_SIZE), int(pos.y / CELL_SIZE))
	
func grid_to_world(pos: Vector2i) -> Vector2:
	return Vector2(pos.x * CELL_SIZE + CELL_SIZE/2, pos.y * CELL_SIZE + CELL_SIZE/2)
