extends Node2D

## Plaza top-down: el jugador camina y decide en cada edificio.

enum UiMode { NONE, INTRO, HOUSE, WORK_JOB, WORK_OT, PAYMENTS, SHOP, BANK, TIP }

var ui_mode: UiMode = UiMode.NONE
var selected_job: Dictionary = {}

@onready var player: CharacterBody2D = %Player
@onready var hud_week: Label = %WeekLabel
@onready var hud_money: Label = %MoneyLabel
@onready var hud_savings: Label = %SavingsLabel
@onready var hud_debt: Label = %DebtLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var panel: PanelContainer = %DecisionPanel
@onready var phase_title: Label = %PhaseTitle
@onready var phase_body: RichTextLabel = %PhaseBody
@onready var choices: VBoxContainer = %Choices
@onready var tip_panel: PanelContainer = %TipPanel
@onready var tip_label: Label = %TipLabel
@onready var hint_label: Label = %HintLabel

func _ready() -> void:
	randomize()
	GameManager.state_changed.connect(_refresh_hud)
	player.interaction_requested.connect(_on_interaction)
	_refresh_hud()
	if not GameManager.intro_done:
		_open_intro()
	else:
		_close_ui()

func _refresh_hud() -> void:
	hud_week.text = "Semana %d / %d" % [mini(GameManager.week, GameManager.TOTAL_WEEKS), GameManager.TOTAL_WEEKS]
	hud_money.text = "Dinero: %s" % GameManager.format_money(GameManager.money)
	hud_savings.text = "Ahorro depto: %s / %s" % [
		GameManager.format_money(GameManager.savings),
		GameManager.format_money(GameManager.GOAL_APARTMENT),
	]
	hud_debt.text = "Deuda: %s" % GameManager.format_money(GameManager.debt)
	progress_bar.value = GameManager.progress_ratio() * 100.0

func _set_player_locked(locked: bool) -> void:
	player.can_move = not locked

func _clear_choices() -> void:
	for child in choices.get_children():
		child.queue_free()

func _add_choice(text: String, callback: Callable, disabled: bool = false) -> void:
	var btn := Button.new()
	btn.text = text
	btn.disabled = disabled
	btn.custom_minimum_size = Vector2(0, 42)
	btn.pressed.connect(callback)
	choices.add_child(btn)

func _open_panel(title: String, body: String) -> void:
	panel.visible = true
	tip_panel.visible = false
	phase_title.text = title
	phase_body.text = body
	_clear_choices()
	_set_player_locked(true)

func _close_ui() -> void:
	ui_mode = UiMode.NONE
	panel.visible = false
	_clear_choices()
	_set_player_locked(false)
	hint_label.text = "A/D caminar · Espacio/W saltar · E / Enter entrar a edificios"

func _on_interaction(building_id: String) -> void:
	if ui_mode != UiMode.NONE:
		return
	match building_id:
		"house":
			_open_house()
		"work":
			_open_work()
		"payments":
			_open_payments()
		"shop":
			_open_shop()
		"bank":
			_open_bank()
		_:
			pass

func _open_intro() -> void:
	ui_mode = UiMode.INTRO
	_open_panel(
		"Bienvenido al barrio",
		"Tu meta: juntar [b]%s[/b] en [b]4 semanas[/b] para el depósito del apartamento.\n\nCamina de lado por la calle (como un platformer). Cada edificio es una decisión financiera.\nEl [b]orden importa[/b]: si ahorras antes de trabajar, tendrás menos; si duermes sin pagar, crece la deuda.\n\n[i]A/D para moverte · Espacio para saltar · E para entrar.[/i]" % GameManager.format_money(GameManager.GOAL_APARTMENT)
	)
	_add_choice("Salir a la plaza", func() -> void:
		GameManager.intro_done = true
		_close_ui()
	)

func _open_house() -> void:
	ui_mode = UiMode.HOUSE
	var pending := GameManager.unpaid_essentials_summary()
	var pending_text := "Ninguno (todo al día)"
	if not pending.is_empty():
		pending_text = ""
		for item in pending:
			pending_text += "\n• " + item
	var work_text := "Sí (%s, %s)" % [GameManager.last_job_name, GameManager.format_money(GameManager.week_income)] if GameManager.worked else "Aún no"
	_open_panel(
		"Casa",
		"Aquí descansas y cierras la semana.\n\nTrabajo esta semana: [b]%s[/b]\nPendientes:\n%s\n\nSi duermes con gastos sin pagar, se convierten en [b]deuda[/b]." % [work_text, pending_text]
	)
	_add_choice("Dormir y pasar de semana", _sleep_week)
	_add_choice("Seguir en la plaza", _close_ui)

