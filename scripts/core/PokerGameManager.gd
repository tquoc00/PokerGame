class_name PokerGameManager
extends Node

# ============================================================
# MULTIPLAYER LIAR'S POKER - 4 PLAYERS
# ============================================================

enum GameState { WAITING, PRE_FLOP, FLOP, TURN, RIVER, SHOWDOWN }

var deck: Deck
var state: GameState = GameState.WAITING
var community_cards: Array[Card] = []

var pot_bullets: int = 1
const MAX_BULLETS: int = 6

var my_hand: Array[Card] = []
var turn_order: Array = [] # Array of peer_ids
var current_turn_idx: int = 0
var active_players: Dictionary = {} # peer_id -> { has_folded: bool, bullets_bet: int }
var server_player_hands: Dictionary = {} # peer_id -> Array[Card]

# --- UI references ---
var info_label: Label
var pot_title: Label
var pot_bullet_container: HBoxContainer
var btn_fold: Button
var btn_call: Button
var btn_all_in: Button
var btn_start_round: Button
var player_panels: Dictionary = {} # peer_id -> { panel, name_label, bullet_box, card_uis: Array[CardUI] }
var community_card_uis: Array[CardUI] = []
var card_scene: PackedScene = preload("res://scenes/prefabs/CardUI.tscn")

func _ready():
	_build_ui()
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
	info_label.add_theme_font_size_override("font_size", 26)
	info_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	info_label.add_theme_constant_override("outline_size", 3)
	info_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	info_label.text = "ĐANG CHỜ MÁY CHỦ..."
	add_child(info_label)
	
	# POT
	var pot_area = VBoxContainer.new()
	pot_area.position = Vector2(500, 215)
	pot_area.size = Vector2(280, 80)
	pot_area.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(pot_area)
	
	pot_title = Label.new()
	pot_title.text = "ÁN TỬ"
	pot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pot_title.add_theme_font_size_override("font_size", 16)
	pot_title.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35, 0.9))
	pot_area.add_child(pot_title)
	
	pot_bullet_container = HBoxContainer.new()
	pot_bullet_container.alignment = BoxContainer.ALIGNMENT_CENTER
	pot_bullet_container.add_theme_constant_override("separation", 6)
	pot_area.add_child(pot_bullet_container)
	_draw_bullets(pot_bullet_container, 0, Color("#ef5350"))
	
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
	btn_container.position = Vector2(1070, 530)
	btn_container.size = Vector2(190, 180)
	btn_container.add_theme_constant_override("separation", 10)
	add_child(btn_container)
	
	btn_all_in = _create_btn("⚡ ALL IN", Color("#e65100")); btn_all_in.pressed.connect(func(): _send_action.rpc_id(1, "ALL_IN"))
	btn_call = _create_btn("✦ CALL", Color("#2e7d32")); btn_call.pressed.connect(func(): _send_action.rpc_id(1, "CALL"))
	btn_fold = _create_btn("✕ FOLD", Color("#c62828")); btn_fold.pressed.connect(func(): _send_action.rpc_id(1, "FOLD"))
	btn_container.add_child(btn_all_in); btn_container.add_child(btn_call); btn_container.add_child(btn_fold)
	_disable_buttons()
	
	if multiplayer.is_server():
		btn_start_round = _create_btn("▶ CHIA BÀI", Color("#1565c0"))
		btn_start_round.position = Vector2(540, 360)
		btn_start_round.size = Vector2(200, 60)
		btn_start_round.pressed.connect(_on_host_start_round)
		btn_start_round.disabled = true # Mặc định khóa lại
		add_child(btn_start_round)
		info_label.text = "ĐANG CHỜ NGƯỜI CHƠI KHÁC TẢI XONG..."
		_check_all_ready()
		
	# Nút Thoát Game (Có mặt ở mọi lúc để quay lại Menu chính)
	var btn_exit = _create_btn("✕ THOÁT", Color("#c62828"))
	btn_exit.position = Vector2(20, 20)
	btn_exit.size = Vector2(120, 45)
	btn_exit.pressed.connect(func(): NetworkManager.leave_game())
	add_child(btn_exit)

func _on_host_start_round():
	btn_start_round.hide()
	start_server_game()

