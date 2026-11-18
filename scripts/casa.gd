extends Sala
## Casa de Walter: rutina de la mañana (bañarse, desayunar, vestirse, salir)
## y de la noche (cenar, pijama, alarma, dormir).

const HOME := "res://arte/interior/Home/"
const PARED := 66.0          # y donde termina la pared superior

var _t_lista := 0.0
var _cerrando := false


class Lavadora extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-12, -26, 24, 26), Color("eef1f4"))
		draw_rect(Rect2(-12, -26, 24, 26), Color("8a96a3"), false, 1.0)
		draw_rect(Rect2(-12, -26, 24, 5), Color("c9d1da"))
		draw_circle(Vector2(0, -11), 7.0, Color("8a96a3"))
		draw_circle(Vector2(0, -11), 5.5, Color("7fb6e6"))
		draw_circle(Vector2(6, -23.5), 1.2, Color("4caf50"))


class Despertador extends Node2D:
	var sonando := false
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		var dx := sin(_t * 40.0) * 0.8 if sonando else 0.0
		draw_rect(Rect2(-5 + dx, -8, 10, 7), Color("c0392b"))
		draw_rect(Rect2(-3.5 + dx, -7, 7, 5), Color("fdf6e3"))
		draw_rect(Rect2(-1 + dx, -6, 1, 2.5), Color.BLACK)
		draw_circle(Vector2(-4 + dx, -9), 1.5, Color("c0392b"))
		draw_circle(Vector2(4 + dx, -9), 1.5, Color("c0392b"))


var despertador: Despertador


func construir() -> void:
	var tiles := textura(HOME + "TilesHouse.png")
	# Suelos por zona: baño | cuarto | cocina
	fondo.agregar(Rect2(0, PARED, 120, 270 - PARED), tiles, Rect2(272, 128, 32, 32))
	fondo.agregar(Rect2(124, PARED, 176, 270 - PARED), tiles, Rect2(96, 128, 32, 32))
	fondo.agregar(Rect2(304, PARED, 176, 270 - PARED), tiles, Rect2(32, 128, 32, 32))
	# Pared superior
	fondo.agregar(Rect2(0, ALTO_HUD, 480, PARED - ALTO_HUD), tiles, Rect2(32, 16, 32, 48))
	# Tabiques con paso libre abajo
	var madera := Color("7a4a24")
	for x in [120.0, 300.0]:
		fondo.agregar_color(Rect2(x, PARED - 4, 4, 190 - PARED + 4), madera)
		solido_rect(Rect2(x, PARED, 4, 190 - PARED))
		fondo.agregar_color(Rect2(x, 232, 4, 38), madera)
		solido_rect(Rect2(x, 232, 4, 38))
	muros_borde(PARED - ALTO_HUD)

	# --- Baño ---
	mueble(HOME + "Bathroom-Sheet.png", Rect2(323, 13, 26, 50), Vector2(22, 104), true, 36)
	mueble(HOME + "Bathroom-Sheet.png", Rect2(35, 24, 26, 28), Vector2(60, 86), true, 14)
	mueble(HOME + "Bathroom-Sheet.png", Rect2(135, 13, 18, 39), Vector2(98, 100), true, 20)
	zona("ducha", "Bañarse (15 min)", Rect2(6, 92, 40, 28))
	cartel("BAÑO", Vector2(4, 192), Color(0, 0, 0, 0.45))

	# --- Cuarto ---
	mueble(HOME + "Beds-Sheet.png", Rect2(139, 195, 42, 46), Vector2(152, 114), true, 40)
	zona("cama", "Dormir", Rect2(128, 88, 50, 40))
	mueble(HOME + "Cupboard-Sheet.png", Rect2(406, 16, 20, 32), Vector2(186, 96), true, 14)
	despertador = Despertador.new()
	despertador.position = Vector2(186, 78)
	despertador.z_index = 1
	add_child(despertador)
	zona("despertador", "Poner la alarma", Rect2(174, 80, 24, 30))
	mueble(HOME + "Miscellaneous-Sheet.png", Rect2(527, 17, 35, 39), Vector2(224, 96), true, 16)
	zona("armario", "Vestirse", Rect2(204, 82, 40, 30))
	mueble(HOME + "Cupboard-Sheet.png", Rect2(270, 20, 36, 43), Vector2(276, 96), true, 16)
	mueble(HOME + "LivingRoom-Sheet.png", Rect2(25, 15, 46, 30), Vector2(256, 176), true, 14)
	mueble(HOME + "Kitchen1-Sheet.png", Rect2(138, 12, 12, 20), Vector2(256, 190), false)
	zona("escritorio", "Estudiar", Rect2(228, 160, 56, 40))
	mueble(HOME + "Lights-Sheet.png", Rect2(152, 0, 16, 32), Vector2(132, 196), true, 6)
	cartel("CUARTO", Vector2(128, 238), Color(0, 0, 0, 0.45))

	# --- Cocina ---
	mueble(HOME + "Kitchen-Sheet.png", Rect2(996, 0, 24, 48), Vector2(318, 104), true, 30)
	mueble(HOME + "Kitchen-Sheet.png", Rect2(607, 20, 34, 35), Vector2(350, 100), true, 20)
	mueble(HOME + "Kitchen-Sheet.png", Rect2(128, 21, 33, 34), Vector2(384, 100), true, 20)
	zona("comer", "Comer", Rect2(306, 96, 94, 26))
	var lav := Lavadora.new()
	lav.position = Vector2(416, 98)
	mundo.add_child(lav)
	solido_rect(Rect2(404, 84, 24, 14))
	zona("lavadora", "Lavar la bata", Rect2(402, 90, 28, 26))
	mueble(HOME + "Kitchen1-Sheet.png", Rect2(409, 15, 46, 33), Vector2(372, 186), true, 22)
	mueble(HOME + "Kitchen1-Sheet.png", Rect2(42, 7, 12, 25), Vector2(342, 182), false)
	mueble(HOME + "Kitchen1-Sheet.png", Rect2(232, 9, 14, 23), Vector2(402, 182), false)
	mueble(HOME + "Doors-Sheet.png", Rect2(31, 15, 34, 49), Vector2(452, PARED), false)
	zona("puerta", "Salir de casa", Rect2(432, PARED, 40, 18))
	cartel("COCINA", Vector2(308, 238), Color(0, 0, 0, 0.45))