func _sleep_week() -> void:
	var tip := GameManager.resolve_unpaid_on_sleep()
	ui_mode = UiMode.TIP
	_open_panel("Aprendizaje de la semana", "Antes de continuar, revisa esta idea:")
	tip_panel.visible = true
	tip_label.text = tip
	_add_choice("Continuar", _after_tip)

func _after_tip() -> void:
	# Victoria si ya se alcanzó la meta
	if GameManager.savings >= GameManager.GOAL_APARTMENT:
		GameManager.check_end_conditions()
		get_tree().change_scene_to_file("res://scenes/end_screen.tscn")
		return

	# Derrota por deuda / arriendo tras resolver impagos
	var result := GameManager.check_end_conditions()
	if result != "":
		get_tree().change_scene_to_file("res://scenes/end_screen.tscn")
		return

	# Fin del mes (semana 4 dormida)
	if GameManager.week >= GameManager.TOTAL_WEEKS:
		GameManager.week += 1
		GameManager.check_end_conditions()
		get_tree().change_scene_to_file("res://scenes/end_screen.tscn")
		return

	GameManager.start_new_week_after_sleep()
	_close_ui()

func _open_work() -> void:
	if GameManager.worked:
		ui_mode = UiMode.WORK_JOB
		_open_panel(
			"Trabajo",
			"Ya trabajaste esta semana como [b]%s[/b] y cobraste [b]%s[/b].\n\nSolo puedes cobrar una vez por semana. Vuelve el próximo ciclo." % [
				GameManager.last_job_name,
				GameManager.format_money(GameManager.week_income),
			]
		)
		_add_choice("Volver a la plaza", _close_ui)
		return

	ui_mode = UiMode.WORK_JOB
	_open_panel("Trabajo", "Elige cómo ganar dinero esta semana. El orden libre importa: si aún no pagaste gastos, este ingreso te puede salvar.")
	for job in GameManager.JOBS:
		var label: String
		if job["min"] == job["max"]:
			label = "%s — %s" % [job["name"], GameManager.format_money(job["min"])]
		else:
			label = "%s — %s a %s" % [job["name"], GameManager.format_money(job["min"]), GameManager.format_money(job["max"])]
		var job_copy: Dictionary = job
		_add_choice(label, func() -> void: _pick_job(job_copy))
	_add_choice("Salir sin trabajar", _close_ui)

func _pick_job(job: Dictionary) -> void:
	selected_job = job
	var income := GameManager.apply_job(job)
	ui_mode = UiMode.WORK_OT
	_open_panel(
		"¿Horas extra?",
		"Cobraste [b]%s[/b] por [b]%s[/b].\n\nLas horas extra suben tu ingreso, pero pueden generar un gasto de cansancio la próxima semana." % [
			GameManager.format_money(income),
			job["name"],
		]
	)
	_add_choice("Sí, horas extra (+$300 a $550)", _do_overtime)
	_add_choice("No, cuidar energía", func() -> void: _close_ui())

func _do_overtime() -> void:
	var extra := GameManager.apply_overtime()
	var fatigue_note := "Puede aparecer un gasto por cansancio la próxima semana." if GameManager.pending_fatigue_cost > 0 else "Esta vez no hubo costo extra de cansancio."
	_open_panel(
		"Horas extra hechas",
		"Sumaste [b]%s[/b]. Total de la semana laboral: [b]%s[/b].\n\n%s" % [
			GameManager.format_money(extra),
			GameManager.format_money(GameManager.week_income),
			fatigue_note,
		]
	)
	_clear_choices()
	_add_choice("Volver a la plaza", _close_ui)

func _open_payments() -> void:
	ui_mode = UiMode.PAYMENTS
	_refresh_payments_panel()

