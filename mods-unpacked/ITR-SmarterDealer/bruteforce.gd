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
const OPTION_INVERTER = 9
const OPTION_BURNER = 10
const OPTION_ADRENALINE = 11

const FREESLOTS_INDEX = 12

const ROUNDTYPE_NORMAL = 0
const ROUNDTYPE_WIRECUT = 1
const ROUNDTYPE_DOUBLEORNOTHING = 2

const itemScoreArray = [
	[], [], [], # Skip none, shoot self, shoot other
	# 0    1    2    3    4    5    6     7    8
	[ 0.0, 1.5, 3.0, 4.0 , 4.5, 5.0 , 6.5 , 6.8, 7.0  ], # Magnify
	[ 0.0, 0.5, 1.0, 1.2 , 1.2, 1.2 , 1.2 , 1.2, 1.2  ], # Cigarette
	[ 0.0, 1.0, 2.0, 3.0 , 3.5, 4.0 , 4.25, 4.5, 4.75 ], # Beer
	[ 0.0, 1.2, 2.0, 2.5 , 2.6, 2.7 , 2.8 , 2.9, 3.0  ], # Handcuff
	[ 0.0, 1.5, 2.6, 3.1 , 3.5, 3.6 , 3.7 , 3.8, 3.9  ], # Handsaw
	[ 0.0, 0.3, 0.6, 0.7 , 0.8, 0.9 , 0.95, 1.0, 1.05 ], # Expired Medicine
	[ 0.0, 1.2, 2.4, 3.3 , 3.7, 4.1 , 4.5 , 4.9, 5.4  ], # Inverter
	[ 0.0, 1.4, 2.8, 2.75, 2.7, 2.65, 2.6 , 2.5, 2.4  ], # Burner Phone
	[ 0.0, 2.0, 4.0, 5.5 , 7.0, 8.0 , 9.0 , 9.5, 10   ], # Adrenaline
	[ 0.0, 1.0, 2.0, 2.6 , 3.0, 3.0 , 3.0 , 3.0, 3.0, ], # FreeSlots
]