func posicion_inicial() -> Vector2:
	return Vector2(452, 92) if Juego.punto_entrada == "puerta" else Vector2(152, 134)


func al_entrar() -> void:
	Juego.pausado = false
	Juego.musica("casa")
	walter.actualizar_aspecto()
	_actualizar_lista()
	if Juego.punto_entrada == "cama":
		if Juego.minutos < 7 * 60 + 30 or Juego.dia == 1:
			_sonar_alarma()
		if Juego.dia == 1 and Juego.ultimo_resumen == "":
			despertador.sonando = true
			hud.mostrar("Día 1. Eres el Dr. Walter Pinkman, médico interno del Hospital de Pillbox.", 4.5)
			hud.mostrar("Tu turno empieza a las 7:30 AM. Báñate, desayuna, vístete y sal de casa.", 5.0)
			hud.mostrar("Muévete con WASD o flechas · E para interactuar y hablar · Mantén Tab para acelerar el tiempo.", 5.0)
		else:
			despertador.sonando = Juego.minutos < 7 * 60
			hud.mostrar(Juego.ultimo_resumen, 5.0)
			if Juego.huele_mal():
				hud.mostrar("Walter: «Uf… creo que necesito una ducha».", 3.5)
		await get_tree().create_timer(4.0).timeout
		if is_inside_tree():
			despertador.sonando = false
	else:
		hud.mostrar("Llegaste a casa a las %s. Cena, ponte la pijama, pon la alarma y duerme." % Juego.hora_texto(), 5.0)


func _sonar_alarma() -> void:
	for i in 3:
		if not is_inside_tree():
			return
		Juego.sonido("alarma", 1.0, -10.0)
		await get_tree().create_timer(1.1).timeout


func _process(delta: float) -> void:
	if _cerrando:
		return
	walter.actualizar_aspecto()
	_t_lista -= delta
	if _t_lista <= 0.0:
		_t_lista = 0.25
		_actualizar_lista()
	# No ir al hospital en toda la mañana = faltar al turno
	if Juego.es_manana() and Juego.minutos >= 12 * 60:
		Juego.faltar_al_turno()
		hud.mostrar("Son las 12:00 PM y no fuiste al hospital. El Dr. Salgado marcó tu falta. (−15 reputación)", 5.0)
	# Desvelarse hasta las 2:00 AM
	if Juego.minutos >= Juego.HORA_LIMITE_NOCHE:
		_ir_a_dormir(true)


func _actualizar_lista() -> void:
	if Juego.es_manana():
		hud.poner_lista("Mañana · turno 7:30 AM", [
			["Bañarse", Juego.banado_hoy],
			["Desayunar", Juego.desayuno_hoy],
			["Ponerse la bata", Juego.ropa == "uniforme"],
			["Salir antes de 7:10", false],
		])
	else:
		hud.poner_lista("Noche", [
			["Cenar", Juego.cenado_hoy],
			["Ponerse la pijama", Juego.ropa == "pijama"],
			["Poner la alarma", Juego.alarma_puesta],
			["Dormir", false],
		])


