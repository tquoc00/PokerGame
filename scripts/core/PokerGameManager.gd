class_name PokerGameManager
extends Node

# ============================================================
# MULTIPLAYER LIAR'S POKER - 4 PLAYERS
# ============================================================

enum GameState { WAITING, PRE_FLOP, FLOP, TURN, RIVER, SHOWDOWN }

var deck: Deck
var state: GameState = GameState.WAITING
var community_cards: Array[Card] = []

var pot_money: int = 0
var current_round_bet: int = 100

var my_hand: Array[Card] = []
var turn_order: Array = [] # Array of peer_ids
var current_turn_idx: int = 0
var active_players: Dictionary = {} # peer_id -> { has_folded: bool, money_bet: int }
var server_player_hands: Dictionary = {} # peer_id -> Array[Card]

# --- UI references ---
var info_label: Label
var pot_title: Label
var pot_bullet_container: HBoxContainer
var btn_fold: Button
var btn_call: Button
var btn_all_in: Button
var btn_start_round: Button
var player_panels: Dictionary = {}
var community_card_uis: Array[CardUI] = []
var card_scene: PackedScene = preload("res://scenes/prefabs/CardUI.tscn")
var result_overlay: Panel
var result_label: Label
var elim_overlay: ColorRect
var is_mouse_over_trigger: bool = false
var is_mouse_over_popup: bool = false
var _guide_tween: Tween

# All-In Challenge State & UI
var is_all_in_challenge: bool = false
var all_in_challenger_id: int = -1
var all_in_responses: Dictionary = {}
var challenge_panel: PanelContainer
var challenge_lbl: Label
var challenge_btn_in: Button
var challenge_btn_out: Button

func _ready():
	_build_ui()
	if NetworkManager.is_single_player:
		NetworkManager.ready_peers = [1, 2, 3, 4]
		_check_all_ready()
	else:
		if multiplayer.is_server():
			if not NetworkManager.ready_peers.has(1):
				NetworkManager.ready_peers.append(1)
		# Báo cáo lên Server thông qua Autoload NetworkManager (Đảm bảo 100% không bị mất gói tin)
		NetworkManager.server_notify_ready.rpc_id(1)

