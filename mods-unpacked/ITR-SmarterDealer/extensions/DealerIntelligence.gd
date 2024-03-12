extends "res://scripts/DealerIntelligence.gd"

const Bruteforce = preload("res://mods-unpacked/ITR-SmarterDealer/bruteforce.gd") 

var prevBatchIndex = -1
var prevWonRounds = -1
func AlternativeChoice(isPlayer: bool = false, overrideShell = ""):
	if (shellSpawner.sequenceArray.size() == 0):
		return Bruteforce.OPTION_NONE

	if roundManager.playerData.currentBatchIndex != prevBatchIndex:
		Bruteforce.RandomizeDealer()
		prevBatchIndex = roundManager.playerData.currentBatchIndex

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

	if isPlayer:
		if cigarettesP > 0 and roundManager.health_player < startingHealth:
			return Bruteforce.OPTION_CIGARETTES
	else:
		if (cigarettes > 0 and roundManager.health_opponent < startingHealth):
			return Bruteforce.OPTION_CIGARETTES


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
	if overrideShell:
		if overrideShell == "live":
			shell = Bruteforce.MAGNIFYING_LIVE
		elif overrideShell == "blank":
			shell = Bruteforce.MAGNIFYING_BLANK		
	else:
		if knownShell == "live":
			shell = Bruteforce.MAGNIFYING_LIVE
		elif knownShell == "blank":
			shell = Bruteforce.MAGNIFYING_BLANK

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

	var roundType = Bruteforce.ROUNDTYPE_NORMAL
	if roundManager.defibCutterReady && !roundManager.endless:
		roundType = Bruteforce.ROUNDTYPE_WIRECUT
	elif roundManager.playerData.currentBatchIndex == 2:
		roundType = Bruteforce.ROUNDTYPE_DOUBLEORNOTHING

	# Call the static function with the required arguments
	var result = Bruteforce.GetBestChoiceAndDamage(
		roundType,
		liveCount, blankCount,
		player if isPlayer else dealer, dealer if isPlayer else player,
		playerHandcuffState,
		shell,
		roundManager.barrelSawedOff
	)
	ModLoaderLog.info("%s" % result, "ITR-SmarterDealer")

	if prevWonRounds != roundManager.wonRounds:
		prevWonRounds = roundManager.wonRounds
		CommentOnChance(result.deathChance[0], result.deathChance[1])

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
