extends Sala
## Frente de la casa de Walter: patio con un árbol grande, cerca blanca, camino a la puerta
## y la calle. Desde el portón se sale al hospital (entre semana) o a pasear (fin de semana).

const R := "res://arte/exterior/"
const B := "res://arte/exterior/barrio/"
const PUERTA := Vector2(240, 150)       # puerta de la casa (base)
const Y_CERCA := 196.0                  # cerca del frente
const X_CERCA_IZQ := 110.0
const X_CERCA_DER := 370.0
const Y_CERCA_FONDO := 118.0
const PORTON := Vector2(240, 196)
const Y_ANDEN := 200.0
const Y_CALLE := 216.0

var _cerrando := false
var _t_lista := 0.0
var _noche: CanvasModulate
var _bici: Node2D
var _auto: Sprite2D


## Bicicleta apoyada en la cerca.
class Bici extends Node2D:
	var pinchada := false
	func _draw() -> void:
		var marco := Color("d64541")
		var rueda := Color("2b2b2b")
		draw_arc(Vector2(-8, -5), 5.0, 0, TAU, 16, rueda, 1.5)
		if pinchada:
			draw_line(Vector2(9, -1), Vector2(15, -1), rueda, 1.5)
			draw_arc(Vector2(12, -4), 4.0, PI * 0.1, PI * 0.9, 8, rueda, 1.5)
		else:
			draw_arc(Vector2(12, -5), 5.0, 0, TAU, 16, rueda, 1.5)
		draw_line(Vector2(-8, -5), Vector2(0, -12), marco, 1.5)
		draw_line(Vector2(0, -12), Vector2(10, -12), marco, 1.5)
		draw_line(Vector2(10, -12), Vector2(12, -5), marco, 1.5)
		draw_line(Vector2(0, -12), Vector2(2, -5), marco, 1.5)
		draw_line(Vector2(-8, -5), Vector2(2, -5), marco, 1.5)
		draw_line(Vector2(-1, -13), Vector2(-4, -15), Color("333333"), 1.5)
		draw_line(Vector2(10, -12), Vector2(10, -16), Color("333333"), 1.2)
		draw_line(Vector2(8, -16), Vector2(12, -16), Color("333333"), 1.5)


## Buzón al lado del portón.
class Buzon extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-1, -14, 2, 14), Color("5b4636"))
		draw_rect(Rect2(-6, -22, 12, 8), Color("2f6ea3"))
		draw_rect(Rect2(-6, -22, 12, 8), Color("1b3a5c"), false, 1.0)
		draw_rect(Rect2(5, -24, 2, 5), Color("e74c3c"))
		draw_line(Vector2(-4, -18), Vector2(3, -18), Color("9fc7ea"), 1.0)


