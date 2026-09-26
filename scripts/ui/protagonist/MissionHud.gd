extends CanvasLayer

## An adventurer's HUD during a dive. It lives in GameView next to the world's viewport, not in
## Dungeon.tscn, so it draws on the 640x360 UI grid and not the world's 320x180 one.

@onready var chat_box: ChatBox = $ChatBox
@onready var hotbar: Hotbar = $Hotbar
@onready var hotbar_column: Control = $Hotbar/Column
@onready var inventory_hud: Control = $InventoryHud

## UI pixels between the top of the hotbar and the open inventory.
const GAP := 4

## The open inventory sits above the hotbar, never over it. The hotbar's column grows upward
## from the hotbar's bottom edge, so its top is its height above that edge.
func _ready() -> void:
	hotbar_column.resized.connect(_place_inventory)
	_place_inventory()

func _place_inventory() -> void:
	inventory_hud.place_above(hotbar.offset_bottom - hotbar_column.size.y - GAP)

## NetworkSync.receive_chat() -> GameView.add_chat_line() -> here.
func add_chat_line(line: String) -> void:
	chat_box.add_chat_line(line)