class Result:
	var option: int
	var deathChance: Array[float]
	var deathChanceNextTurn: Array[float]
	var healthScore: Array[float]
	var itemScore: Array[float]

	@warning_ignore("shadowed_variable")
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

	func clone()->Result:
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
	var max_medicine: int
	var max_inverter: int
	var max_burner: int
	var max_adrenaline: int

	var magnify: int
	var cigarettes: int
	var beer: int
	var handcuffs: int
	var handsaw: int
	var medicine: int
	var inverter: int
	var burner: int
	var adrenaline: int

	@warning_ignore("shadowed_variable")
	func _init(player_index: int, max_health: int, max_magnify: int, max_cigarettes: int, max_beer: int, max_handcuffs: int, max_handsaw: int, max_medicine: int, max_inverter: int, max_burner: int, max_adrenaline: int):
		self.player_index = player_index

		self.max_health = max_health
		self.health = max_health

		self.max_magnify = max_magnify
		self.max_cigarettes = max_cigarettes
		self.max_beer = max_beer
		self.max_handcuffs = max_handcuffs
		self.max_handsaw = max_handsaw
		self.max_medicine = max_medicine
		self.max_inverter = max_inverter
		self.max_burner = max_burner
		self.max_adrenaline = max_adrenaline

		self.magnify = max_magnify
		self.cigarettes = max_cigarettes
		self.beer = max_beer
		self.handcuffs = max_handcuffs
		self.handsaw = max_handsaw
		self.medicine = max_medicine
		self.inverter = max_inverter
		self.burner = max_burner
		self.adrenaline = max_adrenaline

	func do_hash(num: int)->int:
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

		num *= (self.max_inverter+1)
		num += self.inverter

		num *= (self.max_burner+1)
		num += self.burner

		num *= (self.max_adrenaline+1)
		num += self.adrenaline

		return num

	func use(item, count=1)->BruteforcePlayer:
		var new_player = BruteforcePlayer.new(self.player_index, self.max_health, self.max_magnify, self.max_cigarettes, self.max_beer, self.max_handcuffs, self.max_handsaw, self.max_medicine, self.max_inverter, self.max_burner, self.max_adrenaline)

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

	func createSubplayer(other: BruteforcePlayer)->BruteforcePlayer:
		if other.player_index != self.player_index:
			return null
		if other.max_health != self.max_health:
			return null
		if other.magnify > self.max_magnify or other.cigarettes > self.max_cigarettes or other.beer > self.max_beer or other.handcuffs > self.max_handcuffs or other.handsaw > self.max_handsaw or other.medicine > self.max_medicine or other.inverter > self.max_inverter or other.burner > self.max_burner:
			return null

		var copy = BruteforcePlayer.new(self.player_index, self.max_health, self.max_magnify, self.max_cigarettes, self.max_beer, self.max_handcuffs, self.max_handsaw, self.max_medicine, self.max_inverter, self.max_burner, self.max_adrenaline)
		copy.health = other.health
		copy.magnify = other.magnify
		copy.cigarettes = other.cigarettes
		copy.beer = other.beer
		copy.handcuffs = other.handcuffs
		copy.handsaw = other.handsaw
		copy.medicine = other.medicine
		copy.inverter = other.inverter
		copy.burner = other.burner
		copy.adrenaline = other.adrenaline
		return copy

	func sum_items()->int:
		var totalItems = self.count_items()
		var freeSlots = 8 - totalItems

		# Player 0 can consume cigarettes next turn, so saving them makes you less likely to draw more cigarettes
		var cigaretteMultiplier = 1 if freeSlots < 4 else 2
		var score: int = 0
		score += itemScoreArray[OPTION_MAGNIFY][self.magnify]
		score += itemScoreArray[OPTION_BEER][self.beer]
		score += itemScoreArray[OPTION_CIGARETTES][self.cigarettes] * cigaretteMultiplier
		score += itemScoreArray[OPTION_HANDSAW][self.handsaw]
		score += itemScoreArray[OPTION_HANDCUFFS][self.handcuffs]
		score += itemScoreArray[OPTION_MEDICINE][self.medicine]
		score += itemScoreArray[OPTION_INVERTER][self.inverter]
		score += itemScoreArray[OPTION_BURNER][self.burner]
		score += itemScoreArray[OPTION_ADRENALINE][self.adrenaline]
		score += itemScoreArray[FREESLOTS_INDEX][freeSlots]

		return score

	func count_items()->int:
		return self.magnify + self.beer + self.cigarettes + self.handsaw + self.handcuffs + self.medicine + self.inverter + self.burner + self.adrenaline

	func _to_string():
		return JSON.stringify(self._to_dict())

	func _to_dict():
		var dict = {
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
			"max_medicine": self.max_medicine,
			"inverter": self.inverter,
			"max_inverter": self.max_inverter,
			"burner": self.burner,
			"max_burner": self.max_burner,
			"adrenaline": self.adrenaline,
			"max_adrenaline": self.max_adrenaline
		}
		for key in dict.keys():
			if dict[key] == 0:
				dict.erase(key)
		return dict

class BruteforceGame:
	var liveCount: int
	var blankCount: int
	var player: BruteforcePlayer
	var opponent: BruteforcePlayer

	@warning_ignore("shadowed_variable")
	func _init(liveCount, blankCount, player: BruteforcePlayer, opponent: BruteforcePlayer):
		self.liveCount = liveCount
		self.blankCount = blankCount
		self.player = player
		self.opponent = opponent

	@warning_ignore("shadowed_variable")
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

