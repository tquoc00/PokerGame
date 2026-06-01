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

# Đánh giá tập hợp bài (kết hợp 2 lá trên tay + 5 lá chung = 7 lá) để tìm tổ hợp 5 lá tốt nhất
static func evaluate(cards: Array[Card]) -> EvaluationResult:
	if cards.size() < 5:
		return EvaluationResult.new(HandRank.HIGH_CARD, 0, "Chưa đủ bài")
		
	# Lấy tất cả các hoán vị 5 lá từ 7 lá để tìm 5 lá mạnh nhất theo đúng luật Poker Texas Hold'em
	var best_result: EvaluationResult = null
	
	var n = cards.size()
	# Tạo ra tất cả các bộ 5 lá bài
	for i in range(0, n - 4):
		for j in range(i + 1, n - 3):
			for k in range(j + 1, n - 2):
				for l in range(k + 1, n - 1):
					for m in range(l + 1, n):
						var combo: Array[Card] = [cards[i], cards[j], cards[k], cards[l], cards[m]]
						var res = _evaluate_5_cards(combo)
						if best_result == null or res.rank > best_result.rank or (res.rank == best_result.rank and res.score > best_result.score):
							best_result = res
							
	return best_result

# Đánh giá chính xác bộ 5 lá
static func _evaluate_5_cards(hand: Array[Card]) -> EvaluationResult:
	# 1. Sắp xếp 5 lá theo bậc từ cao xuống thấp
	var sorted = hand.duplicate()
	sorted.sort_custom(func(a, b): return a.rank > b.rank)
	
	var is_flush = true
	var target_suit = sorted[0].suit
	for card in sorted:
		if card.suit != target_suit:
			is_flush = false
			break
			
	# Kiểm tra sảnh
	var is_straight = false
	var straight_high_rank = sorted[0].rank
	
	if sorted[0].rank - sorted[4].rank == 4:
		# Sảnh bình thường (liên tiếp 5 bậc)
		is_straight = true
		for idx in range(1, 5):
			if sorted[idx-1].rank - sorted[idx].rank != 1:
				is_straight = false
				break
	elif sorted[0].rank == Card.Rank.ACE and sorted[1].rank == Card.Rank.FIVE and sorted[2].rank == Card.Rank.FOUR and sorted[3].rank == Card.Rank.THREE and sorted[4].rank == Card.Rank.TWO:
		# Sảnh đặc biệt A-2-3-4-5 (Ace-low straight, Ace đóng vai trò lá số 1)
		is_straight = true
		straight_high_rank = Card.Rank.FIVE
		
	# Đếm số lượng bậc giống nhau
	var rank_counts = {}
	for card in sorted:
		rank_counts[card.rank] = rank_counts.get(card.rank, 0) + 1
		
	var fours = []
	var threes = []
	var pairs = []
	
	for r in rank_counts:
		var c = rank_counts[r]
		if c == 4: fours.append(r)
		elif c == 3: threes.append(r)
		elif c == 2: pairs.append(r)
		
	fours.sort_custom(func(a,b): return a > b)
	threes.sort_custom(func(a,b): return a > b)
	pairs.sort_custom(func(a,b): return a > b)
	
	# 2. XÁC ĐỊNH BẬC TỔ HỢP & TÍNH SCORE ĐỂ SO SÁNH TIE-BREAKER (KICKERS)
	
	# Thùng phá Sảnh / Thùng phá Sảnh Hoàng Gia
	if is_flush and is_straight:
		if straight_high_rank == Card.Rank.ACE:
			return EvaluationResult.new(HandRank.ROYAL_FLUSH, 0, "Thung pha Sanh Hoang Gia (Royal Flush)")
		else:
			return EvaluationResult.new(HandRank.STRAIGHT_FLUSH, int(straight_high_rank), "Thung pha Sanh (Straight Flush)")
			
	# Tứ Quý (Four of a Kind)
	if fours.size() > 0:
		var kicker = _get_kickers(sorted, fours)
		var score = (fours[0] << 4) + kicker[0]
		return EvaluationResult.new(HandRank.FOUR_OF_A_KIND, score, "Tu Quy (Four of a Kind)")
		
	# Cù Lũ (Full House)
	if threes.size() > 0 and pairs.size() > 0:
		var score = (threes[0] << 4) + pairs[0]
		return EvaluationResult.new(HandRank.FULL_HOUSE, score, "Cu Lu (Full House)")
		
	# Thùng (Flush)
	if is_flush:
		# Điểm thùng dựa vào bậc của cả 5 lá theo thứ tự giảm dần
		var score = (sorted[0].rank << 16) + (sorted[1].rank << 12) + (sorted[2].rank << 8) + (sorted[3].rank << 4) + sorted[4].rank
		return EvaluationResult.new(HandRank.FLUSH, score, "Thung (Flush)")
		
	# Sảnh (Straight)
	if is_straight:
		return EvaluationResult.new(HandRank.STRAIGHT, int(straight_high_rank), "Sanh (Straight)")
		
	# Sám Cô (Three of a Kind)
	if threes.size() > 0:
		var kickers = _get_kickers(sorted, threes)
		var score = (threes[0] << 8) + (kickers[0] << 4) + kickers[1]
		return EvaluationResult.new(HandRank.THREE_OF_A_KIND, score, "Sam Co (Three of a Kind)")
		
	# Thú (Two Pair)
	if pairs.size() >= 2:
		var kickers = _get_kickers(sorted, [pairs[0], pairs[1]])
		var score = (pairs[0] << 8) + (pairs[1] << 4) + kickers[0]
		return EvaluationResult.new(HandRank.TWO_PAIR, score, "Thu (Two Pair)")
		
	# Đôi (One Pair)
	if pairs.size() == 1:
		var kickers = _get_kickers(sorted, [pairs[0]])
		var score = (pairs[0] << 12) + (kickers[0] << 8) + (kickers[1] << 4) + kickers[2]
		return EvaluationResult.new(HandRank.PAIR, score, "Mot Doi (One Pair)")
		
	# Mậu Thầu (High Card)
	var score = (sorted[0].rank << 16) + (sorted[1].rank << 12) + (sorted[2].rank << 8) + (sorted[3].rank << 4) + sorted[4].rank
	return EvaluationResult.new(HandRank.HIGH_CARD, score, "Mau Thau (High Card)")

# Lấy danh sách các lá bài rác (kickers) không tham gia vào tổ hợp chính để làm tie-breaker
static func _get_kickers(sorted_hand: Array[Card], exclude_ranks: Array) -> Array[int]:
	var kickers: Array[int] = []
	for card in sorted_hand:
		if not exclude_ranks.has(card.rank):
			kickers.append(int(card.rank))
	return kickers
