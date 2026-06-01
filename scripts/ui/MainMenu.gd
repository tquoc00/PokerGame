extends Control

var username_input: LineEdit
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
	# Xóa UI cũ (giữ lại background nếu có)
	for c in get_children():
		c.queue_free()
	
	# === BACKGROUND GRADIENT PREMIUM ===
	var bg = ColorRect.new()
	bg.color = Color("#0a0e17")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# === Animated particle-like decorations ===
	_create_ambient_particles()
	
	# === TITLE ===
	title_label = Label.new()
	title_label.text = "LIAR'S POKER"
	title_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_label.offset_top = 80
	title_label.offset_bottom = 180
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 72)
	title_label.add_theme_color_override("font_color", Color("#ff1744"))
	title_label.add_theme_constant_override("outline_size", 4)
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title_label.modulate.a = 0.0
	add_child(title_label)
	
	# === SUBTITLE ===
	subtitle_label = Label.new()
	subtitle_label.text = "Tiền có thể kiếm lại... Mạng thì không."
	subtitle_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle_label.offset_top = 175
	subtitle_label.offset_bottom = 220
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 22)
	subtitle_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6, 0.8))
	subtitle_label.add_theme_constant_override("outline_size", 2)
	subtitle_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	subtitle_label.modulate.a = 0.0
	add_child(subtitle_label)

	# === INPUT STYLES ===
	var input_normal = StyleBoxFlat.new()
	input_normal.bg_color = Color(1, 1, 1, 0.05)
	input_normal.set_border_width_all(1)
	input_normal.border_color = Color(1, 1, 1, 0.1)
	input_normal.set_corner_radius_all(12)
	input_normal.content_margin_left = 20; input_normal.content_margin_right = 20
	input_normal.content_margin_top = 8; input_normal.content_margin_bottom = 8
	
	var input_focus = input_normal.duplicate()
	input_focus.bg_color = Color(1, 1, 1, 0.08)
	input_focus.border_color = Color("#ff1744")
	input_focus.shadow_size = 12
	input_focus.shadow_color = Color(1.0, 0.09, 0.27, 0.2)

	# === CENTER FORM ===
	center_container = VBoxContainer.new()
	center_container.set_anchors_preset(Control.PRESET_CENTER)
	center_container.offset_left = -220
	center_container.offset_right = 220
	center_container.offset_top = 20
	center_container.offset_bottom = 310
	center_container.add_theme_constant_override("separation", 18)
	center_container.modulate.a = 0.0
	add_child(center_container)
	
	# Tên người chơi
	var name_label = Label.new()
	name_label.text = "TÊN NGƯỜI CHƠI"
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	center_container.add_child(name_label)
	
	username_input = LineEdit.new()
	username_input.placeholder_text = "Nhập biệt danh..."
	username_input.add_theme_font_size_override("font_size", 20)
	username_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	username_input.custom_minimum_size.y = 50
	username_input.add_theme_stylebox_override("normal", input_normal)
	username_input.add_theme_stylebox_override("focus", input_focus)
	username_input.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.25))
	center_container.add_child(username_input)
	
	# Địa chỉ kết nối
	var ip_label = Label.new()
	ip_label.text = "ĐỊA CHỈ KẾT NỐI"
	ip_label.add_theme_font_size_override("font_size", 14)
	ip_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	center_container.add_child(ip_label)
	
	ip_input = LineEdit.new()
	ip_input.placeholder_text = "IP hoặc Link wss:// (để trống = LAN)"
	ip_input.add_theme_font_size_override("font_size", 18)
	ip_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	ip_input.custom_minimum_size.y = 50
	ip_input.add_theme_stylebox_override("normal", input_normal)
	ip_input.add_theme_stylebox_override("focus", input_focus)
	ip_input.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.25))
	center_container.add_child(ip_input)
	
	# Nút bấm
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center_container.add_child(hbox)
	
	var btn_host = _create_premium_btn("🏠 TẠO PHÒNG", Color("#1565c0"), Color("#0d47a1"))
	btn_host.pressed.connect(_on_host)
	
	if OS.has_feature("web"):
		btn_host.disabled = true
		btn_host.tooltip_text = "Web không thể Host. Hãy dùng bản PC."
		ip_input.placeholder_text = "Nhập link wss:// từ Host..."
		
	hbox.add_child(btn_host)
	
	var btn_join = _create_premium_btn("🎮 THAM GIA", Color("#2e7d32"), Color("#1b5e20"))
	btn_join.pressed.connect(_on_join)
	hbox.add_child(btn_join)
	
	# Hướng dẫn kết nối
	var help_label = Label.new()
	help_label.text = "💡 Cùng WiFi: nhập IP  |  Khác mạng: dùng ngrok/playit"
	help_label.add_theme_font_size_override("font_size", 13)
	help_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_container.add_child(help_label)
	
	# === LOBBY PANEL ===
	_build_lobby_panel()
	
	# === KẾT NỐI SIGNALS ===
	NetworkManager.player_list_changed.connect(_update_lobby)
	multiplayer.connection_failed.connect(_on_connection_error)
	multiplayer.server_disconnected.connect(_on_server_died)
	
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
	tw.tween_property(title_label, "theme_override_colors/font_color", Color("#ff4444"), 1.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(title_label, "theme_override_colors/font_color", Color("#ff1744"), 1.5).set_trans(Tween.TRANS_SINE)

func _create_ambient_particles():
	# Tạo các chấm sáng nhỏ floating xung quanh
	for i in range(8):
		var dot = Panel.new()
		var s = StyleBoxFlat.new()
		s.set_corner_radius_all(20)
		s.bg_color = Color(1.0, 0.09, 0.27, randf_range(0.03, 0.08))
		dot.add_theme_stylebox_override("panel", s)
		dot.size = Vector2(randf_range(4, 12), randf_range(4, 12))
		dot.position = Vector2(randf_range(50, 1230), randf_range(50, 670))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dot)
		
		# Float animation
		var tw = create_tween().set_loops()
		var target_y = dot.position.y + randf_range(-40, 40)
		tw.tween_property(dot, "position:y", target_y, randf_range(2.0, 4.0)).set_trans(Tween.TRANS_SINE)
		tw.tween_property(dot, "position:y", dot.position.y, randf_range(2.0, 4.0)).set_trans(Tween.TRANS_SINE)

