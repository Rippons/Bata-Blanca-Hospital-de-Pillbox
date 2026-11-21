class_name Walter
extends CharacterBody2D
## Dr. Walter Pinkman, el personaje del jugador.

signal objetivo_cambiado(objetivo: Interactuable)

var figura: Personaje
var camara: Camera2D
var detector: Area2D
var objetivo: Interactuable
var bloqueado := false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 6)
	forma.shape = rect
	forma.position = Vector2(0, -2)
	add_child(forma)

	figura = Personaje.new()
	figura.piel = 0
	figura.pelo_hoja = Personaje.PELOS
	figura.pelo_fila = 0
	figura.unico = true
	add_child(figura)

	camara = Camera2D.new()
	camara.position = Vector2(0, -12)
	add_child(camara)
	limitar_camara(Rect2(0, 0, 480, 270))

	detector = Area2D.new()
	detector.collision_layer = 0
	detector.collision_mask = 2
	detector.monitorable = false
	var fd := CollisionShape2D.new()
	var circulo := CircleShape2D.new()
	circulo.radius = 12.0
	fd.shape = circulo
	fd.position = Vector2(0, -6)
	detector.add_child(fd)
	add_child(detector)
	actualizar_aspecto()


func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if not bloqueado and not Juego.pausado:
		dir = Input.get_vector("izquierda", "derecha", "arriba", "abajo")
	velocity = dir * Juego.velocidad_walter()
	move_and_slide()
	if dir != Vector2.ZERO:
		figura.mirando = dir
	figura.caminar(dir != Vector2.ZERO, delta)
	_buscar_objetivo()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interactuar") and not bloqueado and not Juego.pausado:
		if objetivo and objetivo.activo:
			get_viewport().set_input_as_handled()
			objetivo.usar()


func _buscar_objetivo() -> void:
	if objetivo != null and not is_instance_valid(objetivo):
		objetivo = null                 # su NPC desapareció (p. ej. al final de una cinemática)
		objetivo_cambiado.emit(null)
	var mejor: Interactuable = null
	var mejor_d := INF
	for area in detector.get_overlapping_areas():
		if area is Interactuable and area.activo:
			var d := global_position.distance_to(area.global_position)
			if d < mejor_d:
				mejor_d = d
				mejor = area
	if mejor != objetivo:
		objetivo = mejor
		objetivo_cambiado.emit(objetivo)


## La cámara no sale del rectángulo de la sala actual.
func limitar_camara(r: Rect2) -> void:
	camara.limit_left = int(r.position.x)
	camara.limit_top = int(r.position.y)
	camara.limit_right = int(r.end.x)
	camara.limit_bottom = int(r.end.y)
	camara.reset_smoothing()


## Cambia la ropa según Juego.ropa, la bata sucia y el olor.
func actualizar_aspecto() -> void:
	var olor := 2 if Juego.huele_muy_mal() else (1 if Juego.huele_mal() else 0)
	var tinte := Color("e6d6a8") if (Juego.ropa == "uniforme" and Juego.bata_sucia()) else Color.WHITE
	if figura.ropa == Juego.ropa and figura.olor == olor and figura.tinte_ropa == tinte:
		return
	figura.ropa = Juego.ropa
	figura.olor = olor
	figura.tinte_ropa = tinte
	figura.aplicar()