func _check_all_ready():
	if not multiplayer.is_server(): return
	var all_ready = true
	for pid in NetworkManager.players:
		if not NetworkManager.ready_peers.has(pid):
			all_ready = false
			break
	if all_ready and btn_start_round:
		btn_start_round.disabled = false
		info_label.text = "MỌI NGƯỜI ĐÃ SẴN SÀNG! BẤM CHIA BÀI ĐỂ BẮT ĐẦU"

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
	rpc("client_remove_disconnected_player", disconnected_id)
		
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
	
	var total_b = 0
	if NetworkManager.players.has(peer_id): total_b = NetworkManager.players[peer_id].total_bullets
	_draw_bullets(hbox, total_b, Color("#ffb300")) # Glow màu vàng đạn neon cực ngầu

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

func _draw_bullets(container: HBoxContainer, count: int, color: Color):
	for c in container.get_children(): c.queue_free()
	for i in MAX_BULLETS:
		var bullet = Panel.new(); bullet.custom_minimum_size = Vector2(14, 35)
		var s = StyleBoxFlat.new(); s.corner_radius_top_left = 8; s.corner_radius_top_right = 8; s.corner_radius_bottom_left = 2; s.corner_radius_bottom_right = 2
		if i < count:
			s.bg_color = color
			s.shadow_size = 6
			s.shadow_color = color
			s.shadow_color.a = 0.35 # Hiệu ứng phát sáng dạ quang neon
		else:
			s.bg_color = Color(1, 1, 1, 0.08)
			s.shadow_size = 0
		bullet.add_theme_stylebox_override("panel", s)
		container.add_child(bullet)

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
func start_server_game():
	deck = Deck.new()
	deck.shuffle()
	
	pot_bullets = 1
	state = GameState.PRE_FLOP
	turn_order = NetworkManager.players.keys()
	current_turn_idx = 0
	
	active_players.clear()
	for pid in turn_order:
		active_players[pid] = { "has_folded": false, "bullets_bet": 0 }
	
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
	rpc("client_start_game", hand_data, comm_data, pot_bullets, turn_order[current_turn_idx])

@rpc("any_peer", "reliable", "call_local")
func _send_action(action: String):
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == 0: sender_id = 1 # Fallback an toàn nếu gọi trực tiếp trên Server
	if not multiplayer.is_server(): return
	if state == GameState.SHOWDOWN or state == GameState.WAITING: return
	if sender_id != turn_order[current_turn_idx]: return # Not their turn
	
	if action == "FOLD":
		active_players[sender_id].has_folded = true
		NetworkManager.players[sender_id].total_bullets = min(NetworkManager.players[sender_id].total_bullets + pot_bullets, MAX_BULLETS)
		rpc("client_sync_bullets", sender_id, NetworkManager.players[sender_id].total_bullets)
		
	elif action == "CALL":
		if pot_bullets < MAX_BULLETS: pot_bullets += 1
		
	elif action == "ALL_IN":
		pot_bullets = MAX_BULLETS
	
	rpc("client_sync_pot", pot_bullets, sender_id, action)
	
	# Check if all folded except one
	var active_count = 0
	for pid in active_players:
		if not active_players[pid].has_folded: active_count += 1
		
	if active_count <= 1 or action == "ALL_IN":
		_server_force_showdown()
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
	
	# Tạm thời đơn giản: Đổi vòng ngay nếu ai cũng đánh 1 lượt (cần logic Poker chuẩn hơn, nhưng tạm thời vòng quanh)
	if current_turn_idx == 0:
		if state == GameState.PRE_FLOP: state = GameState.FLOP
		elif state == GameState.FLOP: state = GameState.TURN
		elif state == GameState.TURN: state = GameState.RIVER
		elif state == GameState.RIVER: _server_force_showdown(); return
		rpc("client_advance_phase", state)
		
	rpc("client_sync_turn", turn_order[current_turn_idx])

