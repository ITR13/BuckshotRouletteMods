extends Node

const AUTHORNAME_MODNAME_DIR := "ITR-ShellDisplay"
const AUTHORNAME_MODNAME_LOG_NAME := "ITR-ShellDisplay:Main"

@export var shownLive : Array[Node]
@export var shownBlank : Array[Node]

var mod_dir_path := ""

const ShellSpawner = preload("res://scripts/ShellSpawner.gd") 
const ShellDisplay = preload("res://mods-unpacked/ITR-ShellDisplay/shell_display.gd") 

var shellSpawner: ShellSpawner = null
var shell_display : ShellDisplay
var searchTimer: float = 0.1

func _init() -> void:
	mod_dir_path = ModLoaderMod.get_unpacked_dir()+(AUTHORNAME_MODNAME_DIR)+"/"

func _ready() -> void:
	var shell_display_prefab = load("res://mods-unpacked/ITR-ShellDisplay/shell_display.tscn")
	shell_display = shell_display_prefab.instantiate()
	add_child(shell_display)

	|1
