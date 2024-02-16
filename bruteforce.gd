extends Node

# Constants
const HANDCUFF_NONE = 0
const HANDCUFF_FREENEXT = 1
const HANDCUFF_CUFFED = 2

const MAGNIFYING_NONE = 0
const MAGNIFYING_LIVE = 1
const MAGNIFYING_BLANK = 2

const OPTION_NONE = 0
const OPTION_SHOOT_SELF = 1
const OPTION_SHOOT_OTHER = 2
const OPTION_MAGNIFY = 3
const OPTION_CIGARETTES = 4
const OPTION_BEER = 5
const OPTION_HANDCUFFS = 6
const OPTION_HANDSAW = 7

const FREESLOTS_INDEX = 8

const ROUNDTYPE_NORMAL = 0
const ROUNDTYPE_WIRECUT = 1
const ROUNDTYPE_DOUBLEORNOTHING = 2

const itemScoreArray = [
	[], [], [], # Skip none, shoot self, shoot other
	# 0    1    2    3    4    5    6     7    8
	[ 0.0, 1.5, 3.0, 3.5, 4.5, 5.0, 6.5 , 6.8, 7.0  ], # Magnify
	[ 0.0, 0.5, 1.0, 1.2, 1.2, 1.2, 1.2 , 1.2, 1.2  ], # Cigarette
	[ 0.0, 1.0, 2.0, 3.0, 3.5, 4.0, 4.25, 4.5, 4.75 ], # Beer
	[ 0.0, 1.2, 2.0, 2.5, 2.6, 2.7, 2.8 , 2.9, 3.0  ], # Handcuff
	[ 0.0, 1.5, 2.6, 3.1, 3.5, 3.6, 3.7 , 3.8, 3.9  ], # Handsaw
	[ 0.0, 1.0, 2.0, 2.6, 3.0, 3.0, 3.0 , 3.0, 3.0, ], # FreeSlots
]

class Result:
	var option: int
	var deathChance: Array[float]
	var healthScore: Array[float]
	var itemScore: Array[float]

	func _init(option: int, deathChance, healthScore, itemScore):
		self.option = option
		self.deathChance.assign(deathChance)
		self.healthScore.assign(healthScore)
		self.itemScore.assign(itemScore)

	func mult(multiplier):
		return Result.new(
			self.option, 
			[multiplier*self.deathChance[0], multiplier*self.deathChance[1]],
			[multiplier*self.healthScore[0], multiplier*self.healthScore[1]],
			[multiplier*self.itemScore[0], multiplier*self.itemScore[1]]
		)

	func mutAdd(other: Result):
		self.deathChance[0] += other.deathChance[0]
		self.deathChance[1] += other.deathChance[1]
		self.healthScore[0] += other.healthScore[0]
		self.healthScore[1] += other.healthScore[1]
		self.itemScore[0] += other.itemScore[0]
		self.itemScore[1] += other.itemScore[1]

	func clone():
		return self.mult(1)

	func _to_string():
		return "Option %s [%s] [%s] [%s]" % [
			self.option, self.deathChance, self.healthScore, self.itemScore
		]

