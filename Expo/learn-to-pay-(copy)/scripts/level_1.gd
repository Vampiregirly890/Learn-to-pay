extends Control

enum Phase { INTRO, JOB, OVERTIME, BILLS, SAVE, TIP, WEEK_END }

const JOBS := [
	{
		"id": "part",
		"name": "Medio tiempo",
		"desc": "Ingreso seguro y bajo. Ideal si quieres estabilidad.",
		"min": 900,
		"max": 900,
	},
	{
		"id": "full",
		"name": "Tiempo completo",
		"desc": "Buen equilibrio entre esfuerzo e ingreso.",
		"min": 1500,
		"max": 1500,
	},
	{
		"id": "freelance",
		"name": "Freelance",
		"desc": "Puede pagar más… o menos. Enseña incertidumbre.",
		"min": 1100,
		"max": 2100,
	},
]

var phase: Phase = Phase.INTRO
var selected_job: Dictionary = {}
var week_income: int = 0
var did_overtime: bool = false
var bills: Array[Dictionary] = []
var current_tip: String = ""
var food_cut: bool = false
var week_lesson: String = ""

@onready var week_label: Label = %WeekLabel
@onready var money_label: Label = %MoneyLabel
@onready var savings_label: Label = %SavingsLabel
@onready var debt_label: Label = %DebtLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var phase_title: Label = %PhaseTitle
@onready var phase_body: RichTextLabel = %PhaseBody
@onready var choices: VBoxContainer = %Choices
@onready var tip_panel: PanelContainer = %TipPanel
@onready var tip_label: Label = %TipLabel

func _ready() -> void:
	randomize()
	GameManager.state_changed.connect(_refresh_hud)
	_refresh_hud()
	_set_phase(Phase.INTRO)

func _refresh_hud() -> void:
	week_label.text = "Semana %d / %d" % [mini(GameManager.week, GameManager.TOTAL_WEEKS), GameManager.TOTAL_WEEKS]
	money_label.text = "Dinero: %s" % GameManager.format_money(GameManager.money)
	savings_label.text = "Ahorro depto: %s / %s" % [
		GameManager.format_money(GameManager.savings),
		GameManager.format_money(GameManager.GOAL_APARTMENT),
	]
	debt_label.text = "Deuda: %s" % GameManager.format_money(GameManager.debt)
	progress_bar.value = GameManager.progress_ratio() * 100.0

func _clear_choices() -> void:
	for child in choices.get_children():
		child.queue_free()

func _add_choice(text: String, callback: Callable, disabled: bool = false) -> void:
	var btn := Button.new()
	btn.text = text
	btn.disabled = disabled
	btn.custom_minimum_size = Vector2(0, 44)
	btn.pressed.connect(callback)
	choices.add_child(btn)

func _set_phase(next: Phase) -> void:
	phase = next
	_clear_choices()
	tip_panel.visible = false

	match phase:
		Phase.INTRO:
			_show_intro()
		Phase.JOB:
			_show_jobs()
		Phase.OVERTIME:
			_show_overtime()
		Phase.BILLS:
			_build_bills()
			_show_bills()
		Phase.SAVE:
			_show_save()
		Phase.TIP:
			_show_tip()
		Phase.WEEK_END:
			_finish_week()

func _show_intro() -> void:
	phase_title.text = "Tu meta"
	phase_body.text = "Tienes [b]4 semanas[/b] para juntar [b]%s[/b] (depósito del apartamento).\n\nCada semana eliges trabajo, gestionas gastos reales (arriendo, servicios, comida…) y decides cuánto ahorrar.\n\n[i]Consejo:[/i] paga primero lo esencial y deja un colchón para imprevistos." % GameManager.format_money(GameManager.GOAL_APARTMENT)
	_add_choice("Empezar semana 1", func() -> void: _set_phase(Phase.JOB))

func _show_jobs() -> void:
	phase_title.text = "Elige tu trabajo"
	phase_body.text = "Tu ingreso de esta semana depende de la opción que elijas."
	for job in JOBS:
		var label: String
		if job["min"] == job["max"]:
			label = "%s — %s" % [job["name"], GameManager.format_money(job["min"])]
		else:
			label = "%s — %s a %s" % [job["name"], GameManager.format_money(job["min"]), GameManager.format_money(job["max"])]
		var job_copy: Dictionary = job
		_add_choice(label, func() -> void: _pick_job(job_copy))

func _pick_job(job: Dictionary) -> void:
	selected_job = job
	week_income = randi_range(job["min"], job["max"])
	GameManager.last_job_name = job["name"]
	GameManager.add_income(week_income)
	current_tip = "Elegiste %s y ganaste %s esta semana." % [job["name"], GameManager.format_money(week_income)]
	_set_phase(Phase.OVERTIME)

