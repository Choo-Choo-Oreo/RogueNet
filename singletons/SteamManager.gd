extends Node

var result

func _ready():
	result = Steam.steamInit(480) # Maybe remove?
	print(result)

func _process(_delta):
	Steam.run_callbacks()
