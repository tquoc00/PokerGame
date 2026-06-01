extends Control

var username_input: LineEdit
var money_display_label: Label
var ip_input: LineEdit
var lobby_panel: Panel
var players_vbox: VBoxContainer
var start_btn: Button
var center_container: VBoxContainer
var title_label: Label
var subtitle_label: Label
var lobby_title_label: Label
var ip_display_label: Label
var status_label: Label

# ============================================================
# MENU KHỞI TẠO
# ============================================================
func _ready():
	for c in get_children():
		c.queue_free()
	
	# === BACKGROUND ===
	var bg = ColorRect.new()
	bg.color = Color("#080c14")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# === Vignette overlay ===
	_create_ambient_particles()
	
	# === MAIN CARD PANEL (trung tâm, phong cách bảng gỗ casino) ===
	var card_panel = Panel.new()
	var cp_style = StyleBoxFlat.new()
	cp_style.bg_color = Color(0.08, 0.11, 0.20, 0.97)
	cp_style.set_border_width_all(3)
	cp_style.border_color = Color("#c0965c")
	cp_style.set_corner_radius_all(24)
	cp_style.shadow_size = 40
	cp_style.shadow_color = Color(0, 0, 0, 0.7)
	cp_style.shadow_offset = Vector2(0, 6)
	card_panel.add_theme_stylebox_override("panel", cp_style)
	card_panel.custom_minimum_size = Vector2(520, 580)
	
	var card_center = CenterContainer.new()
	card_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card_center)
	card_center.add_child(card_panel)
	
	# === Viền vàng trang trí bên trong panel ===
	var inner_border = Panel.new()
	var ib_style = StyleBoxFlat.new()
	ib_style.bg_color = Color(0, 0, 0, 0)
	ib_style.set_border_width_all(1)
	ib_style.border_color = Color(0.75, 0.60, 0.35, 0.35)
	ib_style.set_corner_radius_all(18)
	inner_border.add_theme_stylebox_override("panel", ib_style)
	inner_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner_border.offset_left = 8; inner_border.offset_right = -8
	inner_border.offset_top = 8; inner_border.offset_bottom = -8
	inner_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.add_child(inner_border)
	
	# === Suit decorations (♠ ♥ ♦ ♣) ===
	var suits = ["♠", "♥", "♦", "♣"]
	var suit_colors = [Color("#8ecae6"), Color("#e63946"), Color("#f4a261"), Color("#2a9d8f")]
	for i in 4:
		var s_lbl = Label.new()
		s_lbl.text = suits[i]
		s_lbl.add_theme_font_size_override("font_size", 28)
		s_lbl.add_theme_color_override("font_color", Color(suit_colors[i], 0.15))
		s_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_panel.add_child(s_lbl)
		s_lbl.position = Vector2(18 + i * 125, 12)
	
	# === Content margin inside card panel ===
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	card_panel.add_child(margin)
	
	center_container = VBoxContainer.new()
	center_container.add_theme_constant_override("separation", 10)
	center_container.alignment = BoxContainer.ALIGNMENT_CENTER
	center_container.modulate.a = 0.0
	margin.add_child(center_container)
	
	# === TITLE inside panel ===
	title_label = Label.new()
	title_label.text = "♠ LIAR'S POKER ♠"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 42)
	title_label.add_theme_color_override("font_color", Color("#ffd700"))
	title_label.add_theme_constant_override("outline_size", 3)
	title_label.add_theme_color_override("font_outline_color", Color(0.4, 0.25, 0.0, 0.8))
	title_label.modulate.a = 0.0
	center_container.add_child(title_label)
	
	# === SUBTITLE ===
	subtitle_label = Label.new()
	subtitle_label.text = "Tiền có thể kiếm lại... Mạng thì không."
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 15)
	subtitle_label.add_theme_color_override("font_color", Color(0.75, 0.65, 0.55, 0.7))
	subtitle_label.modulate.a = 0.0
	center_container.add_child(subtitle_label)
	
	# Separator
	var sep1 = _make_gold_separator()
	center_container.add_child(sep1)
	
	# === INPUT STYLES ===
	var input_normal = StyleBoxFlat.new()
	input_normal.bg_color = Color(0.04, 0.06, 0.12, 0.9)
	input_normal.set_border_width_all(2)
	input_normal.border_color = Color("#c0965c")
	input_normal.set_corner_radius_all(10)
	input_normal.content_margin_left = 20; input_normal.content_margin_right = 20
	input_normal.content_margin_top = 8; input_normal.content_margin_bottom = 8
	
	var input_focus = input_normal.duplicate()
	input_focus.bg_color = Color(0.06, 0.09, 0.18, 0.95)
	input_focus.border_color = Color("#ffd700")
	input_focus.shadow_size = 8
	input_focus.shadow_color = Color(1.0, 0.84, 0.0, 0.15)
	
	# === Tên người chơi ===
	var name_label = Label.new()
	name_label.text = "♦ TÊN NGƯỜI CHƠI"
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color("#c0965c"))
	center_container.add_child(name_label)
	
	username_input = LineEdit.new()
	username_input.placeholder_text = "Nhập biệt danh..."
	username_input.add_theme_font_size_override("font_size", 20)
	username_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	username_input.custom_minimum_size.y = 46
	username_input.add_theme_stylebox_override("normal", input_normal)
	username_input.add_theme_stylebox_override("focus", input_focus)
	username_input.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.2))
	username_input.add_theme_color_override("font_color", Color.WHITE)
	center_container.add_child(username_input)
	
	# === Số dư tài khoản ===
	money_display_label = Label.new()
	money_display_label.text = "💰 Số dư: $ 1000"
	money_display_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	money_display_label.add_theme_font_size_override("font_size", 16)
	money_display_label.add_theme_color_override("font_color", Color("#4caf50"))
	center_container.add_child(money_display_label)
	
	username_input.text_changed.connect(_on_username_changed)
	
	# === Địa chỉ kết nối ===
	var ip_label = Label.new()
	ip_label.text = "♣ ĐỊA CHỈ KẾT NỐI"
	ip_label.add_theme_font_size_override("font_size", 13)
	ip_label.add_theme_color_override("font_color", Color("#c0965c"))
	center_container.add_child(ip_label)
	
	ip_input = LineEdit.new()
	ip_input.placeholder_text = "IP hoặc Link wss:// (để trống = LAN)"
	ip_input.add_theme_font_size_override("font_size", 17)
	ip_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	ip_input.custom_minimum_size.y = 46
	ip_input.add_theme_stylebox_override("normal", input_normal)
	ip_input.add_theme_stylebox_override("focus", input_focus)
	ip_input.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.2))
	ip_input.add_theme_color_override("font_color", Color.WHITE)
	center_container.add_child(ip_input)
	
	# Separator
	var sep2 = _make_gold_separator()
	center_container.add_child(sep2)
	
	# === Buttons ===
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_container.add_child(hbox)
	
	var btn_host = _create_premium_btn("🏠 TẠO PHÒNG", Color("#1a5276"), Color("#0e3d5c"))
	btn_host.pressed.connect(_on_host)
	if OS.has_feature("web"):
		btn_host.disabled = true
		btn_host.tooltip_text = "Web không thể Host. Hãy dùng bản PC."
		ip_input.placeholder_text = "Nhập link wss:// từ Host..."
	hbox.add_child(btn_host)
	
	var btn_join = _create_premium_btn("🎮 THAM GIA", Color("#1e6f40"), Color("#145c32"))
	btn_join.pressed.connect(_on_join)
	hbox.add_child(btn_join)
	
	var btn_single = _create_premium_btn("🤖 CHƠI ĐƠN (VS BOT)", Color("#c0965c"), Color("#a07a44"))
	btn_single.custom_minimum_size.y = 50
	btn_single.pressed.connect(_on_single_player)
	center_container.add_child(btn_single)
	
	# Hướng dẫn kết nối
	var help_label = Label.new()
	help_label.text = "💡 Cùng WiFi: nhập IP  |  Khác mạng: dùng ngrok/playit"
	help_label.add_theme_font_size_override("font_size", 12)
	help_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.25))
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_container.add_child(help_label)
	
	# === LOBBY PANEL ===
	_build_lobby_panel()
	
	# === KẾT NỐI SIGNALS ===
	NetworkManager.player_list_changed.connect(_update_lobby)
	multiplayer.connection_failed.connect(_on_connection_error)
	multiplayer.server_disconnected.connect(_on_server_died)
	
	# Load tên người chơi cuối cùng đã sử dụng
	var last_name = NetworkManager.load_last_username()
	if last_name != "":
		username_input.text = last_name
		_update_money_display(last_name)
	else:
		_update_money_display("")
		
	# === ENTRANCE ANIMATION ===
	_play_entrance_animation()
	
	# === AUTO-SERVER MODE ===
	if "--auto-server" in OS.get_cmdline_args():
		print("--- AUTO SERVER MODE ---")
		_on_host()
		NetworkManager.player_list_changed.connect(func():
			if NetworkManager.players.size() >= 2:
				print("PLAYER JOINED! STARTING GAME...")
				_on_start_game()
		)