func _show_overtime() -> void:
	phase_title.text = "¿Horas extra?"
	phase_body.text = "Ya cobraste [b]%s[/b] por [b]%s[/b].\n\nLas horas extra aumentan tu ingreso, pero también el riesgo de gastos por cansancio o imprevistos." % [
		GameManager.format_money(week_income),
		selected_job.get("name", "tu trabajo"),
	]
	_add_choice("Sí, hacer horas extra (+$300 a $550)", _do_overtime)
	_add_choice("No, cuidar mi energía", _skip_overtime)

func _do_overtime() -> void:
	did_overtime = true
	var extra := randi_range(300, 550)
	GameManager.add_income(extra)
	week_income += extra
	# 55% chance of fatigue cost next week
	if randf() < 0.55:
		GameManager.pending_fatigue_cost = randi_range(100, 220)
		current_tip = "Hiciste horas extra (+%s). Ojo: el cansancio puede generar gastos extra la próxima semana." % GameManager.format_money(extra)
	else:
		GameManager.pending_fatigue_cost = 0
		current_tip = "Hiciste horas extra y sumaste %s sin costos adicionales. ¡Buen cálculo!" % GameManager.format_money(extra)
	_set_phase(Phase.BILLS)

func _skip_overtime() -> void:
	did_overtime = false
	GameManager.pending_fatigue_cost = 0
	current_tip = "Priorizaste descanso. A veces cuidar tu energía también es una decisión financiera inteligente."
	_set_phase(Phase.BILLS)

func _build_bills() -> void:
	bills.clear()
	food_cut = false
	bills.append({"id": "rent", "name": "Arriendo", "amount": 650, "priority": "alta", "paid": false, "skippable": true, "cut": false})
	bills.append({"id": "utils", "name": "Luz y agua", "amount": 180, "priority": "alta", "paid": false, "skippable": true, "cut": false})
	bills.append({"id": "food", "name": "Comida", "amount": 320, "priority": "media", "paid": false, "skippable": true, "cut": false, "cut_to": 200})
	bills.append({"id": "transport", "name": "Transporte", "amount": 120, "priority": "media", "paid": false, "skippable": true, "cut": false})

	if GameManager.pending_fatigue_cost > 0:
		bills.append({
			"id": "fatigue",
			"name": "Gasto por cansancio (horas extra previas)",
			"amount": GameManager.pending_fatigue_cost,
			"priority": "media",
			"paid": false,
			"skippable": true,
			"cut": false,
		})
		GameManager.pending_fatigue_cost = 0

	if randf() < 0.30:
		bills.append({
			"id": "surprise",
			"name": "Imprevisto",
			"amount": randi_range(150, 350),
			"priority": "variable",
			"paid": false,
			"skippable": true,
			"cut": false,
		})

	if GameManager.debt > 0:
		bills.append({
			"id": "debt_pay",
			"name": "Abonar deuda acumulada",
			"amount": mini(GameManager.debt, 500),
			"priority": "alta",
			"paid": false,
			"skippable": true,
			"cut": false,
			"is_debt": true,
		})

func _unpaid_total() -> int:
	var total := 0
	for bill in bills:
		if not bill["paid"]:
			total += int(bill["amount"])
	return total

func _show_bills() -> void:
	phase_title.text = "Gastos de la semana"
	var lines := "Paga lo que puedas. Lo esencial primero.\n\n"
	for bill in bills:
		var status := "✓ Pagado" if bill["paid"] else "Pendiente"
		lines += "• [b]%s[/b] — %s (%s) — prioridad %s\n" % [
			bill["name"],
			GameManager.format_money(bill["amount"]),
			status,
			bill["priority"],
		]
	lines += "\nDinero disponible: [b]%s[/b]" % GameManager.format_money(GameManager.money)
	phase_body.text = lines

	for i in bills.size():
		var bill: Dictionary = bills[i]
		if bill["paid"]:
			continue
		var idx := i
		_add_choice("Pagar %s (%s)" % [bill["name"], GameManager.format_money(bill["amount"])], func() -> void: _pay_bill(idx))
		if bill.get("id", "") == "food" and not bill.get("cut", false):
			_add_choice("Recortar comida a $200", func() -> void: _cut_food(idx))

	_add_choice("Continuar (dejar pendientes)", _resolve_unpaid_and_continue)

