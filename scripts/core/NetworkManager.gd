extends Node

signal player_list_changed

const PORT = 8080
const MAX_PLAYERS = 4

var players = {} # { peer_id: { "name": String, "total_bullets": 0 } }
var my_name = ""

func host_game(player_name: String):
	if OS.has_feature("web"):
		print("Web browser cannot host a WebSocket server!")
		return false
		
	my_name = player_name
	var peer = WebSocketMultiplayerPeer.new()
	var err = peer.create_server(PORT)
	if err != OK:
		print("Cannot host!")
		return false
	
	multiplayer.multiplayer_peer = peer
	players[1] = { "name": player_name, "total_bullets": 0 }
	player_list_changed.emit()
	return true

func join_game(ip: String, player_name: String):
	my_name = player_name
	var peer = WebSocketMultiplayerPeer.new()
	var url = "ws://" + ip + ":" + str(PORT)
	var err = peer.create_client(url)
	if err != OK:
		print("Cannot join!")
		return false
		
	multiplayer.multiplayer_peer = peer
	return true

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_peer_connected(id: int):
	print("Peer connected: ", id)

func _on_peer_disconnected(id: int):
	if multiplayer.is_server():
		players.erase(id)
		rpc("sync_players", players)

func _on_connected_to_server():
	print("Connected to server!")
	rpc_id(1, "register_player", multiplayer.get_unique_id(), my_name)

func _on_connection_failed():
	print("Connection failed!")

func _on_server_disconnected():
	print("Server disconnected!")
	players.clear()
	player_list_changed.emit()
	get_tree().change_scene_to_file("res://scenes/main/Menu.tscn")

@rpc("any_peer", "reliable")
func register_player(id: int, p_name: String):
	if multiplayer.is_server():
		players[id] = { "name": p_name, "total_bullets": 0 }
		rpc("sync_players", players)

@rpc("authority", "reliable", "call_local")
func sync_players(p_list: Dictionary):
	players = p_list
	player_list_changed.emit()
	
@rpc("authority", "reliable", "call_local")
func start_game():
	get_tree().change_scene_to_file("res://scenes/main/Table.tscn")
