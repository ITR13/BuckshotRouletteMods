extends "res://scripts/ItemInteraction.gd"

func InteractWith(alias : String)->void:
	print("Player used ", alias)
	itemManager.itemArray_player.erase(alias)
	await super(alias)
	