# Player class
class BruteforcePlayer:
	var player_index: int

	var max_health: int
	var health: int

	var max_magnify: int
	var max_cigarettes: int
	var max_beer: int
	var max_handcuffs: int
	var max_handsaw: int

	var magnify: int
	var cigarettes: int
	var beer: int
	var handcuffs: int
	var handsaw: int

	func _init(player_index, max_health, max_magnify, max_cigarettes, max_beer, max_handcuffs, max_handsaw):
		self.player_index = player_index

		self.max_health = max_health
		self.health = max_health

		self.max_magnify = max_magnify
		self.max_cigarettes = max_cigarettes
		self.max_beer = max_beer
		self.max_handcuffs = max_handcuffs
		self.max_handsaw = max_handsaw

		self.magnify = max_magnify
		self.cigarettes = max_cigarettes
		self.beer = max_beer
		self.handcuffs = max_handcuffs
		self.handsaw = max_handsaw

	func hash(num):
		num *= 2
		num += self.player_index

		num *= (self.max_health+1)
		num += self.health

		num *= (self.max_magnify+1)
		num += self.magnify

		num *= (self.max_cigarettes+1)
		num += self.cigarettes

		num *= (self.max_beer+1)
		num += self.beer

		num *= (self.max_handcuffs+1)
		num += self.handcuffs

		num *= (self.max_handsaw+1)
		num += self.handsaw

		return num

	func use(item, count=1):
		var new_player = BruteforcePlayer.new(self.player_index, self.max_health, self.max_magnify, self.max_cigarettes, self.max_beer, self.max_handcuffs, self.max_handsaw)

		# Copy attributes to the new instance
		var found = false
		for attribute in self.get_property_list():
			if not found and attribute["name"] == item:
				found = true
				new_player.set(attribute["name"], self.get(attribute["name"]) - count)
			else:
				new_player.set(attribute["name"], self.get(attribute["name"]))

		if not found and item:
			print("Invalid item:", item)

		return new_player

	func createSubplayer(other: BruteforcePlayer):
		if other.player_index != self.player_index:
			return null
		if other.max_health != self.max_health:
			return null
		if other.magnify > self.max_magnify or other.cigarettes > self.max_cigarettes or other.beer > self.max_beer or other.handcuffs > self.max_handcuffs or other.handsaw > self.max_handsaw:
			return null

		var copy = BruteforcePlayer.new(self.player_index, self.max_health, self.max_magnify, self.max_cigarettes, self.max_beer, self.max_handcuffs, self.max_handsaw)
		copy.health = other.health
		copy.magnify = other.magnify
		copy.cigarettes = other.cigarettes
		copy.beer = other.beer
		copy.handcuffs = other.handcuffs
		copy.handsaw = other.handsaw
		return copy

	func sum_items():
		var totalItems = self.magnify + self.beer + self.cigarettes + self.handsaw + self.handcuffs
		var freeSlots = 8 - totalItems
		
		var score = 0
		score += itemScoreArray[OPTION_MAGNIFY][self.magnify]
		score += itemScoreArray[OPTION_BEER][self.beer]
		score += itemScoreArray[OPTION_CIGARETTES][self.cigarettes]
		score += itemScoreArray[OPTION_HANDSAW][self.handsaw]
		score += itemScoreArray[OPTION_HANDCUFFS][self.handcuffs]
		score += itemScoreArray[FREESLOTS_INDEX][freeSlots]
		
		return score
		

	static func falloff(someNum, limit, overmult = 0.5):
		if someNum <= limit:
			return someNum
		return limit + (someNum-limit) * overmult

	func _to_string():
		return "Player %s: Health=%s/%s, Magnify=%s/%s, Cigarettes=%s/%s, Beer=%s/%s, Handcuffs=%s/%s, Handsaw=%s/%s" % [
			self.player_index, self.health, self.max_health, self.magnify, self.max_magnify, self.cigarettes, self.max_cigarettes, self.beer, self.max_beer, self.handcuffs, self.max_handcuffs, self.handsaw, self.max_handsaw
		]

class BruteforceGame:
	var liveCount: int
	var blankCount: int
	var player: BruteforcePlayer
	var opponent: BruteforcePlayer

	func _init(liveCount, blankCount, player: BruteforcePlayer, opponent: BruteforcePlayer):
		self.liveCount = liveCount
		self.blankCount = blankCount
		self.player = player
		self.opponent = opponent

	func CreateSubPlayers(liveCount, blankCount, player, opponent):
		if liveCount > self.liveCount or blankCount > self.blankCount:
			return null
		if player.player_index == self.player.player_index:
			player = self.player.createSubplayer(player)
			opponent = self.opponent.createSubplayer(opponent)
		else:
			player = self.opponent.createSubplayer(player)
			opponent = self.player.createSubplayer(opponent)

		if player == null or opponent == null:
			return null

		return [player, opponent]

static var printOptions = false
static var cachedGame = null
static var cache = {}
static func GetBestChoiceAndDamage(roundType, liveCount, blankCount, player: BruteforcePlayer, opponent: BruteforcePlayer, handcuffState=HANDCUFF_NONE, magnifyingGlassResult=MAGNIFYING_NONE, usedHandsaw=false)->Result:
	var liveCountMax = liveCount
	if cachedGame != null:
		var subPlayers = cachedGame.CreateSubPlayers(liveCount, blankCount, player, opponent)
		if subPlayers != null:
			player = subPlayers[0]
			opponent = subPlayers[1]
			liveCountMax = cachedGame.liveCount
		else:
			cachedGame = null

	if cachedGame == null:
		cache = {}
		cachedGame = BruteforceGame.new(liveCount, blankCount, player, opponent)

	var roundString
	if roundType == ROUNDTYPE_NORMAL:
		roundString = "Normal"
	elif roundType == ROUNDTYPE_WIRECUT:
		roundString = "WireCut"
	else:
		roundString = "DoN"

	ModLoaderLog.info("[%s] %s Live, %s Blank\n%s\n%s\n%s, %s, %s" % [roundString, liveCount, blankCount, player, opponent, handcuffState, magnifyingGlassResult, usedHandsaw], "ITR-SmarterDealer")

	var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCountMax, player, opponent, handcuffState, magnifyingGlassResult, usedHandsaw, true)
	return result

