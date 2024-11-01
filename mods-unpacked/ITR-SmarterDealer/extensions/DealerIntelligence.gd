extends "res://scripts/DealerIntelligence.gd"

const Bruteforce = preload("res://mods-unpacked/ITR-SmarterDealer/bruteforce.gd")

var thread_semaphore: Semaphore
var main_semaphore: Semaphore
var thread: Thread
var keep_thread_alive := true
var thread_isPlayer := false
var thread_overrideShell := ""
var thread_choice := Bruteforce.OPTION_NONE

func _ready():
	thread_semaphore = Semaphore.new()
	main_semaphore = Semaphore.new()
	keep_thread_alive = true

	thread = Thread.new()
	thread.start(_thread_function)

func _exit_tree():
	keep_thread_alive = false
	thread_semaphore.post()

func _thread_function():
	while keep_thread_alive:
		thread_semaphore.wait()
		if not keep_thread_alive:
			break

		thread_choice = Bruteforce.OPTION_NONE
		thread_choice = AlternativeChoice(thread_isPlayer, thread_overrideShell)
		main_semaphore.post()

func createPlayer(player_index, itemArray):
	var magnifyingGlasses = 0
	var cigarettes = 0
	var beer = 0
	var handcuffs = 0
	var handsaw = 0
	var medicine = 0
	var inverters = 0
	var burners = 0
	var adrenaline = 0

	for item in itemArray:
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
		elif (item == "expired medicine"):
			medicine += 1
		elif (item == "inverter"):
			inverters += 1
		elif (item == "burner phone"):
			burners += 1
		elif (item == "adrenaline"):
			adrenaline += 1

	return Bruteforce.BruteforcePlayer.new(
		player_index,
		roundManager.roundArray[0].startingHealth,
		magnifyingGlasses, cigarettes, beer, handcuffs, handsaw, medicine, inverters, burners, adrenaline
	)

func playerStateSpaceSizeEstimation(player: Bruteforce.BruteforcePlayer) -> int:
	var result = player.health + 1
	for item in [player.magnify, player.cigarettes, player.beer, player.handcuffs, player.handsaw, player.medicine, player.inverter, player.burner, player.adrenaline]:
		result *= item + 1
	return result