# ============================================================
# UI CONSTRUCTION
# ============================================================
func _build_ui():
	# Background
	var bg = ColorRect.new()
	bg.color = Color("#0d1117")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Table (Bàn chơi phong cách Premium Mahogany Wood)
	var table_panel = Panel.new()
	var ts = StyleBoxFlat.new()
	ts.bg_color = Color("#0d3c26") # Màu xanh lá đậm sang trọng của sòng bài
	ts.corner_radius_top_left = 220; ts.corner_radius_top_right = 220
	ts.corner_radius_bottom_left = 220; ts.corner_radius_bottom_right = 220
	ts.border_width_left = 18; ts.border_width_right = 18; ts.border_width_top = 18; ts.border_width_bottom = 18
	ts.border_color = Color("#3e2723") # Viền gỗ Mahogany đánh bóng
	ts.shadow_size = 60; ts.shadow_color = Color(0, 0, 0, 0.75)
	table_panel.add_theme_stylebox_override("panel", ts)
	table_panel.size = Vector2(960, 460)
	table_panel.position = Vector2(160, 130)
	add_child(table_panel)
	
	info_label = Label.new()
	info_label.position = Vector2(0, 90)
	info_label.size = Vector2(1280, 40)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 22)
	info_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	info_label.add_theme_constant_override("outline_size", 3)
	info_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	info_label.text = "ĐANG CHỜ MÁY CHỦ..."
	add_child(info_label)
	
	# Result Overlay (hiện kết quả ván đấu không đè lên bàn)
	result_overlay = Panel.new()
	var ro_style = StyleBoxFlat.new()
	ro_style.bg_color = Color(0, 0, 0, 0.85)
	ro_style.set_corner_radius_all(16)
	ro_style.set_border_width_all(2)
	ro_style.border_color = Color("#ffd54f")
	ro_style.shadow_size = 30
	ro_style.shadow_color = Color(0, 0, 0, 0.6)
	result_overlay.add_theme_stylebox_override("panel", ro_style)
	result_overlay.position = Vector2(240, 140)
	result_overlay.size = Vector2(800, 300)
	result_overlay.hide()
	result_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(result_overlay)
	
	result_label = Label.new()
	result_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 24)
	result_label.add_theme_color_override("font_color", Color.WHITE)
	result_label.add_theme_constant_override("outline_size", 3)
	result_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	result_overlay.add_child(result_label)
	
	# Elimination flash overlay
	elim_overlay = ColorRect.new()
	elim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	elim_overlay.color = Color(1, 0, 0, 0)
	elim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(elim_overlay)
	
	# All-In Challenge Overlay Panel (Thiết kế phong cách Sinh tử đỏ đen cực chất)
	challenge_panel = PanelContainer.new()
	var cp_style = StyleBoxFlat.new()
	cp_style.bg_color = Color(0.12, 0.03, 0.03, 0.95) # Dark velvet-red
	cp_style.set_border_width_all(3)
	cp_style.border_color = Color("#ff1744") # Blood red border
	cp_style.set_corner_radius_all(18)
	cp_style.content_margin_left = 24
	cp_style.content_margin_right = 24
	cp_style.content_margin_top = 20
	cp_style.content_margin_bottom = 20
	cp_style.shadow_size = 40
	cp_style.shadow_color = Color(0, 0, 0, 0.8)
	challenge_panel.add_theme_stylebox_override("panel", cp_style)
	challenge_panel.position = Vector2(340, 160)
	challenge_panel.size = Vector2(600, 260)
	challenge_panel.hide()
	add_child(challenge_panel)
	
	var cp_vbox = VBoxContainer.new()
	cp_vbox.add_theme_constant_override("separation", 16)
	challenge_panel.add_child(cp_vbox)
	
	var cp_title = Label.new()
	cp_title.text = "THỬ THÁCH SINH TỬ ALL-IN"
	cp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cp_title.add_theme_font_size_override("font_size", 22)
	cp_title.add_theme_color_override("font_color", Color("#ff1744"))
	cp_title.add_theme_constant_override("outline_size", 2)
	cp_title.add_theme_color_override("font_outline_color", Color.BLACK)
	cp_vbox.add_child(cp_title)
	
	challenge_lbl = Label.new()
	challenge_lbl.text = "Có người đã ALL-IN! Hãy chọn sinh tử..."
	challenge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	challenge_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	challenge_lbl.add_theme_font_size_override("font_size", 16)
	challenge_lbl.add_theme_color_override("font_color", Color.WHITE)
	cp_vbox.add_child(challenge_lbl)
	
	var cp_hbox = HBoxContainer.new()
	cp_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cp_hbox.add_theme_constant_override("separation", 30)
	cp_vbox.add_child(cp_hbox)
	
	challenge_btn_in = _create_btn("IN (Theo cược)", Color("#2e7d32"))
	challenge_btn_in.custom_minimum_size = Vector2(200, 45)
	challenge_btn_in.pressed.connect(func():
		challenge_panel.hide()
		send_challenge_response_to_server("IN")
	)
	cp_hbox.add_child(challenge_btn_in)
	
	challenge_btn_out = _create_btn("OUT (Úp bài)", Color("#c62828"))
	challenge_btn_out.custom_minimum_size = Vector2(200, 45)
	challenge_btn_out.pressed.connect(func():
		challenge_panel.hide()
		send_challenge_response_to_server("OUT")
	)
	cp_hbox.add_child(challenge_btn_out)


	
	# POT
	var pot_area = VBoxContainer.new()
	pot_area.position = Vector2(500, 215)
	pot_area.size = Vector2(280, 80)
	pot_area.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(pot_area)
	
	pot_title = Label.new()
	pot_title.text = "HŨ TIỀN"
	pot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pot_title.add_theme_font_size_override("font_size", 18)
	pot_title.add_theme_color_override("font_color", Color("#ffd54f"))
	pot_area.add_child(pot_title)
	
	pot_bullet_container = HBoxContainer.new()
	pot_bullet_container.alignment = BoxContainer.ALIGNMENT_CENTER
	pot_bullet_container.add_theme_constant_override("separation", 6)
	pot_area.add_child(pot_bullet_container)
	_draw_money(pot_bullet_container, 0, "")
	
	# Tạo Panel cho người chơi
	var my_id = multiplayer.get_unique_id()
	var peers = []
	for k in NetworkManager.players.keys():
		if int(k) != my_id:
			peers.append(int(k))
	
	# Layout positions: Bottom (Local), Top, Left, Right
	_create_player_ui(my_id, NetworkManager.players[my_id].name if NetworkManager.players.has(my_id) else "Bạn", Vector2(540, 560), Color("#1b5e20"))
	
	var pos_array = [Vector2(540, 10), Vector2(30, 250), Vector2(1050, 250)]
	for i in range(peers.size()):
		if i < pos_array.size():
			_create_player_ui(peers[i], NetworkManager.players[peers[i]].name, pos_array[i], Color("#b71c1c"))
	
	# BUTTONS
	var btn_container = VBoxContainer.new()
	btn_container.position = Vector2(1080, 420)
	btn_container.size = Vector2(180, 200)
	btn_container.add_theme_constant_override("separation", 8)
	add_child(btn_container)
	
	btn_all_in = _create_btn("ALL IN", Color("#e65100")); btn_all_in.pressed.connect(func(): send_action_to_server("ALL_IN"))
	btn_call = _create_btn("CALL", Color("#2e7d32")); btn_call.pressed.connect(func(): send_action_to_server("CALL"))
	btn_fold = _create_btn("FOLD", Color("#c62828")); btn_fold.pressed.connect(func(): send_action_to_server("FOLD"))
	btn_container.add_child(btn_all_in); btn_container.add_child(btn_call); btn_container.add_child(btn_fold)
	_disable_buttons()
	
	if multiplayer.is_server():
		# Panel điều khiển cược của Host ở góc dưới bên trái
		var host_panel = PanelContainer.new()
		var h_style = StyleBoxFlat.new()
		h_style.bg_color = Color(0.06, 0.09, 0.13, 0.85) # Glassmorphic dark
		h_style.set_border_width_all(2)
		h_style.border_color = Color("#1565c0") # Host blue theme accent
		h_style.set_corner_radius_all(12)
		h_style.content_margin_left = 12
		h_style.content_margin_right = 12
		h_style.content_margin_top = 8
		h_style.content_margin_bottom = 8
		host_panel.add_theme_stylebox_override("panel", h_style)
		host_panel.position = Vector2(30, 480)
		host_panel.size = Vector2(220, 130)
		host_panel.name = "HostSettings"
		add_child(host_panel)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		host_panel.add_child(vbox)
		
		var title_lbl = Label.new()
		title_lbl.text = "BÀN PHÍM CHỦ PHÒNG"
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_lbl.add_theme_font_size_override("font_size", 14)
		title_lbl.add_theme_color_override("font_color", Color("#90caf9"))
		vbox.add_child(title_lbl)
		
		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 8)
		vbox.add_child(hbox)
		
		var bet_lbl = Label.new()
		bet_lbl.text = "Cược:"
		bet_lbl.add_theme_font_size_override("font_size", 16)
		hbox.add_child(bet_lbl)
		
		var bet_input = LineEdit.new()
		bet_input.text = "100"
		bet_input.name = "BetInput"
		bet_input.custom_minimum_size = Vector2(90, 30)
		bet_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		bet_input.add_theme_font_size_override("font_size", 14)
		
		var le_style = StyleBoxFlat.new()
		le_style.bg_color = Color(1, 1, 1, 0.08)
		le_style.set_corner_radius_all(4)
		bet_input.add_theme_stylebox_override("normal", le_style)
		hbox.add_child(bet_input)
		
		btn_start_round = _create_btn("CHIA BÀI", Color("#1565c0"))
		btn_start_round.custom_minimum_size = Vector2(190, 35)
		btn_start_round.add_theme_font_size_override("font_size", 14)
		btn_start_round.pressed.connect(_on_host_start_round)
		btn_start_round.disabled = (NetworkManager.players.size() < 2)
		vbox.add_child(btn_start_round)
		
		info_label.text = "ĐANG CHỜ NGƯỜI CHƠI KHÁC TẢI XONG..."
		_check_all_ready()
		
	# Nút Thoát Game (Có mặt ở mọi lúc để quay lại Menu chính)
	var btn_exit = _create_btn("THOÁT", Color("#c62828"))
	btn_exit.position = Vector2(20, 20)
	btn_exit.size = Vector2(120, 45)
	btn_exit.pressed.connect(func(): NetworkManager.leave_game())
	add_child(btn_exit)

	# === BẢNG HƯỚNG DẪN XẾP HẠNG BÀI (Cheat Sheet giống Liar's Bar) ===
	var guide_trigger = PanelContainer.new()
	var gt_style = StyleBoxFlat.new()
	gt_style.bg_color = Color(0.09, 0.12, 0.17, 0.85)
	gt_style.set_border_width_all(1)
	gt_style.border_color = Color("#ffb300") # Gold accent
	gt_style.set_corner_radius_all(10)
	gt_style.content_margin_left = 12
	gt_style.content_margin_right = 12
	gt_style.content_margin_top = 6
	gt_style.content_margin_bottom = 6
	guide_trigger.add_theme_stylebox_override("panel", gt_style)
	guide_trigger.position = Vector2(1100, 20)
	guide_trigger.size = Vector2(160, 36)
	add_child(guide_trigger)
	
	var gt_lbl = Label.new()
	gt_lbl.text = "HƯỚNG DẪN BÀI"
	gt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gt_lbl.add_theme_font_size_override("font_size", 12)
	gt_lbl.add_theme_color_override("font_color", Color("#ffd54f"))
	guide_trigger.add_child(gt_lbl)
	
	# Tạo Guide Popup Panel
	var guide_popup = PanelContainer.new()
	var gp_style = StyleBoxFlat.new()
	gp_style.bg_color = Color(0.04, 0.06, 0.1, 0.95) # Dark rich glassmorphism
	gp_style.set_border_width_all(2)
	gp_style.border_color = Color("#ffb300")
	gp_style.set_corner_radius_all(14)
	gp_style.content_margin_left = 16
	gp_style.content_margin_right = 16
	gp_style.content_margin_top = 16
	gp_style.content_margin_bottom = 16
	gp_style.shadow_size = 25
	gp_style.shadow_color = Color(0, 0, 0, 0.6)
	guide_popup.add_theme_stylebox_override("panel", gp_style)
	guide_popup.position = Vector2(930, 70)
	guide_popup.size = Vector2(360, 520)
	guide_popup.position = Vector2(900, 70)
	guide_popup.visible = false
	guide_popup.modulate.a = 0.0
	add_child(guide_popup)
	
	var gp_vbox = VBoxContainer.new()
	gp_vbox.add_theme_constant_override("separation", 8)
	guide_popup.add_child(gp_vbox)
	
	var gp_title = Label.new()
	gp_title.text = "THỨ HẠNG TAY BÀI"
	gp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gp_title.add_theme_font_size_override("font_size", 16)
	gp_title.add_theme_color_override("font_color", Color("#ffb300"))
	gp_vbox.add_child(gp_title)
	
	var gp_divider = ColorRect.new()
	gp_divider.color = Color(1, 1, 1, 0.15)
	gp_divider.custom_minimum_size = Vector2(0, 2)
	gp_vbox.add_child(gp_divider)
	
	# ScrollContainer cho danh sách
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gp_vbox.add_child(scroll)
	
	var list_vbox = VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(list_vbox)
	
	var hands_data = [
		{
			"name": "1. Royal Flush",
			"desc": "Sảnh đồng chất cao (10-J-Q-K-A)",
			"color": "#ffb300",
			"cards": [
				{"r": "A", "s": "Bích", "c": "#263238"},
				{"r": "K", "s": "Bích", "c": "#263238"},
				{"r": "Q", "s": "Bích", "c": "#263238"},
				{"r": "J", "s": "Bích", "c": "#263238"},
				{"r": "10", "s": "Bích", "c": "#263238"}
			]
		},
		{
			"name": "2. Straight Flush",
			"desc": "Sảnh đồng chất bất kỳ (vd: 5-6-7-8-9)",
			"color": "#ff8f00",
			"cards": [
				{"r": "9", "s": "Cơ", "c": "#e53935"},
				{"r": "8", "s": "Cơ", "c": "#e53935"},
				{"r": "7", "s": "Cơ", "c": "#e53935"},
				{"r": "6", "s": "Cơ", "c": "#e53935"},
				{"r": "5", "s": "Cơ", "c": "#e53935"}
			]
		},
		{
			"name": "3. Four of a Kind",
			"desc": "Tứ Quý (4 lá cùng bậc, vd: 4 lá 9)",
			"color": "#29b6f6",
			"cards": [
				{"r": "K", "s": "Bích", "c": "#263238"},
				{"r": "K", "s": "Cơ", "c": "#e53935"},
				{"r": "K", "s": "Rô", "c": "#e53935"},
				{"r": "K", "s": "Tép", "c": "#263238"},
				{"r": "3", "s": "Bích", "c": "#263238"}
			]
		},
		{
			"name": "4. Full House",
			"desc": "Cù Lũ (1 bộ ba + 1 bộ đôi)",
			"color": "#66bb6a",
			"cards": [
				{"r": "10", "s": "Bích", "c": "#263238"},
				{"r": "10", "s": "Cơ", "c": "#e53935"},
				{"r": "10", "s": "Rô", "c": "#e53935"},
				{"r": "7", "s": "Tép", "c": "#263238"},
				{"r": "7", "s": "Bích", "c": "#263238"}
			]
		},
		{
			"name": "5. Flush",
			"desc": "Thùng (5 lá cùng chất, không liên tiếp)",
			"color": "#ab47bc",
			"cards": [
				{"r": "A", "s": "Rô", "c": "#e53935"},
				{"r": "J", "s": "Rô", "c": "#e53935"},
				{"r": "8", "s": "Rô", "c": "#e53935"},
				{"r": "6", "s": "Rô", "c": "#e53935"},
				{"r": "2", "s": "Rô", "c": "#e53935"}
			]
		},
		{
			"name": "6. Straight",
			"desc": "Sảnh (5 lá liên tiếp, khác chất)",
			"color": "#26a69a",
			"cards": [
				{"r": "8", "s": "Bích", "c": "#263238"},
				{"r": "7", "s": "Cơ", "c": "#e53935"},
				{"r": "6", "s": "Rô", "c": "#e53935"},
				{"r": "5", "s": "Tép", "c": "#263238"},
				{"r": "4", "s": "Bích", "c": "#263238"}
			]
		},
		{
			"name": "7. Three of a Kind",
			"desc": "Sám Cô (3 lá cùng bậc, vd: 3 lá K)",
			"color": "#d4e157",
			"cards": [
				{"r": "Q", "s": "Bích", "c": "#263238"},
				{"r": "Q", "s": "Cơ", "c": "#e53935"},
				{"r": "Q", "s": "Rô", "c": "#e53935"},
				{"r": "A", "s": "Tép", "c": "#263238"},
				{"r": "4", "s": "Bích", "c": "#263238"}
			]
		},
		{
			"name": "8. Two Pair",
			"desc": "Thú (2 cặp đôi khác nhau)",
			"color": "#ff7043",
			"cards": [
				{"r": "J", "s": "Bích", "c": "#263238"},
				{"r": "J", "s": "Cơ", "c": "#e53935"},
				{"r": "5", "s": "Rô", "c": "#e53935"},
				{"r": "5", "s": "Tép", "c": "#263238"},
				{"r": "K", "s": "Bích", "c": "#263238"}
			]
		},
		{
			"name": "9. One Pair",
			"desc": "Một Đôi (2 lá cùng bậc, vd: Đôi A)",
			"color": "#e0e0e0",
			"cards": [
				{"r": "A", "s": "Bích", "c": "#263238"},
				{"r": "A", "s": "Cơ", "c": "#e53935"},
				{"r": "K", "s": "Rô", "c": "#e53935"},
				{"r": "9", "s": "Tép", "c": "#263238"},
				{"r": "2", "s": "Bích", "c": "#263238"}
			]
		},
		{
			"name": "10. High Card",
			"desc": "Mậu Thầu (Lá bài cao nhất trong bộ)",
			"color": "#9e9e9e",
			"cards": [
				{"r": "A", "s": "Bích", "c": "#263238"},
				{"r": "Q", "s": "Cơ", "c": "#e53935"},
				{"r": "9", "s": "Rô", "c": "#e53935"},
				{"r": "6", "s": "Tép", "c": "#263238"},
				{"r": "3", "s": "Bích", "c": "#263238"}
			]
		}
	]
	
	for h in hands_data:
		var item_vbox = VBoxContainer.new()
		item_vbox.add_theme_constant_override("separation", 4)
		list_vbox.add_child(item_vbox)
		
		var item_title = Label.new()
		item_title.text = h.name
		item_title.add_theme_font_size_override("font_size", 14)
		item_title.add_theme_color_override("font_color", Color(h.color))
		item_vbox.add_child(item_title)
		
		var item_desc = Label.new()
		item_desc.text = h.desc
		item_desc.add_theme_font_size_override("font_size", 11)
		item_desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		item_vbox.add_child(item_desc)
		
		# HBox chứa 5 quân bài mini minh họa
		var cards_hbox = HBoxContainer.new()
		cards_hbox.add_theme_constant_override("separation", 4)
		item_vbox.add_child(cards_hbox)
		
		for c_info in h.cards:
			var mini_card = PanelContainer.new()
			mini_card.custom_minimum_size = Vector2(36, 44)
			
			var m_style = StyleBoxFlat.new()
			m_style.bg_color = Color.WHITE
			m_style.set_corner_radius_all(4)
			m_style.set_border_width_all(1)
			m_style.border_color = Color("#b0bec5")
			m_style.content_margin_left = 1
			m_style.content_margin_right = 1
			m_style.content_margin_top = 1
			m_style.content_margin_bottom = 1
			mini_card.add_theme_stylebox_override("panel", m_style)
			cards_hbox.add_child(mini_card)
			
			var card_vbox = VBoxContainer.new()
			card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			card_vbox.add_theme_constant_override("separation", -4)
			mini_card.add_child(card_vbox)
			
			var r_lbl = Label.new()
			r_lbl.text = c_info.r
			r_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			r_lbl.add_theme_font_size_override("font_size", 12)
			r_lbl.add_theme_color_override("font_color", Color(c_info.c))
			card_vbox.add_child(r_lbl)
			
			var s_lbl = Label.new()
			s_lbl.text = c_info.s
			s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			s_lbl.add_theme_font_size_override("font_size", 10)
			s_lbl.add_theme_color_override("font_color", Color(c_info.c))
			card_vbox.add_child(s_lbl)
	
	# Kết nối sự kiện chuột trỏ vào / trỏ ra để tạo hiệu ứng Pop-up tuyệt đẹp!
	guide_trigger.mouse_entered.connect(func():
		is_mouse_over_trigger = true
		_update_guide_popup(guide_popup)
	)
	guide_trigger.mouse_exited.connect(func():
		is_mouse_over_trigger = false
		_update_guide_popup(guide_popup)
	)
	
	guide_popup.mouse_entered.connect(func():
		is_mouse_over_popup = true
		_update_guide_popup(guide_popup)
	)
	guide_popup.mouse_exited.connect(func():
		is_mouse_over_popup = false
		_update_guide_popup(guide_popup)
	)

