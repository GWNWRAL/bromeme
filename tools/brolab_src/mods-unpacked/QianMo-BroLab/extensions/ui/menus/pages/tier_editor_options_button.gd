extends OptionButton


func _ready()->void :
	add_item(ItemService.get_tier_text(Tier.COMMON), 0)
	add_item(ItemService.get_tier_text(Tier.UNCOMMON), 1)
	add_item(ItemService.get_tier_text(Tier.RARE), 2)
	add_item(ItemService.get_tier_text(Tier.LEGENDARY), 3)
