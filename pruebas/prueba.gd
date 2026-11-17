extends Node
## Prueba automática: juega un día completo y parte del segundo.
## Uso: godot --path . res://pruebas/prueba.tscn  (con pantalla, guarda capturas en user://capturas)

func _ready() -> void:
	var c := preload("res://pruebas/corredor.gd").new()
	get_tree().root.add_child.call_deferred(c)