func construir() -> void:
	var adoquin := textura(R + "adoquin2.png")
	# Césped, andén y calle
	fondo.agregar_color(Rect2(0, ALTO_HUD, 480, Y_ANDEN - ALTO_HUD), Color("78c349"))
	for i in 70:
		var p := Vector2(fmod(i * 83.7, 480.0), 30.0 + fmod(i * 47.3, Y_ANDEN - 40.0))
		fondo.agregar_color(Rect2(p, Vector2(2, 1)), Color("5fa83a"))
	fondo.agregar(Rect2(228, PUERTA.y, 24, Y_ANDEN - PUERTA.y), adoquin, Rect2(0, 0, 48, 48))   # camino a la puerta
	fondo.agregar(Rect2(0, Y_ANDEN, 480, Y_CALLE - Y_ANDEN), adoquin, Rect2(0, 0, 48, 48))
	fondo.agregar_color(Rect2(0, Y_CALLE - 2, 480, 2), Color("f5f5f5"))
	fondo.agregar_color(Rect2(0, Y_CALLE, 480, 270 - Y_CALLE), Color("888888"))
	var x := 0.0
	while x < 480.0:
		fondo.agregar_color(Rect2(x, 244, 14, 2), Color("fffffb"))
		x += 28.0

	# Casas: la de Walter al centro y las vecinas a los lados
	mueble(B + "casa_walter.png", Rect2(0, 0, 168, 137), Vector2(PUERTA.x - 57.0 + 84.0, PUERTA.y + 1.0), false)
	solido_rect(Rect2(PUERTA.x - 58.0, 60, 118, 88))
	mueble(B + "casa_azul.png", Rect2(0, 0, 159, 123), Vector2(-52 + 79.5, PUERTA.y), false)
	solido_rect(Rect2(0, 60, 60, 90))
	mueble(B + "casa_naranja.png", Rect2(0, 0, 157, 123), Vector2(386 + 78.5, PUERTA.y), false)
	solido_rect(Rect2(386, 60, 94, 90))
	zona("puerta_casa", "Entrar a casa", Rect2(PUERTA.x - 12, PUERTA.y - 4, 24, 14))

	# Cerca blanca con portón abierto en el camino
	_cerca_horizontal(X_CERCA_IZQ, PORTON.x - 14.0, Y_CERCA)
	_cerca_horizontal(PORTON.x + 14.0, X_CERCA_DER, Y_CERCA)
	_cerca_horizontal(X_CERCA_IZQ, PUERTA.x - 58.0, Y_CERCA_FONDO)
	_cerca_horizontal(PUERTA.x + 60.0, X_CERCA_DER, Y_CERCA_FONDO)
	_cerca_vertical(X_CERCA_IZQ, Y_CERCA_FONDO, Y_CERCA)
	_cerca_vertical(X_CERCA_DER - 7.0, Y_CERCA_FONDO, Y_CERCA)

	# Árbol grande del patio (el doble de grande que los de la ciudad)
	_arbol_grande(Vector2(150, 184))
	zona("arbol", "Mirar el árbol", Rect2(130, 170, 40, 20))
	mueble(R + "arbol1.png", Rect2(0, 0, 26, 52), Vector2(340, 186), true, 8)
	mueble(R + "arbusto.png", Rect2(0, 0, 42, 42), Vector2(320, 154), true, 10)
	mueble(R + "arbusto.png", Rect2(0, 0, 42, 42), Vector2(196, 160), false)
	mueble(R + "flores.png", Rect2(0, 0, 26, 53), Vector2(262, 188), false)
	mueble(R + "flores.png", Rect2(0, 0, 26, 53), Vector2(214, 188), false)
	mueble(R + "flores.png", Rect2(0, 0, 26, 53), Vector2(300, 190), false)
	var buzon := Buzon.new()
	buzon.position = Vector2(PORTON.x + 22.0, Y_CERCA + 8.0)
	mundo.add_child(buzon)
	zona("buzon", "Revisar el buzón", Rect2(PORTON.x + 14.0, Y_CERCA - 2.0, 18, 14))
	mueble(R + "hidrante.png", Rect2(0, 0, 12, 18), Vector2(60, Y_ANDEN + 12.0), true, 6)

	# Vehículos de Walter
	if Juego.bicicleta:
		_bici = Bici.new()
		_bici.pinchada = Juego.llanta_pinchada
		_bici.position = Vector2(196, Y_CERCA + 1.0)
		mundo.add_child(_bici)
		zona("bici", "Ver la bicicleta", Rect2(184, Y_CERCA - 4.0, 26, 10))
	if Juego.auto:
		_auto = Sprite2D.new()
		_auto.texture = textura(R + "auto1.png")
		_auto.centered = false
		_auto.offset = Vector2(0, -_auto.texture.get_height())
		_auto.position = Vector2(286, 262)
		mundo.add_child(_auto)

	# Bordes: no se puede salir de la pantalla ni meterse a la calle
	solido_rect(Rect2(-10, 0, 10, 270))
	solido_rect(Rect2(480, 0, 10, 270))
	solido_rect(Rect2(0, Y_CALLE, 480, 60))
	solido_rect(Rect2(0, 0, 480, 60))
	zona("calle", _etiqueta_calle(), Rect2(PORTON.x - 14.0, Y_ANDEN, 28, 14))

	_noche = CanvasModulate.new()
	add_child(_noche)
	_actualizar_luz()


func _cerca_horizontal(x0: float, x1: float, y: float) -> void:
	var tex := textura(B + "cerca_h.png")
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, x1 - x0, 16)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.offset = Vector2(0, -16)
	s.position = Vector2(x0, y)
	mundo.add_child(s)
	solido_rect(Rect2(x0, y - 5, x1 - x0, 5))


func _cerca_vertical(x: float, y0: float, y1: float) -> void:
	var s := Sprite2D.new()
	s.texture = textura(B + "cerca_v.png")
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, 7, y1 - y0)
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.offset = Vector2(0, -(y1 - y0))
	s.position = Vector2(x, y1 - 1.0)
	mundo.add_child(s)
	solido_rect(Rect2(x, y0, 7, y1 - y0))


