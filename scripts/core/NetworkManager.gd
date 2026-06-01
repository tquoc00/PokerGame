extends Node

signal player_list_changed

const PORT = 8080
const MAX_PLAYERS = 4

var players = {} # { peer_id: { "name": String, "total_bullets": 0 } }
var my_name = ""
var ready_peers = [] # Danh sách các peer đã sẵn sàng trong Table scene

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

func leave_game():
	multiplayer.multiplayer_peer = null
	players.clear()
	ready_peers.clear()
	player_list_changed.emit()
	get_tree().change_scene_to_file("res://scenes/main/Menu.tscn")

func join_game(ip: String, player_name: String):
	my_name = player_name
	var peer = WebSocketMultiplayerPeer.new()
	
	var url = ip
	if not url.begins_with("ws://") and not url.begins_with("wss://"):
		url = "ws://" + ip + ":" + str(PORT)
		
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
		
		# Thông báo PokerGameManager xử lý rớt mạng nếu game đang chạy
		var table = get_tree().root.get_node_or_null("Table")
		if table and table.has_method("server_handle_player_disconnect"):
			table.server_handle_player_disconnect(id)

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
		if players.size() >= MAX_PLAYERS:
			rpc_id(id, "client_reject_join", "PHÒNG ĐÃ ĐẦY! (TỐI ĐA 4 NGƯỜI)")
			return
		players[id] = { "name": p_name, "total_bullets": 0 }
		rpc("sync_players", players)

@rpc("authority", "reliable")
func client_reject_join(reason: String):
	multiplayer.multiplayer_peer = null
	var menu = get_tree().root.get_node_or_null("Menu")
	if menu and menu.has_method("_on_connection_error"):
		var lbl = menu.lobby_panel.get_child(0) as Label
		lbl.text = reason
		lbl.add_theme_color_override("font_color", Color.RED)

@rpc("authority", "reliable", "call_local")
func sync_players(p_list: Dictionary):
	if multiplayer.is_server():
		player_list_changed.emit()
		return # Server đã tự quản lý biến players
		
	players.clear()
	for k in p_list:
		players[int(k)] = p_list[k]
	player_list_changed.emit()
	
@rpc("authority", "reliable", "call_local")
func start_game():
	ready_peers.clear() # Reset danh sách sẵn sàng trước khi vào bàn chơi
	get_tree().change_scene_to_file("res://scenes/main/Table.tscn")

@rpc("any_peer", "reliable")
func server_notify_ready():
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: sender_id = 1
	if not ready_peers.has(sender_id):
		ready_peers.append(sender_id)
	
	# Gọi cập nhật UI ở Table nếu scene Table đã sẵn sàng trên Server
	var table = get_tree().root.get_node_or_null("Table")
	if table and table.has_method("_check_all_ready"):
		table._check_all_ready()