func _server_force_showdown():
	state = GameState.SHOWDOWN
	rpc("client_advance_phase", state)
	rpc("client_showdown")
	
	# Phân tích kết quả Poker để tìm người thắng bài mạnh nhất và thua bài yếu nhất
	var best_score = -1
	var best_pid = -1
	var best_name = ""
	var best_hand_name = ""
	
	var worst_score = 9999999
	var worst_pid = -1
	var worst_name = ""
	
	for pid in active_players:
		if active_players[pid].has_folded: continue
		
		var combined_cards: Array[Card] = []
		combined_cards.append_array(server_player_hands[pid])
		combined_cards.append_array(community_cards)
		
		var result = HandEvaluator.evaluate(combined_cards)
		var total_score = int(result.rank) * 10000 + result.score
		
		if total_score > best_score:
			best_score = total_score
			best_pid = pid
			best_name = NetworkManager.players[pid].name if NetworkManager.players.has(pid) else "Người chơi"
			best_hand_name = result.name
			
		if total_score < worst_score:
			worst_score = total_score
			worst_pid = pid
			worst_name = NetworkManager.players[pid].name if NetworkManager.players.has(pid) else "Người chơi"

	var winner_name = best_name
	var winner_hand = best_hand_name
	var loser_name = ""
	var added_b = pot_bullets
	var eliminated_name = ""
	
	if worst_pid != -1:
		loser_name = worst_name
		var old_bullets = NetworkManager.players[worst_pid].total_bullets
		var new_bullets = min(old_bullets + pot_bullets, MAX_BULLETS)
		NetworkManager.players[worst_pid].total_bullets = new_bullets
		rpc("client_sync_bullets", worst_pid, new_bullets)
		
		if new_bullets >= MAX_BULLETS:
			eliminated_name = worst_name
			
	# Kiểm tra xem có ai fold mà bị full đạn (loại) không
	for pid in active_players:
		if active_players[pid].has_folded:
			if NetworkManager.players[pid].total_bullets >= MAX_BULLETS:
				eliminated_name = NetworkManager.players[pid].name
				
	rpc("client_announce_result", winner_name, winner_hand, loser_name, added_b, eliminated_name)
	
	await get_tree().create_timer(5.0).timeout
	
	if multiplayer.is_server():
		btn_start_round.show()
		info_label.text = "VÁN ĐẤU KẾT THÚC! CHỦ PHÒNG BẤM CHIA BÀI ĐỂ TIẾP TỤC"

# ============================================================
# CLIENT LOGIC (RPCs)
# ============================================================
@rpc("authority", "reliable", "call_local")
func client_start_game(hand_data: Dictionary, comm_data: Array, pot: int, first_turn_id: int):
	pot_bullets = pot
	_draw_bullets(pot_bullet_container, pot_bullets, Color("#ef5350"))
	
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
		info_label.text = "Chờ người khác..."
		_disable_buttons()

@rpc("authority", "reliable", "call_local")
func client_sync_pot(pot: int, actor_id: int, action: String):
	pot_bullets = pot
	_draw_bullets(pot_bullet_container, pot_bullets, Color("#ef5350"))
	var p_name = NetworkManager.players[actor_id].name
	info_label.text = p_name + " đã " + action + "!"
	
	if action == "FOLD":
		for cui in player_panels[actor_id].card_uis:
			cui.modulate = Color(0.5, 0.5, 0.5, 0.5)

@rpc("authority", "reliable", "call_local")
func client_sync_bullets(pid: int, total: int):
	NetworkManager.players[pid].total_bullets = total
	_draw_bullets(player_panels[pid].bullet_box, total, Color("#ffc107"))

@rpc("authority", "reliable", "call_local")
func client_advance_phase(new_state: int):
	state = new_state
	if state == GameState.FLOP:
		for i in 3: community_card_uis[i].flip_up()
	elif state == GameState.TURN:
		community_card_uis[3].flip_up()
	elif state == GameState.RIVER:
		community_card_uis[4].flip_up()

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
func client_announce_result(w_name: String, w_hand: String, l_name: String, added_b: int, elim_name: String):
	var msg = ""
	if w_name != "":
		msg += w_name + " THẮNG với " + w_hand + "! "
	if l_name != "":
		msg += "\n" + l_name + " THUA phải nạp thêm " + str(added_b) + " viên!"
	if elim_name != "":
		msg += "\n💀 " + elim_name + " ĐÃ BỊ BẮN BỞI ROULETTE (LOẠI)!"
	info_label.text = msg

func _disable_buttons():
	btn_call.disabled = true; btn_fold.disabled = true; btn_all_in.disabled = true

func _enable_buttons():
	btn_call.disabled = false; btn_fold.disabled = false; btn_all_in.disabled = false
