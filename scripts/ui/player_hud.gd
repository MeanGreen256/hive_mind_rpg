class_name PlayerHud
extends CanvasLayer

@onready var _health_bar: ProgressBar = %HealthBar
@onready var _health_label: Label = %HealthLabel
@onready var _energy_bar: ProgressBar = %EnergyBar
@onready var _energy_label: Label = %EnergyLabel

var health_value: float:
	get:
		return _health_bar.value

var energy_value: float:
	get:
		return _energy_bar.value

var _health: HealthComponent
var _energy: EnergyComponent


func bind(health: HealthComponent, energy: EnergyComponent) -> void:
	_unbind()
	_health = health
	_energy = energy
	if _health != null:
		_health.health_changed.connect(_on_health_changed)
		_on_health_changed(_health.current_health, _health.max_health)
	if _energy != null:
		_energy.energy_changed.connect(_on_energy_changed)
		_on_energy_changed(_energy.current_energy, _energy.max_energy)


func _exit_tree() -> void:
	_unbind()


func _unbind() -> void:
	if is_instance_valid(_health) and _health.health_changed.is_connected(_on_health_changed):
		_health.health_changed.disconnect(_on_health_changed)
	if is_instance_valid(_energy) and _energy.energy_changed.is_connected(_on_energy_changed):
		_energy.energy_changed.disconnect(_on_energy_changed)
	_health = null
	_energy = null


func _on_health_changed(current_health: int, maximum_health: int) -> void:
	_health_bar.max_value = maximum_health
	_health_bar.value = current_health
	_health_label.text = "HP %d/%d" % [current_health, maximum_health]


func _on_energy_changed(current_energy: float, maximum_energy: float) -> void:
	_energy_bar.max_value = maximum_energy
	_energy_bar.value = current_energy
	_energy_label.text = "Energy %d/%d" % [roundi(current_energy), roundi(maximum_energy)]
