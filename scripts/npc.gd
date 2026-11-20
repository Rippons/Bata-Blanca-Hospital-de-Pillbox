class_name NPC
extends CharacterBody2D

signal efecto_dialogo(nombre: String, efecto: String)
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

var mirada_base := Vector2.DOWN   # hacia dónde mira cuando está quieto (p. ej. el mostrador)
var _objetivo := Vector2.ZERO
var _y_primero := false            # alterna el orden de los ejes cuando se atasca
var ruta: Array = []               # puntos de paso (mundo) antes de quedarse en su zona
var _espera := 0.0
var guion := false                  # en una cinemática: solo camina por su «ruta» y luego se queda quieto
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
	figura.mirando = mirada_base


func _physics_process(delta: float) -> void:
	if quieto or hablando or Juego.pausado or (guion and ruta.is_empty()):
		velocity = Vector2.ZERO
		figura.caminar(false, delta)
		return
	if _espera > 0.0 and ruta.is_empty():
		_espera -= delta
		figura.caminar(false, delta)
		if _espera <= 0.0:
			_nuevo_objetivo()
		return
	if not ruta.is_empty():
		_objetivo = ruta[0]
	var hacia := _objetivo - position
	if not ruta.is_empty() and hacia.length() < 2.0:
		ruta.pop_front()
		return
	if hacia.length() < 2.0:
		_espera = randf_range(1.5, 5.0)
		velocity = Vector2.ZERO
		if zona_paseo.size.x <= 2.0:
			figura.mirando = mirada_base      # llegó a su puesto fijo: mira al frente
		figura.caminar(false, delta)
		return
	# Camina en tramos rectos (primero en x, luego en y): sin zigzag ni giros raros.
	var dir: Vector2
	if _y_primero:
		dir = Vector2(0.0, signf(hacia.y)) if absf(hacia.y) > 1.5 else Vector2(signf(hacia.x), 0.0)
	else:
		dir = Vector2(signf(hacia.x), 0.0) if absf(hacia.x) > 1.5 else Vector2(0.0, signf(hacia.y))
	velocity = dir * velocidad
	var antes := position
	move_and_slide()
	figura.mirando = dir
	figura.caminar(true, delta)
	if position.distance_to(antes) < velocidad * delta * 0.3:
		_atascado += delta
		if _atascado > 0.6:
			_atascado = 0.0
			_y_primero = not _y_primero        # prueba rodeando por el otro eje
			_espera = randf_range(0.2, 0.6)
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
## Cada entrada de diálogo puede ser un Array de frases, o un Dictionary:
##   {"lineas": [...], "opciones": [{"texto": "...", "amistad": 1, "respuesta": [...], "efecto": "..."}]}
func hablar(hud: HUD, walter_pos: Vector2) -> void:
	hablando = true
	var dir := walter_pos - global_position
	if dir.length() > 0.1:
		figura.mirando = dir
		figura.caminar(false, 0.0)
	var entrada
	if dialogo_dinamico.is_valid():
		entrada = dialogo_dinamico.call()
	elif not lineas.is_empty():
		entrada = lineas[_turno % lineas.size()]
		_turno += 1
	else:
		entrada = ["…"]
	var frases: Array = entrada.get("lineas", []) if entrada is Dictionary else entrada
	var opciones: Array = entrada.get("opciones", []) if entrada is Dictionary else []
	if not frases.is_empty():
		await hud.dialogo(nombre, frases)
	if not opciones.is_empty():
		var textos: Array = []
		for o in opciones:
			textos.append(o["texto"])
		var r: int = await hud.elegir("Responder a %s" % nombre, "", textos)
		if r >= 0:
			var o: Dictionary = opciones[r]
			var cambio := Juego.cambiar_amistad(nombre, int(o.get("amistad", 0)))
			if cambio > 0:
				Juego.sonido("exito", 1.4, -14.0)
				hud.mostrar("(Amistad con %s: +%d)" % [nombre, cambio], 2.0)
			elif cambio < 0:
				Juego.sonido("error", 1.2, -14.0)
				hud.mostrar("(Amistad con %s: %d)" % [nombre, cambio], 2.0)
			if o.has("respuesta"):
				await hud.dialogo(nombre, o["respuesta"])
			if o.has("efecto"):
				efecto_dialogo.emit(nombre, str(o["efecto"]))
	if quieto:
		figura.mirando = mirada_base      # vuelve a mirar hacia su mostrador
		figura.caminar(false, 0.0)
	hablando = false
	_espera = randf_range(1.0, 2.5)


## Camina por los puntos dados (coordenadas del mundo) y espera a llegar.
## Si algo lo bloquea demasiado tiempo, aparece en el último punto.
func ir_a(puntos: Array, vel := -1.0, limite := 8.0) -> void:
	var antes := velocidad
	var mascara := collision_mask
	collision_mask = 0               # en la cinemática el camino ya está planeado: no se traba con Walter ni con otros

	if vel > 0.0:
		velocidad = vel
	guion = true
	quieto = false
	_espera = 0.0
	ruta = puntos.duplicate()
	var t := 0.0
	while not ruta.is_empty() and is_inside_tree():
		await get_tree().physics_frame
		if not Juego.pausado:
			t += get_physics_process_delta_time()
		if t > limite and not ruta.is_empty():
			position = ruta[-1]
			ruta.clear()
	velocidad = antes
	collision_mask = mascara
	figura.caminar(false, 0.0)


## Gira hacia un punto del mundo sin moverse.
func mirar_a(punto: Vector2) -> void:
	figura.mirando = punto - global_position
	figura.caminar(false, 0.0)