# ============================================================
# BUTTON FACTORY
# ============================================================
func _create_premium_btn(text: String, color: Color, dark_color: Color = Color()) -> Button:
	if dark_color == Color(): dark_color = color.darkened(0.2)
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 52)
	
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.set_border_width_all(1)
	s.border_color = Color(1, 1, 1, 0.15)
	s.set_corner_radius_all(12)
	s.shadow_size = 8; s.shadow_color = Color(0, 0, 0, 0.4)
	s.content_margin_left = 16; s.content_margin_right = 16
	
	var h = s.duplicate()
	h.bg_color = color.lightened(0.15)
	h.border_color = Color(1, 1, 1, 0.3)
	h.shadow_size = 16; h.shadow_color = color
	h.shadow_color.a = 0.3
	
	var p = s.duplicate()
	p.bg_color = dark_color
	p.shadow_size = 4
	
	var d = s.duplicate()
	d.bg_color = Color(0.3, 0.3, 0.3, 0.5)
	d.border_color = Color(1, 1, 1, 0.05)
	d.shadow_size = 0
	
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_stylebox_override("disabled", d)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color.WHITE)
	return btn

# ============================================================
# CONNECTION HANDLERS
# ============================================================
func _on_connection_error():
	status_label.text = "❌ LỖI KẾT NỐI! Kiểm tra lại IP/Link."
	status_label.add_theme_color_override("font_color", Color("#ff5252"))
	# Hiệu ứng rung
	var tw = create_tween()
	tw.tween_property(lobby_panel, "position:x", lobby_panel.position.x + 10, 0.05)
	tw.tween_property(lobby_panel, "position:x", lobby_panel.position.x - 10, 0.05)
	tw.tween_property(lobby_panel, "position:x", lobby_panel.position.x + 5, 0.05)
	tw.tween_property(lobby_panel, "position:x", lobby_panel.position.x, 0.05)

func _on_server_died():
	status_label.text = "⚠️ MÁY CHỦ ĐÃ ĐÓNG!"
	status_label.add_theme_color_override("font_color", Color("#ff5252"))

func _get_name():
	var n = username_input.text.strip_edges()
	return n if n != "" else "Gambler_" + str(randi() % 1000)

# ============================================================
# HOST / JOIN
# ============================================================
func _on_host():
	if NetworkManager.host_game(_get_name()):
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
	var ip = ip_input.text.strip_edges()
	if ip == "": ip = "127.0.0.1"
	if NetworkManager.join_game(ip, _get_name()):
		_show_lobby()
		lobby_title_label.text = "ĐANG KẾT NỐI..."
		ip_display_label.text = "Kết nối đến: " + ip
		status_label.text = "Đang chờ phản hồi từ máy chủ..."

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
