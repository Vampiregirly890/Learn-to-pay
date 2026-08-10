extends CharacterBody2D

signal interaction_requested(building_id: String)

const SPEED := 220.0
const JUMP_VELOCITY := -420.0

var nearby_building: Node = null
var can_move: bool = true
var facing: float = 1.0

var _e_was_down: bool = false
var _space_was_down: bool = false
var _w_was_down: bool = false

@onready var prompt_label: Label = %PromptLabel
@onready var placeholder: Polygon2D = %Placeholder
@onready var sprite: Sprite2D = %Sprite

@export var sprite_texture: Texture2D

func _ready() -> void:
	prompt_label.visible = false
	if sprite_texture != null:
		sprite.texture = sprite_texture
	_refresh_visual()

func _refresh_visual() -> void:
	var has_art := sprite.texture != null
	sprite.visible = has_art
	placeholder.visible = not has_art

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta

	if not can_move:
		velocity.x = 0.0
		move_and_slide()
		_update_prompt()
		return

	var dir_x := Input.get_axis("ui_left", "ui_right")
	if Input.is_physical_key_pressed(KEY_A):
		dir_x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		dir_x += 1.0
	dir_x = clampf(dir_x, -1.0, 1.0)

	velocity.x = dir_x * SPEED
	if absf(dir_x) > 0.01:
		facing = signf(dir_x)
		placeholder.scale.x = facing
		sprite.flip_h = facing < 0.0

	if _jump_just_pressed() and is_on_floor():
		velocity.y = JUMP_VELOCITY

	move_and_slide()

	if nearby_building != null and _interact_pressed():
		interaction_requested.emit(str(nearby_building.building_id))

	_update_prompt()

func _jump_just_pressed() -> bool:
	var space_down := Input.is_physical_key_pressed(KEY_SPACE)
	var w_down := Input.is_physical_key_pressed(KEY_W)
	var just := (space_down and not _space_was_down) or (w_down and not _w_was_down)
	_space_was_down = space_down
	_w_was_down = w_down
	return just or Input.is_action_just_pressed("ui_up")

func _interact_pressed() -> bool:
	var e_down := Input.is_physical_key_pressed(KEY_E)
	var e_just := e_down and not _e_was_down
	_e_was_down = e_down
	return e_just or Input.is_action_just_pressed("ui_accept")

func set_nearby_building(building: Node) -> void:
	nearby_building = building
	_update_prompt()

func clear_nearby_building(building: Node) -> void:
	if nearby_building == building:
		nearby_building = null
		_update_prompt()

func _update_prompt() -> void:
	if nearby_building != null and can_move:
		prompt_label.visible = true
		prompt_label.text = "E / Enter · %s" % str(nearby_building.display_name)
	else:
		prompt_label.visible = false
