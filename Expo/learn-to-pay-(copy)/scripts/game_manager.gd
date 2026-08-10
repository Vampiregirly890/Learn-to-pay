extends Node

## Estado global de la partida (autoload).

signal state_changed
signal week_started
signal week_ended

const GOAL_APARTMENT := 2500
const TOTAL_WEEKS := 4
const STARTING_MONEY := 400
const RENT_PENALTY := 120
const MAX_MISSED_RENT := 2

const JOBS := [
	{"id": "part", "name": "Medio tiempo", "min": 900, "max": 900},
	{"id": "full", "name": "Tiempo completo", "min": 1500, "max": 1500},
	{"id": "freelance", "name": "Freelance", "min": 1100, "max": 2100},
]

var money: int = STARTING_MONEY
var savings: int = 0
var debt: int = 0
var week: int = 1
var missed_rent: int = 0
var pending_fatigue_cost: int = 0

var total_earned: int = 0
var total_spent: int = 0
var last_job_name: String = ""
var ended_won: bool = false
var end_reason: String = ""
var intro_done: bool = false

## Estado libre de la semana actual
var worked: bool = false
var did_overtime: bool = false
var week_income: int = 0
var rent_paid: bool = false
var utils_paid: bool = false
var food_paid: bool = false
var food_cut: bool = false
var transport_paid: bool = false
var surprise_paid: bool = false
var surprise_amount: int = 0
var fatigue_amount: int = 0
var fatigue_paid: bool = false
var saved_this_week: bool = false
var last_week_tip: String = ""

func reset_game() -> void:
	money = STARTING_MONEY
	savings = 0
	debt = 0
	week = 1
	missed_rent = 0
	pending_fatigue_cost = 0
	total_earned = 0
	total_spent = 0
	last_job_name = ""
	ended_won = false
	end_reason = ""
	intro_done = false
	last_week_tip = ""
	_reset_week_flags()
	_roll_week_events()
	state_changed.emit()

func _reset_week_flags() -> void:
	worked = false
	did_overtime = false
	week_income = 0
	rent_paid = false
	utils_paid = false
	food_paid = false
	food_cut = false
	transport_paid = false
	surprise_paid = false
	fatigue_paid = false
	saved_this_week = false

func _roll_week_events() -> void:
	surprise_amount = randi_range(150, 350) if randf() < 0.30 else 0
	fatigue_amount = pending_fatigue_cost
	pending_fatigue_cost = 0
	if surprise_amount <= 0:
		surprise_paid = true
	if fatigue_amount <= 0:
		fatigue_paid = true

func start_new_week_after_sleep() -> void:
	week += 1
	_reset_week_flags()
	_roll_week_events()
	state_changed.emit()
	week_started.emit()

func format_money(amount: int) -> String:
	var sign := "-" if amount < 0 else ""
	var n := absi(amount)
	var s := str(n)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "." + result
		result = s[i] + result
		count += 1
	return "$%s%s" % [sign, result]

func add_income(amount: int) -> void:
	money += amount
	total_earned += amount
	state_changed.emit()

func pay_from_money(amount: int) -> bool:
	if amount <= 0:
		return true
	if money < amount:
		return false
	money -= amount
	total_spent += amount
	state_changed.emit()
	return true

func add_debt(amount: int) -> void:
	debt += amount
	state_changed.emit()

func pay_debt(amount: int) -> bool:
	var pay := mini(amount, debt)
	if pay <= 0:
		return true
	if money < pay:
		return false
	money -= pay
	debt -= pay
	total_spent += pay
	state_changed.emit()
	return true

func transfer_to_savings(amount: int) -> void:
	var transfer := clampi(amount, 0, money)
	money -= transfer
	savings += transfer
	if transfer > 0:
		saved_this_week = true
	state_changed.emit()

func progress_ratio() -> float:
	return clampf(float(savings) / float(GOAL_APARTMENT), 0.0, 1.0)

func rent_amount() -> int:
	return 650

