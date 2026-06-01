class_name CardUI
extends Control

@onready var card_sprite: TextureRect = $CardSprite

var card_data: Card
var default_pos_y: float = 0.0
var is_face_up: bool = true

func _ready():
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_leave)
	pivot_offset = size / 2.0

func _on_hover():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", default_pos_y - 20, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	z_index = 10

func _on_leave():
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", default_pos_y, 0.15).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE)
	z_index = 0

# Map Card data to Kenney filename
func _get_card_filename(card: Card) -> String:
	var suit_str = ""
	match card.suit:
		Card.Suit.HEARTS: suit_str = "hearts"
		Card.Suit.DIAMONDS: suit_str = "diamonds"
		Card.Suit.CLUBS: suit_str = "clubs"
		Card.Suit.SPADES: suit_str = "spades"
	
	var rank_str = ""
	match card.rank:
		Card.Rank.ACE: rank_str = "A"
		Card.Rank.JACK: rank_str = "J"
		Card.Rank.QUEEN: rank_str = "Q"
		Card.Rank.KING: rank_str = "K"
		_: rank_str = "%02d" % card.rank
	
	return "res://assets/cards/card_" + suit_str + "_" + rank_str + ".png"

func set_card(card: Card, face_up: bool = true):
	card_data = card
	is_face_up = face_up
	
	if not face_up:
		card_sprite.texture = load("res://assets/cards/card_back.png")
		return
	
	# Load the real Kenney card image
	var path = _get_card_filename(card)
	card_sprite.texture = load(path)

func flip_up():
	if not is_face_up and card_data != null:
		is_face_up = true
		var tween = create_tween()
		tween.tween_property(self, "scale:x", 0.0, 0.12).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(func():
			var path = _get_card_filename(card_data)
			card_sprite.texture = load(path)
		)
		tween.tween_property(self, "scale:x", 1.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