func _arbol_grande(base: Vector2) -> void:
	var nodo := Node2D.new()
	nodo.position = base
	var s := Sprite2D.new()
	s.texture = textura(R + "arbol0.png")
	s.centered = false
	s.scale = Vector2(2, 2)
	s.offset = Vector2(-s.texture.get_width() / 2.0, -s.texture.get_height())
	nodo.add_child(s)
	mundo.add_child(nodo)
	solido_rect(Rect2(base.x - 9, base.y - 10, 18, 10))


func posicion_inicial() -> Vector2:
	return Vector2(PORTON.x, Y_ANDEN + 8.0) if Juego.punto_entrada == "calle" else Vector2(PUERTA.x, PUERTA.y + 14.0)


func al_entrar() -> void:
	Juego.pausado = false
	Juego.musica("barrio")
	walter.actualizar_aspecto()
	walter.figura.mirando = Vector2.UP if Juego.punto_entrada == "calle" else Vector2.DOWN
	_actualizar_lista()
	if Juego.punto_entrada == "calle":
		hud.mostrar("Llegaste a tu casa a las %s. Entra a descansar." % Juego.hora_texto(), 4.0)


func _process(delta: float) -> void:
	if _cerrando:
		return
	walter.actualizar_aspecto()
	_t_lista -= delta
	if _t_lista <= 0.0:
		_t_lista = 0.5
		_actualizar_lista()
		_actualizar_luz()
		interactuables["calle"].etiqueta = _etiqueta_calle()
	if Juego.es_manana() and Juego.minutos >= 12 * 60:
		Juego.faltar_al_turno()
		hud.mostrar("Son las 12:00 PM y no fuiste al hospital. El Dr. Salgado marcó tu falta. (−15 reputación)", 5.0)
	if Juego.minutos >= Juego.HORA_LIMITE_NOCHE:
		_cerrando = true
		Juego.ultimo_resumen = Juego.dormir(true)
		Juego.ir_a("res://escenas/casa.tscn", "Día %d · %s" % [Juego.dia, Juego.nombre_dia()])


## De noche el patio se pone azul oscuro.
func _actualizar_luz() -> void:
	var h := fmod(Juego.minutos, 1440.0)
	var c := Color.WHITE
	if h >= 19 * 60 or h < 5 * 60:
		c = Color(0.55, 0.6, 0.85)
	elif h >= 17 * 60 + 30:
		c = Color(1.0, 0.85, 0.75)
	_noche.color = c


func _etiqueta_calle() -> String:
	if Juego.es_fin_de_semana():
		return "Salir a la calle"
	return "Ir al hospital" if Juego.es_manana() else "La calle"


func _actualizar_lista() -> void:
	if Juego.es_fin_de_semana():
		hud.poner_lista("Frente de la casa · %s" % Juego.nombre_dia(), [["Salir por el portón o volver a entrar", false]])
	elif Juego.es_manana():
		hud.poner_lista("Frente de la casa", [
			["Bañarse", Juego.banado_hoy],
			["Desayunar", Juego.desayuno_hoy],
			["Ponerse la bata", Juego.ropa == "uniforme"],
			["Ir al hospital (portón)", false],
		])
	else:
		hud.poner_lista("Frente de la casa · noche", [["Entrar a casa a descansar", false]])


func interactuar(id: String) -> void:
	match id:
		"puerta_casa":
			_cerrando = true
			Juego.sonido("puerta", 1.0, -8.0)
			Juego.punto_entrada = "puerta"
			Juego.ir_a("res://escenas/casa.tscn", "")
		"calle": await _calle()
		"buzon":
			hud.mostrar(["Publicidad de pizzas: «2×1 los martes». Walter la guarda… por si acaso.",
				"Una postal de mamá: «Come bien, mijo. Te quiero». ",
				"Nada. Solo una hoja seca del árbol.",
				"Factura de la luz. Mejor no mirarla hoy."].pick_random(), 3.5)
		"bici":
			hud.mostrar("Tu bicicleta roja. " + ("La llanta está pinchada: repárala desde el celular (Transporte)." if Juego.llanta_pinchada else "Lista para rodar."), 3.5)
		"arbol":
			hud.mostrar(["Un roble enorme. Da la mejor sombra de toda la calle.",
				"Walter grabó sus iniciales aquí de niño: «W. P.». Todavía se ven.",
				"Un pajarito canta en una rama. Buen día para salvar vidas."].pick_random(), 3.5)
	_actualizar_lista()


