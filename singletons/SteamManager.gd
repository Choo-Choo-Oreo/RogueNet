extends Node

var result

func _ready():
	result = Steam.steamInit(480)
	print(result)
	Steam.initRelayNetworkAccess()

func _process(_delta):
	Steam.run_callbacks()