var inverted_shell = false
var adrenaline = false
func AlternativeChoice(isPlayer: bool = false, overrideShell = ""):
	if (shellSpawner.sequenceArray.size() == 0):
		return Bruteforce.OPTION_NONE

	var liveCount = 0
	var blankCount = 0

	var liveUnknown = 0
	var blankUnknown = 0
	for index in range(shellSpawner.sequenceArray.size()):
		var shell = shellSpawner.sequenceArray[index]
		if (shell == "live") != (index == 0 and inverted_shell):
			liveCount += 1
			if not sequenceArray_knownShell[index]:
				liveUnknown += 1
		else:
			blankCount += 1
			if not sequenceArray_knownShell[index]:
				blankUnknown += 1

	var roundType = Bruteforce.ROUNDTYPE_NORMAL
	if roundManager.defibCutterReady and !roundManager.endless:
		roundType = Bruteforce.ROUNDTYPE_WIRECUT
	elif roundManager.playerData.currentBatchIndex == 2:
		roundType = Bruteforce.ROUNDTYPE_DOUBLEORNOTHING

	# Create instances of BruteforcePlayer for player and opponent
	var player = createPlayer(0, itemManager.itemArray_player)
	player.health = roundManager.health_player

	var dealer = createPlayer(1, itemManager.itemArray_dealer)
	dealer.health = roundManager.health_opponent

	# It's not perfect, but it's typically within a factor of 2 when the number of state spaces is high enough to matter.
	var estimatedStateSpace: int = playerStateSpaceSizeEstimation(player) * playerStateSpaceSizeEstimation(dealer) * (liveCount+1) * (blankCount+1)
	ModLoaderLog.info("Estimated state space size: %s" % estimatedStateSpace, "ITR-SmarterDealer")

	# Some probably dumb plays to prevent the AI from spending ages thinking
	# This threshold caps dealer thinking time to ~20 seconds on my machine.
	if estimatedStateSpace > 75000:
		var check = player if isPlayer else dealer

		if check.cigarettes > 0 and check.health < check.max_health:
			return Bruteforce.OPTION_CIGARETTES

		if check.burner > 0:
			return Bruteforce.OPTION_BURNER

		if check.beer > 0:
			return Bruteforce.OPTION_BEER

		# Favor speed over optimal play if things are really complicated.
		return Bruteforce.OPTION_SHOOT_OTHER


	var shell = Bruteforce.MAGNIFYING_NONE
	if overrideShell:
		if overrideShell == "live":
			shell = Bruteforce.MAGNIFYING_LIVE
		elif overrideShell == "blank":
			shell = Bruteforce.MAGNIFYING_BLANK
	else:
		if dealerKnowsShell or sequenceArray_knownShell[0] or liveUnknown == 0 or blankUnknown == 0:
			shell = Bruteforce.MAGNIFYING_LIVE if shellSpawner.sequenceArray[0] == "live" else Bruteforce.MAGNIFYING_BLANK

	var playerHandcuffState = Bruteforce.HANDCUFF_NONE
	if isPlayer:
		if roundManager.dealerCuffed:
			if dealerAboutToBreakFree:
				playerHandcuffState = Bruteforce.HANDCUFF_FREENEXT
			else:
				playerHandcuffState = Bruteforce.HANDCUFF_CUFFED
	else:
		if roundManager.playerCuffed:
			if roundManager.playerAboutToBreakFree:
				playerHandcuffState = Bruteforce.HANDCUFF_FREENEXT
			else:
				playerHandcuffState = Bruteforce.HANDCUFF_CUFFED


	var tempStates = Bruteforce.TempStates.new()
	tempStates.handcuffState = playerHandcuffState
	tempStates.magnifyingGlassResult = shell
	tempStates.usedHandsaw = roundManager.barrelSawedOff
	tempStates.adrenaline = adrenaline
	tempStates.inverted = inverted_shell
	if shell == Bruteforce.MAGNIFYING_NONE:
		tempStates.futureBlank = blankCount - blankUnknown
		tempStates.futureLive = liveCount - liveUnknown

	# Call the static function with the required arguments
	var result = Bruteforce.GetBestChoiceAndDamage(
		roundType,
		liveCount, blankCount,
		player if isPlayer else dealer, dealer if isPlayer else player,
		tempStates
	)
	ModLoaderLog.info("%s" % result, "ITR-SmarterDealer")

	CommentOnChance(result.deathChance[0], result.deathChance[1])

	# Return the result, you might want to handle the result accordingly
	return result.option

var lastCommentType = ""
func CommentOnChance(playerDeathChance: float, dealerDeathChance: float):
	var commentType: String
	var texts: Array

	if playerDeathChance >= 0.65:
		commentType = "player_danger"
		texts = [
			"say hello to god",
			"greet god from me",
			"sayonara",
			"death incoming",
			"here comes the inevitable",
			"you need more practice,\nI'm afraid",
			"no extra charges this time",
			"your corpse\nwill make good profit",
			"life support: offline",
			"time to collect the toll",
			"your soul is on borrowed time",
			"the abyss awaits your arrival",
			"your luck is running out",
			"the reaper's whisper\ngrows louder",
			"odds stacked against you",
			"the game hungers\nfor your demise",
			"the end draws near",
		]
	elif dealerDeathChance >= 0.65:
		commentType = "dealer_danger"
		texts = [
			"this isn't looking\nvery poggers",
			"this is the end for me",
			"see you next round",
			"brace yourself,\nthe shadows linger",
			"the game tightens its grip,\nbut so do I",
			"a glimpse of the abyss,\nyet I persist",
			"the dance with death grows intense",
			"challenges only make me stronger",
			"the odds may shift,\nbut I remain",
			"a moment of vulnerability,\nswiftly embraced",
			"even in darkness,\nI find my footing",
			"the game tests,\nand I endure",
			"the roulette wheel turns,\nbut I play on",
			"my grip weakens,\nbut not my resolve",
			"struggling against the inevitable",
			"the shadows encroach,\nbut I endure",
			"every moment is a battle,\nbut I fight on",
			"defiance in the face of doom",
		]
	elif playerDeathChance >= 0.4 and dealerDeathChance >= 0.4:
		commentType = "fifty_fifty"
		texts = [
			"now we both dance on the\nedge of life and death",
			"it's showdown time",
			"our fate shall be decided\nby a flip of a coin",
			"fifty, fifty",
			"the roulette spins,\nlet destiny choose",
			"the shadows of death envelop us",
			"we walk the tightrope\nbetween mortality and eternity",
			"each pull of the trigger\nechoes in the abyss",
			"we navigate the\nrazor's edge together",
			"chances oscillate\nlike a pendulum",
			"each heartbeat echoes in the void",
			"our dance with fate\nbecomes a symphony",
			"the game's grip is uncertain",
		]
	else:
		return

	texts.shuffle()
	print(texts[0])
	if commentType == lastCommentType:
		print("Comment skipped")
		return

	lastCommentType = commentType

	shellLoader.dialogue.ShowText_Forever(texts[0])
	await get_tree().create_timer(2.3, false).timeout
	shellLoader.dialogue.HideText()

