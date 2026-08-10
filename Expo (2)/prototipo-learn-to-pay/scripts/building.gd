extends StaticBody2D

## Edificio de fachada (vista de lado).
## Para arte final: asigna `sprite_texture` en el inspector (o en la instancia de la plaza).

@export var building_id: String = "house"
@export var display_name: String = "Casa"
@export var building_color: Color = Color("2A9D8F")
@export var sprite_texture: Texture2D

var player_ref: CharacterBody2D = null

@onready var visual: Polygon2D = %Visual
@onready var sprite: Sprite2D = %Sprite
@onready var name_label: Label = %NameLabel
@onready var interact_area: Area2D = %InteractArea

func _ready() -> void:
	name_label.text = display_name
	_apply_visual()
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)

func _apply_visual() -> void:
	if sprite_texture != null:
		sprite.texture = sprite_texture
		sprite.visible = true
		visual.visible = false
	else:
		sprite.visible = false
		visual.visible = true
		visual.color = building_color

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("set_nearby_building"):
		player_ref = body as CharacterBody2D
		body.set_nearby_building(self)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("clear_nearby_building"):
		body.clear_nearby_building(self)
		if player_ref == body:
			player_ref = null