const EPSILON = 0.00000000000001
static func Compare(a: float, b: float)->int:
	if abs(a-b) < EPSILON:
		return 0
	return -1 if a < b else 1
		
static func GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player: BruteforcePlayer, opponent: BruteforcePlayer, handcuffState=HANDCUFF_NONE, magnifyingGlassResult=MAGNIFYING_NONE, usedHandsaw=false, isTopLayer=false)->Result:
	if player.health <= 0 or opponent.health <= 0:
		var deadPlayerIs0 = (player.player_index if player.health == 0 else opponent.player_index) == 0
		
		var noItemsScore = itemScoreArray[FREESLOTS_INDEX][8]
		var itemScore: Array[float] = [noItemsScore, noItemsScore]
		if roundType == ROUNDTYPE_DOUBLEORNOTHING and not deadPlayerIs0:
			itemScore[player.player_index] = player.sum_items()
			itemScore[opponent.player_index] = opponent.sum_items()
		
		var deathScore = [1.0, 0.0] if deadPlayerIs0 else [0.0, 1.0]
		
		var healthScore = [0.0, 0.0]
		healthScore[player.player_index] = player.health
		healthScore[opponent.player_index] = opponent.health

		return Result.new(OPTION_NONE, deathScore, healthScore, itemScore)

	# On wirecut rounds you can no longer smoke, and your health is set to 1
	if roundType == ROUNDTYPE_WIRECUT:
		if player.health == 2 or (player.health <= 2 and player.cigarettes > 0):
			player = player.use("cigarettes", player.cigarettes)
			player.health = 1
		if opponent.health == 2 or (opponent.health <= 2 and opponent.cigarettes > 0):
			opponent = opponent.use("cigarettes", opponent.cigarettes)
			opponent.health = 1

	var hash = blankCount * (liveCount_max+1) + liveCount
	hash = player.hash(hash)
	hash = opponent.hash(hash)
	hash = ((hash * 3 + handcuffState) * 3 + magnifyingGlassResult ) * 2
	if usedHandsaw:
		hash += 1

	if cache.has(hash) and not isTopLayer:
		return cache[hash].clone()

	# Double or nothing round has special logic
	var donLogic = roundType == ROUNDTYPE_DOUBLEORNOTHING

	var smokeAmount = min(player.cigarettes, player.max_health - player.health)

	if liveCount == 0:
		var shootWho = OPTION_SHOOT_SELF
		if blankCount == 1 and randi() % 10 < 3:
			shootWho = OPTION_SHOOT_OTHER
		
		var playerItemscore = player.sum_items()
		if donLogic and blankCount > 0:
			while player.cigarettes > 0:
				var smokingPlayer = player.use("cigarettes")
				var newItemscore = player.sum_items()
				if newItemscore < playerItemscore:
					break
				player = smokingPlayer
				playerItemscore = newItemscore
	
		if player.player_index != 0:
			smokeAmount = 0

		var opponentSmokeAmount = 0
		if opponent.player_index == 0:
			opponentSmokeAmount = min(opponent.cigarettes, opponent.max_health - opponent.health)

		var opponentItemscore = opponent.sum_items()
		
		var health: Array[float] = [0.0, 0.0]
		health[player.player_index] = player.health
		health[opponent.player_index] = opponent.health
		
		var itemscore: Array[float] = [0.0, 0.0]
		itemscore[player.player_index] = playerItemscore
		itemscore[opponent.player_index] = opponentItemscore
		
		var result = Result.new(shootWho, [0.0, 0.0], health, itemscore)
		cache[hash] = result

		# print("{ OPTION 0: ", result, "} (", hash, ")")

		return result

	if donLogic:
		smokeAmount = 0
	elif smokeAmount > 0:
		player = player.use("cigarettes", smokeAmount)
		player.health += smokeAmount

	var options = {
		OPTION_SHOOT_OTHER: Result.new(OPTION_SHOOT_OTHER, [0.0, 0.0], [0.0, 0.0], [0.0, 0.0]),
	}
	if not usedHandsaw:
		options[OPTION_SHOOT_SELF] = Result.new(OPTION_SHOOT_SELF, [0.0, 0.0], [0.0, 0.0], [0.0, 0.0])

	if handcuffState <= HANDCUFF_NONE and player.handcuffs > 0 and (donLogic or (liveCount+blankCount) > 1):
		var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player.use("handcuffs"), opponent, HANDCUFF_CUFFED, magnifyingGlassResult, usedHandsaw)
		options[OPTION_HANDCUFFS] = result

	if magnifyingGlassResult == MAGNIFYING_NONE and player.magnify > 0 and (donLogic or (liveCount > 0 and blankCount > 0)):
		var blankResult = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player.use("magnify"), opponent, handcuffState, MAGNIFYING_BLANK, usedHandsaw)
		var liveResult = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player.use("magnify"), opponent, handcuffState, MAGNIFYING_LIVE, usedHandsaw)
		options[OPTION_MAGNIFY] = blankResult.mult(blankCount) 
		options[OPTION_MAGNIFY].mutAdd(liveResult.mult(liveCount))
		options[OPTION_MAGNIFY] = options[OPTION_MAGNIFY].mult(1.0/(blankCount + liveCount))
	elif donLogic and player.magnify > 0:
		# Allow wasting magnifying glasses, though you literally never want to do this
		var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player.use("magnify"), opponent, handcuffState, magnifyingGlassResult, usedHandsaw)

	if not usedHandsaw and player.handsaw > 0 and (donLogic or liveCount > 0):
		var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player.use("handsaw"), opponent, handcuffState, magnifyingGlassResult, true)
		options[OPTION_HANDSAW] = result

	if donLogic and player.cigarettes > 0:
		# On double or nothing rounds you might want to waste cigarettes to have them carry over to the next round
		# Technically you might want this even on regular rounds, but it makes the logic messy. Same reason for don-checks above
		var healedPlayer = player.use("cigarettes")
		if healedPlayer.health < healedPlayer.max_health:
			healedPlayer.health += 1
		var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, healedPlayer, opponent, handcuffState, magnifyingGlassResult, usedHandsaw)
		options[OPTION_CIGARETTES] = result

	if player.beer > 0:
		options[OPTION_BEER] = Result.new(OPTION_BEER, [0.0, 0.0], [0.0, 0.0], [0.0, 0.0])

	var liveChance = liveCount / float(liveCount + blankCount)
	var blankChance = blankCount / float(liveCount + blankCount)

	if magnifyingGlassResult == MAGNIFYING_BLANK:
		liveChance = 0.0
		blankChance = 1.0
	elif magnifyingGlassResult == MAGNIFYING_LIVE:
		liveChance = 1.0
		blankChance = 0.0

	var damageToDeal = min(2 if usedHandsaw else 1, opponent.health)

	if liveCount > 0 and magnifyingGlassResult != MAGNIFYING_BLANK:
		var resultIfShootLife
		var resultIfSelfShootLive = Result.new(0,[0.0, 0.0],[0.0, 0.0],[0.0, 0.0])
		if handcuffState <= HANDCUFF_FREENEXT:
			resultIfShootLife = GetBestChoiceAndDamage_Internal(roundType, liveCount - 1, blankCount, liveCount_max, opponent.use("health", damageToDeal), player)
			if not usedHandsaw:
				resultIfSelfShootLive = GetBestChoiceAndDamage_Internal(roundType, liveCount - 1, blankCount, liveCount_max, opponent, player.use("health", damageToDeal))
			resultIfShootLife = resultIfShootLife.clone()
			resultIfSelfShootLive = resultIfSelfShootLive.clone()
		else:
			resultIfShootLife = GetBestChoiceAndDamage_Internal(roundType, liveCount - 1, blankCount, liveCount_max, player, opponent.use("health", damageToDeal), HANDCUFF_FREENEXT)
			if not usedHandsaw:
				resultIfSelfShootLive = GetBestChoiceAndDamage_Internal(roundType, liveCount - 1, blankCount, liveCount_max, player.use("health", damageToDeal), opponent, HANDCUFF_FREENEXT)

		options[OPTION_SHOOT_OTHER].mutAdd(resultIfShootLife.mult(liveChance))
		if not usedHandsaw:
			options[OPTION_SHOOT_SELF].mutAdd(resultIfSelfShootLive.mult(liveChance))

		if player.beer > 0:
			var beerResult = GetBestChoiceAndDamage_Internal(roundType, liveCount - 1, blankCount, liveCount_max, player.use("beer"), opponent, handcuffState, MAGNIFYING_NONE, usedHandsaw)
			options[OPTION_BEER].mutAdd(beerResult.mult(liveChance))

	if blankCount > 0 and magnifyingGlassResult != MAGNIFYING_LIVE:
		if not usedHandsaw:
			var resultIfSelfShootBlank = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount - 1, liveCount_max, player, opponent, handcuffState, MAGNIFYING_NONE, usedHandsaw and player.player_index != 0)
			options[OPTION_SHOOT_SELF].mutAdd(resultIfSelfShootBlank.mult(blankChance))

		if handcuffState <= HANDCUFF_FREENEXT:
			var resultIfShootBlank = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount - 1, liveCount_max, opponent, player)
			options[OPTION_SHOOT_OTHER].mutAdd(resultIfShootBlank.mult(blankChance))
		else:
			var resultIfShootBlank = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount - 1, liveCount_max, player, opponent, HANDCUFF_FREENEXT, MAGNIFYING_NONE, false)
			options[OPTION_SHOOT_OTHER].mutAdd(resultIfShootBlank.mult(blankChance))

		if player.beer > 0:
			var beerResult = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount - 1, liveCount_max, player.use("beer"), opponent, handcuffState, MAGNIFYING_NONE, usedHandsaw)
			options[OPTION_BEER].mutAdd(beerResult.mult(blankChance))

	if printOptions or isTopLayer:
		print(options, " (", hash, ")")

	var current: Result = null
	var results: Array[Result] = []

	for key in options:
		if usedHandsaw and key == OPTION_SHOOT_SELF:
			# Disallow this for now
			continue
			
		var option = options[key].clone()
		option.option = key

		if current == null:
			current = option
			results = [current]
			continue
		
		var comparison = CompareCurrent(player.player_index == 0, donLogic, current, option)
		if comparison == 0:
			results.append(option)
			continue
		
		if comparison < 0:
			continue
		
		current = option
		results = [current]
		
		#current = option
		#results.append(option)
		
		#for i in range(len(results)-1, -1, -1):
		#	if CompareCurrent(player.player_index == 0, donLogic, current, option) < 0:
		#		results.remove_at(i)


	if results.size() <= 1:
		cache[hash] = results[0]
		return results[0]

	results.shuffle()

	cache[hash] = results[0]

	return results[0]