func _update_guide_popup(guide_popup: PanelContainer):
	if is_mouse_over_trigger or is_mouse_over_popup:
		if _guide_tween and _guide_tween.is_valid():
			_guide_tween.kill()
		
		guide_popup.move_to_front()
		guide_popup.show()
		
		_guide_tween = create_tween().set_parallel(true)
		_guide_tween.tween_property(guide_popup, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
		_guide_tween.tween_property(guide_popup, "position:y", 70.0, 0.25).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	else:
		# Tạo cầu nối trễ 120ms khi người chơi chuyển chuột từ nút sang bảng
		await get_tree().create_timer(0.12).timeout
		if not is_mouse_over_trigger and not is_mouse_over_popup:
			if _guide_tween and _guide_tween.is_valid():
				_guide_tween.kill()
			
			_guide_tween = create_tween().set_parallel(true)
			_guide_tween.tween_property(guide_popup, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
			_guide_tween.tween_property(guide_popup, "position:y", 90.0, 0.2).set_trans(Tween.TRANS_SINE)
			await _guide_tween.finished
			if not is_mouse_over_trigger and not is_mouse_over_popup and guide_popup.modulate.a == 0.0:
				guide_popup.hide()


func _on_host_start_round():
	var host_settings = get_node_or_null("HostSettings")
	var starting_bet = 100
	if host_settings:
		var bet_input = host_settings.find_child("BetInput") as LineEdit
		if bet_input and bet_input.text.is_valid_int():
			starting_bet = clampi(bet_input.text.to_int(), 10, 1000)
		host_settings.hide()
	start_server_game(starting_bet)

func _check_all_ready():
	if not multiplayer.is_server(): return
	var all_ready = true
	for pid in NetworkManager.players:
		if not NetworkManager.ready_peers.has(pid):
			all_ready = false
			break
	if btn_start_round:
		btn_start_round.disabled = (NetworkManager.players.size() < 2)
	if all_ready:
		info_label.text = "MỌI NGƯỜI ĐÃ SẴN SÀNG! BẤM CHIA BÀI ĐỂ BẮT ĐẦU"
	else:
		info_label.text = "ĐANG CHỜ NGƯỜI CHƠI KHÁC TẢI XONG..."

func server_handle_player_disconnect(disconnected_id: int):
	if not multiplayer.is_server(): return
	
	# 1. Xóa khỏi danh sách sẵn sàng (nếu có)
	if NetworkManager.ready_peers.has(disconnected_id):
		NetworkManager.ready_peers.erase(disconnected_id)
		
	# 2. Xóa Panel UI của người đó trên Server
	if player_panels.has(disconnected_id):
		player_panels[disconnected_id].panel.queue_free()
		player_panels.erase(disconnected_id)
		
	# 3. Đồng bộ lệnh xóa panel sang toàn bộ Client
	send_rpc("client_remove_disconnected_player", [disconnected_id])
		
	# 4. Nếu đang ở trạng thái chờ ghép phòng, chỉ cần cập nhật trạng thái sẵn sàng
	if state == GameState.WAITING:
		_check_all_ready()
		return
		
	# 5. Nếu đang chơi giữa trận: Cho người này Fold bài
	if active_players.has(disconnected_id):
		active_players[disconnected_id].has_folded = true
		
	# 6. Nếu đến lượt người chơi này, tự động chuyển lượt sang người kế tiếp
	if turn_order.size() > current_turn_idx and turn_order[current_turn_idx] == disconnected_id:
		_server_next_turn()
	else:
		# Kiểm tra xem ván đấu có kết thúc sớm vì những người khác đã fold không
		_server_check_round_end()

func _server_check_round_end():
	if state == GameState.SHOWDOWN or state == GameState.WAITING: return
	var active_count = 0
	for pid in active_players:
		if not active_players[pid].has_folded: active_count += 1
		
	if active_count <= 1:
		_server_force_showdown()

@rpc("authority", "reliable")
func client_remove_disconnected_player(disconnected_id: int):
	if player_panels.has(disconnected_id):
		player_panels[disconnected_id].panel.queue_free()
		player_panels.erase(disconnected_id)

func _create_player_ui(peer_id: int, p_name: String, pos: Vector2, accent: Color):
	var panel = PanelContainer.new()
	var ps = StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.06, 0.09, 0.8) # Glassmorphic dark blue
	ps.border_width_left = 2; ps.border_width_right = 2; ps.border_width_top = 2; ps.border_width_bottom = 2
	ps.border_color = Color(1, 1, 1, 0.12)
	ps.corner_radius_top_left = 14; ps.corner_radius_top_right = 14; ps.corner_radius_bottom_left = 14; ps.corner_radius_bottom_right = 14
	ps.content_margin_left = 18; ps.content_margin_right = 18; ps.content_margin_top = 10; ps.content_margin_bottom = 10
	ps.shadow_size = 15; ps.shadow_color = Color(0, 0, 0, 0.4)
	panel.add_theme_stylebox_override("panel", ps)
	panel.position = pos
	panel.size = Vector2(200, 80)
	
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var lbl = Label.new()
	lbl.text = p_name
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", accent.lightened(0.5))
	vbox.add_child(lbl)
	
	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)
	add_child(panel)
	
	player_panels[peer_id] = { "panel": panel, "name_label": lbl, "bullet_box": hbox, "card_uis": [] }
	
	var total_m = 1000
	if NetworkManager.players.has(peer_id): total_m = NetworkManager.players[peer_id].money
	_draw_money(hbox, total_m, "$ ")