class TempStates:
	var handcuffState := HANDCUFF_NONE
	var magnifyingGlassResult := MAGNIFYING_NONE
	var usedHandsaw := false
	var inverted := false
	var adrenaline := false
	var futureLive := 0
	var futureBlank := 0

	func clone()->TempStates:
		var other: TempStates = TempStates.new()
		other.handcuffState = self.handcuffState
		other.magnifyingGlassResult = self.magnifyingGlassResult
		other.usedHandsaw = self.usedHandsaw
		other.inverted = self.inverted
		other.adrenaline = self.adrenaline
		other.futureLive = self.futureLive
		other.futureBlank = self.futureBlank
		return other

	func Cuff()->TempStates:
		var other: TempStates = self.clone()
		other.handcuffState = HANDCUFF_CUFFED
		other.adrenaline = false
		return other

	func Magnify(result)->TempStates:
		var other: TempStates = self.clone()
		other.magnifyingGlassResult = result
		other.adrenaline = false
		return other

	func Saw()->TempStates:
		var other: TempStates = self.clone()
		other.usedHandsaw = true
		other.adrenaline = false
		return other

	func Adrenaline()->TempStates:
		var other: TempStates = self.clone()
		other.adrenaline = true
		return other

	func Invert()->TempStates:
		var other: TempStates = self.clone()
		other.inverted = not other.inverted
		other.adrenaline = false
		return other

	func SkipBullet()->TempStates:
		var other: TempStates = self.clone()
		other.inverted = false
		other.magnifyingGlassResult = MAGNIFYING_NONE
		other.adrenaline = false
		other.futureLive = 0
		other.futureBlank = 0
		return other

	func Future(live, blank)->TempStates:
		var other: TempStates = self.clone()
		other.futureLive += live
		other.futureBlank += blank
		other.adrenaline = false
		return other

	func Cigarettes()->TempStates:
		var other: TempStates = self.clone()
		other.adrenaline = false
		return other


	func do_hash(num: int, liveCount_max: int)->int:
		num = ((num * 3 + self.handcuffState) * 3 + self.magnifyingGlassResult) * 4
		if self.usedHandsaw:
			num += 2
		if self.inverted:
			num += 1
		num *= liveCount_max
		num += self.futureLive
		num *= (liveCount_max+1)
		num += self.futureBlank

		return num

	func _to_string():
		return JSON.stringify(self._to_dict())

	func _to_dict():
		return {
			"HandcuffState": self.handcuffState,
			"MagnifyingGlassResult": self.magnifyingGlassResult,
			"UsedHandsaw": self.usedHandsaw,
			"Inverted": self.inverted,
			"Adrenaline": self.adrenaline,
			"Future Live": self.futureLive,
			"Future Blank": self.futureBlank,
		}

static var printOptions = false
static var cachedGame: BruteforceGame = null
static var cache = {}
static func GetBestChoiceAndDamage(roundType: int, liveCount: int, blankCount: int, player: BruteforcePlayer, opponent: BruteforcePlayer, tempStates: TempStates):
	var liveCountMax := liveCount
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

	ModLoaderLog.info("[%s] %s Live, %s Blank\n%s\n%s\n%s" % [roundString, liveCount, blankCount, player, opponent, tempStates], "ITR-SmarterDealer")

	var result := GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCountMax, player, opponent, tempStates, true)
	return result

const EPSILON = 0.00000000000001
static func Compare(a: float, b: float)->int:
	if abs(a-b) < EPSILON:
		return 0
	return -1 if a < b else 1

static func sum_array(array)->float:
	var sum := 0.0
	for element in array:
		sum += element
	return sum

