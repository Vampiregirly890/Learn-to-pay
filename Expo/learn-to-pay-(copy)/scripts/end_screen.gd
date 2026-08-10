extends Control

@onready var title_label: Label = %TitleLabel
@onready var reason_label: Label = %ReasonLabel
@onready var summary_label: Label = %SummaryLabel
@onready var again_button: Button = %AgainButton
@onready var menu_button: Button = %MenuButton

func _ready() -> void:
	if GameManager.ended_won:
		title_label.text = "¡Meta alcanzada!"
		title_label.add_theme_color_override("font_color", Color("3DDC97"))
	else:
		title_label.text = "Fin del mes"
		title_label.add_theme_color_override("font_color", Color("F4A261"))

	reason_label.text = GameManager.end_reason
	summary_label.text = "Resumen de tu mes\n\nIngresos totales: %s\nGastos totales: %s\nAhorro apartamento: %s / %s\nDeuda final: %s\nDinero en mano: %s" % [
		GameManager.format_money(GameManager.total_earned),
		GameManager.format_money(GameManager.total_spent),
		GameManager.format_money(GameManager.savings),
		GameManager.format_money(GameManager.GOAL_APARTMENT),
		GameManager.format_money(GameManager.debt),
		GameManager.format_money(GameManager.money),
	]

	again_button.pressed.connect(_on_again)
	menu_button.pressed.connect(_on_menu)

func _on_again() -> void:
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/plaza.tscn")

func _on_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