func _create_btn(text: String, color: Color) -> Button:
	var btn = Button.new(); btn.text = text; btn.custom_minimum_size = Vector2(180, 45)
	var s = StyleBoxFlat.new(); s.bg_color = color
	s.border_width_left = 1; s.border_width_right = 1; s.border_width_top = 1; s.border_width_bottom = 1
	s.border_color = Color(1, 1, 1, 0.15)
	s.corner_radius_top_left = 10; s.corner_radius_top_right = 10; s.corner_radius_bottom_left = 10; s.corner_radius_bottom_right = 10
	s.shadow_size = 8; s.shadow_color = Color(0, 0, 0, 0.3)
	
	var h = s.duplicate()
	h.bg_color = color.lightened(0.12)
	h.border_color = Color(1, 1, 1, 0.3)
	h.shadow_size = 12; h.shadow_color = color
	h.shadow_color.a = 0.2
	
	var p = s.duplicate()
	p.bg_color = color.darkened(0.15)
	
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_font_size_override("font_size", 18)
	return btn

func _draw_money(container: HBoxContainer, amount: int, prefix: String = ""):
	for c in container.get_children(): c.queue_free()
	var lbl = Label.new()
	lbl.text = prefix + str(amount) + " $"
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color("#ffd54f"))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	container.add_child(lbl)

