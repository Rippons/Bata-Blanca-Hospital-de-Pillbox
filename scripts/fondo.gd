class_name Fondo
extends Node2D
## Dibuja suelos y paredes repitiendo una región de un tileset.

var capas: Array = []   # [destino: Rect2, textura: Texture2D, region: Rect2] o [destino, Color]


func agregar(destino: Rect2, textura: Texture2D, region: Rect2) -> void:
	capas.append([destino, textura, region])
	queue_redraw()


func agregar_color(destino: Rect2, color: Color) -> void:
	capas.append([destino, color])
	queue_redraw()


func _draw() -> void:
	for c in capas:
		var destino: Rect2 = c[0]
		if c.size() == 2:
			draw_rect(destino, c[1])
			continue
		var tex: Texture2D = c[1]
		var reg: Rect2 = c[2]
		var y := destino.position.y
		while y < destino.end.y:
			var alto := minf(reg.size.y, destino.end.y - y)
			var x := destino.position.x
			while x < destino.end.x:
				var ancho := minf(reg.size.x, destino.end.x - x)
				draw_texture_rect_region(tex, Rect2(x, y, ancho, alto), Rect2(reg.position, Vector2(ancho, alto)))
				x += reg.size.x
			y += reg.size.y
