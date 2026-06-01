class_name Deck
extends RefCounted

var cards: Array[Card] = []

func _init():
	build_deck()

# Tạo bộ bài 52 lá
func build_deck():
	cards.clear()
	for s in Card.Suit.values():
		for r in Card.Rank.values():
			cards.append(Card.new(s, r))

# Xáo trộn bài
func shuffle():
	randomize() # Đảm bảo random khác nhau mỗi lần chạy
	cards.shuffle()

# Rút 1 lá bài từ trên cùng
func draw_card() -> Card:
	if cards.is_empty():
		return null
	return cards.pop_back()
