extends Control

var username_input: LineEdit
var ip_input: LineEdit
var lobby_panel: Panel
var players_vbox: VBoxContainer
var start_btn: Button

func _ready():
	# Xóa UI cũ (giữ lại background nếu có)
	for c in get_children():
		if c.name != "ColorRect" and c.name != "Title" and c.name != "Subtitle":
			c.queue_free()
			
	# --- THIẾT KẾ PHONG CÁCH GLASSMORPHISM SIÊU CAO CẤP ---
	var input_normal = StyleBoxFlat.new()
	input_normal.bg_color = Color(1, 1, 1, 0.04)
	input_normal.border_width_left = 1; input_normal.border_width_right = 1; input_normal.border_width_top = 1; input_normal.border_width_bottom = 1
	input_normal.border_color = Color(1, 1, 1, 0.12)
	input_normal.corner_radius_top_left = 8; input_normal.corner_radius_top_right = 8; input_normal.corner_radius_bottom_left = 8; input_normal.corner_radius_bottom_right = 8
	input_normal.content_margin_left = 15; input_normal.content_margin_right = 15
	
	var input_focus = input_normal.duplicate()
	input_focus.bg_color = Color(1, 1, 1, 0.07)
	input_focus.border_color = Color("#00b0ff") # Neon Blue
	input_focus.shadow_size = 10
	input_focus.shadow_color = Color(0, 0.69, 1.0, 0.25)

	# Định vị VBoxContainer căn giữa ngang nhưng lệch dọc xuống dưới để tránh đè chữ lên Subtitle
	var center = VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.offset_left = -200
	center.offset_right = 200
	center.offset_top = 0 # Đẩy xuống dưới mốc Y=360 (Tâm màn hình)
	center.offset_bottom = 290
	center.add_theme_constant_override("separation", 15)
	add_child(center)
	
	username_input = LineEdit.new()
	username_input.placeholder_text = "Tên của bạn..."
	username_input.add_theme_font_size_override("font_size", 20)
	username_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	username_input.add_theme_stylebox_override("normal", input_normal)
	username_input.add_theme_stylebox_override("focus", input_focus)
	center.add_child(username_input)
	
	ip_input = LineEdit.new()
	ip_input.placeholder_text = "Nhập IP để Join (để trống nếu Host)"
	ip_input.add_theme_font_size_override("font_size", 20)
	ip_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	ip_input.add_theme_stylebox_override("normal", input_normal)
	ip_input.add_theme_stylebox_override("focus", input_focus)
	center.add_child(ip_input)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(hbox)
	
	var btn_host = _create_fancy_btn("TẠO PHÒNG (HOST)", Color("#1565c0"))
	btn_host.pressed.connect(_on_host)
	
	if OS.has_feature("web"):
		btn_host.disabled = true
		btn_host.tooltip_text = "Trình duyệt Web không thể làm Máy chủ. Hãy tải bản PC để làm Host."
		ip_input.placeholder_text = "Nhập IP Máy chủ PC để Join..."
		
	hbox.add_child(btn_host)
	
	var btn_join = _create_fancy_btn("THAM GIA (JOIN)", Color("#2e7d32"))
	btn_join.pressed.connect(_on_join)
	hbox.add_child(btn_join)
	
	# --- Màn hình Lobby ---
	lobby_panel = Panel.new()
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.06, 0.09, 0.9) # Dark translucent blue
	ps.border_width_left = 1; ps.border_width_right = 1; ps.border_width_top = 1; ps.border_width_bottom = 1
	ps.border_color = Color(1, 1, 1, 0.18)
	ps.corner_radius_top_left = 18; ps.corner_radius_top_right = 18; ps.corner_radius_bottom_left = 18; ps.corner_radius_bottom_right = 18
	ps.shadow_size = 40; ps.shadow_color = Color(0, 0, 0, 0.7)
	lobby_panel.add_theme_stylebox_override("panel", ps)
	lobby_panel.custom_minimum_size = Vector2(480, 380)
	lobby_panel.hide()
	
	var lobby_center = CenterContainer.new()
	lobby_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	lobby_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lobby_center)
	lobby_center.add_child(lobby_panel)
	
	var lobby_vbox = VBoxContainer.new()
	lobby_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	lobby_vbox.add_theme_constant_override("separation", 20)
	lobby_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	lobby_panel.add_child(lobby_vbox)
	
	var lbl = Label.new()
	lbl.text = "ĐANG CHỜ NGƯỜI CHƠI..."
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_vbox.add_child(lbl)
	
	players_vbox = VBoxContainer.new()
	players_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	players_vbox.add_theme_constant_override("separation", 10)
	lobby_vbox.add_child(players_vbox)
	
	start_btn = _create_fancy_btn("BẮT ĐẦU GAME", Color("#ff8f00"))
	start_btn.custom_minimum_size = Vector2(320, 55)
	start_btn.pressed.connect(_on_start_game)
	start_btn.hide()
	lobby_vbox.add_child(start_btn)
	
	var btn_leave = _create_fancy_btn("THOÁT PHÒNG", Color("#c62828"))
	btn_leave.custom_minimum_size = Vector2(320, 55)
	btn_leave.pressed.connect(_on_leave_lobby)
	lobby_vbox.add_child(btn_leave)
	
	NetworkManager.player_list_changed.connect(_update_lobby)
	multiplayer.connection_failed.connect(_on_connection_error)
	multiplayer.server_disconnected.connect(_on_server_died)

func _create_fancy_btn(text: String, color: Color) -> Button:
	var btn = Button.new(); btn.text = text; btn.custom_minimum_size = Vector2(180, 50)
	var s = StyleBoxFlat.new(); s.bg_color = color
	s.border_width_left = 1; s.border_width_right = 1; s.border_width_top = 1; s.border_width_bottom = 1
	s.border_color = Color(1, 1, 1, 0.15)
	s.corner_radius_top_left = 10; s.corner_radius_top_right = 10; s.corner_radius_bottom_left = 10; s.corner_radius_bottom_right = 10
	s.shadow_size = 10; s.shadow_color = Color(0, 0, 0, 0.3)
	
	var h = s.duplicate()
	h.bg_color = color.lightened(0.12)
	h.border_color = Color(1, 1, 1, 0.3)
	h.shadow_size = 15; h.shadow_color = color
	h.shadow_color.a = 0.2
	
	var p = s.duplicate()
	p.bg_color = color.darkened(0.15)
	
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_font_size_override("font_size", 18)
	return btn

func _on_connection_error():
	var lbl = lobby_panel.get_child(0) as Label
	lbl.text = "LỖI KẾT NỐI! KIỂM TRA LẠI IP HOẶC LINK NGROK"
	lbl.add_theme_color_override("font_color", Color.RED)

func _on_server_died():
	var lbl = lobby_panel.get_child(0) as Label
	lbl.text = "MÁY CHỦ ĐÃ ĐÓNG HOẶC MẤT MẠNG!"
	lbl.add_theme_color_override("font_color", Color.RED)

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
	# Ẩn tiêu đề và phụ đề để giao diện sảnh chờ rộng rãi, chuyên nghiệp
	var title = get_node_or_null("Title")
	if title: title.hide()
	var subtitle = get_node_or_null("Subtitle")
	if subtitle: subtitle.hide()
	
	lobby_panel.show()
	_update_lobby()

func _on_leave_lobby():
	NetworkManager.leave_game()
	var title = get_node_or_null("Title")
	if title: title.show()
	var subtitle = get_node_or_null("Subtitle")
	if subtitle: subtitle.show()
	lobby_panel.hide()

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
