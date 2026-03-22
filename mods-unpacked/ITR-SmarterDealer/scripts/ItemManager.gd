extends Object

func SetupItemClear(chain: ModLoaderHookChain)->void:
	chain.reference_object.itemArray_player.clear()
	chain.execute_next_async()
	
func PlaceDownItem(chain: ModLoaderHookChain, gridIndex : int)->void:
	chain.reference_object.itemArray_player.append(chain.reference_object.temp_interaction.itemName)
	chain.execute_next_async([gridIndex])
