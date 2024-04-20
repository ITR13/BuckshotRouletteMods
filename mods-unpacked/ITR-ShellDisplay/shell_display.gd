extends Control

@export var shownLive : Array[Node]
@export var shownBlank : Array[Node]

var mod_dir_path := ""

const ShellSpawner = preload("res://scripts/ShellSpawner.gd")
var shellSpawner: Node = null

var searchTimer: float = 0.1
var pastSequenceArrayLength: int = 8

func _process(dt: float) -> void:
	if shellSpawner == null:
		MaybeFindShellSpawner(dt)
	else:
		MaybeUpdateShells()

func MaybeFindShellSpawner(dt: float) -> void:
	searchTimer -= dt
	if searchTimer > 0:
		return
	searchTimer += 1

	var tree = get_tree()
	if tree.current_scene.name != "main":
		return

	shellSpawner = tree.get_root().get_node_or_null("main/standalone managers/shell spawner")
	pastSequenceArrayLength = 8
	for liveIndex in shownLive.size():
		shownLive[liveIndex].visible = false
	for blankIndex in shownBlank.size():
		shownBlank[blankIndex].visible = false

func MaybeUpdateShells() -> void:
	if pastSequenceArrayLength == len(shellSpawner.sequenceArray):
		return

	pastSequenceArrayLength = len(shellSpawner.sequenceArray)

	var live = 0
	var blank = 0
	for shell in shellSpawner.sequenceArray:
		if shell == "live":
			live += 1
		elif shell == "blank":
			blank += 1

	for liveIndex in shownLive.size():
		shownLive[liveIndex].visible = liveIndex < live
	for blankIndex in shownBlank.size():
		shownBlank[blankIndex].visible = blankIndex < blank