func DealerChoice()->void:
	# Check if the dealer is dead, to cover the case where the dealer takes expired medicine on 1 health. (Which then leads to calling DealerChoice again.)
	if roundManager.health_opponent <= 0:
		roundManager.OutOfHealth("dealer")
		healthCounter.UpdateDisplayRoutine(false, false, true)
		return

	if (roundManager.requestedWireCut):
		await(roundManager.defibCutter.CutWire(roundManager.wireToCut))
	if adrenaline:
		await get_tree().create_timer(0.5, false).timeout
	elif roundManager.playerCuffed:
		await get_tree().create_timer(1.5, false).timeout

	thread_isPlayer = false
	thread_overrideShell = ""
	thread_semaphore.post()

	while not main_semaphore.try_wait():
		await get_tree().process_frame

	var choice = thread_choice;
	var dealerWantsToUse = ""
	dealerTarget = ""

	if choice == Bruteforce.OPTION_SHOOT_OTHER:
		dealerTarget = "player"
		inverted_shell = false
	elif choice == Bruteforce.OPTION_SHOOT_SELF:
		dealerTarget = "self"
		inverted_shell = false
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
		inverted_shell = false
	elif choice == Bruteforce.OPTION_HANDSAW:
		dealerWantsToUse = "handsaw"
		usingHandsaw = true
		roundManager.barrelSawedOff = true
		roundManager.currentShotgunDamage = 2
	elif choice == Bruteforce.OPTION_MEDICINE:
		dealerWantsToUse = "expired medicine"
		usingMedicine = true
	elif choice == Bruteforce.OPTION_INVERTER:
		dealerWantsToUse = "inverter"
		inverted_shell = !inverted_shell
		if roundManager.shellSpawner.sequenceArray[0] == "live":
			roundManager.shellSpawner.sequenceArray[0] = "blank"
		else:
			roundManager.shellSpawner.sequenceArray[0] = "live"
	elif choice == Bruteforce.OPTION_BURNER:
		var sequence  = roundManager.shellSpawner.sequenceArray
		var len = sequence.size()
		var randindex =  randi_range(1, len - 1)
		if(randindex == 8): randindex -= 1
		sequenceArray_knownShell[randindex] = true
		print("Dealer saw shell #", randindex)
		dealerWantsToUse = "burner phone"
	elif choice == Bruteforce.OPTION_ADRENALINE:
		adrenaline = true
		dealerWantsToUse = "adrenaline"
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

		# Medicine
		var returning = false
		if (dealerWantsToUse == "expired medicine"):
			var medicine_outcome = randf_range(0.0, 1.0)
			var dying = medicine_outcome >= .5
			medicine.dealerDying = dying
			returning = true

		if not adrenaline or dealerWantsToUse == "adrenaline":
			for res in amounts.array_amounts:
				if (dealerWantsToUse == res.itemName):
					res.amount_dealer -= 1
					break

			await(hands.PickupItemFromTable(dealerWantsToUse))
			#if (dealerWantsToUse == "handcuffs"): await get_tree().create_timer(.8, false).timeout #additional delay for initial player handcuff check (continues outside animation)
			if (dealerWantsToUse == "cigarettes"): await get_tree().create_timer(1.1, false).timeout #additional delay for health update routine (called in animator. continues outside animation)
			itemManager.itemArray_dealer.erase(dealerWantsToUse)
			itemManager.numberOfItemsGrabbed_enemy -= 1
			print("Dealer uses "+dealerWantsToUse)
		else:
			# I don't understand what this code does, but we need to add an item to itemManager.itemArray_instances_dealer
			var ch = itemManager.itemSpawnParent.get_children()
			for c in ch.size():
				if(not (ch[c].get_child(0) is PickupIndicator)):
					continue

				var temp_indicator : PickupIndicator = ch[c].get_child(0)
				var temp_interaction : InteractionBranch = ch[c].get_child(1)
				if (ch[c].transform.origin.z > 0): temp_indicator.whichSide = "right"
				else: temp_indicator.whichSide= "left"
				if (not temp_interaction.isPlayerSide) or temp_interaction.itemName != dealerWantsToUse:
					continue

				itemManager.itemArray_instances_dealer.insert(0, ch[c])
				break

			adrenaline = false
			hands.stealing = true
			await(hands.PickupItemFromTable(dealerWantsToUse))
			await get_tree().create_timer(1.1, false).timeout
			print("Dealer steals "+dealerWantsToUse)
			itemManager.itemArray_player.erase(dealerWantsToUse)

		if (returning): return
		DealerChoice()
		return

	# When the dealer shoots to end his turn, reset his last comment type so he can make any comment next turn.
	if (shellSpawner.sequenceArray[0] == "live" or dealerTarget == "player") and not (roundManager.playerCuffed and not roundManager.playerAboutToBreakFree):
		lastCommentType = ""

	# shoot
	if (roundManager.waitingForDealerReturn):
		await get_tree().create_timer(1.8, false).timeout
	if (!dealerHoldingShotgun):
		GrabShotgun()
		await get_tree().create_timer(1.4 + .5 - 1, false).timeout
	await get_tree().create_timer(1, false).timeout
	print("Dealer shoots "+dealerTarget)
	Shoot(dealerTarget)
	dealerTarget = ""
	knownShell = ""
	dealerKnowsShell = false
	inverted_shell = false
	return

