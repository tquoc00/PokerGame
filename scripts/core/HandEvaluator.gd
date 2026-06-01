class_name HandEvaluator
extends RefCounted

enum HandRank {
	HIGH_CARD,
	PAIR,
	TWO_PAIR,
	THREE_OF_A_KIND,
	STRAIGHT,
	FLUSH,
	FULL_HOUSE,
	FOUR_OF_A_KIND,
	STRAIGHT_FLUSH,
	ROYAL_FLUSH
}

class EvaluationResult:
	var rank: HandRank
	var score: int
	var name: String
	
	func _init(p_rank: HandRank, p_score: int, p_name: String):
		self.rank = p_rank
		self.score = p_score
		self.name = p_name

# Đánh giá tập hợp bài (kết hợp 2 lá trên tay + 5 lá chung = 7 lá)
static func evaluate(cards: Array[Card]) -> EvaluationResult:
	if cards.size() < 5:
		return EvaluationResult.new(HandRank.HIGH_CARD, 0, "Chưa đủ bài")
		
	# 1. Sắp xếp bài theo giá trị giảm dần
	var sorted_cards = cards.duplicate()
	sorted_cards.sort_custom(func(a, b): return a.rank > b.rank)
	
	# 2. Đếm số lượng các chất (suit) và bậc (rank)
	var rank_counts = {}
	var suit_counts = {}
	
	for card in sorted_cards:
		rank_counts[card.rank] = rank_counts.get(card.rank, 0) + 1
		suit_counts[card.suit] = suit_counts.get(card.suit, 0) + 1
		
	# 3. Phân tích kết quả đếm
	var is_flush = false
	var flush_suit = -1
	for suit in suit_counts:
		if suit_counts[suit] >= 5:
			is_flush = true
			flush_suit = suit
			break
			
	var pairs = []
	var threes = []
	var fours = []
	
	for rank in rank_counts:
		var count = rank_counts[rank]
		if count == 4: fours.append(rank)
		elif count == 3: threes.append(rank)
		elif count == 2: pairs.append(rank)
		
	# Sắp xếp để lấy rank cao nhất lên đầu
	pairs.sort_custom(func(a, b): return a > b)
	threes.sort_custom(func(a, b): return a > b)
	
	# 4. Kiểm tra Sảnh (Straight)
	var unique_ranks = rank_counts.keys()
	unique_ranks.sort_custom(func(a, b): return a > b)
	var straight_high = check_straight(unique_ranks)
	
	# 5. Xác định thứ hạng (từ cao xuống thấp)
	# Tạm bỏ qua Straight Flush/Royal Flush ở bản demo này để tránh code quá dài.
	
	# Tứ Quý (Four of a Kind)
	if fours.size() > 0:
		return EvaluationResult.new(HandRank.FOUR_OF_A_KIND, fours[0] * 1000, "Tứ Quý (Four of a Kind)")
		
	# Cù Lũ (Full House)
	if (threes.size() > 0 and pairs.size() > 0) or threes.size() > 1:
		return EvaluationResult.new(HandRank.FULL_HOUSE, threes[0] * 1000, "Cù Lũ (Full House)")
		
	# Thùng (Flush)
	if is_flush:
		return EvaluationResult.new(HandRank.FLUSH, 8000, "Thùng (Flush)")
		
	# Sảnh (Straight)
	if straight_high > 0:
		return EvaluationResult.new(HandRank.STRAIGHT, straight_high * 100, "Sảnh (Straight)")
		
	# Sám Cô (Three of a Kind)
	if threes.size() > 0:
		return EvaluationResult.new(HandRank.THREE_OF_A_KIND, threes[0] * 100, "Sám Cô (Three of a Kind)")
		
	# Thú (Two Pair)
	if pairs.size() >= 2:
		var score = pairs[0] * 100 + pairs[1]
		return EvaluationResult.new(HandRank.TWO_PAIR, score, "Thú (Two Pair)")
		
	# Đôi (One Pair)
	if pairs.size() == 1:
		return EvaluationResult.new(HandRank.PAIR, pairs[0] * 10, "Một Đôi (One Pair)")
		
	# Mậu Thầu (High Card)
	return EvaluationResult.new(HandRank.HIGH_CARD, sorted_cards[0].rank, "Mậu Thầu (High Card)")

static func check_straight(unique_ranks: Array) -> int:
	if unique_ranks.size() < 5: return 0
	var consecutive = 1
	var high_rank = unique_ranks[0]
	
	for i in range(1, unique_ranks.size()):
		if unique_ranks[i-1] - unique_ranks[i] == 1:
			consecutive += 1
			if consecutive == 5:
				return high_rank
		else:
			consecutive = 1
			high_rank = unique_ranks[i]
			
	# Trường hợp đặc biệt: Sảnh A, 2, 3, 4, 5 (Godot rank: ACE = 14)
	if consecutive == 4 and unique_ranks[0] == Card.Rank.ACE and unique_ranks.back() == Card.Rank.TWO:
		return Card.Rank.FIVE
		
	return 0
