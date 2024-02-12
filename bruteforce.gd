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

const ROUNDTYPE_NORMAL = 0
const ROUNDTYPE_WIRECUT = 1
const ROUNDTYPE_DOUBLEORNOTHING = 2

class Result:
	var option: int
	var round3Score: float
	var healthScore: float
	var itemScore: float

	func _init(option, round3Score, healthScore, itemScore):
		self.option = option
		self.round3Score = round3Score
		self.healthScore = healthScore
		self.itemScore = itemScore

	func mult(multiplier=-1.0):
		return Result.new(self.option, multiplier*self.round3Score, multiplier*self.healthScore, multiplier*self.itemScore)

	func mutAdd(other: Result):
		self.round3Score += other.round3Score
		self.healthScore += other.healthScore
		self.itemScore += other.itemScore

	func clone():
		return Result.new(self.option, self.round3Score, self.healthScore, self.itemScore)

	func _to_string():
		return "Option %s [%s] [%s] (%s)" % [
			self.option, snapped(self.healthScore, 0.000001), snapped(self.itemScore, 0.000001), snapped(self.round3Score, 0.000001)
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
		var freeScore = falloff(max(8 - totalItems - 4, 0), 2, 0.75)
		return freeScore+self.magnify * 1.5 + self.beer + BruteforcePlayer.falloff(self.handsaw, 2) + BruteforcePlayer.falloff(self.handcuffs, 1) + self.cigarettes * 0.5

	func sum_items_round3():
		var totalItems = self.magnify + self.beer + self.cigarettes + self.handsaw + self.handcuffs
		var freeScore = falloff(max(8 - totalItems - 4, 0), 3)
		return totalItems+freeScore+self.magnify * 1.5 + BruteforcePlayer.falloff(self.beer, 2) - self.cigarettes + BruteforcePlayer.falloff(self.handsaw, 2, -1) + BruteforcePlayer.falloff(self.handcuffs, 1, -0.5)

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

static func RandomizeLethality():
	# How hard the bot should be trying to kill the player
	# 10 is the highest, -1 disables it completely
	round3Lethality = randi_range(-1, 10)

static var printOptions = false
static var round3Lethality = 0
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
	elif round3Lethality == -1:
		roundString = "Normal (DoN)"
	else:
		roundString = "Lethality %s" % round3Lethality

	ModLoaderLog.info("[%s] %s Live, %s Blank\n%s\n%s\n%s, %s, %s" % [roundString, liveCount, blankCount, player, opponent, handcuffState, magnifyingGlassResult, usedHandsaw], "ITR-SmarterDealer")

	var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCountMax, player, opponent, handcuffState, magnifyingGlassResult, usedHandsaw)
	return result