func _refresh_payments_panel() -> void:
	var lines := "Oficina de pagos · arriendo, servicios y deuda.\n\n"
	lines += "• Arriendo %s — %s\n" % [GameManager.format_money(GameManager.rent_amount()), "Pagado" if GameManager.rent_paid else "Pendiente"]
	lines += "• Luz y agua %s — %s\n" % [GameManager.format_money(GameManager.utils_amount()), "Pagado" if GameManager.utils_paid else "Pendiente"]
	if GameManager.surprise_amount > 0:
		lines += "• Imprevisto %s — %s\n" % [GameManager.format_money(GameManager.surprise_amount), "Pagado" if GameManager.surprise_paid else "Pendiente"]
	if GameManager.fatigue_amount > 0:
		lines += "• Cansancio (extra previa) %s — %s\n" % [GameManager.format_money(GameManager.fatigue_amount), "Pagado" if GameManager.fatigue_paid else "Pendiente"]
	if GameManager.debt > 0:
		lines += "• Deuda acumulada: %s\n" % GameManager.format_money(GameManager.debt)
	lines += "\nDinero disponible: [b]%s[/b]" % GameManager.format_money(GameManager.money)
	_open_panel("Pagos / Servicios", lines)

	if not GameManager.rent_paid:
		_add_choice("Pagar arriendo (%s)" % GameManager.format_money(GameManager.rent_amount()), func() -> void:
			if GameManager.pay_from_money(GameManager.rent_amount()):
				GameManager.rent_paid = true
				GameManager.state_changed.emit()
			_refresh_payments_panel()
		)
	if not GameManager.utils_paid:
		_add_choice("Pagar luz y agua (%s)" % GameManager.format_money(GameManager.utils_amount()), func() -> void:
			if GameManager.pay_from_money(GameManager.utils_amount()):
				GameManager.utils_paid = true
				GameManager.state_changed.emit()
			_refresh_payments_panel()
		)
	if GameManager.surprise_amount > 0 and not GameManager.surprise_paid:
		_add_choice("Pagar imprevisto (%s)" % GameManager.format_money(GameManager.surprise_amount), func() -> void:
			if GameManager.pay_from_money(GameManager.surprise_amount):
				GameManager.surprise_paid = true
				GameManager.state_changed.emit()
			_refresh_payments_panel()
		)
	if GameManager.fatigue_amount > 0 and not GameManager.fatigue_paid:
		_add_choice("Pagar cansancio (%s)" % GameManager.format_money(GameManager.fatigue_amount), func() -> void:
			if GameManager.pay_from_money(GameManager.fatigue_amount):
				GameManager.fatigue_paid = true
				GameManager.state_changed.emit()
			_refresh_payments_panel()
		)
	if GameManager.debt > 0:
		var abono := mini(GameManager.debt, 500)
		_add_choice("Abonar deuda (%s)" % GameManager.format_money(abono), func() -> void:
			GameManager.pay_debt(abono)
			_refresh_payments_panel()
		)
	_add_choice("Volver a la plaza", _close_ui)

func _open_shop() -> void:
	ui_mode = UiMode.SHOP
	_refresh_shop_panel()

func _refresh_shop_panel() -> void:
	var lines := "Mercado · comida y transporte.\n\n"
	lines += "• Comida %s — %s%s\n" % [
		GameManager.format_money(GameManager.food_amount()),
		"Pagado" if GameManager.food_paid else "Pendiente",
		" (recortada)" if GameManager.food_cut else "",
	]
	lines += "• Transporte %s — %s\n" % [GameManager.format_money(GameManager.transport_amount()), "Pagado" if GameManager.transport_paid else "Pendiente"]
	lines += "\nDinero disponible: [b]%s[/b]" % GameManager.format_money(GameManager.money)
	_open_panel("Tienda / Mercado", lines)

	if not GameManager.food_paid:
		_add_choice("Pagar comida (%s)" % GameManager.format_money(GameManager.food_amount()), func() -> void:
			if GameManager.pay_from_money(GameManager.food_amount()):
				GameManager.food_paid = true
				GameManager.state_changed.emit()
			_refresh_shop_panel()
		)
		if not GameManager.food_cut:
			_add_choice("Recortar comida a $200", func() -> void:
				GameManager.food_cut = true
				GameManager.state_changed.emit()
				_refresh_shop_panel()
			)
	if not GameManager.transport_paid:
		_add_choice("Pagar transporte (%s)" % GameManager.format_money(GameManager.transport_amount()), func() -> void:
			if GameManager.pay_from_money(GameManager.transport_amount()):
				GameManager.transport_paid = true
				GameManager.state_changed.emit()
			_refresh_shop_panel()
		)
	_add_choice("Volver a la plaza", _close_ui)

func _open_bank() -> void:
	ui_mode = UiMode.BANK
	_open_panel(
		"Banco",
		"Mueve dinero de tu mano al [b]ahorro del apartamento[/b].\n\nDisponible: [b]%s[/b]\nAhorro: [b]%s[/b] / [b]%s[/b]\n\nSi vienes antes de trabajar, podrás ahorrar menos. El orden es parte del aprendizaje." % [
			GameManager.format_money(GameManager.money),
			GameManager.format_money(GameManager.savings),
			GameManager.format_money(GameManager.GOAL_APARTMENT),
		]
	)
	var half := GameManager.money / 2
	_add_choice("Ahorrar todo (%s)" % GameManager.format_money(GameManager.money), func() -> void:
		GameManager.transfer_to_savings(GameManager.money)
		_check_win_or_close()
	, GameManager.money <= 0)
	_add_choice("Ahorrar la mitad (%s)" % GameManager.format_money(half), func() -> void:
		GameManager.transfer_to_savings(half)
		_check_win_or_close()
	, half <= 0)
	_add_choice("No mover dinero ahora", _close_ui)

func _check_win_or_close() -> void:
	if GameManager.savings >= GameManager.GOAL_APARTMENT:
		GameManager.check_end_conditions()
		get_tree().change_scene_to_file("res://scenes/end_screen.tscn")
		return
	_close_ui()

