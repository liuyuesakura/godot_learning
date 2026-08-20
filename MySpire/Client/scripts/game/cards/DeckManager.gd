## DeckManager.gd — 牌组与四区管理（抽牌堆/手牌/弃牌堆/消耗堆）。
## 抽牌堆空时自动把弃牌堆洗回 —— 这是杀戮尖塔牌组循环的骨架。
class_name DeckManager
extends RefCounted

var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []
var exhaust_pile: Array[CardInstance] = []


func _init(deck_ids: Array) -> void:
	for id: Variant in deck_ids:
		draw_pile.append(CardInstance.new(String(id)))


## Fisher-Yates，使用传入的受管 RNG（ADR-003：不用全局 randi）。
func shuffle(r: RandomNumberGenerator) -> void:
	for i: int in range(draw_pile.size() - 1, 0, -1):
		var j: int = r.randi_range(0, i)
		var tmp: CardInstance = draw_pile[i]
		draw_pile[i] = draw_pile[j]
		draw_pile[j] = tmp


## 抽 n 张（含自动洗回）。返回实际抽到的卡，由调用方决定进手牌还是溢出弃牌。
func draw_cards(n: int, r: RandomNumberGenerator) -> Array[CardInstance]:
	var drawn: Array[CardInstance] = []
	for i: int in n:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile.append_array(discard_pile)
			discard_pile.clear()
			shuffle(r)
		drawn.append(draw_pile.pop_back())
	return drawn


func remove_from_hand(card: CardInstance) -> void:
	hand.erase(card)


func move_to_discard(card: CardInstance) -> void:
	discard_pile.append(card)


func move_to_exhaust(card: CardInstance) -> void:
	exhaust_pile.append(card)


func discard_hand() -> void:
	for c: CardInstance in hand:
		discard_pile.append(c)
	hand.clear()