static func GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player: BruteforcePlayer, opponent: BruteforcePlayer, handcuffState=HANDCUFF_NONE, magnifyingGlassResult=MAGNIFYING_NONE, usedHandsaw=false)->Result:
	if player.health <= 0 or opponent.health <= 0:
		var isDead = player.health <= 0
		var deadPlayerIs0 = (player.player_index if isDead else opponent.player_index) == 0

		# Winning player always gets a bonus
		var winningBonus = -10.0 if isDead else 10.0
		# On round 3, prioritize getting items
		var round3Score = player.sum_items_round3() - opponent.sum_items_round3()
		if deadPlayerIs0:
			# If we _can_ kill the player then lethality decides if the ai prioritizes murder or stockpiling
			round3Score += -round3Lethality if isDead else round3Lethality

		return Result.new(OPTION_NONE, round3Score, winningBonus, player.sum_items() - opponent.sum_items())

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

	if cache.has(hash):
		return cache[hash].clone()

	var smokeAmount = min(player.cigarettes, player.max_health - player.health)

	if liveCount == 0:
		var shootWho = OPTION_SHOOT_SELF
		if blankCount == 1 and randi() % 10 < 3:
			shootWho = OPTION_SHOOT_OTHER

		if player.player_index == 0 or blankCount > 0:
			player = player.use("cigarettes", smokeAmount)
		else:
			smokeAmount = 0

		var opponentSmokeAmount = 0
		if opponent.player_index == 0:
			opponentSmokeAmount = min(opponent.cigarettes, opponent.max_health - opponent.health)
			opponent = opponent.use("cigarettes", opponentSmokeAmount)

		var round3Score = player.sum_items_round3() - opponent.sum_items_round3()
		var result = Result.new(shootWho, round3Score, smokeAmount - opponentSmokeAmount, player.sum_items() - opponent.sum_items())
		cache[hash] = result
		return result

	if smokeAmount > 0:
		player = player.use("cigarettes", smokeAmount)
		player.health += smokeAmount

	var options = {
		OPTION_SHOOT_OTHER: Result.new(OPTION_SHOOT_OTHER, 0, 0, 0),
	}
	if not usedHandsaw:
		options[OPTION_SHOOT_SELF] = Result.new(OPTION_SHOOT_SELF, 0, 0, 0)

	if handcuffState <= HANDCUFF_NONE and player.handcuffs > 0 and (roundType == ROUNDTYPE_DOUBLEORNOTHING or (liveCount+blankCount) > 1):
		var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player.use("handcuffs"), opponent, HANDCUFF_CUFFED, magnifyingGlassResult, usedHandsaw)
		options[OPTION_HANDCUFFS] = result

	if magnifyingGlassResult == MAGNIFYING_NONE and player.magnify > 0 and (roundType == ROUNDTYPE_DOUBLEORNOTHING or (liveCount > 0 and blankCount > 0)):
		var blankResult = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player.use("magnify"), opponent, handcuffState, MAGNIFYING_BLANK, usedHandsaw)
		var liveResult = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player.use("magnify"), opponent, handcuffState, MAGNIFYING_LIVE, usedHandsaw)
		options[OPTION_MAGNIFY] = blankResult.mult(blankCount) 
		options[OPTION_MAGNIFY].mutAdd(liveResult.mult(liveCount))
		options[OPTION_MAGNIFY] = options[OPTION_MAGNIFY].mult(1.0/(blankCount + liveCount))

	if not usedHandsaw and player.handsaw > 0 and (roundType == ROUNDTYPE_DOUBLEORNOTHING or liveCount > 0):
		var result = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount, liveCount_max, player.use("handsaw"), opponent, handcuffState, magnifyingGlassResult, true)
		options[OPTION_HANDSAW] = result

	if player.beer > 0:
		options[OPTION_BEER] = Result.new(OPTION_BEER, 0, 0, 0)

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
		var resultIfSelfShootLive = Result.new(0,0,0,0)
		if handcuffState <= HANDCUFF_FREENEXT:
			resultIfShootLife = GetBestChoiceAndDamage_Internal(roundType, liveCount - 1, blankCount, liveCount_max, opponent.use("health", damageToDeal), player)
			if not usedHandsaw:
				resultIfSelfShootLive = GetBestChoiceAndDamage_Internal(roundType, liveCount - 1, blankCount, liveCount_max, opponent, player.use("health", damageToDeal))
			resultIfShootLife = resultIfShootLife.mult(-1.0)
			resultIfSelfShootLive = resultIfSelfShootLive.mult(-1.0)
		else:
			resultIfShootLife = GetBestChoiceAndDamage_Internal(roundType, liveCount - 1, blankCount, liveCount_max, player, opponent.use("health", damageToDeal), HANDCUFF_FREENEXT)
			if not usedHandsaw:
				resultIfSelfShootLive = GetBestChoiceAndDamage_Internal(roundType, liveCount - 1, blankCount, liveCount_max, player.use("health", damageToDeal), opponent, HANDCUFF_FREENEXT)

		resultIfShootLife.healthScore += damageToDeal 
		resultIfSelfShootLive.healthScore -= damageToDeal

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
			options[OPTION_SHOOT_OTHER].mutAdd(resultIfShootBlank.mult(-blankChance))
		else:
			var resultIfShootBlank = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount - 1, liveCount_max, player, opponent, HANDCUFF_FREENEXT, MAGNIFYING_NONE, false)
			options[OPTION_SHOOT_OTHER].mutAdd(resultIfShootBlank.mult(blankChance))

		if player.beer > 0:
			var beerResult = GetBestChoiceAndDamage_Internal(roundType, liveCount, blankCount - 1, liveCount_max, player.use("beer"), opponent, handcuffState, MAGNIFYING_NONE, usedHandsaw)
			options[OPTION_BEER].mutAdd(beerResult.mult(blankChance))

	if printOptions:
		print(options, " (", hash, ")")

	var highestDamage = -10000.0
	var highestItems = -10000.0
	var highestRound3 = -10000.0
	var results: Array[Result] = []

	var potentialEnemyDamage = 2 if opponent.handsaw > 0 else 1
	if opponent.handcuffs > 0:
		potentialEnemyDamage += 2 if opponent.handsaw > 1 else 1

	const EPSILON = 0.00000000000001
	for key in options:
		if usedHandsaw and key == OPTION_SHOOT_SELF:
			# Disallow this for now
			continue

		# We're doing messy stuff, so we want to just override this
		var option = Result.new(key, options[key].round3Score, options[key].healthScore+smokeAmount, options[key].itemScore)

		if roundType == ROUNDTYPE_DOUBLEORNOTHING and not (player.player_index == 0 and player.health <= potentialEnemyDamage) and round3Lethality >= 0:
			# If it's double or nothing then we want to try stockpiling items
			# We assume the player however will still try not to die if it's not in the danger zone:
			if highestRound3 - option.round3Score < EPSILON:
				# Forces it to add this option
				highestDamage = -10000.0
				highestItems = -10000.0
				highestRound3 = option.round3Score
			elif highestRound3 > option.round3Score:
				continue


		if option.healthScore - highestDamage < EPSILON:
			continue

		if option.healthScore - highestDamage > EPSILON or option.itemScore - highestItems > EPSILON:
			results = [option]
			highestDamage = option.healthScore
			highestItems = option.itemScore
			highestRound3 = option.round3Score
			continue

		if option.itemScore - highestItems < EPSILON:
			continue

		results += [option]

	if results.size() == 0:
		print("Error, no valid options!")
		return Result.new(OPTION_NONE, 0, 0, 0)

	if results.size() == 1:
		cache[hash] = results[0]
		return results[0]

	results.shuffle()

	cache[hash] = results[0]

	return results[0]
