extends Node

var result

# True when the Steam client is running and we are logged on. Singleplayer works without it;
# hosting and joining need it.
var online := false

func _ready():
	result = Steam.steamInit(480)
	print(result)
	if Steam.isSteamRunning():
		Steam.initRelayNetworkAccess()
		online = Steam.loggedOn()
	if not online:
		print("Steam is not running or not logged on: only singleplayer will work.")

func _process(_delta):
	if online:
		Steam.run_callbacks()
