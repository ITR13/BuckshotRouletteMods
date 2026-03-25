extends Node

const Bruteforce = preload("res://mods-unpacked/ITR-SmarterDealer/bruteforce.gd")

var dealerIntelligence: DealerIntelligence

var thread_semaphore: Semaphore
var main_semaphore: Semaphore
var thread: Thread
var keep_thread_alive := true
var thread_isPlayer := false
var thread_overrideShell := ""
var thread_choice := Bruteforce.OPTION_NONE
var enable_comments = true

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

var timer = 0.0
var timer_running = false

func _process(delta):
	if timer_running:
		timer += delta

func run_timer(time: float):
	timer = 0.0
	timer_running = true
	while timer < time:
		pass
	timer_running = false

func createPlayer(player_index, itemArray):
	var magnifyingGlasses = 0
	var cigarettes = 0
	var beer = 0
	var handcuffs = 0
	var handsaw = 0
	var medicine = 0
	var inverters = 0
	var burners = 0
	var adrenalines = 0

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
			adrenalines += 1

	return Bruteforce.BruteforcePlayer.new(
		player_index,
		dealerIntelligence.roundManager.roundArray[0].startingHealth,
		magnifyingGlasses, cigarettes, beer, handcuffs, handsaw, medicine, inverters, burners, adrenalines
	)

func playerStateSpaceSizeEstimation(player: Bruteforce.BruteforcePlayer) -> int:
	var result = player.health + 1
	for item in [player.magnify, player.cigarettes, player.beer, player.handcuffs, player.handsaw, player.medicine, player.inverter, player.burner, player.adrenaline]:
		result *= item + 1
	return result

var inverted_shell = false
var adrenaline = false
func AlternativeChoice(isPlayer: bool = false, overrideShell = ""):
	if (dealerIntelligence.shellSpawner.sequenceArray.size() == 0):
		return Bruteforce.OPTION_NONE

	var liveCount = 0
	var blankCount = 0

	var liveUnknown = 0
	var blankUnknown = 0
	for index in range(dealerIntelligence.shellSpawner.sequenceArray.size()):
		var shell = dealerIntelligence.shellSpawner.sequenceArray[index]
		if (shell == "live") != (index == 0 and inverted_shell):
			liveCount += 1
			if not dealerIntelligence.sequenceArray_knownShell[index]:
				liveUnknown += 1
		else:
			blankCount += 1
			if not dealerIntelligence.sequenceArray_knownShell[index]:
				blankUnknown += 1

	var roundType = Bruteforce.ROUNDTYPE_NORMAL
	if dealerIntelligence.roundManager.defibCutterReady and not dealerIntelligence.roundManager.endless:
		roundType = Bruteforce.ROUNDTYPE_WIRECUT
	elif dealerIntelligence.roundManager.playerData.currentBatchIndex == 2:
		roundType = Bruteforce.ROUNDTYPE_DOUBLEORNOTHING

	# Create instances of BruteforcePlayer for player and opponent
	var player = createPlayer(0, dealerIntelligence.itemManager.itemArray_player)
	player.health = dealerIntelligence.roundManager.health_player

	var dealer = createPlayer(1, dealerIntelligence.itemManager.itemArray_dealer)
	dealer.health = dealerIntelligence.roundManager.health_opponent

	# It's not perfect, but it's typically within a factor of 2 when the number of state spaces is high enough to matter.
	var estimatedStateSpace: int = playerStateSpaceSizeEstimation(player) * playerStateSpaceSizeEstimation(dealer) * (liveCount+1) * (blankCount+1)
	ModLoaderLog.info("Estimated state space size: %s" % estimatedStateSpace, "ITR-SmarterDealer")

	# Some probably dumb plays to prevent the AI from spending ages thinking
	# This threshold caps dealer thinking time to ~20 seconds on my machine.
	if estimatedStateSpace > 75000:
		var check = player if isPlayer else dealer
		
		if check.burner > 0:
			return Bruteforce.OPTION_BURNER
		
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
		if dealerIntelligence.dealerKnowsShell or dealerIntelligence.sequenceArray_knownShell[0] or liveUnknown == 0 or blankUnknown == 0:
			shell = Bruteforce.MAGNIFYING_LIVE if dealerIntelligence.shellSpawner.sequenceArray[0] == "live" else Bruteforce.MAGNIFYING_BLANK

	var playerHandcuffState = Bruteforce.HANDCUFF_NONE
	if isPlayer:
		if dealerIntelligence.roundManager.dealerCuffed:
			if dealerIntelligence.dealerAboutToBreakFree:
				playerHandcuffState = Bruteforce.HANDCUFF_FREENEXT
			else:
				playerHandcuffState = Bruteforce.HANDCUFF_CUFFED
	else:
		if dealerIntelligence.roundManager.playerCuffed:
			if dealerIntelligence.roundManager.playerAboutToBreakFree:
				playerHandcuffState = Bruteforce.HANDCUFF_FREENEXT
			else:
				playerHandcuffState = Bruteforce.HANDCUFF_CUFFED


	var tempStates = Bruteforce.TempStates.new()
	tempStates.handcuffState = playerHandcuffState
	tempStates.magnifyingGlassResult = shell
	tempStates.usedHandsaw = dealerIntelligence.roundManager.barrelSawedOff
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
	ModLoaderLog.info.call_deferred("%s" % result, "ITR-SmarterDealer")
	
	if enable_comments:
		CommentOnChance(result.deathChance[0], result.deathChance[1])
	
	# Return the result, you might want to handle the result accordingly
	return result.option

var lastCommentType = ""
func CommentOnChance(playerDeathChance: float, dealerDeathChance: float):
	var commentType: String
	var texts_num

	if playerDeathChance >= 0.65:
		commentType = "PLAYER DANGER"
		texts_num = 17
	elif dealerDeathChance >= 0.65:
		commentType = "DEALER DANGER"
		texts_num = 18
	elif playerDeathChance >= 0.4 and dealerDeathChance >= 0.4:
		commentType = "FIFTY FIFTY"
		texts_num = 13
	else:
		return

	var text_chosen = tr("SMARTERDEALER_%s%s" % [commentType, randi_range(1, texts_num)])
	print(text_chosen)
	if commentType == lastCommentType:
		print("Comment skipped")
		return

	lastCommentType = commentType

	dealerIntelligence.shellLoader.dialogue.ShowText_Forever.call_deferred(text_chosen)
	run_timer(2.3)
	dealerIntelligence.shellLoader.dialogue.HideText.call_deferred()