func EndDealerTurn(canDealerGoAgain : bool):
	dealerCanGoAgain = canDealerGoAgain
	#USINGITEMS: ASSIGN DEALER CAN GO AGAIN FROM ITEMS HERE
	#CHECK IF OUT OF HEALTH
	var outOfHealth_player = roundManager.health_player == 0
	var outOfHealth_enemy = roundManager.health_opponent == 0
	var outOfHealth = outOfHealth_player or outOfHealth_enemy
	if (outOfHealth):
		#if (outOfHealth_player): roundManager.OutOfHealth("player")
		if (outOfHealth_enemy):	roundManager.OutOfHealth("dealer")
		return

	if (!dealerCanGoAgain):
		EndTurnMain()
	else:
		if (shellSpawner.sequenceArray.size()):
			# If the dealer shot himself with a sawed-off shotgun, reset the barrel by effectively calling EndTurnMain, but passing control back to the dealer instead of the player.
			if roundManager.barrelSawedOff:
				await get_tree().create_timer(.5, false).timeout
				camera.BeginLerp("home")
				if (dealerHoldingShotgun):
					animator_shotgun.play("enemy put down shotgun")
					shellLoader.DealerHandsDropShotgun()
				dealerHoldingShotgun = false
				await get_tree().create_timer(1, false).timeout
				roundManager.EndTurn(false)
			else:
				BeginDealerTurn()
		else:
			EndTurnMain()
	pass