func _accion(minutos_accion: int, texto: String) -> void:
	walter.bloqueado = true
	Juego.pausado = true
	Juego.pasar_tiempo(minutos_accion)
	await Juego.fundido_accion(texto)
	Juego.pausado = false
	walter.bloqueado = false


## Portón: al hospital entre semana; a pasear el fin de semana.
func _calle() -> void:
	if Juego.es_fin_de_semana():
		await _salir_fin_de_semana()
		return
	if not Juego.es_manana():
		hud.mostrar("Ya terminó el día de trabajo. Entra a descansar para mañana.")
		return
	var pendientes: Array = []
	if not Juego.banado_hoy:
		pendientes.append("no te has bañado")
	if not Juego.desayuno_hoy:
		pendientes.append("no has desayunado")
	if Juego.ropa != "uniforme":
		pendientes.append("vas en pijama")
	var medios: Array = Juego.medios_de_viaje()
	var texto := "Son las %s. ¿Cómo vas al hospital? (el turno empieza a las 7:30)" % Juego.hora_texto()
	if not pendientes.is_empty():
		texto += " Ojo: " + ", ".join(pendientes) + "."
	if Juego.bicicleta and Juego.llanta_pinchada:
		texto += " La bici tiene la llanta pinchada."
	var opciones: Array = medios.map(func(m): return "%s → llegas %s" % [m[1], Juego.hora_texto(Juego.minutos + m[2])])
	opciones.append("Quedarme un rato más")
	var r: int = await hud.elegir("¿Salir hacia el hospital?", texto, opciones)
	if r < 0 or r >= medios.size():
		return
	_cerrando = true
	var medio: String = medios[r][0]
	if medio == "auto" and _auto:
		Juego.sonido("puerta", 0.8, -8.0)
		var tw := create_tween()
		walter.visible = false
		tw.tween_property(_auto, "position:x", 520.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		await tw.finished
	elif medio == "bici" and _bici:
		_bici.visible = false
	Juego.viajar(medio)
	Juego.punto_entrada = "puerta"
	Juego.ir_a("res://escenas/hospital.tscn", "Hospital de Pillbox · %s" % Juego.hora_texto())


func _salir_fin_de_semana() -> void:
	var h := fmod(Juego.minutos, 1440.0)
	if h >= 20 * 60 or h < 6 * 60:
		hud.mostrar("Ya es tarde para salir. Mañana será otro día.")
		return
	var r: int = await hud.elegir("Día libre", "Hoy es %s. ¿Qué quieres hacer? (Saldo: $%d)" % [Juego.nombre_dia(), Juego.dinero], [
		"Ir al mercado: 6 comidas por $70 (1 h)",
		"Pasear por el parque (1 h, +energía)",
		"Visitar a mamá (2 h, comes rico y te da comida)",
		"Ir a la playa en auto (4 h, $20, +30 energía)" if Juego.auto else "Ir a la playa (necesitas un auto)",
		"Quedarme en casa"])
	match r:
		0:
			if Juego.dinero < 70:
				hud.mostrar("No te alcanza para el mercado ($70). Tienes $%d." % Juego.dinero, 3.5)
				return
			await _accion(60, "Haciendo mercado…\n1 hora después")
			Juego.dinero -= 70
			Juego.comida += 6
			hud.mostrar("Compraste mercado. La nevera tiene %d comidas. (−$70)" % Juego.comida, 3.5)
		1:
			await _accion(60, "Paseando por el parque de Pillbox…\n1 hora después")
			Juego.energia = minf(Juego.energia + 15.0, 100.0)
			hud.mostrar("El aire libre te hizo bien. (+energía)", 3.0)
		2:
			await _accion(120, "En casa de mamá…\n2 horas después")
			Juego.hambre = minf(Juego.hambre + 50.0, 100.0)
			Juego.comida += 3
			hud.mostrar("Mamá: «¡Estás muy flaco, mijo! Llévate este tupper». (+hambre, +3 comidas)", 4.5)
		3:
			if not Juego.auto:
				hud.mostrar("La playa queda lejos. Con un auto podrías ir (Tienda del celular).", 3.5)
				return
			if Juego.dinero < 20:
				hud.mostrar("No te alcanza para la gasolina ($20).", 3.0)
				return
			await _accion(240, "En la playa de Pillbox…\n4 horas después")
			Juego.dinero -= 20
			Juego.energia = minf(Juego.energia + 30.0, 100.0)
			hud.mostrar("Sol, arena y cero pacientes. Volviste como nuevo. (+energía, −$20)", 4.0)
