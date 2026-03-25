extends Object

const Bruteforce = preload("res://mods-unpacked/ITR-SmarterDealer/bruteforce.gd")

func DealerChoice(chain: ModLoaderHookChain)->void:
	var dealerIntelligence = chain.reference_object
	var dealerManager = dealerIntelligence.get_child(0)
	
	# Check if the dealer is dead, to cover the case where the dealer takes expired medicine on 1 health. (Which then leads to calling DealerChoice again.)
	if dealerIntelligence.roundManager.health_opponent <= 0:
		dealerIntelligence.roundManager.OutOfHealth("dealer")
		dealerIntelligence.healthCounter.UpdateDisplayRoutine(false, false, true)
		return

	if (dealerIntelligence.roundManager.requestedWireCut):
		await(dealerIntelligence.roundManager.defibCutter.CutWire(dealerIntelligence.roundManager.wireToCut))
	if dealerManager.adrenaline:
		await dealerIntelligence.get_tree().create_timer(0.5, false).timeout
	elif dealerIntelligence.roundManager.playerCuffed:
		await dealerIntelligence.get_tree().create_timer(1.5, false).timeout

	dealerManager.thread_isPlayer = false
	dealerManager.thread_overrideShell = ""
	dealerManager.thread_semaphore.post()

	while not dealerManager.main_semaphore.try_wait():
		await dealerIntelligence.get_tree().process_frame

	var choice = dealerManager.thread_choice;
	var dealerWantsToUse = ""
	dealerIntelligence.dealerTarget = ""

	match choice:
		Bruteforce.OPTION_SHOOT_OTHER:
			dealerIntelligence.dealerTarget = "player"
			dealerManager.inverted_shell = false
		Bruteforce.OPTION_SHOOT_SELF:
			dealerIntelligence.dealerTarget = "self"
			dealerManager.inverted_shell = false
		Bruteforce.OPTION_CIGARETTES:
			dealerWantsToUse = "cigarettes"
		Bruteforce.OPTION_HANDCUFFS:
			dealerWantsToUse = "handcuffs"
			dealerIntelligence.roundManager.playerCuffed = true
		Bruteforce.OPTION_MAGNIFY:
			dealerWantsToUse = "magnifying glass"
			dealerIntelligence.dealerKnowsShell = true
			dealerIntelligence.knownShell = dealerIntelligence.shellSpawner.sequenceArray[0]
		Bruteforce.OPTION_BEER:
			dealerWantsToUse = "beer"
			dealerIntelligence.shellEject_dealer.FadeOutShell()
			# I added this to fix it
			dealerIntelligence.knownShell = ""
			dealerIntelligence.dealerKnowsShell = false
			dealerManager.inverted_shell = false
		Bruteforce.OPTION_HANDSAW:
			dealerWantsToUse = "handsaw"
			dealerIntelligence.usingHandsaw = true
			dealerIntelligence.roundManager.barrelSawedOff = true
			dealerIntelligence.roundManager.currentShotgunDamage = 2
		Bruteforce.OPTION_MEDICINE:
			dealerWantsToUse = "expired medicine"
			dealerIntelligence.usingMedicine = true
		Bruteforce.OPTION_INVERTER:
			dealerWantsToUse = "inverter"
			dealerManager.inverted_shell = not dealerManager.inverted_shell
			var shell = dealerIntelligence.roundManager.shellSpawner.sequenceArray[0]
			dealerIntelligence.roundManager.shellSpawner.sequenceArray[0] = "blank" if shell == "live" else "live"
		Bruteforce.OPTION_BURNER:
			var sequence  = dealerIntelligence.roundManager.shellSpawner.sequenceArray
			var len = sequence.size()
			var randindex =  randi_range(1, len - 1)
			if(randindex == 8): randindex -= 1
			dealerIntelligence.sequenceArray_knownShell[randindex] = true
			print("Dealer saw shell #", randindex)
			dealerWantsToUse = "burner phone"
		Bruteforce.OPTION_ADRENALINE:
			dealerManager.adrenaline = true
			dealerWantsToUse = "adrenaline"
		_:
			chain.execute_next_async()
			return

	# use item
	if (dealerWantsToUse != ""):
		if (dealerIntelligence.dealerHoldingShotgun):
			dealerIntelligence.animator_shotgun.play("enemy put down shotgun")
			dealerIntelligence.shellLoader.DealerHandsDropShotgun()
			dealerIntelligence.dealerHoldingShotgun = false
			await dealerIntelligence.get_tree().create_timer(.45, false).timeout
		dealerIntelligence.dealerUsedItem = true
		if (dealerIntelligence.roundManager.waitingForDealerReturn):
			await dealerIntelligence.get_tree().create_timer(1.8, false).timeout
			dealerIntelligence.roundManager.waitingForDealerReturn = false

		# Medicine
		var returning = false
		if (dealerWantsToUse == "expired medicine"):
			var medicine_outcome = randf_range(0.0, 1.0)
			var dying = medicine_outcome >= .5
			dealerIntelligence.medicine.dealerDying = dying
			returning = true

		if not dealerManager.adrenaline or dealerWantsToUse == "adrenaline":
			for res in dealerIntelligence.amounts.array_amounts:
				if (dealerWantsToUse == res.itemName):
					res.amount_dealer -= 1
					break

			await(dealerIntelligence.hands.PickupItemFromTable(dealerWantsToUse))
			#if (dealerWantsToUse == "handcuffs"): await dealerIntelligence.get_tree().create_timer(.8, false).timeout #additional delay for initial player handcuff check (continues outside animation)
			if (dealerWantsToUse == "cigarettes"): await dealerIntelligence.get_tree().create_timer(1.1, false).timeout #additional delay for health update routine (called in animator. continues outside animation)
			dealerIntelligence.itemManager.itemArray_dealer.erase(dealerWantsToUse)
			dealerIntelligence.itemManager.numberOfItemsGrabbed_enemy -= 1
			print("Dealer uses "+dealerWantsToUse)
		else:
			# I don't understand what this code does, but we need to add an item to itemManager.itemArray_instances_dealer
			var ch = dealerIntelligence.itemManager.itemSpawnParent.get_children()
			for c in ch.size():
				if(not (ch[c].get_child(0) is PickupIndicator)):
					continue

				var temp_indicator : PickupIndicator = ch[c].get_child(0)
				var temp_interaction : InteractionBranch = ch[c].get_child(1)
				if (ch[c].transform.origin.z > 0): temp_indicator.whichSide = "right"
				else: temp_indicator.whichSide= "left"
				if (not temp_interaction.isPlayerSide) or temp_interaction.itemName != dealerWantsToUse:
					continue

				dealerIntelligence.itemManager.itemArray_instances_dealer.insert(0, ch[c])
				break

			dealerManager.adrenaline = false
			dealerIntelligence.hands.stealing = true
			await(dealerIntelligence.hands.PickupItemFromTable(dealerWantsToUse))
			await dealerIntelligence.get_tree().create_timer(1.1, false).timeout
			print("Dealer steals "+dealerWantsToUse)
			dealerIntelligence.itemManager.itemArray_player.erase(dealerWantsToUse)

		if (returning): return
		dealerIntelligence.DealerChoice()
		return

	# When the dealer shoots to end his turn, reset his last comment type so he can make any comment next turn.
	if (dealerIntelligence.shellSpawner.sequenceArray[0] == "live" or dealerIntelligence.dealerTarget == "player") \
		and not (dealerIntelligence.roundManager.playerCuffed and not dealerIntelligence.roundManager.playerAboutToBreakFree):
		dealerManager.lastCommentType = ""

	# shoot
	if (dealerIntelligence.roundManager.waitingForDealerReturn):
		await dealerIntelligence.get_tree().create_timer(1.8, false).timeout
	if (not dealerIntelligence.dealerHoldingShotgun):
		dealerIntelligence.GrabShotgun()
		await dealerIntelligence.get_tree().create_timer(1.4 + .5 - 1, false).timeout
	await dealerIntelligence.get_tree().create_timer(1, false).timeout
	print("Dealer shoots "+dealerIntelligence.dealerTarget)
	dealerIntelligence.Shoot(dealerIntelligence.dealerTarget)
	dealerIntelligence.dealerTarget = ""
	dealerIntelligence.knownShell = ""
	dealerIntelligence.dealerKnowsShell = false
	dealerManager.inverted_shell = false
	return

