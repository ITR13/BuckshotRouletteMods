extends Control

@export var comment_toggle: CheckButton

const id = "ITR-SmarterDealer"
const id_modmenu = "MSLaFaver-ModMenu"

var speaker_press: AudioStreamPlayer2D

func _ready():
	var config = ModLoaderConfig.get_config(id, "user")
	if config != null:
		var data = config.data
		comment_toggle.button_pressed = data.get("comments")
	
	comment_toggle.toggled.connect(_on_toggled_comments)
	
	speaker_press = get_node("/root/menu/speaker_press")
	
	var toggle_off_image = Image.load_from_file("res://mods-unpacked/%s/assets/toggle-off.png" % id_modmenu)
	var toggle_off_texture = ImageTexture.create_from_image(toggle_off_image)
	var toggle_on_image = Image.load_from_file("res://mods-unpacked/%s/assets/toggle-on.png" % id_modmenu)
	var toggle_on_texture = ImageTexture.create_from_image(toggle_on_image)
	
	for toggle in [comment_toggle]:
		toggle.add_theme_icon_override("unchecked", toggle_off_texture)
		toggle.add_theme_icon_override("unchecked_disabled", toggle_off_texture)
		toggle.add_theme_icon_override("checked", toggle_on_texture)
		toggle.add_theme_icon_override("checked_disabled", toggle_on_texture)
	
func _on_toggled_comments(enabled: bool):
	update_config("comments", enabled)
	speaker_press.play()

func update_config(config_name: String, config_value):
	var config = ModLoaderConfig.get_config(id, "user")
	if config != null:
		config.data[config_name] = config_value
		ModLoaderConfig.update_config(config)
