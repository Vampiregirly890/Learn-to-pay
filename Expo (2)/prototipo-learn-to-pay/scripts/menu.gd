extends Control

@onready var play_button: Button = %PlayButton
@onready var how_button: Button = %HowButton
@onready var quit_button: Button = %QuitButton

func _ready() -> void:
	play_button.pressed.connect(_on_play)
	how_button.pressed.connect(_on_how)
	quit_button.pressed.connect(_on_quit)

func _on_play() -> void:
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/plaza.tscn")

func _on_how() -> void:
	get_tree().change_scene_to_file("res://scenes/how_to_play.tscn")

func _on_quit() -> void:
	get_tree().quit()
