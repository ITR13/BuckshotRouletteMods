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
		elif (item == "burner"):
			burners += 1
		elif (item == "adrenaline"):
			adrenaline += 1

	return Bruteforce.BruteforcePlayer.new(
		player_index,
		roundManager.roundArray[0].startingHealth,
		magnifyingGlasses, cigarettes, beer, handcuffs, handsaw, medicine, inverters, burners, adrenaline
	)


var prevBatchIndex = -1
var prevWonRounds = -1
var inverted_shell = false
var adrenaline = false
func AlternativeChoice(isPlayer: bool = false, overrideShell = ""):
	if (shellSpawner.sequenceArray.size() == 0):
		return Bruteforce.OPTION_NONE

	if roundManager.playerData.currentBatchIndex != prevBatchIndex:
		Bruteforce.RandomizeDealer()
		prevBatchIndex = roundManager.playerData.currentBatchIndex

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
	if roundManager.defibCutterReady && !roundManager.endless:
		roundType = Bruteforce.ROUNDTYPE_WIRECUT
	elif roundManager.playerData.currentBatchIndex == 2:
		roundType = Bruteforce.ROUNDTYPE_DOUBLEORNOTHING

	# Create instances of BruteforcePlayer for player and opponent
	var player = createPlayer(0, itemManager.itemArray_player)
	player.health = roundManager.health_player

	var dealer = createPlayer(1, itemManager.itemArray_dealer)
	dealer.health = roundManager.health_opponent

	if roundType != Bruteforce.ROUNDTYPE_DOUBLEORNOTHING:
		var check = player if isPlayer else dealer
		if check.cigarettes > 0 and check.health > check.max_health:
			return Bruteforce.OPTION_CIGARETTES

	var shell = Bruteforce.MAGNIFYING_NONE
	if overrideShell:
		if overrideShell == "live":
			shell = Bruteforce.MAGNIFYING_LIVE
		elif overrideShell == "blank":
			shell = Bruteforce.MAGNIFYING_BLANK
	else:
		if dealerKnowsShell or sequenceArray_knownShell[0] or liveUnknown == 0 or blankUnknown == 0:
			shell = Bruteforce.MAGNIFYING_LIVE if (shellSpawner.sequenceArray[0] == "live") != inverted_shell else Bruteforce.MAGNIFYING_BLANK

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

	# Call the static function with the required arguments
	var result = Bruteforce.GetBestChoiceAndDamage(
		roundType,
		liveCount, blankCount,
		player if isPlayer else dealer, dealer if isPlayer else player,
		tempStates
	)
	ModLoaderLog.info("%s" % result, "ITR-SmarterDealer")

	# Disabled until I figure out how A: roundManager.wonRounds doesn't exist, and B: How the code works in spite of this
	# if prevWonRounds != roundManager.wonRounds:
	# 	prevWonRounds = roundManager.wonRounds
	# 	CommentOnChance(result.deathChance[0], result.deathChance[1])

	# Return the result, you might want to handle the result accordingly
	return result.option

var commentDelay = 3
func CommentOnChance(playerDeathChance: float, dealerDeathChance: float):
	var texts: Array

	commentDelay -= 1

	if playerDeathChance >= 0.65:
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
	if commentDelay > 0:
		print("Comment skipped")
		return

	commentDelay = 3

	shellLoader.dialogue.ShowText_Forever(texts[0])
	await get_tree().create_timer(2.3, false).timeout
	shellLoader.dialogue.HideText()

func DealerChoice()->void:
	if (roundManager.requestedWireCut):
		await(roundManager.defibCutter.CutWire(roundManager.wireToCut))
	if roundManager.playerCuffed:
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
		inverted_shell = true
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
		else:
			# I don't understand what this code does, but we need to add an item to itemManager.itemArray_instances_dealer
			var ch = itemManager.itemSpawnParent.get_children()
			for c in ch.size():
				if(ch[c].get_child(0) is PickupIndicator):
					var temp_indicator : PickupIndicator = ch[c].get_child(0)
					var temp_interaction : InteractionBranch = ch[c].get_child(1)
					if (ch[c].transform.origin.z > 0): temp_indicator.whichSide = "right"
					else: temp_indicator.whichSide= "left"
					if (temp_interaction.isPlayerSide):
						itemManager.itemArray_instances_dealer.append(ch[c])
						inv_playerside.append(temp_interaction.itemName)

			adrenaline = false
			hands.stealing = true
			await(hands.PickupItemFromTable(dealerWantsToUse))
			await get_tree().create_timer(1.1, false).timeout

		if (returning): return
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
	inverted_shell = false
	return
