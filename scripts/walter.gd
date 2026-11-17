class_name Walter
extends CharacterBody2D
## Dr. Walter Vega, el personaje del jugador.

signal objetivo_cambiado(objetivo: Interactuable)

var figura: PersonaDibujo
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

	figura = PersonaDibujo.new()
	figura.color_pelo = Color("2b1a10")
	add_child(figura)

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


## Cambia colores según la ropa, la bata y el olor.
func actualizar_aspecto() -> void:
	match Juego.ropa:
		"pijama":
			figura.color_ropa = Color("8fb3e0")
			figura.color_pantalon = Color("6d8fc0")
		_:
			figura.color_ropa = Color("d8cfae") if Juego.bata_sucia() else Color("f4f4f4")
			figura.color_pantalon = Color("4a6fa5")
	if Juego.huele_muy_mal():
		figura.olor = 2
	elif Juego.huele_mal():
		figura.olor = 1
	else:
		figura.olor = 0
	figura.queue_redraw()
