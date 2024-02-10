extends "res://scripts/DealerIntelligence.gd"

const Bruteforce = preload("res://mods-unpacked/ITR-SmarterDealer/bruteforce.gd") 

func AlternativeChoice():
	if (shellSpawner.sequenceArray.size() == 0):
		return Bruteforce.OPTION_NONE

	var magnifyingGlasses = 0
	var cigarettes = 0
	var beer = 0
	var handcuffs = 0
	var handsaw = 0
		
	for item in itemManager.itemArray_dealer:
		if (item == "magnifying glass"):
			magnifyingGlasses += 1
		elif (item == "cigarettes"):
			cigarettes += 1
		elif (item == "beer"):
			beer += 1
		elif (item == "handcuffs"):
			handcuffs += 1
		elif (item == "handsaw"):
			handsaw += 1
			
	var startingHealth = roundManager.roundArray[0].startingHealth
	if (cigarettes > 0 and roundManager.health_opponent < startingHealth):
		return Bruteforce.OPTION_CIGARETTES
		
	var liveCount = 0
	var blankCount = 0
	for shell in shellSpawner.sequenceArray:
		if shell == "live":
			liveCount += 1
		else:
			blankCount += 1

	var magnifyingGlassesP = 0
	var cigarettesP = 0
	var beerP = 0
	var handcuffsP = 0
	var handsawP = 0
		
	for item in itemManager.itemArray_player:
		if (item == "magnifying glass"):
			magnifyingGlassesP += 1
		elif (item == "cigarettes"):
			cigarettesP += 1
		elif (item == "beer"):
			beerP += 1
		elif (item == "handcuffs"):
			handcuffsP += 1
		elif (item == "handsaw"):
			handsawP += 1

	# Create instances of BruteforcePlayer for player and opponent
	var player = Bruteforce.BruteforcePlayer.new(
		0,
		startingHealth,
		magnifyingGlassesP, cigarettesP, beerP, handcuffsP, handsawP
	)
	player.health = roundManager.health_player
	
	var dealer = Bruteforce.BruteforcePlayer.new(
		1,
		startingHealth,
		magnifyingGlasses, cigarettes, beer, handcuffs, handsaw
	)
	dealer.health = roundManager.health_opponent

	var shell = Bruteforce.MAGNIFYING_NONE
	if knownShell == "live":
		shell = Bruteforce.MAGNIFYING_LIVE
	elif knownShell == "blank":
		shell = Bruteforce.MAGNIFYING_BLANK
		
	var playerHandcuffState = Bruteforce.HANDCUFF_NONE if not roundManager.playerCuffed else (Bruteforce.HANDCUFF_FREENEXT if roundManager.playerAboutToBreakFree else Bruteforce.HANDCUFF_CUFFED)

	# Call the static function with the required arguments
	var result = Bruteforce.GetBestChoiceAndDamage(
		liveCount, blankCount,
		dealer, player,
		playerHandcuffState,
		shell,
		roundManager.barrelSawedOff
	)
	ModLoaderLog.info("%s" % result, "ITR-SmarterDealer")

	# Return the result, you might want to handle the result accordingly
	return result.option

func DealerChoice()->void:
	if roundManager.playerCuffed:
		await get_tree().create_timer(1.5, false).timeout
	var choice = AlternativeChoice();
	var dealerWantsToUse = ""
	dealerTarget = ""
	
	if choice == Bruteforce.OPTION_SHOOT_OTHER:
		dealerTarget = "player"
	elif choice == Bruteforce.OPTION_SHOOT_SELF:
		dealerTarget = "self"
	elif choice  == Bruteforce.OPTION_CIGARETTES:
		dealerWantsToUse = "cigarettes"
	elif choice == Bruteforce.OPTION_HANDCUFFS:
		dealerWantsToUse = "handcuffs"
		roundManager.playerCuffed = true
	elif choice == Bruteforce.OPTION_MAGNIFY:
		dealerWantsToUse = "magnifying glass"
		dealerKnowsShell = true
		knownShell = shellSpawner.sequenceArray[0]
	elif choice == Bruteforce.OPTION_BEER:
		dealerWantsToUse = "beer"
		shellEject_dealer.FadeOutShell()
		# I added this to fix it
		knownShell = ""
		dealerKnowsShell = false
	elif choice == Bruteforce.OPTION_HANDSAW:
		dealerWantsToUse = "handsaw"
		usingHandsaw = true
		roundManager.barrelSawedOff = true
		roundManager.currentShotgunDamage = 2
	else:
		super()
		return
		
	# use item
	if (dealerWantsToUse != ""): 
		if (dealerHoldingShotgun):
			animator_shotgun.play("enemy put down shotgun")
			shellLoader.DealerHandsDropShotgun()
			dealerHoldingShotgun = false
			await get_tree().create_timer(.45, false).timeout
		dealerUsedItem = true
		if (roundManager.waitingForDealerReturn):
			await get_tree().create_timer(1.8, false).timeout
			roundManager.waitingForDealerReturn = false
		await(hands.PickupItemFromTable(dealerWantsToUse))
		#if (dealerWantsToUse == "handcuffs"): await get_tree().create_timer(.8, false).timeout #additional delay for initial player handcuff check (continues outside animation)
		if (dealerWantsToUse == "cigarettes"): await get_tree().create_timer(1.1, false).timeout #additional delay for health update routine (called in aninator. continues outside animation)
		itemManager.itemArray_dealer.erase(dealerWantsToUse)
		itemManager.numberOfItemsGrabbed_enemy -= 1
		DealerChoice()
		return
		
	# shoot
	if (roundManager.waitingForDealerReturn):
		await get_tree().create_timer(1.8, false).timeout
	if (!dealerHoldingShotgun):
		GrabShotgun()
		await get_tree().create_timer(1.4 + .5 - 1, false).timeout
	await get_tree().create_timer(1, false).timeout
	Shoot(dealerTarget)
	dealerTarget = ""
	knownShell = ""
	dealerKnowsShell = false
	return