func _make_gold_separator() -> Control:
	var sep_container = CenterContainer.new()
	sep_container.custom_minimum_size.y = 12
	var sep_line = ColorRect.new()
	sep_line.custom_minimum_size = Vector2(280, 1)
	sep_line.color = Color("#c0965c", 0.3)
	sep_container.add_child(sep_line)
	return sep_container

# ============================================================
# LOBBY PANEL
# ============================================================
func _build_lobby_panel():
	lobby_panel = Panel.new()
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.08, 0.14, 0.95)
	ps.set_border_width_all(1)
	ps.border_color = Color(1, 1, 1, 0.12)
	ps.set_corner_radius_all(20)
	ps.shadow_size = 50; ps.shadow_color = Color(0, 0, 0, 0.8)
	lobby_panel.add_theme_stylebox_override("panel", ps)
	lobby_panel.custom_minimum_size = Vector2(520, 450)
	lobby_panel.hide()
	
	var lobby_center = CenterContainer.new()
	lobby_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	lobby_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lobby_center)
	lobby_center.add_child(lobby_panel)
	
	var lobby_vbox = VBoxContainer.new()
	lobby_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	lobby_vbox.add_theme_constant_override("separation", 14)
	lobby_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var lobby_margin = MarginContainer.new()
	lobby_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	lobby_margin.add_theme_constant_override("margin_left", 30)
	lobby_margin.add_theme_constant_override("margin_right", 30)
	lobby_margin.add_theme_constant_override("margin_top", 25)
	lobby_margin.add_theme_constant_override("margin_bottom", 25)
	lobby_panel.add_child(lobby_margin)
	lobby_margin.add_child(lobby_vbox)
	
	# Tiêu đề lobby
	lobby_title_label = Label.new()
	lobby_title_label.text = "PHÒNG CHỜ"
	lobby_title_label.add_theme_font_size_override("font_size", 28)
	lobby_title_label.add_theme_color_override("font_color", Color("#ff1744"))
	lobby_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_vbox.add_child(lobby_title_label)
	
	# Hiển thị IP
	ip_display_label = Label.new()
	ip_display_label.text = ""
	ip_display_label.add_theme_font_size_override("font_size", 16)
	ip_display_label.add_theme_color_override("font_color", Color("#4fc3f7"))
	ip_display_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ip_display_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_vbox.add_child(ip_display_label)
	
	# Separator
	var sep = HSeparator.new()
	sep.add_theme_stylebox_override("separator", StyleBoxFlat.new())
	sep.add_theme_constant_override("separation", 8)
	lobby_vbox.add_child(sep)
	
	# Trạng thái
	status_label = Label.new()
	status_label.text = "Đang chờ người chơi..."
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_vbox.add_child(status_label)
	
	# Danh sách người chơi
	players_vbox = VBoxContainer.new()
	players_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	players_vbox.add_theme_constant_override("separation", 8)
	lobby_vbox.add_child(players_vbox)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 10
	lobby_vbox.add_child(spacer)
	
	# Nút bắt đầu
	start_btn = _create_premium_btn("⚔️ BẮT ĐẦU TRẬN ĐẤU", Color("#ff8f00"), Color("#e65100"))
	start_btn.custom_minimum_size = Vector2(360, 55)
	start_btn.pressed.connect(_on_start_game)
	start_btn.hide()
	lobby_vbox.add_child(start_btn)
	
	# Nút thoát
	var btn_leave = _create_premium_btn("🚪 RỜI PHÒNG", Color("#c62828"), Color("#b71c1c"))
	btn_leave.custom_minimum_size = Vector2(360, 50)
	btn_leave.pressed.connect(_on_leave_lobby)
	lobby_vbox.add_child(btn_leave)

