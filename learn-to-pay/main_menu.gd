extends Control

func _on_options_button_pressed():
	get_tree().change_scene_to_file("res://options.tscn")

func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://game.tscn")

func _on_exit_button_pressed():
	get_tree().quit()
