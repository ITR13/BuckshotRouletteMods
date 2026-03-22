extends Node

const AUTHORNAME_MODNAME_DIR := "ITR-SmarterDealer"
#const AUTHORNAME_MODNAME_LOG_NAME := "ITR-SmarterDealer:Main"

const hooks = [
	"scripts/DealerIntelligence.gd",
	"scripts/ItemInteraction.gd",
	"scripts/ItemManager.gd"
]

const config_defaults = {
	"comments": true
}

func _init() -> void:
	for hook in hooks:
		ModLoaderMod.install_script_hooks("res://%s" % hook,
			"res://mods-unpacked/%s/%s" % [AUTHORNAME_MODNAME_DIR, hook])

func _ready():
	ModLoader.get_node("MSLaFaver-ModMenu").config_init(AUTHORNAME_MODNAME_DIR, config_defaults)
