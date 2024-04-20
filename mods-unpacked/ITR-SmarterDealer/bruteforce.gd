extends Node

# Constants
const HANDCUFF_NONE = 0
const HANDCUFF_FREENEXT = 1
const HANDCUFF_CUFFED = 2

const MAGNIFYING_NONE = 0
const MAGNIFYING_LIVE = 1
const MAGNIFYING_BLANK = 2

const OPTION_DEALER_RANDOM = -2
const OPTION_NO_DEALER_CHOICE = -1
const OPTION_NONE = 0
const OPTION_SHOOT_SELF = 1
const OPTION_SHOOT_OTHER = 2
const OPTION_MAGNIFY = 3
const OPTION_CIGARETTES = 4
const OPTION_BEER = 5
const OPTION_HANDCUFFS = 6
const OPTION_HANDSAW = 7
const OPTION_MEDICINE = 8

const FREESLOTS_INDEX = 9

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
	[ 0.0, 0.3, 0.6, 0.7, 0.8, 0.9, 0.95, 1.0, 1.05 ], # Expired Medicine
	[ 0.0, 1.0, 2.0, 2.6, 3.0, 3.0, 3.0 , 3.0, 3.0, ], # FreeSlots
]

class Result:
	var option: int
	var deathChance: Array[float]
	var deathChanceNextTurn: Array[float]
	var healthScore: Array[float]
	var itemScore: Array[float]

	func _init(option: int, deathChance, deathChanceNextTurn, healthScore, itemScore):
		self.option = option
		self.deathChance.assign(deathChance)
		self.deathChanceNextTurn.assign(deathChanceNextTurn)
		self.healthScore.assign(healthScore)
		self.itemScore.assign(itemScore)

	func mult(multiplier):
		return Result.new(
			self.option,
			[multiplier*self.deathChance[0], multiplier*self.deathChance[1]],
			[multiplier*self.deathChanceNextTurn[0], multiplier*self.deathChanceNextTurn[1]],
			[multiplier*self.healthScore[0], multiplier*self.healthScore[1]],
			[multiplier*self.itemScore[0], multiplier*self.itemScore[1]]
		)

	func mutAdd(other: Result):
		self.deathChance[0] += other.deathChance[0]
		self.deathChance[1] += other.deathChance[1]
		self.deathChanceNextTurn[0] += other.deathChanceNextTurn[0]
		self.deathChanceNextTurn[1] += other.deathChanceNextTurn[1]
		self.healthScore[0] += other.healthScore[0]
		self.healthScore[1] += other.healthScore[1]
		self.itemScore[0] += other.itemScore[0]
		self.itemScore[1] += other.itemScore[1]

	func clone():
		return self.mult(1)

	func _to_string():
		return "Option %s [%s] [%s] [%s] [%s]" % [
			self.option, self.deathChance, self.deathChanceNextTurn, self.healthScore, self.itemScore
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
	var medicine: int

	func _init(player_index, max_health, max_magnify, max_cigarettes, max_beer, max_handcuffs, max_handsaw, max_medicine):
		self.player_index = player_index

		self.max_health = max_health
		self.health = max_health

		self.max_magnify = max_magnify
		self.max_cigarettes = max_cigarettes
		self.max_beer = max_beer
		self.max_handcuffs = max_handcuffs
		self.max_handsaw = max_handsaw
		self.max_medicine = max_medicine

		self.magnify = max_magnify
		self.cigarettes = max_cigarettes
		self.beer = max_beer
		self.handcuffs = max_handcuffs
		self.handsaw = max_handsaw
		self.medicine = max_medicine

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

		num *= (self.max_medicine+1)
		num += self.medicine

		return num

	func use(item, count=1):
		var new_player = BruteforcePlayer.new(self.player_index, self.max_health, self.max_magnify, self.max_cigarettes, self.max_beer, self.max_handcuffs, self.max_handsaw, self.max_medicine)

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
		if other.magnify > self.max_magnify or other.cigarettes > self.max_cigarettes or other.beer > self.max_beer or other.handcuffs > self.max_handcuffs or other.handsaw > self.max_handsaw or other.medicine > self.max_medicine:
			return null

		var copy = BruteforcePlayer.new(self.player_index, self.max_health, self.max_magnify, self.max_cigarettes, self.max_beer, self.max_handcuffs, self.max_handsaw, self.max_medicine)
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

		# Player 0 can consume cigarettes next turn, so saving them makes you less likely to draw more cigarettes
		var cigaretteMultiplier = 1 if freeSlots < 4 else 2
		var score = 0
		score += itemScoreArray[OPTION_MAGNIFY][self.magnify]
		score += itemScoreArray[OPTION_BEER][self.beer]
		score += itemScoreArray[OPTION_CIGARETTES][self.cigarettes] * cigaretteMultiplier
		score += itemScoreArray[OPTION_HANDSAW][self.handsaw]
		score += itemScoreArray[OPTION_HANDCUFFS][self.handcuffs]
		score += itemScoreArray[FREESLOTS_INDEX][freeSlots]

		return score


	static func falloff(someNum, limit, overmult = 0.5):
		if someNum <= limit:
			return someNum
		return limit + (someNum-limit) * overmult

	func _to_string():
		return JSON.stringify(self._to_dict())

	func _to_dict():
		return {
			"player_index": self.player_index,
			"health": self.health,
			"max_health": self.max_health,
			"magnify": self.magnify,
			"max_magnify": self.max_magnify,
			"cigarettes": self.cigarettes,
			"max_cigarettes": self.max_cigarettes,
			"beer": self.beer,
			"max_beer": self.max_beer,
			"handcuffs": self.handcuffs,
			"max_handcuffs": self.max_handcuffs,
			"handsaw": self.handsaw,
			"max_handsaw": self.max_handsaw,
			"medicine": self.medicine,
			"max_medicine": self.max_medicine
		}

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

	func _to_string():
		return JSON.stringify(self._to_dict())

	func _to_dict():
		return {
			"LiveCount": self.liveCount,
			"BlankCount": self.blankCount,
			"Player": self.player._to_dict(),
			"Dealer": self.opponent._to_dict()
		}

static var printOptions = false
static var cachedGame = null
static var cache = {}
static func GetBestChoiceAndDamage(roundType, liveCount, blankCount, player: BruteforcePlayer, opponent: BruteforcePlayer, handcuffState=HANDCUFF_NONE, magnifyingGlassResult=MAGNIFYING_NONE, usedHandsaw=false):
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
static func Compare(a: float, b: float):
	if abs(a-b) < EPSILON:
		return 0
	return -1 if a < b else 1

static func sum_array(array):
	var sum = 0.0
	for element in array:
		sum += element
	return sum

static func GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player: BruteforcePlayer, opponent: BruteforcePlayer, handcuffState=HANDCUFF_NONE, magnifyingGlassResult=MAGNIFYING_NONE, usedHandsaw=false, isTopLayer=false):
	if player.health <= 0 or opponent.health <= 0:
		var deadPlayerIs0 = (player.player_index if player.health == 0 else opponent.player_index) == 0

		var itemScore: Array[float] = [0.0, 0.0]

		itemScore[player.player_index] = player.sum_items()
		itemScore[opponent.player_index] = opponent.sum_items()

		var deathScore = [1.0, 0.0] if deadPlayerIs0 else [0.0, 1.0]

		var healthScore = [0.0, 0.0]
		healthScore[player.player_index] = player.health
		healthScore[opponent.player_index] = opponent.health

		if not deadPlayerIs0:
			if player.player_index == 0:
				healthScore[0] += min(player.cigarettes, player.max_health - player.health)
			else:
				healthScore[0] += min(opponent.cigarettes, opponent.max_health - opponent.health)

		return Result.new(OPTION_NONE, deathScore, [0.0, 0.0], healthScore, itemScore)

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
	var donLogic = roundType == ROUNDTYPE_DOUBLEORNOTHING and player.player_index == 1

	var smokeAmount = min(player.cigarettes, player.max_health - player.health)

	if liveCount == 0 and blankCount == 0:
		var shootWho = OPTION_SHOOT_SELF
		if blankCount == 1 and randi() % 10 < 3:
			shootWho = OPTION_SHOOT_OTHER

		var playerItemscore = player.sum_items()

		if player.player_index != 0:
			smokeAmount = 0

		var opponentSmokeAmount = 0
		if opponent.player_index == 0:
			opponentSmokeAmount = min(opponent.cigarettes, opponent.max_health - opponent.health)

		var opponentItemscore = opponent.sum_items()

		var health: Array[float] = [0.0, 0.0]
		health[player.player_index] = player.health + smokeAmount
		health[opponent.player_index] = opponent.health + opponentSmokeAmount

		var itemscore: Array[float] = [0.0, 0.0]
		itemscore[player.player_index] = playerItemscore
		itemscore[opponent.player_index] = opponentItemscore


		var dealerDeathChance = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		var playerDeathChance = 0.0

		var startingPlayer = player if player.player_index == 0 else opponent
		var otherPlayer = player if player.player_index == 1 else opponent

		# two shells
		var damageToDeal = 2 if startingPlayer.handsaw > 0 else 1

		if health[1] <= damageToDeal:
			if startingPlayer.handcuffs > 0 or startingPlayer.magnify > 0:
				dealerDeathChance[0] += 1.0
			elif startingPlayer.beer > 0 or health[0] >= 2:
				dealerDeathChance[0] += 0.5

		if startingPlayer.handcuffs == 0 and startingPlayer.magnify == 0 and startingPlayer.beer == 0 and health[0] <= 1:
			playerDeathChance += 0.5

		# 3 shells
		if startingPlayer.magnify >= 2:
			dealerDeathChance[1] += 1
		elif startingPlayer.magnify >= 1:
			if startingPlayer.handcuffs > 0:
				dealerDeathChance[1] += 1.0 if health[1] <= 1 else 2.0 / 3
			elif startingPlayer.beer > 0:
				dealerDeathChance[1] += 2.0 / 3.0
		elif startingPlayer.handcuffs > 0:
			if startingPlayer.beer > 0:
				dealerDeathChance[1] += 2.0 / 3.0 if health[1] <= 1 else 1.0 / 3.0
			elif health[0] >= 2:
				dealerDeathChance[1] += 2.0 / 3.0 if health[1] <= 1 else 1.0 / 3.0
			else:
				playerDeathChance = 1.0 / 3.0
		elif startingPlayer.beer >= 2:
			dealerDeathChance[1] += 1.0 / 3.0
		elif health[0] >= 2:
			dealerDeathChance[1] += 1.0 / 3.0
		else:
			dealerDeathChance[1] += 1.0 / 3.0
			playerDeathChance += 1.0 / 3.0

		if health[1] > damageToDeal:
			dealerDeathChance[1] *= 0


		# 4+ shells
		var handcuffDamageToDeal = damageToDeal
		if startingPlayer.handcuffs > 0:
			handcuffDamageToDeal += 2 if startingPlayer.handsaw >= 2 else 1

		var dealerDamage = 2 if otherPlayer.handsaw > 0 else 1
		if otherPlayer.handcuffs > 0:
			dealerDamage += 2 if otherPlayer.handsaw >= 2 else 1

		for i in range(4, 9):
			var tempLiveShells = i / 2
			var tempBlankShells = i - tempLiveShells
			if health[1] <= damageToDeal:
				if startingPlayer.magnify >= tempBlankShells:
					dealerDeathChance[i-2] += 1
				if startingPlayer.handcuffs > 0 and health[1] <= 1:
					if startingPlayer.magnify >= tempBlankShells - 1:
						dealerDeathChance[i-2] += 1
			elif health[1] <= handcuffDamageToDeal:
				if startingPlayer.magnify >= tempBlankShells + 1:
					dealerDeathChance[i-2] += 1

			if dealerDeathChance[i-2] != 1 and health[0] <= dealerDamage:
				var lastIsLiveChance = tempLiveShells / float(i)
				var secondIsLiveChance = (tempLiveShells-1) / float(i - 1)
				playerDeathChance += lastIsLiveChance * secondIsLiveChance

		var shellChance = 1.0/7.0
		var result = Result.new(shootWho, [0.0, 0.0], [playerDeathChance * shellChance, sum_array(dealerDeathChance) * shellChance], health, itemscore)
		cache[hash] = result

		return result

	if donLogic:
		smokeAmount = 0
	elif smokeAmount > 0:
		player = player.use("cigarettes", smokeAmount)
		player.health += smokeAmount

	var options = {
		OPTION_SHOOT_OTHER: Result.new(OPTION_SHOOT_OTHER, [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0]),
	}
	if not usedHandsaw:
		options[OPTION_SHOOT_SELF] = Result.new(OPTION_SHOOT_SELF, [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0])

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
		options[OPTION_MAGNIFY] = result

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
		options[OPTION_BEER] = Result.new(OPTION_BEER, [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0])

	if player.medicine > 0:
		var goodMedicine = player.use("medicine")
		goodMedicine.health += 2
		var badMedicine = player.use("medicine")
		badMedicine.health -= 1
		var goodResult = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, goodMedicine, opponent, handcuffState, magnifyingGlassResult, usedHandsaw)
		var badResult = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, badMedicine, opponent, handcuffState, magnifyingGlassResult, usedHandsaw)
		goodResult.mutAdd(badResult)
		options[OPTION_MEDICINE] = goodResult.mult(0.5)

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
		var resultIfShootLife = Result.new(0,[0.0, 0.0],[0.0, 0.0],[0.0, 0.0],[0.0, 0.0])
		var resultIfSelfShootLive = Result.new(0,[0.0, 0.0],[0.0, 0.0],[0.0, 0.0],[0.0, 0.0])
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

	if printOptions:
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

		var comparison = CompareCurrent(player.player_index == 0, false, current, option)
		if comparison == 0:
			results.append(option)
			continue

		if comparison < 0:
			continue

		current = option
		results = [current]

	if results.size() <= 1:
		cache[hash] = results[0]
		return results[0]

	results.shuffle()

	cache[hash] = results[0]

	return results[0]


