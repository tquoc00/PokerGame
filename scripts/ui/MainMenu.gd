extends Control

var username_input: LineEdit
var ip_input: LineEdit
var lobby_panel: Panel
var players_vbox: VBoxContainer
var start_btn: Button

func _ready():
	# Xóa UI cũ
	for c in get_children():
		if c.name != "ColorRect" and c.name != "Title" and c.name != "Subtitle":
			c.queue_free()
			
	# --- Màn hình chọn ---
	var center = VBoxContainer.new()
	center.position = Vector2(440, 320)
	center.size = Vector2(400, 300)
	center.add_theme_constant_override("separation", 20)
	add_child(center)
	
	username_input = LineEdit.new()
	username_input.placeholder_text = "Tên của bạn..."
	username_input.add_theme_font_size_override("font_size", 24)
	username_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(username_input)
	
	ip_input = LineEdit.new()
	ip_input.placeholder_text = "Nhập IP để Join (để trống nếu Host)"
	ip_input.add_theme_font_size_override("font_size", 24)
	ip_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(ip_input)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(hbox)
	
	var btn_host = Button.new()
	btn_host.text = "TẠO PHÒNG (HOST)"
	btn_host.custom_minimum_size = Vector2(180, 60)
	btn_host.add_theme_font_size_override("font_size", 20)
	btn_host.pressed.connect(_on_host)
	
	if OS.has_feature("web"):
		btn_host.disabled = true
		btn_host.tooltip_text = "Trình duyệt Web không thể làm Máy chủ. Hãy tải bản PC để làm Host."
		ip_input.placeholder_text = "Nhập IP Máy chủ PC để Join..."
		
	hbox.add_child(btn_host)
	
	var btn_join = Button.new()
	btn_join.text = "THAM GIA (JOIN)"
	btn_join.custom_minimum_size = Vector2(180, 60)
	btn_join.add_theme_font_size_override("font_size", 20)
	btn_join.pressed.connect(_on_join)
	hbox.add_child(btn_join)
	
	# --- Màn hình Lobby (Ẩn lúc đầu) ---
	lobby_panel = Panel.new()
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0, 0, 0, 0.8)
	ps.corner_radius_top_left = 15; ps.corner_radius_top_right = 15
	ps.corner_radius_bottom_left = 15; ps.corner_radius_bottom_right = 15
	lobby_panel.add_theme_stylebox_override("panel", ps)
	lobby_panel.size = Vector2(500, 400)
	lobby_panel.position = Vector2(390, 250)
	lobby_panel.hide()
	add_child(lobby_panel)
	
	var lbl = Label.new()
	lbl.text = "ĐANG CHỜ NGƯỜI CHƠI..."
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0, 20)
	lbl.size = Vector2(500, 40)
	lobby_panel.add_child(lbl)
	
	players_vbox = VBoxContainer.new()
	players_vbox.position = Vector2(50, 80)
	players_vbox.size = Vector2(400, 200)
	lobby_panel.add_child(players_vbox)
	
	start_btn = Button.new()
	start_btn.text = "BẮT ĐẦU GAME"
	start_btn.add_theme_font_size_override("font_size", 24)
	start_btn.position = Vector2(100, 320)
	start_btn.size = Vector2(300, 50)
	start_btn.pressed.connect(_on_start_game)
	start_btn.hide()
	lobby_panel.add_child(start_btn)
	
	NetworkManager.player_list_changed.connect(_update_lobby)

func _get_name():
	var n = username_input.text.strip_edges()
	return n if n != "" else "Gambler_" + str(randi() % 1000)

func _on_host():
	if NetworkManager.host_game(_get_name()):
		_show_lobby()
		start_btn.show()

func _on_join():
	var ip = ip_input.text.strip_edges()
	if ip == "": ip = "127.0.0.1"
	if NetworkManager.join_game(ip, _get_name()):
		_show_lobby()

func _show_lobby():
	lobby_panel.show()
	_update_lobby()

func _update_lobby():
	for c in players_vbox.get_children():
		c.queue_free()
		
	for id in NetworkManager.players:
		var p_name = NetworkManager.players[id].name
		var l = Label.new()
		l.text = "👤 " + p_name + ( " (Host)" if id == 1 else "" )
		l.add_theme_font_size_override("font_size", 20)
		players_vbox.add_child(l)

func _on_start_game():
	NetworkManager.start_game.rpc()