# ============================================================
# ANIMATIONS
# ============================================================
func _play_entrance_animation():
	var tw = create_tween()
	tw.tween_property(title_label, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(subtitle_label, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(center_container, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	
	# Title glow pulse animation (loop)
	_start_title_pulse()

func _start_title_pulse():
	var tw = create_tween().set_loops()
	tw.tween_property(title_label, "theme_override_colors/font_color", Color("#ffed8a"), 1.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(title_label, "theme_override_colors/font_color", Color("#ffd700"), 1.8).set_trans(Tween.TRANS_SINE)

func _create_ambient_particles():
	# Tạo các chấm sáng vàng/đỏ floating xung quanh phong cách casino
	var colors = [Color("#c0965c"), Color("#ffd700"), Color("#e63946"), Color("#2a9d8f")]
	for i in range(12):
		var dot = Panel.new()
		var s = StyleBoxFlat.new()
		s.set_corner_radius_all(20)
		s.bg_color = Color(colors[i % 4], randf_range(0.03, 0.07))
		dot.add_theme_stylebox_override("panel", s)
		dot.size = Vector2(randf_range(3, 10), randf_range(3, 10))
		dot.position = Vector2(randf_range(30, 1250), randf_range(30, 690))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dot)
		
		var tw = create_tween().set_loops()
		var target_y = dot.position.y + randf_range(-50, 50)
		tw.tween_property(dot, "position:y", target_y, randf_range(2.5, 5.0)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(dot, "position:y", dot.position.y, randf_range(2.5, 5.0)).set_trans(Tween.TRANS_SINE)

# ============================================================
# BUTTON FACTORY
# ============================================================
func _create_premium_btn(text: String, color: Color, dark_color: Color = Color()) -> Button:
	if dark_color == Color(): dark_color = color.darkened(0.2)
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 48)
	
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_border_width_all(2)
	s.border_color = Color(0.85, 0.70, 0.45, 0.5)
	s.set_corner_radius_all(10)
	s.shadow_size = 6; s.shadow_color = Color(0, 0, 0, 0.4)
	s.content_margin_left = 16; s.content_margin_right = 16
	
	var h = s.duplicate()
	h.bg_color = color.lightened(0.15)
	h.border_color = Color("#ffd700")
	h.shadow_size = 12; h.shadow_color = Color(color, 0.3)
	
	var p = s.duplicate()
	p.bg_color = dark_color
	p.shadow_size = 2
	
	var d = s.duplicate()
	d.bg_color = Color(0.2, 0.2, 0.2, 0.5)
	d.border_color = Color(1, 1, 1, 0.05)
	d.shadow_size = 0
	
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_stylebox_override("disabled", d)
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", Color.WHITE)
	return btn

# ============================================================
# CONNECTION HANDLERS
# ============================================================
func _on_connection_error():
	status_label.text = "❌ LỖI KẾT NỐI! Kiểm tra lại IP/Link."
	status_label.add_theme_color_override("font_color", Color("#ff5252"))
	var tw = create_tween()
	tw.tween_property(lobby_panel, "position:x", lobby_panel.position.x + 10, 0.05)
	tw.tween_property(lobby_panel, "position:x", lobby_panel.position.x - 10, 0.05)
	tw.tween_property(lobby_panel, "position:x", lobby_panel.position.x + 5, 0.05)
	tw.tween_property(lobby_panel, "position:x", lobby_panel.position.x, 0.05)

func _on_server_died():
	status_label.text = "⚠️ MÁY CHỦ ĐÃ ĐÓNG!"
	status_label.add_theme_color_override("font_color", Color("#ff5252"))

func _on_username_changed(new_text: String):
	_update_money_display(new_text)

func _update_money_display(name_str: String):
	var target_name = name_str.strip_edges()
	if target_name == "":
		money_display_label.text = "💰 Số dư mặc định: $ 1000"
		money_display_label.add_theme_color_override("font_color", Color("#4caf50"))
	else:
		var money = NetworkManager.load_player_money(target_name)
		money_display_label.text = "💰 Số dư [" + target_name + "]: $ " + str(money)
		if money >= 1000:
			money_display_label.add_theme_color_override("font_color", Color("#4caf50"))
		elif money > 0:
			money_display_label.add_theme_color_override("font_color", Color("#ffd54f"))
		else:
			money_display_label.add_theme_color_override("font_color", Color("#ff5252"))

func _get_name():
	var n = username_input.text.strip_edges()
	return n if n != "" else "Gambler_" + str(randi() % 1000)

# ============================================================
# HOST / JOIN
# ============================================================
func _on_host():
	NetworkManager.is_single_player = false
	var name_input = _get_name()
	NetworkManager.save_last_username(name_input)
	if NetworkManager.host_game(name_input):
		_show_lobby()
		start_btn.show()
		
		# Hiển thị IP
		var ips = IP.get_local_addresses()
		var local_ip = ""
		for ip in ips:
			if ip.begins_with("192.168.") or ip.begins_with("10.") or (ip.begins_with("172.") and int(ip.split(".")[1]) >= 16 and int(ip.split(".")[1]) <= 31):
				local_ip = ip
				break
		if local_ip == "": local_ip = "127.0.0.1"
		
		lobby_title_label.text = "PHÒNG CỦA BẠN"
		ip_display_label.text = "IP (LAN): " + local_ip + ":" + str(NetworkManager.PORT) + "\nKhác mạng: Chạy ngrok tcp 8080 rồi gửi link cho bạn bè"

func _on_join():
	NetworkManager.is_single_player = false
	var name_input = _get_name()
	NetworkManager.save_last_username(name_input)
	var ip = ip_input.text.strip_edges()
	if ip == "": ip = "127.0.0.1"
	if NetworkManager.join_game(ip, name_input):
		_show_lobby()
		lobby_title_label.text = "ĐANG KẾT NỐI..."
		ip_display_label.text = "Kết nối đến: " + ip
		status_label.text = "Đang chờ phản hồi từ máy chủ..."

func _on_single_player():
	var name_input = _get_name()
	NetworkManager.save_last_username(name_input)
	NetworkManager.is_single_player = true
	NetworkManager.my_name = name_input
	NetworkManager.players = {
		1: { "name": name_input, "money": NetworkManager.load_player_money(name_input) },
		2: { "name": "Máy A (Bot Đỏ)", "money": NetworkManager.load_player_money("Máy A (Bot Đỏ)") },
		3: { "name": "Máy B (Bot Xanh)", "money": NetworkManager.load_player_money("Máy B (Bot Xanh)") },
		4: { "name": "Máy C (Bot Vàng)", "money": NetworkManager.load_player_money("Máy C (Bot Vàng)") }
	}
	get_tree().change_scene_to_file("res://scenes/main/Table.tscn")

func _show_lobby():
	# Ẩn menu chính
	title_label.hide()
	subtitle_label.hide()
	center_container.hide()
	
	# Hiện lobby với animation
	lobby_panel.modulate.a = 0.0
	lobby_panel.scale = Vector2(0.9, 0.9)
	lobby_panel.show()
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(lobby_panel, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(lobby_panel, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	_update_lobby()

func _on_leave_lobby():
	NetworkManager.leave_game()
	title_label.show()
	subtitle_label.show()
	center_container.show()
	lobby_panel.hide()
	
	# Fade in menu lại
	center_container.modulate.a = 0.0
	title_label.modulate.a = 0.0
	subtitle_label.modulate.a = 0.0
	_play_entrance_animation()

# ============================================================
# LOBBY UPDATE
# ============================================================
func _update_lobby():
	for c in players_vbox.get_children():
		c.queue_free()
	
	status_label.text = str(NetworkManager.players.size()) + "/4 người chơi"
	status_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	
	if multiplayer.is_server():
		lobby_title_label.text = "PHÒNG CỦA BẠN"
	else:
		lobby_title_label.text = "PHÒNG CHỜ"
		
	for id in NetworkManager.players:
		var p_name = NetworkManager.players[id].name
		var player_card = _create_player_card(p_name, id == 1)
		players_vbox.add_child(player_card)
		
		# Animation slide in
		player_card.modulate.a = 0.0
		player_card.position.x = -20
		var tw = create_tween().set_parallel(true)
		tw.tween_property(player_card, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE)
		tw.tween_property(player_card, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func _create_player_card(p_name: String, is_host: bool) -> PanelContainer:
	var card = PanelContainer.new()
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(1, 1, 1, 0.05)
	ps.set_border_width_all(1)
	ps.border_color = Color(1, 1, 1, 0.08)
	ps.set_corner_radius_all(10)
	ps.content_margin_left = 16; ps.content_margin_right = 16
	ps.content_margin_top = 10; ps.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", ps)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)
	
	var icon = Label.new()
	icon.text = "★" if is_host else "●"
	icon.add_theme_font_size_override("font_size", 22)
	icon.add_theme_color_override("font_color", Color("#ffd54f") if is_host else Color("#90caf9"))
	hbox.add_child(icon)
	
	var name_lbl = Label.new()
	name_lbl.text = p_name
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color("#ffd54f") if is_host else Color.WHITE)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_lbl)
	
	if is_host:
		var badge = Label.new()
		badge.text = "HOST"
		badge.add_theme_font_size_override("font_size", 12)
		badge.add_theme_color_override("font_color", Color("#ff8f00"))
		hbox.add_child(badge)
	
	return card

func _on_start_game():
	NetworkManager.start_game.rpc()