static func RandomizeDealer():
	dealerKillCutoff = randf()
	dealerDeathCutoff = randf()

	print(
		"Randomized dealer!\nkillCutoff %s\ndeathCutoff %s" % [
			dealerKillCutoff, dealerDeathCutoff
		]
	)

static var dealerKillCutoff: float = 0.8
static var dealerDeathCutoff: float = 0.8

# -1 means current is better than other
static func CompareCurrent(isPlayer0: bool, donLogic: bool, current: Result, other: Result):
	if isPlayer0:
		# Lower is better
		var comparison = Compare(
			current.deathChance[0]+current.deathChanceNextTurn[0], 
			other.deathChance[0]+other.deathChanceNextTurn[0]
		)
		if comparison != 0:
			return comparison
		comparison = Compare(
			current.deathChance[0], 
			other.deathChance[0]
		)
		if comparison != 0:
			return comparison

		# Higher is better
		var killComparison = Compare(
			other.deathChance[1] + other.deathChanceNextTurn[1], 
			current.deathChance[1] + current.deathChanceNextTurn[1]
		)
		var killComparison2 = Compare(
			other.deathChance[1], 
			current.deathChance[1]
		)
		if killComparison != 0 and killComparison == killComparison2:
			return killComparison
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
		if not isPlayer0:
			if current.deathChance[0] >= dealerKillCutoff:
				if other.deathChance[0] < dealerKillCutoff:
					return -1
			elif other.deathChance[0] >= dealerKillCutoff:
				return 1
		else:
			# Higher is better
			var killComparison = Compare(other.deathChance[otherIndex], current.deathChance[otherIndex])
			if killComparison != 0:
				return killComparison

		# Higher is better
		var itemComparison = Compare(other.itemScore[otherIndex], current.itemScore[otherIndex])
		if itemComparison != 0:
			return itemComparison

	else:
		# Higher is better
		var killComparison = Compare(other.deathChance[otherIndex], current.deathChance[otherIndex])
		if killComparison != 0:
			return killComparison

		if Compare(other.deathChance[otherIndex], 1.0) >= 0:
			var itemDiff = current.itemScore[myIndex] - current.itemScore[otherIndex]
			var otherItemDiff = other.itemScore[myIndex] - other.itemScore[otherIndex]

			# Higher is better
			var comparison = Compare(otherItemDiff, itemDiff)
			if comparison != 0:
				return comparison

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