static func RandomizeDealer():
	dealerKillCutoff = 1-pow(randf(), 2)*0.5
	dealerDeathCutoff = 1-pow(randf(), 2)*0.5
	dealerDonItemMargin = 1-pow(randf(), 2)
	dealerKillMargin = 1-pow(randf(), 2)
	
	print(
		"Randomized dealer!\nkillCutoff %s\ndeathCutoff %s\ndealerDonItemMargin %s\ndealerKillMargin %s" % [
			dealerKillCutoff, dealerDeathCutoff, dealerDonItemMargin, dealerKillMargin
		]
	)

static func RandomizePlayer():
	playerDeathSafety = pow(randf(), 2)
	playerDonKillMargin = randf()
	playerHealthMargin = 1-pow(randf(), 2)*0.5
	playerDonHealthMargin = randf() * playerHealthMargin
	print(
		"Randomized player!\nplayerDeathSafety %s\nplayerDonKillMargin %s\nplayerHealthMargin %s\nplayerDonHealthMargin %s" % [
			playerDeathSafety, playerDonKillMargin, playerHealthMargin, playerDonHealthMargin
		]
	)

static var dealerKillCutoff: float = 0.8
static var dealerDeathCutoff: float = 0.8
static var dealerDonItemMargin: float = 0.3
static var dealerKillMargin: float = 0.3