func _pay_bill(index: int) -> void:
	var bill: Dictionary = bills[index]
	if bill["paid"]:
		return
	var amount: int = bill["amount"]
	if bill.get("is_debt", false):
		if GameManager.money < amount:
			phase_body.text += "\n\n[color=#F4A261]No te alcanza para abonar esa parte de la deuda.[/color]"
			return
		GameManager.pay_debt(amount)
		bill["paid"] = true
		bills[index] = bill
		_show_bills()
		return

	if GameManager.pay_from_money(amount):
		bill["paid"] = true
		bills[index] = bill
		if bill.get("id", "") == "rent":
			GameManager.missed_rent = 0
		_show_bills()
	else:
		phase_body.text += "\n\n[color=#F4A261]No te alcanza para pagar esto ahora.[/color]"

func _cut_food(index: int) -> void:
	var bill: Dictionary = bills[index]
	bill["amount"] = int(bill.get("cut_to", 250))
	bill["cut"] = true
	bill["name"] = "Comida (recortada)"
	bills[index] = bill
	food_cut = true
	current_tip = "Recortar comida ayuda al corto plazo, pero no siempre es sostenible. Busca equilibrio."
	_show_bills()

func _resolve_unpaid_and_continue() -> void:
	week_lesson = ""
	for bill in bills:
		if bill["paid"]:
			continue
		var amount: int = bill["amount"]
		if bill.get("is_debt", false):
			continue
		GameManager.add_debt(amount)
		if bill.get("id", "") == "rent":
			GameManager.add_debt(GameManager.RENT_PENALTY)
			GameManager.missed_rent += 1
			week_lesson = "No pagar el arriendo genera deuda y una multa. La vivienda suele ser prioridad #1."

	if week_lesson == "":
		if food_cut:
			week_lesson = "Recortar comida ayuda al corto plazo, pero cuida tu bienestar. El ahorro también necesita equilibrio."
		elif current_tip != "":
			week_lesson = current_tip
		else:
			week_lesson = "Pagar a tiempo evita deudas. Cada peso que no se va en atrasos puede ir a tu meta."

	_set_phase(Phase.SAVE)

func _show_save() -> void:
	phase_title.text = "Ahorro para el apartamento"
	phase_body.text = "Después de cubrir gastos, decide cuánto mover de tu dinero en mano al [b]ahorro del apartamento[/b].\n\nDinero disponible: [b]%s[/b]\nAhorro actual: [b]%s[/b]\nMeta: [b]%s[/b]\n\nTip: dejar un poco en mano ayuda ante imprevistos." % [
		GameManager.format_money(GameManager.money),
		GameManager.format_money(GameManager.savings),
		GameManager.format_money(GameManager.GOAL_APARTMENT),
	]

	var half := GameManager.money / 2
	_add_choice("Ahorrar todo (%s)" % GameManager.format_money(GameManager.money), func() -> void: _save_amount(GameManager.money), GameManager.money <= 0)
	_add_choice("Ahorrar la mitad (%s)" % GameManager.format_money(half), func() -> void: _save_amount(half), half <= 0)
	_add_choice("No ahorrar esta semana", func() -> void: _save_amount(0))

func _save_amount(amount: int) -> void:
	var kept_liquid := GameManager.money - amount
	var save_tip := ""
	if amount > 0:
		GameManager.transfer_to_savings(amount)
		if kept_liquid <= 0:
			save_tip = "Ahorraste todo. Avanzas rápido a la meta, pero sin colchón un imprevisto duele más."
		else:
			save_tip = "Buen equilibrio: aportaste al apartamento y dejaste algo líquido para imprevistos."
	else:
		save_tip = "Guardar liquidez puede ser útil, pero sin aportes constantes la meta se aleja."

	if week_lesson != "" and week_lesson != save_tip:
		current_tip = week_lesson + "\n\n" + save_tip
	else:
		current_tip = save_tip
	_set_phase(Phase.TIP)

func _show_tip() -> void:
	phase_title.text = "Aprendizaje de la semana"
	phase_body.text = "Revisa esta idea clave antes de seguir:"
	tip_panel.visible = true
	tip_label.text = current_tip if current_tip != "" else "Ingreso − gastos esenciales − colchón = ahorro real para tus metas."
	_add_choice("Siguiente", func() -> void: _set_phase(Phase.WEEK_END))

func _finish_week() -> void:
	# If still in week <= TOTAL, advance; then check end
	var result := ""
	if GameManager.week >= GameManager.TOTAL_WEEKS:
		# Force month end evaluation
		GameManager.week += 1
		result = GameManager.check_end_conditions()
	else:
		GameManager.advance_week()
		result = GameManager.check_end_conditions()
		if result == "":
			# Early lose conditions already checked; continue
			pass

	if result != "":
		get_tree().change_scene_to_file("res://scenes/end_screen.tscn")
		return

	# Prepare next week
	current_tip = ""
	week_lesson = ""
	selected_job = {}
	week_income = 0
	did_overtime = false
	_set_phase(Phase.JOB)