# --- Interacciones -------------------------------------------------------------
func interactuar(id: String) -> void:
	match id:
		"ducha": await _banarse()
		"comer": await _comer()
		"armario": await _vestirse()
		"despertador": await _alarma()
		"lavadora": await _lavar()
		"cama": await _cama()
		"escritorio": await _estudiar()
		"puerta": await _puerta()
	walter.actualizar_aspecto()
	_actualizar_lista()


func _accion(minutos_accion: int, texto: String) -> void:
	walter.bloqueado = true
	Juego.pausado = true
	Juego.pasar_tiempo(minutos_accion)
	await Juego.fundido_accion(texto)
	Juego.pausado = false
	walter.bloqueado = false


func _banarse() -> void:
	await _accion(15, "15 minutos después…")
	Juego.higiene = 100.0
	Juego.banado_hoy = true
	hud.mostrar("Te bañaste. Hueles a jabón. (Higiene al máximo)")


func _comer() -> void:
	var h := fmod(Juego.minutos, 1440.0)
	if Juego.es_manana() and h < 12 * 60:
		var r: int = await hud.elegir("Desayuno", "¿Qué vas a desayunar?",
			["Algo rápido: café y pan (5 min)", "Desayuno completo (20 min)", "Nada por ahora"])
		if r == 0:
			await _accion(5, "5 minutos después…")
			Juego.hambre = minf(Juego.hambre + 25.0, 100.0)
			Juego.energia = minf(Juego.energia + 5.0, 100.0)
			Juego.desayuno_hoy = true
			hud.mostrar("Desayuno rápido. Te va a dar hambre antes del mediodía.")
		elif r == 1:
			await _accion(20, "20 minutos después…")
			Juego.hambre = minf(Juego.hambre + 50.0, 100.0)
			Juego.energia = minf(Juego.energia + 15.0, 100.0)
			Juego.desayuno_hoy = true
			hud.mostrar("Desayuno completo. Tienes energía para la mañana.")
	else:
		var r: int = await hud.elegir("Cocina", "Ya es de noche.", ["Cenar (25 min)", "Nada por ahora"])
		if r == 0:
			await _accion(25, "25 minutos después…")
			Juego.hambre = minf(Juego.hambre + 50.0, 100.0)
			Juego.cenado_hoy = true
			hud.mostrar("Cenaste. Mañana amanecerás con menos hambre.")


func _vestirse() -> void:
	var opciones := ["Uniforme y bata (10 min)", "Pijama (5 min)", "Cancelar"]
	var texto := "Llevas puesta: %s." % ("la pijama" if Juego.ropa == "pijama" else "la bata")
	if Juego.bata_sucia():
		texto += " Ojo: la bata está sucia."
	var r: int = await hud.elegir("Armario", texto, opciones)
	if r == 0 and Juego.ropa != "uniforme":
		await _accion(10, "10 minutos después…")
		Juego.ropa = "uniforme"
		hud.mostrar("Te pusiste el uniforme y la bata." + (" Está sucia: lávala esta noche." if Juego.bata_sucia() else ""))
	elif r == 1 and Juego.ropa != "pijama":
		await _accion(5, "5 minutos después…")
		Juego.ropa = "pijama"
		hud.mostrar("Te pusiste la pijama.")


func _alarma() -> void:
	var horas := [5 * 60 + 30, 6 * 60, 6 * 60 + 30, 7 * 60]
	var opciones: Array = []
	for m in horas:
		opciones.append(Juego.hora_texto(m))
	opciones.append("Quitar la alarma")
	var actual := ("Alarma puesta: %s." % Juego.hora_texto(Juego.hora_alarma)) if Juego.alarma_puesta else "La alarma no está puesta."
	var r: int = await hud.elegir("Despertador", actual + " Recuerda: el viaje al hospital tarda 20 min.", opciones)
	if r >= 0 and r < horas.size():
		Juego.hora_alarma = horas[r]
		Juego.alarma_puesta = true
		hud.mostrar("Alarma puesta a las %s." % Juego.hora_texto(Juego.hora_alarma))
	elif r == horas.size():
		Juego.alarma_puesta = false
		hud.mostrar("Quitaste la alarma.")


