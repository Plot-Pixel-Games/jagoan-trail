extends Control

func _ready():
	AudioManager.play_music()
	
	var target_position = position
	position = target_position + Vector2(0, 200)

	var tween = create_tween()

	tween.tween_property(
		self,
		"position",
		target_position,
		3
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_play_pressed():
	get_tree().change_scene_to_file("res://scenes/menus/select_level.tscn")

func _on_settings_pressed():
	get_tree().change_scene_to_file('')
	
func _on_quit_pressed():
	get_tree().quit()
