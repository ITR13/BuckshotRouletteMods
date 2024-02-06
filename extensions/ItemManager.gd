extends "res://scripts/ItemManager.gd"

func SetupItemClear()->void:
	itemArray_player = []
	await super()
	
func PlaceDownItem(gridIndex : int)->void:
	itemArray_player.append(temp_interaction.itemName)
	super(gridIndex)
