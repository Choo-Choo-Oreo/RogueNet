@tool
extends Node2D

@export var data_layer: TileMapLayer
@export var display_layer: TileMapLayer

func _ready():
	display_layer.position = Vector2(data_layer.tile_set.tile_size) / 2.0
	
func refresh():
	pass
