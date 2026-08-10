extends Control

@onready var start_button: Button = %StartButton
@onready var back_button: Button = %BackButton

func _ready() -> void:
	start_button.pressed.connect(_on_start)
	back_button.pressed.connect(_on_back)

func _on_start() -> void:
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/plaza.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