func _spawn_card(card: Card, target: Vector2, face_up: bool) -> CardUI:
	var card_ui = card_scene.instantiate()
	add_child(card_ui)
	card_ui.set_card(card, face_up)
	card_ui.default_pos_y = target.y
	card_ui.position = Vector2(640, -150)
	card_ui.rotation = deg_to_rad(randf_range(-30, 30))
	card_ui.scale = Vector2(0.3, 0.3)
	card_ui.modulate.a = 0.0
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(card_ui, "position", target, 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(card_ui, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(card_ui, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card_ui, "modulate:a", 1.0, 0.25)
	return card_ui

# ============================================================
# SERVER LOGIC
# ============================================================
func start_server_game(starting_bet: int):
	deck = Deck.new()
	deck.shuffle()
	
	current_round_bet = starting_bet
	pot_money = starting_bet * NetworkManager.players.size()
	state = GameState.PRE_FLOP
	turn_order = NetworkManager.players.keys()
	current_turn_idx = 0
	
	active_players.clear()
	for pid in turn_order:
		active_players[pid] = { "has_folded": false, "money_bet": starting_bet }
		# Khấu trừ tiền cược bắt đầu ván
		if NetworkManager.players.has(pid):
			NetworkManager.players[pid].money = max(0, NetworkManager.players[pid].money - starting_bet)
			send_rpc("client_sync_money", [pid, NetworkManager.players[pid].money])
	
	# Deal Hands
	server_player_hands.clear()
	var hand_data = {} # peer_id -> [{suit, rank}, {suit, rank}]
	for pid in turn_order:
		var c1 = deck.draw_card()
		var c2 = deck.draw_card()
		server_player_hands[pid] = [c1, c2]
		hand_data[pid] = [{"suit": c1.suit, "rank": c1.rank}, {"suit": c2.suit, "rank": c2.rank}]
	
	# Deal Community
	community_cards.clear()
	var comm_data = []
	for i in 5:
		var c = deck.draw_card()
		community_cards.append(c)
		comm_data.append({"suit": c.suit, "rank": c.rank})
		
	# Broadcast Start
	send_rpc("client_start_game", [hand_data, comm_data, pot_money, turn_order[current_turn_idx]])

@rpc("any_peer", "reliable", "call_local")
func _send_action(action: String):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: sender_id = 1 # Fallback an toàn nếu gọi trực tiếp trên Server
	if not multiplayer.is_server(): return
	if state == GameState.SHOWDOWN or state == GameState.WAITING: return
	if sender_id != turn_order[current_turn_idx]: return # Not their turn
	
	if action == "FOLD":
		active_players[sender_id].has_folded = true
		
	elif action == "CALL":
		var bet_amount = min(current_round_bet, NetworkManager.players[sender_id].money)
		NetworkManager.players[sender_id].money -= bet_amount
		pot_money += bet_amount
		send_rpc("client_sync_money", [sender_id, NetworkManager.players[sender_id].money])
		
	elif action == "ALL_IN":
		is_all_in_challenge = true
		all_in_challenger_id = sender_id
		all_in_responses.clear()
		
		# Challenger cược toàn bộ tiền và chọn IN
		var bet_amount = NetworkManager.players[sender_id].money
		NetworkManager.players[sender_id].money = 0
		pot_money += bet_amount
		send_rpc("client_sync_money", [sender_id, 0])
		send_rpc("client_sync_pot", [pot_money, sender_id, action])
		
		all_in_responses[sender_id] = "IN"
		
		var challenger_name = NetworkManager.players[sender_id].name if NetworkManager.players.has(sender_id) else "Người chơi"
		send_rpc("client_trigger_all_in_challenge", [sender_id, challenger_name])
		return

	
	# Next turn
	_server_next_turn()

func _server_next_turn():
	current_turn_idx = (current_turn_idx + 1) % turn_order.size()
	
	# Lặp qua đến khi gặp người chưa fold
	var start_idx = current_turn_idx
	while active_players[turn_order[current_turn_idx]].has_folded:
		current_turn_idx = (current_turn_idx + 1) % turn_order.size()
		if current_turn_idx == start_idx: break # Everyone folded?
	
	# Tạm thời đơn giản: Đổi vòng ngay nếu ai cũng đánh 1 lượt
	if current_turn_idx == 0:
		if state == GameState.PRE_FLOP: state = GameState.FLOP
		elif state == GameState.FLOP: state = GameState.TURN
		elif state == GameState.TURN: state = GameState.RIVER
		elif state == GameState.RIVER: _server_force_showdown(); return
		send_rpc("client_advance_phase", [state])
		
	send_rpc("client_sync_turn", [turn_order[current_turn_idx]])

func _server_force_showdown():
	state = GameState.SHOWDOWN
	send_rpc("client_advance_phase", [state])
	send_rpc("client_showdown")
	
	# Phân tích kết quả Poker để tìm người thắng bài mạnh nhất
	var best_score = -1
	var best_pid = -1
	var best_name = ""
	var best_hand_name = ""
	
	for pid in active_players:
		if active_players[pid].has_folded: continue
		
		var combined_cards: Array[Card] = []
		combined_cards.append_array(server_player_hands[pid])
		combined_cards.append_array(community_cards)
		
		var result = HandEvaluator.evaluate(combined_cards)
		var total_score = int(result.rank) * 10000000 + result.score
		
		if total_score > best_score:
			best_score = total_score
			best_pid = pid
			best_name = NetworkManager.players[pid].name if NetworkManager.players.has(pid) else "Người chơi"
			best_hand_name = result.name

	var winner_name = best_name
	var won_amount = pot_money
	var eliminated_name = ""
	
	if best_pid != -1:
		NetworkManager.players[best_pid].money += pot_money
		send_rpc("client_sync_money", [best_pid, NetworkManager.players[best_pid].money])
		
	# Kiểm tra xem có ai hết tiền bị loại không
	for pid in active_players:
		if NetworkManager.players[pid].money <= 0:
			eliminated_name = NetworkManager.players[pid].name
			break
				
	# Lập bảng xếp hạng người chơi
	var ranking_list = []
	for pid in active_players:
		var p_name = NetworkManager.players[pid].name if NetworkManager.players.has(pid) else "Người chơi"
		var is_folded = active_players[pid].has_folded
		var hand_name = "Đã úp bài (Folded)"
		var score = -1
		
		if not is_folded:
			var combined_cards: Array[Card] = []
			combined_cards.append_array(server_player_hands[pid])
			combined_cards.append_array(community_cards)
			
			var result = HandEvaluator.evaluate(combined_cards)
			score = int(result.rank) * 10000000 + result.score
			hand_name = result.name
			
		var card1_suit = -1
		var card1_rank = -1
		var card2_suit = -1
		var card2_rank = -1
		if server_player_hands.has(pid) and server_player_hands[pid].size() >= 2:
			card1_suit = server_player_hands[pid][0].suit
			card1_rank = server_player_hands[pid][0].rank
			card2_suit = server_player_hands[pid][1].suit
			card2_rank = server_player_hands[pid][1].rank

		ranking_list.append({
			"pid": pid,
			"name": p_name,
			"hand": hand_name,
			"score": score,
			"is_folded": is_folded,
			"is_winner": false,
			"card1_suit": card1_suit,
			"card1_rank": card1_rank,
			"card2_suit": card2_suit,
			"card2_rank": card2_rank
		})
		
	ranking_list.sort_custom(func(a, b): return a.score > b.score)
	
	if best_pid != -1:
		for item in ranking_list:
			if item.pid == best_pid:
				item.is_winner = true
				
	send_rpc("client_announce_result", [winner_name, won_amount, ranking_list, eliminated_name])
	
	await get_tree().create_timer(5.0).timeout
	
	if multiplayer.is_server():
		var host_settings = get_node_or_null("HostSettings")
		if host_settings:
			host_settings.show()
		if btn_start_round:
			btn_start_round.show()
		info_label.text = "VÁN ĐẤU KẾT THÚC! CHỦ PHÒNG BẤM CHIA BÀI ĐỂ TIẾP TỤC"

# ============================================================
# CLIENT LOGIC (RPCs)
# ============================================================
@rpc("authority", "reliable", "call_local")
func client_start_game(hand_data: Dictionary, comm_data: Array, pot: int, first_turn_id: int):
	state = GameState.PRE_FLOP
	pot_money = pot
	_draw_money(pot_bullet_container, pot_money, "")
	result_overlay.hide()
	
	# Clear old cards
	for pid in player_panels:
		for cui in player_panels[pid].card_uis: cui.queue_free()
		player_panels[pid].card_uis.clear()
	for cui in community_card_uis: cui.queue_free()
	community_card_uis.clear()
	
	# Deal Community (Căn giữa hoàn hảo bằng mốc 440px)
	for i in comm_data.size():
		var c = Card.new(comm_data[i].suit, comm_data[i].rank)
		var cui = _spawn_card(c, Vector2(440 + i * 100, 285), false)
		community_card_uis.append(cui)
		
	# Deal Player Hands
	var my_id = multiplayer.get_unique_id()
	for pid in hand_data:
		var p_panel = player_panels[pid].panel
		var target_x = p_panel.position.x
		var target_y = p_panel.position.y - 120 if p_panel.position.y > 300 else p_panel.position.y + 100
		
		var is_me = (pid == my_id)
		var c1 = Card.new(hand_data[pid][0].suit, hand_data[pid][0].rank)
		var c2 = Card.new(hand_data[pid][1].suit, hand_data[pid][1].rank)
		
		var cui1 = _spawn_card(c1, Vector2(target_x + 50, target_y), is_me)
		var cui2 = _spawn_card(c2, Vector2(target_x + 140, target_y), is_me)
		player_panels[pid].card_uis.append(cui1)
		player_panels[pid].card_uis.append(cui2)
		
	client_sync_turn(first_turn_id)

@rpc("authority", "reliable", "call_local")
func client_sync_turn(turn_id: int):
	for pid in player_panels:
		var ps = player_panels[pid].panel.get_theme_stylebox("panel") as StyleBoxFlat
		if pid == turn_id:
			# Viền phát sáng neon cực đẹp khi tới lượt!
			ps.border_color = Color("#00e676") # Neon Green
			ps.shadow_size = 20
			ps.shadow_color = Color(0, 0.9, 0.46, 0.35)
		else:
			var is_me = (pid == multiplayer.get_unique_id())
			ps.border_color = Color("#1b5e20") if is_me else Color("#b71c1c")
			ps.border_color = ps.border_color.darkened(0.2)
			ps.border_color.a = 0.4
			ps.shadow_size = 8
			ps.shadow_color = Color(0, 0, 0, 0.4)
			
	if turn_id == multiplayer.get_unique_id():
		info_label.text = "LƯỢT CỦA BẠN!"
		_enable_buttons()
	else:
		info_label.text = "Chờ " + (NetworkManager.players[turn_id].name if NetworkManager.players.has(turn_id) else "đối thủ") + "..."
		_disable_buttons()
		if NetworkManager.is_single_player and multiplayer.is_server():
			_on_bot_turn(turn_id)

@rpc("authority", "reliable", "call_local")
func client_sync_pot(pot: int, actor_id: int, action: String):
	pot_money = pot
	_draw_money(pot_bullet_container, pot_money, "")
	var p_name = NetworkManager.players[actor_id].name
	info_label.text = p_name + " đã " + action + "!"
	
	if action == "FOLD":
		for cui in player_panels[actor_id].card_uis:
			cui.modulate = Color(0.5, 0.5, 0.5, 0.5)

@rpc("authority", "reliable", "call_local")
func client_sync_money(pid: int, total: int):
	NetworkManager.players[pid].money = total
	_draw_money(player_panels[pid].bullet_box, total, "$ ")

@rpc("authority", "reliable", "call_local")
func client_advance_phase(new_state: int):
	state = new_state
	if state == GameState.FLOP:
		for i in 3: community_card_uis[i].flip_up()
	elif state == GameState.TURN:
		community_card_uis[3].flip_up()
	elif state == GameState.RIVER:
		community_card_uis[4].flip_up()
	elif state == GameState.SHOWDOWN:
		_clear_turn_highlights()

@rpc("authority", "reliable", "call_local")
func client_showdown():
	info_label.text = "SHOWDOWN!"
	# Lật bài mọi người
	for pid in player_panels:
		if pid != multiplayer.get_unique_id():
			for cui in player_panels[pid].card_uis:
				cui.flip_up()
				
	# Mở hết bài chung
	for cui in community_card_uis:
		if not cui.is_face_up: cui.flip_up()
	
@rpc("authority", "reliable", "call_local")
func client_announce_result(winner_name: String, won_amount: int, ranking_list: Array, eliminated_name: String):
	info_label.text = "VÁN ĐẤU KẾT THÚC!"
	_show_result_overlay_leaderboard(winner_name, won_amount, ranking_list, eliminated_name)
	
	if eliminated_name != "":
		_play_elimination_effect()

func get_accented_hand_name(unaccented_name: String) -> String:
	match unaccented_name:
		"Thung pha Sanh Hoang Gia (Royal Flush)": return "Thùng Phá Sảnh Hoàng Gia (Royal Flush)"
		"Thung pha Sanh (Straight Flush)": return "Thùng Phá Sảnh (Straight Flush)"
		"Tu Quy (Four of a Kind)": return "Tứ Quý (Four of a Kind)"
		"Cu Lu (Full House)": return "Cù Lũ (Full House)"
		"Thung (Flush)": return "Thùng (Flush)"
		"Sanh (Straight)": return "Sảnh (Straight)"
		"Sam Co (Three of a Kind)": return "Sám Cô (Three of a Kind)"
		"Thu (Two Pair)": return "Thú (Two Pair)"
		"Mot Doi (One Pair)": return "Một Đôi (One Pair)"
		"Mau Thau (High Card)": return "Mậu Thầu (High Card)"
		"Mọi đối thủ đã rút lui": return "Mọi đối thủ đã rút lui 🏃"
		_: return unaccented_name

func _show_result_overlay_leaderboard(winner_name: String, won_amount: int, ranking_list: Array, eliminated_name: String):
	# Điều chỉnh kích thước panel bảng xếp hạng to hơn để chứa đủ 5 cột và tự động căn giữa
	result_overlay.size = Vector2(900, 330)
	result_overlay.position = (Vector2(1280, 720) - result_overlay.size) / 2.0
	
	for child in result_overlay.get_children():
		if child == result_label:
			result_label.hide()
		else:
			child.queue_free()
			
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	result_overlay.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "🏆 BẢNG THỨ HẠNG VÁN ĐẤU 🏆"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("#ffd54f"))
	title.add_theme_constant_override("outline_size", 4)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	vbox.add_child(title)
	
	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 35)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)
	
	var headers = ["Trạng Thái", "Người Chơi", "Bài Trên Tay", "Hạng Bài (Tổ Hợp)", "Kết Quả / Tiền cược"]
	for h in headers:
		var h_lbl = Label.new()
		h_lbl.text = h
		h_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h_lbl.add_theme_font_size_override("font_size", 13)
		h_lbl.add_theme_color_override("font_color", Color("#90caf9"))
		h_lbl.add_theme_constant_override("outline_size", 2)
		h_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		grid.add_child(h_lbl)
		
	var idx = 1
	for item in ranking_list:
		# 1. Trạng Thái (Winner / Looser)
		var status_lbl = Label.new()
		if item.is_winner:
			status_lbl.text = "👑 WINNER"
			status_lbl.add_theme_color_override("font_color", Color("#ffd54f"))
			status_lbl.add_theme_font_size_override("font_size", 14)
		else:
			status_lbl.text = str(idx) + ". LOOSER"
			status_lbl.add_theme_color_override("font_color", Color("#b0bec5"))
			status_lbl.add_theme_font_size_override("font_size", 13)
		status_lbl.add_theme_constant_override("outline_size", 2)
		status_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		grid.add_child(status_lbl)
		
		# 2. Người Chơi
		var name_lbl = Label.new()
		name_lbl.text = item.name
		if item.is_winner:
			name_lbl.add_theme_color_override("font_color", Color("#ffd54f"))
			name_lbl.add_theme_font_size_override("font_size", 14)
		else:
			name_lbl.add_theme_color_override("font_color", Color.WHITE)
			name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_constant_override("outline_size", 2)
		name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		grid.add_child(name_lbl)
		
		# 3. Bài Trên Tay (Hai lá bài mini)
		var card_hbox = HBoxContainer.new()
		card_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card_hbox.add_theme_constant_override("separation", 5)
		grid.add_child(card_hbox)
		
		if item.card1_rank != -1:
			var c1 = Card.new(item.card1_suit, item.card1_rank)
			var c2 = Card.new(item.card2_suit, item.card2_rank)
			
			for c in [c1, c2]:
				var mini_c = card_scene.instantiate() as CardUI
				card_hbox.add_child(mini_c)
				mini_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
				mini_c.set_card(c, true)
				
				mini_c.custom_minimum_size = Vector2(32, 45)
				mini_c.size = Vector2(32, 45)
				
				var sprite = mini_c.get_node_or_null("CardSprite") as TextureRect
				if sprite:
					sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					sprite.size = Vector2(32, 45)
					
				if item.is_folded:
					mini_c.modulate = Color(1, 1, 1, 0.45)
		else:
			var no_card = Label.new()
			no_card.text = "Đã úp"
			no_card.add_theme_font_size_override("font_size", 12)
			no_card.add_theme_color_override("font_color", Color("#ef5350"))
			card_hbox.add_child(no_card)
		
		# 4. Hạng Bài
		var hand_lbl = Label.new()
		hand_lbl.text = get_accented_hand_name(item.hand)
		if item.is_winner:
			hand_lbl.add_theme_color_override("font_color", Color("#ffd54f"))
			hand_lbl.add_theme_font_size_override("font_size", 14)
		elif item.is_folded:
			hand_lbl.add_theme_color_override("font_color", Color("#ef5350"))
			hand_lbl.add_theme_font_size_override("font_size", 13)
		else:
			hand_lbl.add_theme_color_override("font_color", Color("#81c784"))
			hand_lbl.add_theme_font_size_override("font_size", 13)
		hand_lbl.add_theme_constant_override("outline_size", 2)
		hand_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		grid.add_child(hand_lbl)
		
		# 5. Kết Quả
		var money_lbl = Label.new()
		if item.is_winner:
			money_lbl.text = "+" + str(won_amount) + " $"
			money_lbl.add_theme_color_override("font_color", Color("#00e676"))
			money_lbl.add_theme_font_size_override("font_size", 14)
		else:
			money_lbl.text = "Mất cược"
			money_lbl.add_theme_color_override("font_color", Color("#b0bec5"))
			money_lbl.add_theme_font_size_override("font_size", 13)
		money_lbl.add_theme_constant_override("outline_size", 2)
		money_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		grid.add_child(money_lbl)
		
		if not item.is_winner:
			idx += 1
			
	if eliminated_name != "":
		var elim = Label.new()
		elim.text = "💀 " + eliminated_name + " đã bị loại khỏi bàn chơi vì cạn sạch tiền cược!"
		elim.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		elim.add_theme_font_size_override("font_size", 13)
		elim.add_theme_color_override("font_color", Color("#ff1744"))
		elim.add_theme_constant_override("outline_size", 2)
		elim.add_theme_color_override("font_outline_color", Color.BLACK)
		vbox.add_child(elim)
		
	result_overlay.move_to_front()
	result_overlay.modulate.a = 0.0
	result_overlay.scale = Vector2(0.8, 0.8)
	result_overlay.pivot_offset = result_overlay.size / 2.0
	result_overlay.show()
	var tw = create_tween().set_parallel(true)
	tw.tween_property(result_overlay, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(result_overlay, "scale", Vector2(1.0, 1.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _show_result_overlay(msg: String):
	result_overlay.move_to_front()
	result_label.text = msg
	result_overlay.modulate.a = 0.0
	result_overlay.scale = Vector2(0.8, 0.8)
	result_overlay.pivot_offset = result_overlay.size / 2.0
	result_overlay.show()
	var tw = create_tween().set_parallel(true)
	tw.tween_property(result_overlay, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(result_overlay, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _play_elimination_effect():
	# Flash đỏ toàn màn hình (3 lần nhấp nháy mô phỏng phát súng)
	var tw = create_tween()
	tw.tween_property(elim_overlay, "color:a", 0.6, 0.08)
	tw.tween_property(elim_overlay, "color:a", 0.0, 0.15)
	tw.tween_property(elim_overlay, "color:a", 0.4, 0.08)
	tw.tween_property(elim_overlay, "color:a", 0.0, 0.15)
	tw.tween_property(elim_overlay, "color:a", 0.3, 0.08)
	tw.tween_property(elim_overlay, "color:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE)

func _disable_buttons():
	btn_call.disabled = true; btn_fold.disabled = true; btn_all_in.disabled = true

func _enable_buttons():
	btn_call.disabled = false
	btn_fold.disabled = false
	# All-in chỉ được phép dùng từ vòng 2 (FLOP trở đi)
	btn_all_in.disabled = (state == GameState.PRE_FLOP or state == GameState.WAITING)

@rpc("authority", "reliable", "call_local")
func client_trigger_all_in_challenge(challenger_id: int, challenger_name: String):
	var my_id = multiplayer.get_unique_id()
	_disable_buttons()
	
	# Đầu tiên: Kích hoạt các Bot phản hồi nếu chơi đơn offline trên Server
	if NetworkManager.is_single_player and multiplayer.is_server():
		for pid in active_players:
			if pid != 1 and pid != challenger_id and not active_players[pid].has_folded:
				_on_bot_all_in_challenge(pid)
	
	if my_id == challenger_id:
		info_label.text = "BẠN ĐÃ ALL-IN! Đang chờ đối thủ sinh tử..."
		return
		
	var is_folded = false
	if active_players.has(my_id):
		is_folded = active_players[my_id].has_folded
		
	if is_folded:
		info_label.text = challenger_name.to_upper() + " ĐÃ ALL-IN! Đang chờ đối thủ..."
		return
		
	challenge_lbl.text = challenger_name.to_upper() + " đã cược toàn bộ số tiền!\nHãy chọn tiếp tục sinh tử (IN) hoặc úp bài chấp nhận mất cược (OUT)"
	challenge_panel.move_to_front()
	challenge_panel.show()

@rpc("any_peer", "reliable", "call_local")
func server_respond_all_in_challenge(response: String):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: sender_id = 1
	if not multiplayer.is_server(): return
	if not is_all_in_challenge: return
	
	all_in_responses[sender_id] = response
	
	var responder_name = NetworkManager.players[sender_id].name if NetworkManager.players.has(sender_id) else "Người chơi"
	var response_text = "ĐÃ THEO (IN)" if response == "IN" else "ĐÃ RÚT LUI (OUT)"
	send_rpc("client_log_challenge_response", [responder_name, response_text])
	
	# Kiểm tra xem tất cả người chơi hoạt động đã phản hồi chưa
	var all_responded = true
	for pid in active_players:
		if active_players[pid].has_folded: continue
		if not all_in_responses.has(pid):
			all_responded = false
			break
			
	if all_responded:
		_server_process_all_in_results()

@rpc("authority", "reliable", "call_local")
func client_log_challenge_response(r_name: String, r_text: String):
	info_label.text = r_name + " " + r_text + " thử thách ALL-IN!"

@rpc("authority", "reliable", "call_local")
func client_highlight_all_in_choices(choices: Dictionary):
	for pid in choices:
		if not player_panels.has(pid): continue
		var panel_ui = player_panels[pid]
		var ps = panel_ui.panel.get_theme_stylebox("panel") as StyleBoxFlat
		if ps:
			if choices[pid] == "IN":
				ps.border_color = Color("#00e676") # Neon Green
				ps.shadow_size = 20
				ps.shadow_color = Color(0, 0.9, 0.46, 0.35)
			else:
				ps.border_color = Color("#ff1744") # Blood Red
				ps.shadow_size = 20
				ps.shadow_color = Color(1.0, 0.09, 0.27, 0.35)

@rpc("authority", "reliable", "call_local")
func client_start_showdown_countdown():
	info_label.text = "TẤT CẢ ĐÃ CHỌN! LẬT BÀI SAU 3 GIÂY..."
	await get_tree().create_timer(1.0).timeout
	info_label.text = "TẤT CẢ ĐÃ CHỌN! LẬT BÀI SAU 2 GIÂY..."
	await get_tree().create_timer(1.0).timeout
	info_label.text = "TẤT CẢ ĐÃ CHỌN! LẬT BÀI SAU 1 GIÂY..."
	await get_tree().create_timer(1.0).timeout
	info_label.text = "LẬT BÀI SINH TỬ!"

func _server_process_all_in_results():
	is_all_in_challenge = false
	
	# Phát sóng highlight khung tên xanh/đỏ cho tất cả mọi người
	send_rpc("client_highlight_all_in_choices", [all_in_responses])
	
	# Đếm ngược 3s lật bài
	send_rpc("client_start_showdown_countdown", [])
	
	# Chờ 3.0 giây đếm ngược kết thúc
	await get_tree().create_timer(3.0).timeout
	
	# Áp dụng OUT (Fold)
	for pid in all_in_responses:
		if all_in_responses[pid] == "OUT":
			active_players[pid].has_folded = true
			send_rpc("client_sync_pot", [pot_money, pid, "FOLD"])
			
	# Áp dụng IN (All-in)
	for pid in all_in_responses:
		if all_in_responses[pid] == "IN" and pid != all_in_challenger_id:
			var balance = NetworkManager.players[pid].money
			NetworkManager.players[pid].money = 0
			pot_money += balance
			send_rpc("client_sync_money", [pid, 0])
			send_rpc("client_sync_pot", [pot_money, pid, "ALL_IN"])
			
	# Kiểm tra số người chơi còn lại
	var active_count = 0
	var last_active_pid = -1
	for pid in active_players:
		if not active_players[pid].has_folded:
			active_count += 1
			last_active_pid = pid
			
	if active_count <= 1:
		_server_force_instant_winner(last_active_pid)
	else:
		_server_force_showdown()

func _server_force_instant_winner(winner_pid: int):
	state = GameState.SHOWDOWN
	send_rpc("client_advance_phase", [state])
	
	var winner_name = "Challenger"
	var won_amount = pot_money
	var eliminated_name = ""
	
	if winner_pid != -1:
		winner_name = NetworkManager.players[winner_pid].name if NetworkManager.players.has(winner_pid) else "Người chơi"
		NetworkManager.players[winner_pid].money += pot_money
		send_rpc("client_sync_money", [winner_pid, NetworkManager.players[winner_pid].money])
		
	# Lập bảng xếp hạng người chơi
	var ranking_list = []
	for pid in active_players:
		var p_name = NetworkManager.players[pid].name if NetworkManager.players.has(pid) else "Người chơi"
		var is_winner = (pid == winner_pid)
		var is_folded = active_players[pid].has_folded
		var hand_name = "Mọi đối thủ đã rút lui" if is_winner else "Đã úp bài (Folded)"
		var card1_suit = -1
		var card1_rank = -1
		var card2_suit = -1
		var card2_rank = -1
		if server_player_hands.has(pid) and server_player_hands[pid].size() >= 2:
			card1_suit = server_player_hands[pid][0].suit
			card1_rank = server_player_hands[pid][0].rank
			card2_suit = server_player_hands[pid][1].suit
			card2_rank = server_player_hands[pid][1].rank
			
		ranking_list.append({
			"pid": pid,
			"name": p_name,
			"hand": hand_name,
			"score": 1 if is_winner else -1,
			"is_folded": is_folded,
			"is_winner": is_winner,
			"card1_suit": card1_suit,
			"card1_rank": card1_rank,
			"card2_suit": card2_suit,
			"card2_rank": card2_rank
		})
	ranking_list.sort_custom(func(a, b): return a.score > b.score)
	
	for pid in active_players:
		if NetworkManager.players[pid].money <= 0:
			eliminated_name = NetworkManager.players[pid].name
			break
			
	send_rpc("client_announce_result", [winner_name, won_amount, ranking_list, eliminated_name])
	
	await get_tree().create_timer(5.0).timeout
	
	if multiplayer.is_server():
		var host_settings = get_node_or_null("HostSettings")
		if host_settings:
			host_settings.show()
		if btn_start_round:
			btn_start_round.show()
		info_label.text = "VÁN ĐẤU KẾT THÚC! CHỦ PHÒNG BẤM CHIA BÀI ĐỂ TIẾP TỤC"

# ============================================================
# SINGLE-PLAYER / BOT AI LOGIC & RPC WRAPPER
# ============================================================
func send_rpc(method_name: String, args: Array = []):
	if NetworkManager.is_single_player:
		callv(method_name, args)
	else:
		match args.size():
			0: rpc(method_name)
			1: rpc(method_name, args[0])
			2: rpc(method_name, args[0], args[1])
			3: rpc(method_name, args[0], args[1], args[2])
			4: rpc(method_name, args[0], args[1], args[2], args[3])
			5: rpc(method_name, args[0], args[1], args[2], args[3], args[4])

func _on_bot_turn(bot_id: int):
	# Chờ 1.2 - 2.2 giây tạo hiệu ứng suy nghĩ thực tế
	await get_tree().create_timer(randf_range(1.2, 2.2)).timeout
	if state == GameState.SHOWDOWN or state == GameState.WAITING: return
	if turn_order.is_empty() or turn_order[current_turn_idx] != bot_id: return
	
	# Đánh giá bài của Bot hiện tại
	var bot_cards: Array[Card] = []
	if server_player_hands.has(bot_id):
		bot_cards.append_array(server_player_hands[bot_id])
	bot_cards.append_array(community_cards)
	
	var action = "CALL" # Mặc định
	
	if bot_cards.size() >= 5:
		var eval = HandEvaluator.evaluate(bot_cards)
		var rank = int(eval.rank)
		
		# Quyết định hành động dựa trên độ mạnh bài
		if rank >= 3: # Sám Cô, Sảnh, Thùng trở lên -> Rất mạnh!
			# 85% Call, 15% All-in nếu ở vòng 2 trở đi
			if state != GameState.PRE_FLOP and randf() < 0.15:
				action = "ALL_IN"
			else:
				action = "CALL"
		elif rank == 1 or rank == 2: # Đôi, Thú -> Khá
			# 95% Call, 5% Fold
			if randf() < 0.05:
				action = "FOLD"
			else:
				action = "CALL"
		else: # Mậu Thầu -> Bài yếu
			# Ở Pre-flop: 90% Call, 10% Fold
			# Ở Flop/Turn: 60% Call, 40% Fold
			# Ở River: 40% Call, 60% Fold
			var fold_chance = 0.1
			if state == GameState.FLOP: fold_chance = 0.35
			elif state == GameState.TURN: fold_chance = 0.5
			elif state == GameState.RIVER: fold_chance = 0.65
			
			if randf() < fold_chance:
				action = "FOLD"
			else:
				action = "CALL"
	else:
		# Vòng 1 (Pre-flop) chưa đủ 5 lá
		# Dựa vào bài tẩy (2 lá)
		var c1 = server_player_hands[bot_id][0]
		var c2 = server_player_hands[bot_id][1]
		if c1.rank == c2.rank: # Có đôi sẵn trên tay -> Mạnh!
			action = "CALL"
		elif int(c1.rank) >= 10 or int(c2.rank) >= 10: # Có lá to
			action = "CALL"
		else:
			# Bài tẩy xấu
			if randf() < 0.15:
				action = "FOLD"
			else:
				action = "CALL"
				
	# Thực hiện hành động bot
	_process_bot_action(bot_id, action)

func _process_bot_action(bot_id: int, action: String):
	if state == GameState.SHOWDOWN or state == GameState.WAITING: return
	if turn_order[current_turn_idx] != bot_id: return
	
	if action == "FOLD":
		active_players[bot_id].has_folded = true
		send_rpc("client_sync_pot", [pot_money, bot_id, "FOLD"])
	elif action == "CALL":
		var bet_amount = min(current_round_bet, NetworkManager.players[bot_id].money)
		NetworkManager.players[bot_id].money -= bet_amount
		pot_money += bet_amount
		send_rpc("client_sync_money", [bot_id, NetworkManager.players[bot_id].money])
		send_rpc("client_sync_pot", [pot_money, bot_id, "CALL"])
	elif action == "ALL_IN":
		is_all_in_challenge = true
		all_in_challenger_id = bot_id
		all_in_responses.clear()
		
		# Bot cược toàn bộ tiền và chọn IN
		var bet_amount = NetworkManager.players[bot_id].money
		NetworkManager.players[bot_id].money = 0
		pot_money += bet_amount
		send_rpc("client_sync_money", [bot_id, 0])
		send_rpc("client_sync_pot", [pot_money, bot_id, "ALL_IN"])
		
		all_in_responses[bot_id] = "IN"
		
		var bot_name = NetworkManager.players[bot_id].name
		send_rpc("client_trigger_all_in_challenge", [bot_id, bot_name])
		return
		
	# Tiếp tục lượt
	_server_next_turn()

func _on_bot_all_in_challenge(bot_id: int):
	# Chờ 1.0 - 2.0 giây suy nghĩ
	await get_tree().create_timer(randf_range(1.0, 2.0)).timeout
	if not is_all_in_challenge: return
	
	# Đánh giá bài xem có dám cược mạng không
	var bot_cards: Array[Card] = []
	if server_player_hands.has(bot_id):
		bot_cards.append_array(server_player_hands[bot_id])
	bot_cards.append_array(community_cards)
	
	var response = "OUT" # Mặc định rút lui
	
	if bot_cards.size() >= 5:
		var eval = HandEvaluator.evaluate(bot_cards)
		var rank = int(eval.rank)
		# Nếu có Đôi hoặc Thú trở lên thì 70% chọn IN, nếu Sám cô trở lên thì 95% chọn IN!
		if rank >= 3:
			response = "IN" if randf() < 0.95 else "OUT"
		elif rank == 1 or rank == 2:
			response = "IN" if randf() < 0.65 else "OUT"
		else:
			# Mậu thầu thì chỉ 15% chọn IN để bluff/liều lĩnh
			response = "IN" if randf() < 0.15 else "OUT"
	else:
		# Vòng 1 (Pre-flop - thực ra All-In đã bị khóa ở vòng 1 nên trường hợp này hiếm xảy ra)
		response = "IN" if randf() < 0.3 else "OUT"
		
	# Ghi nhận phản hồi bot
	all_in_responses[bot_id] = response
	var bot_name = NetworkManager.players[bot_id].name
	var resp_text = "ĐÃ THEO (IN)" if response == "IN" else "ĐÃ RÚT LUI (OUT)"
	send_rpc("client_log_challenge_response", [bot_name, resp_text])
	
	# Kiểm tra xem toàn bộ bot đã phản hồi chưa
	var all_responded = true
	for pid in active_players:
		if active_players[pid].has_folded: continue
		if not all_in_responses.has(pid):
			all_responded = false
			break
			
	if all_responded:
		_server_process_all_in_results()

func send_action_to_server(action: String):
	if NetworkManager.is_single_player:
		_send_action(action)
	else:
		_send_action.rpc_id(1, action)

func send_challenge_response_to_server(response: String):
	if NetworkManager.is_single_player:
		server_respond_all_in_challenge(response)
	else:
		server_respond_all_in_challenge.rpc_id(1, response)

func _clear_turn_highlights():
	for pid in player_panels:
		var ps = player_panels[pid].panel.get_theme_stylebox("panel") as StyleBoxFlat
		if ps:
			var is_me = (pid == multiplayer.get_unique_id())
			ps.border_color = Color("#1b5e20") if is_me else Color("#b71c1c")
			ps.border_color = ps.border_color.darkened(0.2)
			ps.border_color.a = 0.4
			ps.shadow_size = 8
			ps.shadow_color = Color(0, 0, 0, 0.4)
