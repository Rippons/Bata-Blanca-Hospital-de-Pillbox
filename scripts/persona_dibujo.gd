class_name PersonaDibujo
extends Node2D
## Figura provisional de una persona (vista cenital-frontal), dibujada por código.
## Se reemplazará por los sprites de MetroCity cuando estén los cuerpos base.
## El origen (0, 0) está en los pies.

@export var color_ropa := Color("e8e8e8")
@export var color_pantalon := Color("3b4a6b")
@export var color_piel := Color("e0b48a")
@export var color_pelo := Color("3a2618")
@export var mirando := Vector2.DOWN
@export var acostado := false        # pacientes en camilla
@export var olor := 0                # 0 nada, 1 huele, 2 huele mucho

var _t := 0.0
var _paso := 0.0


func _process(delta: float) -> void:
	_t += delta
	if olor > 0 or _paso > 0.0:
		queue_redraw()


func caminar(moviendo: bool, delta: float) -> void:
	_paso = _paso + delta * 10.0 if moviendo else 0.0
	queue_redraw()


func _draw() -> void:
	if acostado:
		_dibujar_acostado()
		return
	var balanceo := sin(_paso) * 1.5 if _paso > 0.0 else 0.0
	# sombra
	draw_circle(Vector2(0, 0), 6.0, Color(0, 0, 0, 0.18))
	# piernas
	draw_rect(Rect2(-4, -9 + balanceo, 3, 9 - balanceo), color_pantalon)
	draw_rect(Rect2(1, -9 - balanceo, 3, 9 + balanceo), color_pantalon)
	# cuerpo
	draw_rect(Rect2(-6, -20, 12, 12), color_ropa)
	draw_rect(Rect2(-6, -20, 12, 12), color_ropa.darkened(0.35), false, 1.0)
	# brazos
	draw_rect(Rect2(-8, -19, 2, 9), color_ropa.darkened(0.1))
	draw_rect(Rect2(6, -19, 2, 9), color_ropa.darkened(0.1))
	# cabeza
	draw_circle(Vector2(0, -25), 5.5, color_piel)
	if mirando.y < 0:
		draw_circle(Vector2(0, -26), 5.5, color_pelo)
	else:
		draw_rect(Rect2(-5.5, -31, 11, 4), color_pelo)
		var ojo_x := clampf(mirando.x, -1.0, 1.0) * 1.5
		draw_rect(Rect2(-2.5 + ojo_x, -26, 1, 1.5), Color.BLACK)
		draw_rect(Rect2(1.5 + ojo_x, -26, 1, 1.5), Color.BLACK)
	if olor > 0:
		_dibujar_olor()


func _dibujar_acostado() -> void:
	draw_circle(Vector2(0, -2), 4.5, color_piel)
	draw_rect(Rect2(-4.5, -6.5, 9, 3), color_pelo)
	draw_rect(Rect2(-6, 3, 12, 16), color_ropa)
	draw_rect(Rect2(-6, 3, 12, 16), color_ropa.darkened(0.3), false, 1.0)


func _dibujar_olor() -> void:
	var verde := Color(0.45, 0.7, 0.2, 0.75)
	var n := 2 if olor == 1 else 4
	for i in n:
		var fase := _t * 1.6 + i * 1.7
		var subida := fmod(fase, 3.0) / 3.0
		var x := -8.0 + i * 5.0 + sin(fase * 2.0) * 2.0
		var y := -30.0 - subida * 14.0
		var c := verde
		c.a = 0.75 * (1.0 - subida)
		draw_arc(Vector2(x, y), 2.0, PI * 0.2, PI * 1.2, 6, c, 1.0)
		draw_arc(Vector2(x + 2.0, y - 3.0), 2.0, PI * 1.2, PI * 2.2, 6, c, 1.0)