func EndDealerTurn(chain: ModLoaderHookChain, canDealerGoAgain : bool):
	var dealerIntelligence = chain.reference_object
	var dealerManager = dealerIntelligence.get_child(0)
	
	dealerIntelligence.dealerCanGoAgain = canDealerGoAgain
	#USINGITEMS: ASSIGN DEALER CAN GO AGAIN FROM ITEMS HERE
	#CHECK IF OUT OF HEALTH
	var outOfHealth_player = dealerIntelligence.roundManager.health_player == 0
	var outOfHealth_enemy = dealerIntelligence.roundManager.health_opponent == 0
	var outOfHealth = outOfHealth_player or outOfHealth_enemy
	if (outOfHealth):
		#if (outOfHealth_player): roundManager.OutOfHealth("player")
		if (outOfHealth_enemy): dealerIntelligence.roundManager.OutOfHealth("dealer")
		return

	if (not dealerIntelligence.dealerCanGoAgain):
		dealerIntelligence.EndTurnMain()
	else:
		if (dealerIntelligence.shellSpawner.sequenceArray.size()):
			# If the dealer shot himself with a sawed-off shotgun, reset the barrel by effectively calling EndTurnMain, but passing control back to the dealer instead of the player.
			if dealerIntelligence.roundManager.barrelSawedOff:
				await dealerIntelligence.get_tree().create_timer(.5, false).timeout
				dealerIntelligence.camera.BeginLerp("home")
				if (dealerIntelligence.dealerHoldingShotgun):
					dealerIntelligence.animator_shotgun.play("enemy put down shotgun")
					dealerIntelligence.shellLoader.DealerHandsDropShotgun()
				dealerIntelligence.dealerHoldingShotgun = false
				await dealerIntelligence.get_tree().create_timer(1, false).timeout
				dealerIntelligence.roundManager.EndTurn(false)
			else:
				dealerIntelligence.BeginDealerTurn()
		else:
			dealerIntelligence.EndTurnMain()
