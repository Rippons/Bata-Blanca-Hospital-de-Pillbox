class_name Exterior
extends Node2D
## Frente del Hospital de Pillbox: edificio, jardines, andén y calle.
## Se usa de fondo en el menú y en la escena de la ambulancia. Coordenadas locales de 480×270.

const R := "res://arte/exterior/"
const ANCHO := 480.0
const Y_EDIFICIO := -90.0      # el techo con los helipuertos queda medio fuera de la pantalla
const Y_ANDEN := 205.0         # base del edificio = borde de arriba del andén
const Y_CALLE := 221.0
const CARRIL_DER := 262.0      # base de los autos que van hacia la derecha
const CARRIL_IZQ := 246.0      # base de los autos que van hacia la izquierda
const PUERTA := Vector2(240, 203)   # entrada principal (bajo la cruz)
const AUTOS := ["auto0", "auto1", "auto2", "auto3", "auto4"]
## Sprites que vienen dibujados mirando a la izquierda (la trompa a la izquierda).
## El resto (ambulancia, bomberos, auto1, auto2) mira a la derecha.
const MIRAN_IZQUIERDA := ["patrulla", "auto0", "auto3", "auto4"]

@export var trafico := false   # en el menú pasan autos solos
var _prox := 1.0
var _adoquin: Texture2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	y_sort_enabled = true      # el auto del carril de abajo se dibuja delante del de arriba
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_adoquin = load(R + "adoquin2.png")
	var suelo := Suelo.new()
	suelo.ext = self
	suelo.z_index = -1          # césped, andén y calle siempre debajo de todo
	add_child(suelo)
	var edificio := _spr("hospital", Vector2(ANCHO / 2.0 - 316.0, Y_EDIFICIO))
	edificio.z_index = 0
	# Jardín izquierdo
	_spr("arbol0", Vector2(4, 156))
	_spr("arbol2", Vector2(160, 156))
	_spr("arbusto", Vector2(118, 168))
	_spr("flores", Vector2(40, 152))
	_spr("flores", Vector2(92, 152))
	# Jardín derecho
	_spr("letrero_hospital", Vector2(292, 114))
	_spr("banca", Vector2(350, 172))
	_spr("arbol1", Vector2(410, 156))
	_spr("arbol0", Vector2(440, 156))
	_spr("arbol3", Vector2(318, 174))
	_spr("flores", Vector2(380, 152))
	_spr("hidrante", Vector2(196, 194))
	_spr("canecas", Vector2(420, 188))
	_spr("cono", Vector2(470, 204))


func _spr(nombre: String, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(R + nombre + ".png")
	s.centered = false
	s.position = pos
	add_child(s)
	return s


## Dibuja el suelo en un nodo aparte (con y-sort, el padre no siempre queda debajo).
class Suelo extends Node2D:
	var ext: Exterior
	func _draw() -> void:
		ext.dibujar_suelo(self)


func dibujar_suelo(c: CanvasItem) -> void:
	# Césped
	c.draw_rect(Rect2(0, 0, ANCHO, Y_ANDEN), Color("78c349"))
	for i in 60:
		var p := Vector2(fmod(i * 97.3, ANCHO), 110.0 + fmod(i * 53.1, Y_ANDEN - 110.0))
		c.draw_rect(Rect2(p, Vector2(2, 1)), Color("5fa83a"))
	# Camino de la entrada
	c.draw_texture_rect(_adoquin, Rect2(196, 150, 88, Y_ANDEN - 150), true)
	# Andén
	c.draw_texture_rect(_adoquin, Rect2(0, Y_ANDEN, ANCHO, Y_CALLE - Y_ANDEN), true)
	c.draw_rect(Rect2(0, Y_CALLE - 3, ANCHO, 2), Color("f5f5f5"))
	c.draw_rect(Rect2(0, Y_CALLE - 1, ANCHO, 1), Color("676767"))
	# Calle
	c.draw_rect(Rect2(0, Y_CALLE, ANCHO, 340 - Y_CALLE), Color("888888"))   # sigue bajo la pantalla por si la escena se sube
	var x := 0.0
	while x < ANCHO:
		c.draw_rect(Rect2(x, 247, 14, 2), Color("fffffb"))
		x += 28.0


func _process(delta: float) -> void:
	if not trafico:
		return
	_prox -= delta
	if _prox <= 0.0:
		_prox = randf_range(2.5, 5.0)
		var r := randf()
		var nombre: String = "ambulancia" if r < 0.2 else ("patrulla" if r < 0.35 else AUTOS.pick_random())
		var a_la_derecha := randf() < 0.5
		vehiculo(nombre, a_la_derecha, randf_range(5.0, 8.0))


## Un vehículo cruza la calle. Devuelve el sprite (se borra solo al salir).
## La posición del sprite es su borde de abajo, para que se ordene por carril.
func vehiculo(nombre: String, a_la_derecha: bool, duracion: float, hasta := -1.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(R + nombre + ".png")
	s.centered = false
	s.flip_h = a_la_derecha == (nombre in MIRAN_IZQUIERDA)
	var w := float(s.texture.get_width())
	var h := float(s.texture.get_height())
	s.offset = Vector2(0, -h)
	var y := CARRIL_DER if a_la_derecha else CARRIL_IZQ
	s.position = Vector2(-w - 4.0 if a_la_derecha else ANCHO + 4.0, y)
	add_child(s)
	var meta := hasta if hasta >= 0.0 else (ANCHO + 4.0 if a_la_derecha else -w - 4.0)
	var tw := create_tween()
	tw.tween_property(s, "position:x", meta, duracion).set_trans(Tween.TRANS_SINE if hasta >= 0.0 else Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	if hasta < 0.0:
		tw.tween_callback(s.queue_free)
	return s
