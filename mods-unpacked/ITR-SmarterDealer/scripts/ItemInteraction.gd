extends Object

const id = "ITR-SmarterDealer"

func InteractWith(chain: ModLoaderHookChain, alias : String)->void:
	#print("Player used ", alias)
	chain.reference_object.itemManager.itemArray_player.erase(alias)
	chain.execute_next_async([alias])

func _ready(chain: ModLoaderHookChain):
	chain.execute_next_async()
	var dealerManager = Node.new()
	dealerManager.set_script(load("res://mods-unpacked/ITR-SmarterDealer/utils/DealerManager.gd"))
	dealerManager.name = "dealer manager"
	var dealerIntelligence = chain.reference_object.dealerIntelligence
	dealerManager.dealerIntelligence = dealerIntelligence
	var config = ModLoaderConfig.get_config(id, "user")
	if config != null and not config.data.comments:
		dealerManager.enable_comments = false
	dealerIntelligence.add_child(dealerManager)