static var playerDeathSafety: float = 0.3
static var playerDonKillMargin: float = 0.8
static var playerDonHealthMargin: float = 0.8
static var playerHealthMargin: float = 0.8


# -1 means current is better than other
static func CompareCurrent(isPlayer0: bool, donLogic: bool, current: Result, other: Result)->int:
	if isPlayer0:
		if current.deathChance[0] > playerDeathSafety:
			# Lower is better
			var comparison = Compare(current.deathChance[0], other.deathChance[0])
			if comparison != 0:
				return comparison
		elif Compare(other.deathChance[0], playerDeathSafety) > 0:
			return -1
	else:
		if current.deathChance[1] > dealerDeathCutoff:
			# Lower is better
			var comparison = Compare(current.deathChance[1], other.deathChance[1])
			if comparison != 0:
				return comparison
		elif Compare(other.deathChance[1], dealerDeathCutoff) > 0:
			return -1

	var myIndex = 0 if isPlayer0 else 1
	var otherIndex = 1 if isPlayer0 else 0

	if donLogic and not isPlayer0:
		if current.deathChance[0] >= dealerKillCutoff:
			if other.deathChance[0] < dealerKillCutoff:
				return -1
		elif other.deathChance[0] >= dealerKillCutoff:
			return 1

		# Higher is better
		var itemComparison = Compare(other.itemScore[1], current.itemScore[1])
		if itemComparison != 0:
			return itemComparison
		
	else:
		# Higher is better
		var killComparison = Compare(other.deathChance[otherIndex], current.deathChance[otherIndex])
		if killComparison != 0:
			return killComparison

	var healthDiff = current.healthScore[myIndex] - current.healthScore[otherIndex]
	var otherHealthDiff = other.healthScore[myIndex] - other.healthScore[otherIndex]

	# Higher is better
	var comparison = Compare(otherHealthDiff, healthDiff)
	if comparison != 0:
		return comparison

	var itemDiff = current.itemScore[myIndex] - current.itemScore[otherIndex]
	var otherItemDiff = other.itemScore[myIndex] - other.itemScore[otherIndex]

	# Higher is better
	return Compare(otherItemDiff, itemDiff)