func utils_amount() -> int:
	return 180

func food_amount() -> int:
	return 200 if food_cut else 320

func transport_amount() -> int:
	return 120

func unpaid_essentials_summary() -> Array[String]:
	var items: Array[String] = []
	if not rent_paid:
		items.append("Arriendo %s" % format_money(rent_amount()))
	if not utils_paid:
		items.append("Luz/agua %s" % format_money(utils_amount()))
	if not food_paid:
		items.append("Comida %s" % format_money(food_amount()))
	if not transport_paid:
		items.append("Transporte %s" % format_money(transport_amount()))
	if surprise_amount > 0 and not surprise_paid:
		items.append("Imprevisto %s" % format_money(surprise_amount))
	if fatigue_amount > 0 and not fatigue_paid:
		items.append("Cansancio %s" % format_money(fatigue_amount))
	return items

func resolve_unpaid_on_sleep() -> String:
	var lesson := ""
	if not rent_paid:
		add_debt(rent_amount() + RENT_PENALTY)
		missed_rent += 1
		lesson = "Dormiste sin pagar el arriendo: deuda + multa. La vivienda suele ser prioridad #1."
	else:
		missed_rent = 0

	if not utils_paid:
		add_debt(utils_amount())
		if lesson.is_empty():
			lesson = "Los servicios sin pagar se convierten en deuda. Pagar a tiempo evita bolas de nieve."
	if not food_paid:
		add_debt(food_amount())
		if lesson.is_empty():
			lesson = "La comida también es un gasto esencial. Si no la cubres, igual pesa en tu presupuesto."
	if not transport_paid:
		add_debt(transport_amount())
	if surprise_amount > 0 and not surprise_paid:
		add_debt(surprise_amount)
		if lesson.is_empty():
			lesson = "Un imprevisto sin pagar hoy es deuda mañana. El colchón de emergencia existe para esto."
	if fatigue_amount > 0 and not fatigue_paid:
		add_debt(fatigue_amount)

	if lesson.is_empty():
		if not worked:
			lesson = "Terminaste la semana sin trabajar: sin ingreso es muy difícil avanzar a la meta."
		elif food_cut:
			lesson = "Recortar comida ayuda al corto plazo, pero el equilibrio también es salud financiera."
		elif saved_this_week:
			lesson = "Buen hábito: trabajaste, cubriste gastos y aportaste al ahorro del apartamento."
		elif worked and not saved_this_week:
			lesson = "Ganaste dinero, pero sin apartar ahorro la meta se aleja. Paga, reserva y luego disfruta."
		else:
			lesson = "Ingreso − gastos esenciales − colchón = avance real hacia tus metas."
	last_week_tip = lesson
	return lesson

func check_end_conditions() -> String:
	if savings >= GOAL_APARTMENT:
		ended_won = true
		end_reason = "¡Lograste juntar el depósito para tu apartamento!"
		return "win"
	if missed_rent >= MAX_MISSED_RENT:
		ended_won = false
		end_reason = "Perdiste el acceso a la vivienda por no pagar el arriendo a tiempo."
		return "lose"
	if debt >= 1800:
		ended_won = false
		end_reason = "La deuda se volvió inmanejable. Sin un plan, los atrasos te comen el presupuesto."
		return "lose"
	if week > TOTAL_WEEKS:
		ended_won = false
		end_reason = "Se acabó el mes y no alcanzaste la meta del apartamento. ¡Vuelve a intentarlo!"
		return "lose"
	return ""

func apply_job(job: Dictionary) -> int:
	var income := randi_range(int(job["min"]), int(job["max"]))
	worked = true
	week_income = income
	last_job_name = str(job["name"])
	add_income(income)
	return income

func apply_overtime() -> int:
	did_overtime = true
	var extra := randi_range(300, 550)
	week_income += extra
	add_income(extra)
	if randf() < 0.55:
		pending_fatigue_cost = randi_range(100, 220)
	else:
		pending_fatigue_cost = 0
	return extra
