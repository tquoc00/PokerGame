class_name Card
extends RefCounted

enum Suit { HEARTS, DIAMONDS, CLUBS, SPADES }
enum Rank { TWO = 2, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, NINE, TEN, JACK, QUEEN, KING, ACE }

var suit: Suit
var rank: Rank

func _init(p_suit: Suit, p_rank: Rank):
	suit = p_suit
	rank = p_rank

# Lấy tên lá bài (vd: "Ace of Spades")
func get_name() -> String:
	var suit_names = {
		Suit.HEARTS: "Hearts",
		Suit.DIAMONDS: "Diamonds",
		Suit.CLUBS: "Clubs",
		Suit.SPADES: "Spades"
	}
	
	var rank_names = {
		Rank.JACK: "Jack",
		Rank.QUEEN: "Queen",
		Rank.KING: "King",
		Rank.ACE: "Ace"
	}
	
	var rank_str = str(rank)
	if rank_names.has(rank):
		rank_str = rank_names[rank]
		
	return rank_str + " of " + suit_names[suit]

# Hàm này giúp print(card) ra chuỗi dễ đọc thay vì Object ID
func _to_string() -> String:
	return get_name()
