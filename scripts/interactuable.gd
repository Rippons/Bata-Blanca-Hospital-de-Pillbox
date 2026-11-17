class_name Interactuable
extends Area2D
## Zona con la que Walter puede interactuar pulsando E.
## La sala decide qué pasa según el «id».

signal usado(id: String)

var id := ""
var etiqueta := ""      # texto del aviso: «E: Bañarse»
var activo := true


func configurar(p_id: String, p_etiqueta: String, rect: Rect2) -> void:
	id = p_id
	etiqueta = p_etiqueta
	collision_layer = 2
	collision_mask = 0
	monitorable = true
	monitoring = false
	var forma := CollisionShape2D.new()
	var rectangulo := RectangleShape2D.new()
	rectangulo.size = rect.size
	forma.shape = rectangulo
	forma.position = rect.get_center()
	add_child(forma)


func usar() -> void:
	if activo:
		usado.emit(id)
