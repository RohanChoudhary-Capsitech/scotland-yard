class_name BoardVehicles
extends Node2D

## BoardVehicles — Pre-placed vehicle sprites for move animations.
## Contains Taxi, Bus, Train, Ferry sprites and water wake particles.
## Reused for all movements without creating any runtime nodes.

@onready var taxi: Sprite2D = $Taxi
@onready var bus: Sprite2D = $Bus
@onready var train: Sprite2D = $Train
@onready var ferry: Sprite2D = $Ferry
@onready var wake: GPUParticles2D = $Ferry/Wake

func _ready() -> void:
	hide_all()

func get_vehicle(transport_type: String) -> Sprite2D:
	match transport_type:
		"taxi":
			return taxi
		"bus":
			return bus
		"underground":
			return train
		"ferry":
			return ferry
		_:
			return taxi

func hide_all() -> void:
	if taxi:
		taxi.visible = false
		taxi.scale = Vector2.ONE
	if bus:
		bus.visible = false
		bus.scale = Vector2.ONE
	if train:
		train.visible = false
		train.scale = Vector2.ONE
		train.modulate.a = 1.0
	if ferry:
		ferry.visible = false
		ferry.scale = Vector2.ONE
	if wake:
		wake.emitting = false
