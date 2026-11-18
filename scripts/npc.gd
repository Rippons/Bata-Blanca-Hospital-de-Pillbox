class_name NPC
extends CharacterBody2D
## Persona no jugable con nombre y diálogos.
## Si no es «quieto», camina sola dentro de su «zona» (puntos al azar), choca con
## muebles y paredes, y se detiene a hablar cuando Walter le habla.

var nombre := ""
var lineas: Array = []        # cada elemento es un Array de frases (una conversación)
var dialogo_dinamico: Callable  # si existe, devuelve las frases (para diálogos que dependen del estado)
var quieto := false
var zona_paseo := Rect2()      # coordenadas del mundo
var velocidad := 24.0
var figura: Personaje
var hablando := false
var zona_hablar: Interactuable

var _objetivo := Vector2.ZERO
var _espera := 0.0
var _atascado := 0.0
var _turno := 0


func configurar(p_nombre: String, piel: int, ropa: String, pelo_hoja: String, pelo_fila: int) -> void:
	nombre = p_nombre
	figura = Personaje.new()
	figura.piel = piel
	figura.ropa = ropa
	figura.pelo_hoja = pelo_hoja
	figura.pelo_fila = pelo_fila
	zona_hablar = Interactuable.new()
	zona_hablar.configurar("npc:" + nombre, "Hablar con %s" % nombre, Rect2(-10, -26, 20, 30))


func _ready() -> void:
	collision_layer = 4          # Walter (máscara 1) no choca con los NPC
	collision_mask = 1           # los NPC sí chocan con muebles y paredes
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 6)
	forma.shape = rect
	forma.position = Vector2(0, -2)
	add_child(forma)
	add_child(figura)
	add_child(zona_hablar)
	_espera = randf_range(0.5, 3.0)
	_objetivo = position


func _physics_process(delta: float) -> void:
	if quieto or hablando or Juego.pausado:
		velocity = Vector2.ZERO
		figura.caminar(false, delta)
		return
	if _espera > 0.0:
		_espera -= delta
		figura.caminar(false, delta)
		if _espera <= 0.0:
			_nuevo_objetivo()
		return
	var hacia := _objetivo - position
	if hacia.length() < 3.0:
		_espera = randf_range(1.5, 5.0)
		velocity = Vector2.ZERO
		figura.caminar(false, delta)
		return
	velocity = hacia.normalized() * velocidad
	var antes := position
	move_and_slide()
	figura.mirando = hacia
	figura.caminar(true, delta)
	if position.distance_to(antes) < velocidad * delta * 0.3:
		_atascado += delta
		if _atascado > 0.6:
			_atascado = 0.0
			_espera = randf_range(0.3, 1.0)   # algo lo bloquea: busca otro destino
	else:
		_atascado = 0.0


func _nuevo_objetivo() -> void:
	if zona_paseo.size == Vector2.ZERO:
		_objetivo = position
		return
	_objetivo = Vector2(
		randf_range(zona_paseo.position.x, zona_paseo.end.x),
		randf_range(zona_paseo.position.y, zona_paseo.end.y))


## Conversación con Walter. Mira hacia él, habla y luego sigue con lo suyo.
func hablar(hud: HUD, walter_pos: Vector2) -> void:
	hablando = true
	var dir := walter_pos - global_position
	if dir.length() > 0.1:
		figura.mirando = dir
		figura.caminar(false, 0.0)
	var frases: Array
	if dialogo_dinamico.is_valid():
		frases = dialogo_dinamico.call()
	elif not lineas.is_empty():
		frases = lineas[_turno % lineas.size()]
		_turno += 1
	else:
		frases = ["…"]
	await hud.dialogo(nombre, frases)
	hablando = false
	_espera = randf_range(1.0, 2.5)