func _estudiar() -> void:
	var meta := "Llevas %.1f h de estudio (la capacitación pide %.0f h)." % [Juego.horas_estudio, Juego.REQ_HORAS_ESTUDIO]
	if Juego.rango != "Interno":
		meta = "Llevas %.1f h de estudio. Estudiar te mantiene al día como %s." % [Juego.horas_estudio, Juego.rango]
	var r: int = await hud.elegir("Escritorio", meta + " Estudiar cansa un poco.",
		["Estudiar 30 minutos", "Estudiar 1 hora", "Ahora no"])
	if r != 0 and r != 1:
		return
	var horas := 0.5 if r == 0 else 1.0
	await _accion(int(horas * 60), "Estudiando… %d minutos después" % int(horas * 60))
	Juego.horas_estudio += horas
	Juego.energia = maxf(Juego.energia - 6.0 * horas * 2.0, 0.0)
	hud.mostrar("Estudiaste %s. Horas de estudio: %.1f." % ["30 minutos" if horas == 0.5 else "1 hora", Juego.horas_estudio], 3.0)
	await _pregunta_repaso()


## Pregunta de repaso con un caso al azar. Acertar suma media hora extra.
func _pregunta_repaso() -> void:
	var caso: Dictionary = Casos.CASOS.pick_random()
	var opciones: Array = [caso["diagnostico"]] + caso["falsos"]
	opciones.shuffle()
	var texto := "Un paciente llega con: %s\n%s: %s\n¿Cuál es el diagnóstico?" % [caso["signos"], caso["herramienta"], caso["hallazgo"]]
	var r: int = await hud.elegir("Pregunta de repaso", texto, opciones)
	if r < 0:
		return
	if opciones[r] == caso["diagnostico"]:
		Juego.horas_estudio += 0.5
		Juego.sonido("exito", 1.0, -8.0)
		hud.mostrar("¡Correcto! %s se trata con: %s. (+0,5 h de estudio)" % [caso["diagnostico"], caso["insumo"].to_lower()], 4.0)
	else:
		Juego.sonido("error", 1.0, -8.0)
		hud.mostrar("No era eso: era %s, y se trata con %s." % [caso["diagnostico"].to_lower(), caso["insumo"].to_lower()], 4.5)


func _lavar() -> void:
	if Juego.turnos_bata == 0:
		hud.mostrar("La bata está limpia.")
		return
	var r: int = await hud.elegir("Lavadora", "La bata lleva %d turno(s) sin lavar." % Juego.turnos_bata,
		["Lavar la bata (30 min)", "Cancelar"])
	if r == 0:
		await _accion(30, "30 minutos después…")
		Juego.turnos_bata = 0
		hud.mostrar("La bata quedó limpia.")


func _cama() -> void:
	if Juego.es_manana():
		hud.mostrar("No es hora de dormir: tu turno empieza a las 7:30 AM.")
		return
	var aviso := ""
	if not Juego.alarma_puesta:
		aviso = "No has puesto la alarma. Mañana podrías llegar tarde. "
	if Juego.ropa != "pijama":
		aviso += "Sin pijama descansarás peor. "
	var r: int = await hud.elegir("Dormir", aviso + "¿Te vas a dormir?", ["Dormir", "Todavía no"])
	if r == 0:
		_ir_a_dormir(false)


func _ir_a_dormir(desmayado: bool) -> void:
	if _cerrando:
		return
	_cerrando = true
	Juego.ultimo_resumen = Juego.dormir(desmayado)
	Juego.ir_a("res://escenas/casa.tscn", "Día %d · %s" % [Juego.dia, Juego.nombre_dia()])


func _puerta() -> void:
	if not Juego.es_manana():
		hud.mostrar("Ya terminó el día de trabajo. Descansa para mañana.")
		return
	var pendientes: Array = []
	if not Juego.banado_hoy:
		pendientes.append("no te has bañado")
	if not Juego.desayuno_hoy:
		pendientes.append("no has desayunado")
	if Juego.ropa != "uniforme":
		pendientes.append("vas en pijama")
	var texto := "Llegarías al hospital a las %s." % Juego.hora_texto(Juego.minutos + Juego.MINUTOS_VIAJE)
	if not pendientes.is_empty():
		texto += " Ojo: " + ", ".join(pendientes) + "."
	var r: int = await hud.elegir("¿Salir hacia el hospital?", texto, ["Salir", "Quedarme un rato más"])
	if r != 0:
		return
	_cerrando = true
	Juego.sonido("puerta", 1.0, -8.0)
	Juego.pasar_tiempo(Juego.MINUTOS_VIAJE)
	Juego.punto_entrada = "puerta"
	Juego.ir_a("res://escenas/hospital.tscn", "Hospital de Pillbox · %s" % Juego.hora_texto())