# -1 means current is better than other
static func CompareAsPlayer0Broken(donLogic: bool, current: Result, other: Result)->int:
	if current.deathChance[0] > playerDeathSafety:
		# Lower is better
		var comparison = Compare(current.deathChance[0], other.deathChance[0])
		if comparison != 0:
			return comparison
	elif Compare(other.deathChance[0], playerDeathSafety) > 0:
		return -1

	# Higher is better
	var killComparison = Compare(other.deathChance[1], current.deathChance[1])
	if killComparison > 0:
		return killComparison
	
	if donLogic and Compare(other.deathChance[1], current.deathChance[1] * playerDonKillMargin) < 0:
		return -1

	# Add 10 to ensure it's positive
	var healthDiff = current.healthScore[0] - current.healthScore[1] + 10
	var otherHealthDiff = other.healthScore[0] - other.healthScore[1] + 10
	
	# Higher is better
	var healthComparison = Compare(otherHealthDiff, healthDiff)
	if healthComparison > 0:
		return healthComparison
	
	if donLogic:
		if Compare(otherHealthDiff, healthDiff * playerDonKillMargin) < 0:
			return -1
	elif Compare(otherHealthDiff, healthDiff * playerHealthMargin) < 0:
		return -1


	# Add 12 to ensure it's positive
	var itemDiff = current.itemScore[0] - current.itemScore[1] + 12
	var otherItemDiff = other.itemScore[0] - other.itemScore[1] + 12
	
	return Compare(otherItemDiff, itemDiff)



# -1 is bad, +1 is good
static func CompareAsDealerBroken(donLogic: bool, current: Result, other: Result)->int:
	if current.deathChance[0] >= dealerKillCutoff:
		if other.deathChance[0] < dealerKillCutoff:
			return -1
	elif other.deathChance[0] >= dealerKillCutoff:
		return 1


	# Add 20 to ensure it's positive
	var itemDiff = current.itemScore[1] - current.itemScore[0] + 20
	var otherItemDiff = other.itemScore[1] - other.itemScore[0] + 20
	
	if donLogic:
		var itemComparison = Compare(otherItemDiff, itemDiff)
		if itemComparison > 0:
			return itemComparison
		
		if Compare(otherItemDiff, itemDiff * dealerDonItemMargin) < 0:
			return 0
	else:
		# Higher is better
		var killComparison = Compare(other.deathChance[0], current.deathChance[0])
		if killComparison > 0:
			return killComparison
		
		if donLogic and Compare(other.deathChance[0], current.deathChance[0] * dealerKillMargin) < 0:
			return -1

	var healthDiff = current.healthScore[1] - current.healthScore[0]
	var otherHealthDiff = other.healthScore[1] - other.healthScore[0]

	# Higher is better
	var healthComparison = Compare(otherHealthDiff, healthDiff)
	if healthComparison != 0:
		return healthComparison

	return Compare(otherItemDiff, itemDiff)