static func GetBestChoiceAndDamage_Internal(roundType: int, liveCount: int, blankCount: int, liveCount_max: int, player: BruteforcePlayer, opponent: BruteforcePlayer, tempStates: TempStates, isTopLayer:=false)->Result:
	if player.health <= 0 or opponent.health <= 0:
		var deadPlayerIs0 = (player.player_index if player.health == 0 else opponent.player_index) == 0

		var itemScore: Array[float] = [0.0, 0.0]

		itemScore[player.player_index] = player.sum_items()
		itemScore[opponent.player_index] = opponent.sum_items()

		var deathScore := [1.0, 0.0] if deadPlayerIs0 else [0.0, 1.0]

		var healthScore: Array[float] = [0.0, 0.0]
		healthScore[player.player_index] = float(player.health)
		healthScore[opponent.player_index] = float(opponent.health)

		if not deadPlayerIs0:
			if player.player_index == 0:
				healthScore[0] += float(min(player.cigarettes, player.max_health - player.health))
			else:
				healthScore[0] += float(min(opponent.cigarettes, opponent.max_health - opponent.health))

		return Result.new(OPTION_NONE, deathScore, [0.0, 0.0], healthScore, itemScore)

	# On wirecut rounds you can no longer smoke, and your health is set to 1
	if roundType == ROUNDTYPE_WIRECUT:
		if player.health == 2 or (player.health <= 2 and player.cigarettes > 0):
			player = player.use("cigarettes", player.cigarettes)
			player.health = 1
		if opponent.health == 2 or (opponent.health <= 2 and opponent.cigarettes > 0):
			opponent = opponent.use("cigarettes", opponent.cigarettes)
			opponent.health = 1

	var ahash: int = blankCount * (liveCount_max+1) + liveCount
	ahash = player.do_hash(ahash)
	ahash = opponent.do_hash(ahash)
	ahash = tempStates.do_hash(ahash, liveCount_max)

	if cache.has(ahash) and not isTopLayer:
		return cache[ahash].clone()

	# Double or nothing round has special logic
	var donLogic = roundType == ROUNDTYPE_DOUBLEORNOTHING and player.player_index == 1

	if liveCount == 0 and blankCount == 0:
		var playerItemscore := player.sum_items()

		var smokeAmount: int = min(player.cigarettes, player.max_health - player.health)
		if player.player_index != 0:
			smokeAmount = 0

		var opponentSmokeAmount := 0
		if opponent.player_index == 0:
			opponentSmokeAmount = min(opponent.cigarettes, opponent.max_health - opponent.health)

		var opponentItemscore := opponent.sum_items()

		var health: Array[float] = [0.0, 0.0]
		health[player.player_index] = player.health + smokeAmount
		health[opponent.player_index] = opponent.health + opponentSmokeAmount

		var itemscore: Array[float] = [0.0, 0.0]
		itemscore[player.player_index] = playerItemscore
		itemscore[opponent.player_index] = opponentItemscore

		var dealerDeathChance: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
		var playerDeathChance: float = 0.0

		var startingPlayer = player if player.player_index == 0 else opponent
		var otherPlayer = player if player.player_index == 1 else opponent

		# two shells
		var damageToDeal: int = 2 if startingPlayer.handsaw > 0 else 1

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
			@warning_ignore("integer_division")
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
		var result = Result.new(OPTION_NONE, [0.0, 0.0], [playerDeathChance * shellChance, sum_array(dealerDeathChance) * shellChance], health, itemscore)

		cache[ahash] = result

		return result


	var liveChance := 0.0
	var blankChance := 0.0

	if tempStates.magnifyingGlassResult == MAGNIFYING_BLANK:
		liveChance = 0.0
		blankChance = 1.0
	elif tempStates.magnifyingGlassResult == MAGNIFYING_LIVE:
		liveChance = 1.0
		blankChance = 0.0
	else:
		var total := float(liveCount + blankCount - tempStates.futureLive - tempStates.futureBlank)
		liveChance = (liveCount-tempStates.futureLive) / total
		blankChance = (blankCount-tempStates.futureBlank) / total

	var originalRemove := 1
	var invertedRemove := 0
	if tempStates.inverted:
		var temp = liveChance
		liveChance = blankChance
		blankChance = temp
		originalRemove = 0
		invertedRemove = 1

	# Some hard-coded kills to speed up:
	if player.player_index == 1:
		if opponent.health == 1 or (opponent.health == 2 and (tempStates.usedHandsaw or player.handsaw > 0 or (opponent.handsaw > 0 and player.adrenaline > 0))):
			var toSteal = 0
			if opponent.health == 2 and not tempStates.usedHandsaw and player.handsaw == 0:
				toSteal = 1

			if liveChance >= 1:
				if opponent.health == 2 and not tempStates.usedHandsaw:
					if player.handsaw == 0 and opponent.handsaw > 0 and player.adrenaline > 0 and not tempStates.adrenaline:
						var result := GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player.use("adrenaline"), opponent, tempStates.Adrenaline())
						result.option = OPTION_ADRENALINE
						cache[ahash] = result
						return result
					var a = player
					var b = opponent
					if tempStates.adrenaline:
						b = b.use("handsaw")
					else:
						a = a.use("handsaw")
					var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates.Saw())
					result.option = OPTION_HANDSAW
					cache[ahash] = result
					return result

				var result = GetBestChoiceAndDamage_Internal(roundType, liveCount - originalRemove, blankCount - invertedRemove, liveCount_max, opponent.use("health", opponent.health), player, TempStates.new())
				result = result.clone()
				result.option = OPTION_SHOOT_OTHER
				cache[ahash] = result
				return result
			elif blankChance >= 1:
				if player.inverter > 0 or (opponent.inverter > 0 and tempStates.adrenaline):
					var a = player
					var b = opponent
					if tempStates.adrenaline:
						b = b.use("inverter")
					else:
						a = a.use("inverter")
					var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates.Invert())
					result.option = OPTION_INVERTER
					cache[ahash] = result
					return result
				elif opponent.inverter > 0 and player.adrenaline > toSteal:
					var result := GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player.use("adrenaline"), opponent, tempStates.Adrenaline())
					result.option = OPTION_ADRENALINE
					cache[ahash] = result
					return result
			elif (player.magnify > 0 or (tempStates.adrenaline and opponent.magnify > 0)) and (player.inverter > 0 or (opponent.inverter > 0 and player.adrenaline > toSteal)):
				var a = player
				var b = opponent
				if tempStates.adrenaline:
					b = b.use("magnify")
				else:
					a = a.use("magnify")
				var blankResult = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates.Magnify(MAGNIFYING_BLANK))
				var liveResult = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates.Magnify(MAGNIFYING_LIVE))
				var result = blankResult.mult(blankChance)
				result.mutAdd(liveResult.mult(liveChance))
				result.option = OPTION_MAGNIFY
				cache[ahash] = result
				return result
			elif (opponent.magnify > 0 and player.inverter > 0 and player.adrenaline > toSteal) or (opponent.magnify > 0 and opponent.inverter > 0 and player.adrenaline >= toSteal+2):
				var result := GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player.use("adrenaline"), opponent, tempStates.Adrenaline())
				result.option = OPTION_ADRENALINE
				cache[ahash] = result
				return result

	var options: Dictionary = {
		OPTION_SHOOT_OTHER: Result.new(OPTION_SHOOT_OTHER, [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0]),
	}
	if not tempStates.usedHandsaw:
		options[OPTION_SHOOT_SELF] = Result.new(OPTION_SHOOT_SELF, [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0])

	var itemFrom = opponent if tempStates.adrenaline else player

	if tempStates.handcuffState <= HANDCUFF_NONE and itemFrom.handcuffs > 0 and (donLogic or (liveCount+blankCount) > 1):
		var a = player
		var b = opponent
		if tempStates.adrenaline:
			b = b.use("handcuffs")
		else:
			a = a.use("handcuffs")
		var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates.Cuff())
		options[OPTION_HANDCUFFS] = result

	if itemFrom.cigarettes > 0 and (player.health < player.max_health or donLogic):
		# On double or nothing rounds you might want to waste cigarettes to have them carry over to the next round
		# Technically you might want this even on regular rounds, but it makes the logic messy. Same reason for don-checks above
		var healedPlayer := player.use("cigarettes", 0 if tempStates.adrenaline else 1)
		var healedOpponent := opponent.use("cigarettes", 1 if tempStates.adrenaline else 0)
		if healedPlayer.health < healedPlayer.max_health:
			healedPlayer.health += 1
		var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, healedPlayer, healedOpponent, tempStates.Cigarettes())
		options[OPTION_CIGARETTES] = result

	if itemFrom.beer > 0:
		options[OPTION_BEER] = Result.new(OPTION_BEER, [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0])

	# Dealer isn't allowed to eat medicine on 1 health left... for some reason
	if player.medicine > 0 and not tempStates.adrenaline and (player.player_index == 0 or player.health > 1):
		var goodMedicine := player.use("medicine")
		goodMedicine.health += 2
		if goodMedicine.health > goodMedicine.max_health:
			goodMedicine.health = goodMedicine.max_health
		var badMedicine := player.use("medicine")
		badMedicine.health -= 1
		var goodResult := GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, goodMedicine, opponent, tempStates)
		var badResult := GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, badMedicine, opponent, tempStates)
		goodResult.mutAdd(badResult)
		options[OPTION_MEDICINE] = goodResult.mult(0.5)

	if itemFrom.inverter > 0:
		var a = player
		var b = opponent
		if tempStates.adrenaline:
			b = b.use("inverter")
		else:
			a = a.use("inverter")
		var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates.Invert())
		options[OPTION_INVERTER] = result


	if not tempStates.usedHandsaw and itemFrom.handsaw > 0 and (donLogic or liveChance > 0):
		var a = player
		var b = opponent
		if tempStates.adrenaline:
			b = b.use("handsaw")
		else:
			a = a.use("handsaw")
		var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates.Saw())
		options[OPTION_HANDSAW] = result

	if not tempStates.adrenaline and player.adrenaline > 0 and ((opponent.magnify+opponent.burner > 0 and liveChance > 0 and blankChance > 0 and tempStates.magnifyingGlassResult == MAGNIFYING_NONE) or opponent.beer > 0 or (opponent.handcuffs > 0 and (liveCount + blankCount > 1) and tempStates.handcuffState == HANDCUFF_NONE) or (opponent.handsaw > 0 and not tempStates.usedHandsaw and liveChance > 0) or opponent.inverter > 0 or (opponent.cigarettes > 0 and player.health <= 2 and player.max_health > player.health)):
		var result := GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player.use("adrenaline"), opponent, tempStates.Adrenaline())
		options[OPTION_ADRENALINE] = result
		if result.option == OPTION_NONE:
			print("Bad adrenaline pathing: ", liveCount, " ", blankCount, "\n", player, "\n", opponent, "\n", tempStates, "\n")


	if tempStates.magnifyingGlassResult == MAGNIFYING_NONE and itemFrom.magnify > 0 and (liveChance > 0 and blankChance > 0):
		var a = player
		var b = opponent
		if tempStates.adrenaline:
			b = b.use("magnify")
		else:
			a = a.use("magnify")
		var blankResult = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates.Magnify(MAGNIFYING_BLANK))
		var liveResult = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates.Magnify(MAGNIFYING_LIVE))
		options[OPTION_MAGNIFY] = blankResult.mult(blankChance)
		options[OPTION_MAGNIFY].mutAdd(liveResult.mult(liveChance))
	elif donLogic and itemFrom.magnify > 0:
		var a = player
		var b = opponent
		if tempStates.adrenaline:
			b = b.use("magnify")
		else:
			a = a.use("magnify")
		# Allow wasting magnifying glasses, though you literally never want to do this
		var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates)
		options[OPTION_MAGNIFY] = result


	if itemFrom.burner > 0 and tempStates.magnifyingGlassResult == MAGNIFYING_NONE and liveChance > 0 and blankChance > 0:
		var a = player
		var b = opponent
		if tempStates.adrenaline:
			b = b.use("burner")
		else:
			a = a.use("burner")

		# There are 4 possible scenarios:
		# Hit an unseen live (live - futureLive) / total
		# Hit an unseen blank (blank - futureBlank) / total
		# Hit an already seen live (futureLive / total)
		# Hit an already seen blank (futureBlank / total)

		var bTotal := float(blankCount+liveCount)
		var bMissChance := (tempStates.futureBlank+tempStates.futureLive) / bTotal
		var bLiveChance := (liveCount - tempStates.futureLive) / bTotal
		var bBlankChance := (blankCount - tempStates.futureBlank) / bTotal

		options[OPTION_BURNER] = Result.new(OPTION_BURNER, [0.0, 0.0], [0.0, 0.0], [0.0, 0.0], [0.0, 0.0])

		if bMissChance > 0:
			var missResult = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates)
			options[OPTION_BURNER].mutAdd(missResult.mult(bMissChance))
		if bLiveChance > 0:
			var liveResult = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates.Future(0, 1))
			options[OPTION_BURNER].mutAdd(liveResult.mult(bLiveChance))
		if bBlankChance > 0:
			var blankResult = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, a, b, tempStates.Future(1, 0))
			options[OPTION_BURNER].mutAdd(blankResult.mult(bBlankChance))

	var damageToDeal := int(min(2 if tempStates.usedHandsaw else 1, opponent.health))

	var beerPlayer = player
	var beerOpponent = opponent
	if tempStates.adrenaline:
		beerOpponent = beerOpponent.use("beer")
	else:
		beerPlayer = beerPlayer.use("beer")

	if liveChance > 0:
		var resultIfShootLife := Result.new(-1,[-9.0, -9.0],[-9.0, -9.0],[-9.0, -9.0],[-9.0, -9.0])
		var resultIfSelfShootLive := Result.new(-1,[-9.0, -9.0],[-9.0, -9.0],[-9.0, -9.0],[-9.0, -9.0])
		if tempStates.handcuffState <= HANDCUFF_FREENEXT:
			resultIfShootLife = GetBestChoiceAndDamage_Internal(roundType, liveCount - originalRemove, blankCount - invertedRemove, liveCount_max, opponent.use("health", damageToDeal), player, TempStates.new())
			if not tempStates.usedHandsaw:
				resultIfSelfShootLive = GetBestChoiceAndDamage_Internal(roundType, liveCount - originalRemove, blankCount - invertedRemove, liveCount_max, opponent, player.use("health", damageToDeal), TempStates.new())
			resultIfShootLife = resultIfShootLife.clone()
			resultIfSelfShootLive = resultIfSelfShootLive.clone()
		else:
			var newTempState := TempStates.new()
			newTempState.handcuffState = HANDCUFF_FREENEXT
			resultIfShootLife = GetBestChoiceAndDamage_Internal(roundType, liveCount - originalRemove, blankCount - invertedRemove, liveCount_max, player, opponent.use("health", damageToDeal), newTempState)
			if not tempStates.usedHandsaw:
				resultIfSelfShootLive = GetBestChoiceAndDamage_Internal(roundType, liveCount - originalRemove, blankCount - invertedRemove, liveCount_max, player.use("health", damageToDeal), opponent, newTempState)

		options[OPTION_SHOOT_OTHER].mutAdd(resultIfShootLife.mult(liveChance))

		if not tempStates.usedHandsaw:
			options[OPTION_SHOOT_SELF].mutAdd(resultIfSelfShootLive.mult(liveChance))

		if itemFrom.beer > 0:
			var beerResult = GetBestChoiceAndDamage_Internal(roundType, liveCount - originalRemove, blankCount - invertedRemove, liveCount_max, beerPlayer, beerOpponent, tempStates.SkipBullet())
			options[OPTION_BEER].mutAdd(beerResult.mult(liveChance))

	if blankChance > 0:
		if not tempStates.usedHandsaw:
			var resultIfSelfShootBlank := GetBestChoiceAndDamage_Internal(roundType, liveCount - invertedRemove, blankCount - originalRemove, liveCount_max, player, opponent, tempStates.SkipBullet())
			options[OPTION_SHOOT_SELF].mutAdd(resultIfSelfShootBlank.mult(blankChance))

		if tempStates.handcuffState <= HANDCUFF_FREENEXT:
			var resultIfShootBlank := GetBestChoiceAndDamage_Internal(roundType, liveCount - invertedRemove, blankCount - originalRemove, liveCount_max, opponent, player, TempStates.new())
			options[OPTION_SHOOT_OTHER].mutAdd(resultIfShootBlank.mult(blankChance))
		else:
			var newTempState := TempStates.new()
			newTempState.handcuffState = HANDCUFF_FREENEXT
			var resultIfShootBlank = GetBestChoiceAndDamage_Internal(roundType, liveCount - invertedRemove, blankCount - originalRemove, liveCount_max, player, opponent, newTempState)
			options[OPTION_SHOOT_OTHER].mutAdd(resultIfShootBlank.mult(blankChance))

		if itemFrom.beer > 0:
			var beerResult = GetBestChoiceAndDamage_Internal(roundType, liveCount - invertedRemove, blankCount - originalRemove, liveCount_max, beerPlayer, beerOpponent, tempStates.SkipBullet())
			options[OPTION_BEER].mutAdd(beerResult.mult(blankChance))

	if printOptions and isTopLayer:
		print(options, " (", ahash, ")")
		# print(player, " ", opponent, " ", tempStates)

	var current: Result = null
	var results: Array[Result] = []

	for key in options:
		if (tempStates.usedHandsaw or tempStates.adrenaline) and key == OPTION_SHOOT_SELF:
			# Disallow this for now
			continue

		if tempStates.adrenaline and key == OPTION_SHOOT_OTHER:
			# Easier than not traveling down the path
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

	if results.size() <= 0:
		print("Oops! Bad pathing! Probably adrenaline's fault again!:\n", options)
		results = [Result.new(
			OPTION_NONE,
			[-100, 100],
			[-100, 100],
			[100, -100],
			[100, -100]
		)]

	if results.size() <= 1:
		cache[ahash] = results[0]
		return results[0]

	results.shuffle()

	cache[ahash] = results[0]

	return results[0]


static func RandomizeDealer():
	dealerKillCutoff = randf()
	dealerDeathCutoff = randf()

	ModLoaderLog.info(
		"Randomized dealer!\nkillCutoff %s\ndeathCutoff %s" % [
			dealerKillCutoff, dealerDeathCutoff
		],
		"ITR-SmarterDealer"
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
	var comparison := Compare(otherHealthDiff, healthDiff)
	if comparison != 0:
		return comparison

	var itemDiff = current.itemScore[myIndex] - current.itemScore[otherIndex]
	var otherItemDiff = other.itemScore[myIndex] - other.itemScore[otherIndex]

	# Higher is better
	return Compare(otherItemDiff, itemDiff)
