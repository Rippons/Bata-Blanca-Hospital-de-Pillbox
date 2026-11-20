class_name EventosHospital
extends Node
## Eventos del hospital (además del apagón, la hora pico y la ambulancia de Andrés).
## Cada día puede tocar uno al azar; otros dependen de la historia (cumpleaños de Erina,
## visita de mamá, herida de Pawlak, llamada del arrendador).
##
##  1 incendio        · humo en la cocina de la cafetería, evacuar y llegan los bomberos
##  2 fuga            · un paciente se cansa de esperar y se va por el pasillo
##  3 inspeccion      · inspectora sorpresa de salud
##  4 insumos         · se acaba un insumo del botiquín
##  5 ascensor        · el capitán Marcos Rojas queda atrapado; llega Paul Catelli
##  6 detenido        · Dakota trae a un detenido herido (y Zacarías se pone nervioso)
##  7 examen          · examen sorpresa del Dr. Brown a los internos
##  8 cumple_erina    · cumpleaños de Erina: conseguir el pastel y la sorpresa a las 3 PM
##  9 estetoscopio    · Diego esconde el estetoscopio de Walter
## 10 pawlak_herida   · Rhea Pawlak llega herida de verdad; Reyes está muy nervioso
## 11 accidente       · accidente grande: ambulancias, patrulla y bomberos
## 12 calor           · ola de calor: más golpes de calor y jugos gratis
## 14 mama            · mamá visita el hospital con almuerzo
## 15 arrendador      · llamada del arrendador si Walter quedó en deuda

var h        # el hospital (scripts/hospital.gd)
var programados := {}          # evento -> minuto del día en que empieza
var hoy: Array = []            # eventos que tocaron hoy

# Estado de cada evento
var incendio := ""             # "" | "humo" | "evacuado" | "listo"
var incendio_limite := -1.0
var fuga := {}                 # datos del paciente que se fue
var fuga_limite := -1.0
var inspectora_evalua := -1.0
var agotado := ""              # insumo que falta en el botiquín
var agotado_vuelve := -1.0     # hora en que Cristian lo trae
var ascensor := ""             # "" | "atrapado" | "catelli" | "listo"
var catelli_llega := -1.0
var detenido := ""             # nombre del paciente custodiado
var cumple := ""               # "" | "plan" | "hora" | "listo"
var pastel := false
var distraida := false
var sin_estetoscopio := false
var pawlak_herida := false
var calor := false
var jugo_tomado := false
var mama_comentarios := {}     # quién ya comentó la visita de mamá
var _pos_guardadas := {}       # posiciones originales de NPC que se mueven por un evento
var _humo: Node2D

const CASOS_CALOR := ["Golpe de calor", "Deshidratación"]


func _init(hospital) -> void:
	h = hospital


# --- Construcción y planificación ---------------------------------------------------
## Cosas fijas que usan los eventos (el ascensor del pasillo).
func construir() -> void:
	var o: Vector2 = h.SALAS["pasillo"]["origen"]
	var asc := Ascensor.new()
	asc.position = o + Vector2(712, 64)
	h.mundo.add_child(asc)
	h.zona("ev_ascensor", "Ascensor (en mantenimiento)", Rect2(o + Vector2(698, 66), Vector2(28, 18)))


func planear() -> void:
	var d: int = Juego.dia
	# Eventos de la historia
	if Juego.dinero < 0 and int(Juego.flags.get("arrendador_dia", -10)) < d - 3:
		_programar("arrendador", randi_range(9 * 60, 16 * 60))
	if d >= 4 and not Juego.flags.get("ev_cumple_erina", false) and not Juego.es_fin_de_semana():
		iniciar("cumple_erina")
	elif d >= 5 and not Juego.flags.get("ev_mama", false) and randf() < 0.35:
		_programar("mama", randi_range(12 * 60, 13 * 60))
	if d >= 9 and h._pawlak_interes() == "si" and not Juego.flags.get("ev_pawlak_herida", false) and randf() < 0.4:
		_programar("pawlak_herida", randi_range(10 * 60, 16 * 60))
	# Un evento al azar casi todos los días
	if d < 2 or randf() > 0.65:
		return
	var pool: Array = ["fuga", "inspeccion", "insumos", "examen", "estetoscopio"]
	if d >= 3:
		pool += ["incendio", "accidente", "calor"]
	if h._visita_marcos(d) and h.apagon_hora < 0.0:
		pool.append("ascensor")
	if h._dakota_en_recepcion(d):
		pool.append("detenido")
	pool = pool.filter(func(e): return d - int(Juego.flags.get("ev_ultimo_" + e, -10)) >= 4)
	if pool.is_empty():
		return
	var e: String = pool.pick_random()
	Juego.flags["ev_ultimo_" + e] = d
	if e in ["insumos", "estetoscopio", "calor"]:
		iniciar(e)                 # duran todo el día
	else:
		_programar(e, randi_range(9 * 60, 16 * 60))


func _programar(e: String, minuto: int) -> void:
	programados[e] = float(minuto)


func _puede() -> bool:
	return not h.cinematica_activa and not h._cambiando and not h.hud.ocupado() and not h._terminando


## Se llama en cada cuadro desde el hospital.
func revisar() -> void:
	var m: float = Juego.minutos
	for e in programados.keys():
		if m >= programados[e] and _puede():
			programados.erase(e)
			iniciar(e)
			return
	if incendio == "humo" and m >= incendio_limite:
		_incendio_tarde()
	if not fuga.is_empty() and m >= fuga_limite:
		_fuga_se_fue()
	if inspectora_evalua > 0.0 and m >= inspectora_evalua and _puede():
		inspectora_evalua = -1.0
		_inspeccion_resultado()
	if agotado_vuelve > 0.0 and m >= agotado_vuelve:
		agotado_vuelve = -1.0
		h.hud.mostrar("Cristian Daniel: «¡Llegó %s de la farmacia! Ya está en el botiquín»." % agotado.to_lower(), 4.0)
		agotado = ""
	if ascensor == "atrapado" and catelli_llega > 0.0 and m >= catelli_llega:
		catelli_llega = -1.0
		_ascensor_llega_catelli()
	if cumple == "plan" and m >= 15 * 60:
		cumple = "hora"
		Juego.sonido("seleccion", 1.3, -6.0)
		h.hud.mostrar("Mensaje de Diego: «¡Ya es hora! Lleva el pastel a recepción. ¡Rápido!»", 4.5)
	if cumple == "hora":
		if pastel and h.sala_actual == "recepcion" and _puede():
			_cumple_fiesta()
		elif m >= 15 * 60 + 45:
			_cumple_fallo()
	if h.npcs.has("Mamá de Walter") and m >= 14 * 60 + 30 and _puede():
		h.hud.mostrar("Tu mamá se fue a su casa. Te dejó un beso con Erina.", 3.0)
		h._quitar_npc(h.npcs["Mamá de Walter"])


func iniciar(e: String) -> void:
	if not e in hoy:
		hoy.append(e)
	match e:
		"incendio": _incendio()
		"fuga": _fuga()
		"inspeccion": _inspeccion()
		"insumos": _insumos()
		"ascensor": _ascensor()
		"detenido": _detenido()
		"examen": await _examen()
		"cumple_erina": _cumple()
		"estetoscopio": _estetoscopio()
		"pawlak_herida": _pawlak_herida()
		"accidente": await _accidente()
		"calor": _calor()
		"mama": _mama()
		"arrendador": await _arrendador()


# --- Ganchos que usa el hospital ----------------------------------------------------
## Diálogo con prioridad para un NPC (o null para usar el de siempre).
func dialogo(nombre: String):
	match nombre:
		"Lucía":
			if incendio == "humo":
				return {"lineas": ["¡Doctor, sale humo de la cafetería! ¡Hay que sacar a los pacientes de la sala de espera!"],
					"opciones": [{"texto": "¡Evacuemos a recepción, ahora!", "efecto": "ev:evacuar"},
						{"texto": "Espere, primero termino aquí.", "amistad": -1}]}
		"Doña Luz":
			if cumple in ["plan", "hora"] and not pastel:
				return {"lineas": ["¿Viene por el pastel de Erina, doctor? Lo escondí detrás de las ollas."],
					"opciones": [{"texto": "¡Sí! Démelo, Doña Luz.", "amistad": 1, "efecto": "ev:pastel"},
						{"texto": "Todavía no, gracias.", "amistad": 0}]}
			if calor and not jugo_tomado:
				return {"lineas": ["¡Qué calor, doctor! Hoy los jugos naturales son gratis para el personal."],
					"opciones": [{"texto": "Un jugo de maracuyá, por favor.", "amistad": 1, "efecto": "ev:jugo"},
						{"texto": "No, gracias.", "amistad": 0}]}
			if incendio == "listo" and not Juego.flags.get("luz_disculpa_%d" % Juego.dia, false):
				Juego.flags["luz_disculpa_%d" % Juego.dia] = true
				return ["Perdón, doctor… dejé los frijoles en el fogón y me puse a ver la novela.", "¡Los bomberos dijeron que olía a frijol quemado hasta la avenida!"]
		"Erina":
			if mama_dice("Erina"):
				return ["Su mamá me enseñó fotos de usted de bebé, doctor. ¡Tenía unos cachetes!", "Ya todo el hospital las vio. Perdón."]
			if cumple == "plan" and not distraida:
				return {"lineas": ["Hoy todo el mundo está muy raro, doctor. Diego no deja de reírse cuando paso."],
					"opciones": [{"texto": "Erina, ¿me ayudas a buscar una historia clínica en el archivo?", "efecto": "ev:distraer", "amistad": 0},
						{"texto": "Ni idea, Erina. Ya sabes cómo es Diego.", "amistad": 0}]}
		"Diego Quiroz":
			if mama_dice("Diego Quiroz"):
				return ["¡Doctor! Su mamá dice que de niño quería ser bombero y le daba miedo el agua.", "Jajaja. Eso me lo guardo para siempre."]
			if sin_estetoscopio:
				return {"lineas": ["Jeje… ¿buscaba algo, doctor?", "No sé de qué me habla. Este bulto en mi bolsillo es… una dona."],
					"opciones": [{"texto": "Diego, devuélveme el estetoscopio.", "amistad": 0, "efecto": "ev:estetoscopio_pedir"},
						{"texto": "Le voy a contar a Sheyla.", "amistad": -1, "efecto": "ev:estetoscopio_sheyla"}]}
			if cumple == "plan":
				return ["¡Shhh! La sorpresa para Erina es a las 3. ¡Usted consiga el pastel con Doña Luz!"]
		"Sheyla Escobedo":
			if sin_estetoscopio:
				Juego.flags["sheyla_sabe_estetoscopio"] = true
				return ["Comprendo que busca su estetoscopio.", "Quiroz lo tiene en el bolsillo del uniforme. Lo vi esconderlo a las 7:42."]
		"Cristian Daniel":
			if agotado != "" and agotado_vuelve < 0.0:
				return {"lineas": ["Doctor, dicen que se acabó %s en el botiquín." % agotado.to_lower()],
					"opciones": [{"texto": "Cristian, ¿me traes %s de la farmacia?" % agotado.to_lower(), "efecto": "ev:cristian_farmacia", "amistad": 1},
						{"texto": "Después, gracias.", "amistad": 0}]}
		"Dr. Maximiliano Brown":
			if agotado != "":
				return {"lineas": ["¿Se acabó %s? Yo guardo un poco en mi casillero." % agotado.to_lower()],
					"opciones": [{"texto": "Dr. Brown, ¿me presta un poco?", "efecto": "ev:brown_presta", "amistad": 0},
						{"texto": "No se preocupe, lo consigo.", "amistad": 0}]}
			if Juego.flags.get("brown_favor", false) and randf() < 0.3:
				return ["Pinkman, todavía me debe lo del insumo. Un café de la cafetería y quedamos a mano."]
		"Alejandro Reyes":
			if pawlak_herida:
				return {"lineas": ["Doctor… ¿Rhea va a estar bien? Tiene mucha sangre en el brazo.", "Fue en un operativo. Yo estaba en la otra cuadra. Yo debí estar ahí."],
					"opciones": [{"texto": "Respira, Reyes. Está en buenas manos.", "amistad": 1, "efecto": "ev:reyes_calmo"},
						{"texto": "Si estás así, sal un momento.", "amistad": 0}]}
		"Dakota":
			if detenido != "":
				return ["Este sujeto se cortó saltando una reja. No es peligroso… creo.", "Yo me quedo aquí. Usted haga lo suyo, doctor."]
		"Dr. Zacarías Flores":
			if detenido != "":
				return [["¡D-Dakota está aquí! ¡En urgencias! ¿Por qué no me avisaron?", "Se me cayeron todas las gasas. Otra vez."],
					["¿Usted cree que Dakota me vio tropezar con la camilla? Dígame que no."]].pick_random()
		"Paul Catelli":
			if ascensor == "catelli":
				return {"lineas": ["¿Un capitán de la policía encerrado en mi ascensor? ¡Ja! Esto lo cobro doble.",
					"Capitán (desde adentro): «¡Catelli, abra esto ya o le pongo una multa por cada tornillo!»"],
					"opciones": [{"texto": "Catelli, usted es el mejor electricista de Pillbox. Demuéstrelo.", "efecto": "ev:ascensor:halago", "amistad": 1},
						{"texto": "Capitán, tranquilo: Catelli lo saca en un minuto.", "efecto": "ev:ascensor:calmar", "amistad": 0},
						{"texto": "Catelli, apúrese o lo reporto con Salgado.", "efecto": "ev:ascensor:presion", "amistad": -1}]}
		"Inspectora Valdés":
			return ["Inspectora Valdés, Secretaría de Salud.", "Haga como si yo no estuviera, doctor. Solo observo… y anoto."]
		"Mamá de Walter":
			if not Juego.flags.get("mama_almuerzo_%d" % Juego.dia, false):
				return {"lineas": ["¡Mijo! Te traje almuerzo: arroz con pollo y jugo de guayaba.", "Estás muy flaco. ¿Sí estás comiendo bien? ¿Y te bañas todos los días?"],
					"opciones": [{"texto": "¡Gracias, mamá! Me lo como ya.", "efecto": "ev:mama_almuerzo", "amistad": 0},
						{"texto": "Mamá, estoy trabajando… pero gracias.", "efecto": "ev:mama_almuerzo", "amistad": 0}]}
			return ["Ya les mostré a tus compañeros las fotos de cuando eras bebé. ¡Están encantados!", "Sigue trabajando, mijo. Estoy muy orgullosa de ti."]
	if fuga.has("nombre") and nombre == fuga["nombre"]:
		var opciones: Array = [{"texto": "Por favor, vuelva. Ya casi le toca.", "efecto": "ev:fuga_convencer", "amistad": 0}]
		if h.npcs.has("John McClane"):
			opciones.append({"texto": "¡McClane, ayúdeme a detenerlo!", "efecto": "ev:fuga_mcclane", "amistad": 0})
		opciones.append({"texto": "Está bien, váyase.", "efecto": "ev:fuga_dejar", "amistad": 0})
		return {"lineas": ["¡Ya me cansé de esperar, doctor! Llevo horas y nadie me atiende.", "Me voy a otro hospital."], "opciones": opciones}
	return null


func mama_dice(nombre: String) -> bool:
	if not Juego.flags.get("mama_vino_%d" % Juego.dia, false) or mama_comentarios.has(nombre):
		return false
	mama_comentarios[nombre] = true
	return true


func efecto(_nombre: String, e: String) -> void:
	match e:
		"evacuar": await _evacuar()
		"pastel":
			pastel = true
			h.hud.mostrar("Tienes el pastel de Erina. ¡Llévalo a recepción a las 3 PM!", 3.5)
		"distraer":
			distraida = true
			Juego.pasar_tiempo(10)
			h.hud.mostrar("Erina te ayuda en el archivo mientras Diego y Jinu inflan globos. (10 min)", 3.5)
		"jugo":
			jugo_tomado = true
			Juego.energia = minf(Juego.energia + 8.0, 100.0)
			Juego.hambre = minf(Juego.hambre + 10.0, 100.0)
			h.hud.mostrar("Jugo de maracuyá bien frío. (+energía)", 2.5)
		"estetoscopio_pedir":
			sin_estetoscopio = false
			await h.hud.dialogo("Diego Quiroz", ["Ayyy, bueno… aquí tiene. ¡Era una broma, doctor!"])
			if Juego.flags.get("sheyla_sabe_estetoscopio", false):
				h.hud.mostrar("Sheyla, desde lejos: «Comprendo. Quiroz, 0 % de gracia, otra vez».", 3.5)
		"estetoscopio_sheyla":
			sin_estetoscopio = false
			await h.hud.dialogo("Diego Quiroz", ["¡No, a Sheyla no! Tome, tome. Aquí está su estetoscopio."])
			await h.hud.dialogo("Sheyla Escobedo", ["(Desde la cafetería) Comprendo perfectamente lo que pasó, Quiroz.", "Le quedan cero oportunidades. Matemáticamente."])
		"cristian_farmacia":
			var demora := 8.0 if Juego.get_amistad("Cristian Daniel") >= 3 else 15.0
			agotado_vuelve = Juego.minutos + demora
			h.hud.mostrar("Cristian corre a la farmacia por %s (%d min)." % [agotado.to_lower(), int(demora)], 3.5)
		"brown_presta":
			Juego.flags["brown_favor"] = true
			h.hud.mostrar("Brown te presta %s. «Me debe una, Pinkman»." % agotado.to_lower(), 3.5)
			agotado = ""
		"reyes_calmo":
			Juego.flags["reyes_calmado_%d" % Juego.dia] = true
		"mama_almuerzo":
			Juego.flags["mama_almuerzo_%d" % Juego.dia] = true
			Juego.hambre = 100.0
			Juego.energia = minf(Juego.energia + 10.0, 100.0)
			h.hud.mostrar("Arroz con pollo de mamá. (+hambre, +energía)", 3.0)
		"fuga_convencer": await _fuga_vuelve("convencer")
		"fuga_mcclane": await _fuga_vuelve("mcclane")
		"fuga_dejar": _fuga_se_fue()
		_:
			if e.begins_with("ascensor:"):
				await _ascensor_rescate(e.substr(9))


## Un paciente se curó: algunos eventos terminan así.
func paciente_curado(nombre: String) -> void:
	if nombre == detenido:
		detenido = ""
		Juego.cambiar_amistad("Dakota", 1)
		h.hud.mostrar("Dakota: «Buen trabajo, doctor. Ahora este se va a la estación… cojeando»." , 4.0)
		_devolver_todos()
	elif nombre == "Oficial Rhea Pawlak":
		pawlak_herida = false
		Juego.cambiar_amistad("Rhea Pawlak", 1)
		Juego.cambiar_amistad("Alejandro Reyes", 1 if Juego.flags.get("reyes_calmado_%d" % Juego.dia, false) else 0)
		h.hud.mostrar("Reyes abraza a Rhea en la puerta. «Gracias, doctor. Le debo una… otra más»." , 4.5)
		_devolver_todos()


## Multiplica lo que empeoran los pacientes en espera (el humo los afecta).
func mult_espera() -> float:
	return 2.0 if incendio == "humo" else 1.0


func etiqueta_insumo(insumo: String) -> String:
	return insumo + " (agotado)" if insumo == agotado else insumo


func interactuar(id: String) -> void:
	if id == "ev_ascensor":
		if ascensor == "":
			h.hud.mostrar("El ascensor está en mantenimiento. Use las escaleras… que tampoco hay.")
		elif ascensor == "atrapado" or ascensor == "catelli":
			await h.hud.dialogo("Capitán Marcos Rojas", [["(Desde adentro) ¿Pinkman? ¡Sáqueme de aquí! Treinta años en el LSPD y me vence un ascensor.",
				"Y huele a perfume de hospital. Detesto el perfume de hospital."],
				["(Desde adentro) Si Catelli no llega en cinco minutos, arresto al ascensor."]].pick_random())


func tareas() -> Array:
	var t: Array = []
	if incendio == "humo":
		t.append(["¡Incendio! Habla con Lucía para evacuar", false])
	if not fuga.is_empty():
		t.append(["%s se va por el pasillo" % fuga["nombre"], false])
	if agotado != "":
		t.append(["Falta %s (Cristian o Brown)" % agotado.to_lower(), false])
	if sin_estetoscopio:
		t.append(["¿Dónde está tu estetoscopio?", false])
	if ascensor in ["atrapado", "catelli"]:
		t.append(["Capitán atrapado en el ascensor" if ascensor == "atrapado" else "Hablar con Catelli (ascensor)", false])
	if cumple == "plan" or cumple == "hora":
		t.append([("Pastel listo: recepción a las 3 PM" if pastel else "Pedir el pastel a Doña Luz"), false])
	return t


# --- Utilidades ---------------------------------------------------------------------
func _mover(nombre: String, pos: Vector2, mirada := Vector2.DOWN) -> void:
	if not h.npcs.has(nombre):
		return
	var n: NPC = h.npcs[nombre]
	if not _pos_guardadas.has(nombre):
		_pos_guardadas[nombre] = [n.position, n.zona_paseo, n.quieto, n.mirada_base]
	n.position = pos
	n.zona_paseo = Rect2()
	n.quieto = true
	n.mirada_base = mirada
	n.mirar_a(pos + mirada)


func _devolver(nombre: String) -> void:
	if not _pos_guardadas.has(nombre) or not h.npcs.has(nombre):
		return
	var g: Array = _pos_guardadas[nombre]
	var n: NPC = h.npcs[nombre]
	n.position = g[0]
	n.zona_paseo = g[1]
	n.quieto = g[2]
	n.mirada_base = g[3]
	_pos_guardadas.erase(nombre)


func _devolver_todos() -> void:
	for nombre in _pos_guardadas.keys():
		_devolver(nombre)


func _caso(diagnostico: String) -> Dictionary:
	for c in h.CASOS + Casos.casos_leves():
		if c["diagnostico"] == diagnostico:
			return c
	return Casos.casos_leves().pick_random()


## Un paciente llega a la sala de espera (o espera en recepción si está llena).
func _llegar(a: Dictionary) -> void:
	if h.espera.size() < h.PUESTOS_ESPERA.size():
		h._entra_a_espera(a)
	else:
		a["hora"] = Juego.minutos
		h.agenda.push_front(a)


func _sumar_a_la_agenda(caso: Dictionary, nombre: String, en_minutos: float) -> void:
	h.agenda.append({"hora": Juego.minutos + en_minutos, "caso": caso, "nombre": nombre})
	h.agenda.sort_custom(func(x, y): return x["hora"] < y["hora"])


# --- 1. Incendio en la cafetería -----------------------------------------------------
func _incendio() -> void:
	incendio = "humo"
	incendio_limite = Juego.minutos + 25.0
	Juego.sonido("alarma", 1.3, -4.0)
	_humo = Humo.new()
	_humo.position = h.SALAS["cafeteria"]["origen"] + Vector2(260, 120)
	h.mundo.add_child(_humo)
	h.hud.mostrar("¡Alarma de incendio! Sale humo de la cocina de la cafetería. Habla con Lucía para evacuar la sala de espera.", 5.0)
	if h.npcs.has("Dr. Wilder Noctis") and h.npcs["Dr. Wilder Noctis"].position.y > 3900:
		h.hud.mostrar("Wilder sale corriendo de la cafetería… con el plato de galletas en la mano.", 4.0)


func _evacuar() -> void:
	if incendio != "humo":
		return
	incendio = "evacuado"
	await h._accion(5, "Walter, Lucía y Cristian llevan a los pacientes a recepción…")
	Juego.sumar_reputacion(4)
	h.hud.mostrar("¡Sala de espera evacuada a tiempo! (+4 reputación)", 3.0)
	await _bomberos()


func _incendio_tarde() -> void:
	incendio = "evacuado"
	Juego.sumar_reputacion(-3)
	for e in h.espera:
		e["estabilidad"] = maxf(e["estabilidad"] - 15.0, 1.0)
	h.hud.mostrar("Lucía: «¡Los pacientes respiraron mucho humo! Los sacamos sin usted». (−3 reputación)", 4.5)
	await _bomberos()


func _bomberos() -> void:
	while not _puede():
		await h.get_tree().create_timer(0.3).timeout
	h.cinematica_activa = true
	var sala_antes: String = h.sala_actual
	var pos_antes: Vector2 = h.walter.position - h.SALAS[sala_antes]["origen"]
	h.walter.camara.position = Vector2(0, -12)
	await h.ir_a_sala("entrada", h.SALAS["entrada"]["entrada"], true)
	Juego.sonido("sirena", 0.85, -6.0)
	var camion: Sprite2D = h.exterior.vehiculo("bomberos", true, 3.0, 280.0)
	h.poner_sirena(camion, Vector2(118, 4))
	await h.get_tree().create_timer(3.2).timeout
	await h.hud.dialogo("Bombero", ["¡Cuerpo de Bomberos de Pillbox! ¿Dónde es el fuego?"])
	await h.hud.dialogo("Bombero", ["(Cinco minutos después) Listo, doctor. Era una olla de frijoles.", "Mucho humo y poco fuego. Ya pueden volver a entrar."])
	camion.queue_free()
	if is_instance_valid(_humo):
		_humo.queue_free()
	incendio = "listo"
	h.walter.camara.position = Vector2(0, -12)
	await h.ir_a_sala(sala_antes if sala_antes != "entrada" else "urgencias", pos_antes if sala_antes != "entrada" else Vector2(240, 200))
	h.cinematica_activa = false
	h.refrescar_aviso()


# --- 2. Paciente que se escapa -------------------------------------------------------
func _fuga() -> void:
	var candidatos: Array = h.espera.filter(func(e): return not e["caso"]["grave"])
	if candidatos.is_empty():
		_programar("fuga", int(Juego.minutos) + 30)
		return
	var e: Dictionary = candidatos.pick_random()
	h.espera.erase(e)
	h._quitar_npc(e["npc"])
	fuga = {"nombre": e["nombre"], "caso": e["caso"], "apariencia": e["apariencia"]}
	fuga_limite = Juego.minutos + 20.0
	var o: Vector2 = h.SALAS["pasillo"]["origen"]
	var ap: Dictionary = e["apariencia"]
	var n: NPC = h.persona(e["nombre"], ap["piel"], ap["ropa"], ap["pelo_hoja"], ap["pelo_fila"], o + Vector2(230, 160), Rect2(o + Vector2(70, 150), Vector2(1, 1)))
	n.velocidad = 9.0
	n.ruta = [o + Vector2(70, 160), o + Vector2(60, 196)]
	h.hud.mostrar("Lucía: «¡Doctor! %s se cansó de esperar y se fue por el pasillo hacia la salida»." % e["nombre"], 4.5)


func _fuga_vuelve(como: String) -> void:
	if fuga.is_empty():
		return
	var nombre: String = fuga["nombre"]
	if como == "convencer" and (Juego.huele_muy_mal() or randf() < 0.25):
		await h.hud.dialogo(nombre, ["¿Y usted quién es para decirme qué hacer? ¡Ni se ha bañado! Me voy."])
		_fuga_se_fue()
		return
	if como == "mcclane" and h.npcs.has("John McClane"):
		var mc: NPC = h.npcs["John McClane"]
		var n: NPC = h.npcs[nombre]
		_mover("John McClane", mc.position)
		await mc.ir_a([n.position + Vector2(16, 0)], 70.0, 4.0)
		await h.hud.dialogo("John McClane", ["Señor, vuelva a la sala de espera. Ahora.", "No me haga usar la voz de policía."])
		await h.hud.dialogo(nombre, ["E-está bien, oficial. Ya vuelvo."])
		_devolver("John McClane")
		Juego.cambiar_amistad("John McClane", 1)
	else:
		await h.hud.dialogo(nombre, ["…Bueno, doctor. Usted me cae bien. Vuelvo a la sala."])
		Juego.sumar_reputacion(1)
	var a := {"nombre": nombre, "caso": fuga["caso"], "apariencia": fuga["apariencia"]}
	fuga = {}
	fuga_limite = -1.0
	if h.npcs.has(nombre):
		h._quitar_npc(h.npcs[nombre])
	_llegar(a)


func _fuga_se_fue() -> void:
	if fuga.is_empty():
		return
	var nombre: String = fuga["nombre"]
	fuga = {}
	fuga_limite = -1.0
	if h.npcs.has(nombre):
		h._quitar_npc(h.npcs[nombre])
	h.transferidos += 1
	Juego.sumar_reputacion(-3)
	h.hud.mostrar("%s se fue del hospital sin ser atendido. (−3 reputación)" % nombre, 4.0)


# --- 3. Inspección sorpresa -----------------------------------------------------------
func _inspeccion() -> void:
	var o: Vector2 = h.SALAS["pasillo"]["origen"]
	var n: NPC = h.persona("Inspectora Valdés", 2, "casual_blanco", Personaje.PELOS2, 2, o + Vector2(120, 150), Rect2(o + Vector2(60, 112), Vector2(840, 80)))
	n.velocidad = 14.0
	inspectora_evalua = Juego.minutos + 40.0
	Juego.sonido("altavoz", 1.0, -6.0)
	h.hud.mostrar("Altavoz: «Atención, personal: visita de la Secretaría de Salud. Inspectora Valdés en el pasillo»." , 4.5)


func _inspeccion_resultado() -> void:
	var puntos := 0
	var notas: Array = []
	if Juego.higiene >= 40.0:
		puntos += 1
	else:
		notas.append("el médico huele mal")
	if Juego.ropa == "uniforme" and not Juego.bata_sucia():
		puntos += 1
	else:
		notas.append("la bata no está limpia")
	if h.espera.size() <= 2:
		puntos += 1
	else:
		notas.append("hay mucha gente esperando")
	if h.transferidos == 0:
		puntos += 1
	else:
		notas.append("hubo pacientes transferidos")
	var lineas: Array
	if puntos >= 3:
		Juego.sumar_reputacion(5)
		lineas = ["Terminé la inspección, Dr. Pinkman.", "Urgencias está ordenado y limpio. Le diré al Dr. Salgado que lo felicite. (+5 reputación)"]
		Juego.flags["inspeccion_resultado"] = "bien"
	else:
		Juego.sumar_reputacion(-4)
		lineas = ["Terminé la inspección, Dr. Pinkman.", "Anoté que %s. Esto llegará a la dirección. (−4 reputación)" % ", ".join(notas)]
		Juego.flags["inspeccion_resultado"] = "mal"
	await h.hud.dialogo("Inspectora Valdés", lineas)
	if h.npcs.has("Inspectora Valdés"):
		h._quitar_npc(h.npcs["Inspectora Valdés"])


# --- 4. Falta de insumos ------------------------------------------------------------
func _insumos() -> void:
	var lista: Array = Casos.insumos_botiquin().filter(func(i): return i in Casos.INSUMOS_A)
	agotado = lista.pick_random()
	h.hud.mostrar("Lucía: «Doctor, se acabó %s en el botiquín. Pídale a Cristian que traiga de la farmacia, o al Dr. Brown»." % agotado.to_lower(), 5.0)


# --- 5. Ascensor atascado ----------------------------------------------------------
func _ascensor() -> void:
	if h.npcs.has("Paul Catelli"):
		return
	ascensor = "atrapado"
	catelli_llega = Juego.minutos + 15.0
	if h.npcs.has("Capitán Marcos Rojas"):
		h._quitar_npc(h.npcs["Capitán Marcos Rojas"])
	h.interactuables["ev_ascensor"].etiqueta = "Ascensor: hablar con el capitán"
	Juego.sonido("error", 0.6, -4.0)
	h.hud.mostrar("Altavoz: «¡El ascensor del pasillo se detuvo con alguien adentro! Ya llamamos al electricista»." , 4.5)


func _ascensor_llega_catelli() -> void:
	ascensor = "catelli"
	var o: Vector2 = h.SALAS["pasillo"]["origen"]
	var c: NPC = h.persona("Paul Catelli", 2, "overol", Personaje.PELOS, 3, o + Vector2(736, 100), Rect2(), [], true)
	c.mirada_base = Vector2.LEFT
	h.hud.mostrar("Paul Catelli llegó al ascensor del pasillo. «¿Quién me despertó de la siesta?»", 4.0)


func _ascensor_rescate(tono: String) -> void:
	if ascensor != "catelli":
		return
	ascensor = "listo"
	h.interactuables["ev_ascensor"].etiqueta = "Ascensor (en mantenimiento)"
	match tono:
		"halago":
			await h.hud.dialogo("Paul Catelli", ["¡Por fin alguien con buen gusto! Mire y aprenda: un tornillo aquí, un golpecito allá…", "¡Listo! Y sin cobrar doble. Bueno, cobro doble igual."])
			Juego.cambiar_amistad("Paul Catelli", 1)
			Juego.flags["catelli_calidad"] = int(Juego.flags.get("catelli_calidad", 0)) + 1
		"calmar":
			await h.hud.dialogo("Paul Catelli", ["Ya, ya, capitán. Respire hondo. Yo trabajo mejor sin gritos.", "…¡Listo! Fíjese que ni sudé."])
			Juego.cambiar_amistad("Capitán Marcos Rojas", 1)
		"presion":
			await h.hud.dialogo("Paul Catelli", ["¿Salgado? ¡Salgado me debe tres facturas! …Bueno, ya, ya lo abro.", "¡Listo! Pero conste que me presionaron."])
	Juego.sonido("puerta", 1.2, -6.0)
	var o: Vector2 = h.SALAS["pasillo"]["origen"]
	var m: NPC = h.persona("Capitán Marcos Rojas", 0, "hoja:marcos", "", 0, o + Vector2(712, 92), Rect2(o + Vector2(600, 112), Vector2(250, 70)))
	m.velocidad = 14.0
	m.dialogo_dinamico = h._dialogo_marcos
	await h.hud.dialogo("Capitán Marcos Rojas", ["¡Aire! Gracias, Pinkman. Y gracias… Catelli. Supongo.",
		"Esto no sale de aquí. Si McClane se entera, me lo recuerda hasta que me jubile."])
	Juego.sumar_reputacion(2)
	if h.npcs.has("Paul Catelli"):
		h._quitar_npc(h.npcs["Paul Catelli"])


# --- 6. Dakota trae a un detenido ---------------------------------------------------
func _detenido() -> void:
	if not h.npcs.has("Dakota"):
		return
	detenido = "Detenido (LSPD)"
	var caso := _caso("Herida superficial").duplicate(true)
	caso["historias"] = [["Me corté saltando una reja, doctor. Yo no hice nada… casi nada.", "¿La oficial gótica se va a quedar ahí mirándome todo el rato?"]]
	var o: Vector2 = h.SALAS["urgencias"]["origen"]
	_llegar({"nombre": detenido, "caso": caso, "apariencia": {"piel": 3, "ropa": "naranja", "pelo_hoja": Personaje.PELOS, "pelo_fila": 5}})
	_mover("Dakota", o + Vector2(460, 186), Vector2.LEFT)
	if h.npcs.has("Dr. Zacarías Flores"):
		_mover("Dr. Zacarías Flores", o + Vector2(250, 186), Vector2.RIGHT)
	var final_zac: String = Juego.flags.get("zac_final", "")
	var reaccion := "Zacarías aparece en urgencias con una bandeja de gasas… y al ver a Dakota se le cae todo."
	if Juego.flags.get("zac_novios", false):
		reaccion = "Zacarías le guiña un ojo a Dakota. Ella casi sonríe. Casi."
	elif final_zac == "rendido":
		reaccion = "Zacarías ve a Dakota y se esconde detrás de la cortina de la camilla."
	h.hud.mostrar("Dakota (LSPD) trae a un detenido herido a urgencias. " + reaccion, 5.0)


# --- 7. Examen sorpresa de Brown ----------------------------------------------------
func _examen() -> void:
	if not h.npcs.has("Dr. Maximiliano Brown"):
		return
	h.cinematica_activa = true
	Juego.sonido("altavoz", 1.0, -6.0)
	h.hud.mostrar("Altavoz: «Internos al pasillo. Examen sorpresa del Dr. Brown. Sí, ahora»." , 3.5)
	await h.get_tree().create_timer(1.2).timeout
	var o: Vector2 = h.SALAS["pasillo"]["origen"]
	var sala_antes: String = h.sala_actual
	var pos_antes: Vector2 = h.walter.position - h.SALAS[sala_antes]["origen"]
	h.walter.camara.position = Vector2(0, -12)
	await h.ir_a_sala("pasillo", Vector2(430, 186), true)
	h.walter.figura.mirando = Vector2.UP
	_mover("Dr. Maximiliano Brown", o + Vector2(430, 140), Vector2.DOWN)
	var jinu: bool = h.npcs.has("Jinu Blake") and not h._jinu_en_cafeteria()
	var wilder: bool = h.npcs.has("Dr. Wilder Noctis")
	if jinu:
		_mover("Jinu Blake", o + Vector2(400, 180), Vector2.UP)
	if wilder:
		_mover("Dr. Wilder Noctis", o + Vector2(460, 180), Vector2.UP)
	await h.hud.dialogo("Dr. Maximiliano Brown", ["Internos: tres preguntas. Sin celular, sin Google, sin mirar a Lucía.", "Pinkman, empieza usted."])
	var casos: Array = Casos.casos_leves().duplicate()
	casos.shuffle()
	var bien := 0
	var insumos: Array = Casos.insumos_botiquin()
	for k in 3:
		var c: Dictionary = casos[k]
		var opciones: Array = [c["insumo"]]
		while opciones.size() < 3:
			var otro: String = insumos.pick_random()
			if not opciones.has(otro):
				opciones.append(otro)
		opciones.shuffle()
		var r: int = await h.hud.elegir("Examen del Dr. Brown (%d/3)" % (k + 1), "¿Qué se usa para tratar: %s?" % c["diagnostico"].to_lower(), opciones)
		if r >= 0 and opciones[r] == c["insumo"]:
			bien += 1
			Juego.sonido("exito", 1.3, -10.0)
		else:
			Juego.sonido("error", 1.0, -10.0)
	var lineas: Array = ["Pinkman: %d de 3." % bien]
	if jinu:
		lineas.append("Blake: 3 de 3. Ha estado estudiando con Escobedo, se nota." if Juego.flags.get("jinu_sheyla", false) else "Blake: 2 de 3. Nada mal, pero menos nervios.")
	if wilder:
		lineas.append("Noctis: 3 de 3… ¿Noctis? ¿Usted estudió? Estoy sorprendido." if h._wilder_redimido() else "Noctis: 0 de 3. «Para el infarto… ¿una siesta?» No, Noctis.")
	await h.hud.dialogo("Dr. Maximiliano Brown", lineas)
	var premio := bien + (2 if bien == 3 else 0)
	Juego.sumar_reputacion(premio)
	Juego.cambiar_amistad("Dr. Maximiliano Brown", 1 if bien >= 2 else 0)
	h.hud.mostrar("Examen de Brown: %d/3 (+%d reputación)" % [bien, premio], 3.0)
	_devolver_todos()
	h.walter.camara.position = Vector2(0, -12)
	if sala_antes != "pasillo":
		await h.ir_a_sala(sala_antes, pos_antes)
	h.walter.bloqueado = false
	h.cinematica_activa = false
	h.refrescar_aviso()


# --- 8. Cumpleaños de Erina ---------------------------------------------------------
func _cumple() -> void:
	cumple = "plan"
	Juego.flags["ev_cumple_erina"] = true
	Juego.mensaje("Diego Quiroz", "¡Hoy es el cumple de Erina! Sorpresa a las 3 PM en recepción. Usted consiga el pastel con Doña Luz (cafetería). Si puede, distráigala un rato. ¡No le diga nada!")
	h.hud.mostrar("Nuevo mensaje de Diego (C): hoy es el cumpleaños de Erina.", 4.0)


func _cumple_fiesta() -> void:
	cumple = "listo"
	h.cinematica_activa = true
	h.walter.bloqueado = true
	var o: Vector2 = h.SALAS["recepcion"]["origen"]
	var invitados := {"Diego Quiroz": Vector2(196, 182), "Jinu Blake": Vector2(226, 188), "Lucía": Vector2(256, 188), "Dr. Maximiliano Brown": Vector2(286, 182)}
	for n in invitados:
		if h.npcs.has(n):
			_mover(n, o + invitados[n], Vector2.UP)
	h.walter.position = o + Vector2(240, 206)
	h.walter.figura.mirando = Vector2.UP
	Juego.sonido("exito", 1.0, -4.0)
	await h.hud.dialogo("Diego Quiroz", ["¡SORPRESAAAA! ¡Feliz cumpleaños, Erina!"])
	var lineas: Array = ["¿Qué? ¿Para mí? ¡No puede ser!"]
	if distraida:
		lineas.append("¡Por eso el Dr. Pinkman me tuvo media hora en el archivo! ¡Qué tramposos!")
	lineas.append("Pastel de tres leches… ¡mi favorito! Gracias, de verdad. Es el mejor cumpleaños en este hospital.")
	await h.hud.dialogo("Erina", lineas)
	if h.npcs.has("Jinu Blake"):
		await h.hud.dialogo("Jinu Blake", ["¡Yo infle los globos! Bueno, tres. Diego infló uno y se mareó."])
	Juego.cambiar_amistad("Erina", 2 if distraida else 1)
	Juego.sumar_reputacion(2)
	Juego.pasar_tiempo(15)
	h.hud.mostrar("La fiesta duró 15 minutos. Erina está feliz. (+2 reputación)", 3.5)
	_devolver_todos()
	h.walter.bloqueado = false
	h.cinematica_activa = false
	h.refrescar_aviso()


func _cumple_fallo() -> void:
	cumple = "listo"
	Juego.cambiar_amistad("Erina", -1)
	h.hud.mostrar("Mensaje de Diego: «Doctor… no llegó el pastel. Le cantamos sin pastel y Erina se puso triste»." , 4.5)


# --- 9. Diego esconde el estetoscopio ----------------------------------------------
func _estetoscopio() -> void:
	sin_estetoscopio = true
	Juego.flags.erase("sheyla_sabe_estetoscopio")
	h.hud.mostrar("¿Y tu estetoscopio? No está en el bolsillo de la bata. Diego Quiroz no para de reírse…", 4.5)


# --- 10. Pawlak herida de verdad ----------------------------------------------------
func _pawlak_herida() -> void:
	pawlak_herida = true
	Juego.flags["ev_pawlak_herida"] = true
	var caso := _caso("Herida superficial").duplicate(true)
	caso["historias"] = [["Esta vez no me caí de la moto, doctor. Un vidrio en el operativo de la avenida.", "No le diga a Reyes que me dolió. Se va a poner peor que yo."]]
	caso["deterioro"] = 0.6
	caso["premio"] = 5
	_llegar({"nombre": "Oficial Rhea Pawlak", "caso": caso, "apariencia": {"piel": 1, "ropa": "policia", "pelo_hoja": Personaje.PELOS2, "pelo_fila": 0}})
	if h.npcs.has("Alejandro Reyes"):
		_mover("Alejandro Reyes", h.SALAS["urgencias"]["origen"] + Vector2(286, 186), Vector2.RIGHT)
	h.hud.mostrar("Rhea Pawlak llega herida de verdad. Reyes entra detrás de ella, pálido.", 4.5)


# --- 11. Accidente grande en la avenida ---------------------------------------------
func _accidente() -> void:
	while not _puede():
		await h.get_tree().create_timer(0.3).timeout
	h.cinematica_activa = true
	Juego.sonido("altavoz", 0.9, -4.0)
	h.hud.mostrar("Altavoz: «¡Código rojo! Accidente múltiple en la avenida. Todo el personal disponible a la entrada»." , 4.0)
	await h.get_tree().create_timer(1.2).timeout
	h.walter.camara.position = Vector2(0, -12)
	await h.ir_a_sala("entrada", h.SALAS["entrada"]["entrada"], true)
	h.walter.figura.mirando = Vector2.RIGHT
	Juego.sonido("sirena", 1.0, -6.0)
	var ext: Exterior = h.exterior
	var autos: Array = [ext.vehiculo("ambulancia", true, 2.6, 274.0), ext.vehiculo("patrulla", false, 3.0, 40.0)]
	await h.get_tree().create_timer(1.4).timeout
	Juego.sonido("sirena", 0.9, -8.0)
	autos.append(ext.vehiculo("ambulancia", true, 2.6, 120.0))
	await h.get_tree().create_timer(1.6).timeout
	autos.append(ext.vehiculo("bomberos", false, 3.2, 330.0))
	await h.get_tree().create_timer(3.0).timeout
	await h.hud.dialogo("Cristian Daniel", ["¡Doctor! ¡Un bus contra un camión! Traemos tres heridos.", "¡Dos ambulancias, la patrulla de Mendoza y hasta los bomberos!"])
	for a in autos:
		if is_instance_valid(a):
			a.queue_free()
	h.walter.camara.position = Vector2(0, -12)
	await h.ir_a_sala("urgencias", Vector2(240, 160), true)
	var graves: Array = h.CASOS.filter(func(c): return c["grave"])
	var nombres := ["Martín (accidente)", "Valeria (accidente)", "Don Julio (accidente)"]
	_sumar_a_la_agenda(graves.pick_random(), nombres[0], 1.0)
	_sumar_a_la_agenda(_caso("Golpe en la cabeza"), nombres[1], 3.0)
	_sumar_a_la_agenda(_caso("Esguince de tobillo"), nombres[2], 5.0)
	h.walter.bloqueado = false
	h.cinematica_activa = false
	h.refrescar_aviso()


# --- 12. Ola de calor ---------------------------------------------------------------
func _calor() -> void:
	calor = true
	jugo_tomado = false
	for k in 3:
		var c: String = CASOS_CALOR[k % 2]
		_sumar_a_la_agenda(_caso(c), ["Don Aurelio", "Yesenia", "Don Fabio"][k], randf_range(120.0, 420.0))
	var o: Vector2 = h.SALAS["cafeteria"]["origen"]
	h.npc(1, "naranja", Personaje.PELOS, 2, o + Vector2(150, 200), Vector2.RIGHT)
	h.npc(4, "rosa", Personaje.PELOS2, 3, o + Vector2(196, 200), Vector2.LEFT)
	h.npc(2, "casual_rojo", Personaje.PELOS, 6, o + Vector2(380, 196), Vector2.LEFT)
	h.hud.mostrar("Ola de calor en Pillbox: 36 °C. Habrá más golpes de calor. Doña Luz regala jugos al personal.", 5.0)


# --- 14. Mamá visita el hospital ----------------------------------------------------
func _mama() -> void:
	Juego.flags["ev_mama"] = true
	Juego.flags["mama_vino_%d" % Juego.dia] = true
	mama_comentarios.clear()
	var o: Vector2 = h.SALAS["recepcion"]["origen"]
	var m: NPC = h.persona("Mamá de Walter", 0, "rosa", Personaje.PELOS2, 4, o + Vector2(160, 214), Rect2(), [], true)
	m.mirada_base = Vector2.UP
	Juego.sonido("altavoz", 1.1, -8.0)
	h.hud.mostrar("Altavoz: «Dr. Walter Pinkman, lo busca… su mamá. En recepción». Se escuchan risas en todo el hospital.", 5.0)


# --- 15. Llamada del arrendador ---------------------------------------------------------
func _arrendador() -> void:
	Juego.flags["arrendador_dia"] = Juego.dia
	if Juego.dinero >= 0:
		return
	for k in 2:
		Juego.sonido("alarma", 1.7, -8.0)
		await h.get_tree().create_timer(0.5).timeout
	var enojado: bool = Juego.flags.get("arrendador_promesa", false)
	var lineas: Array = ["¿Aló? ¿Doctor Pinkman? Habla Don Rigoberto, el dueño del apartamento."]
	if enojado:
		lineas.append("¡Usted me prometió que me pagaba y sigo esperando! Debe $%d." % -Juego.dinero)
	else:
		lineas.append("Me llegó el aviso del banco: el arriendo quedó en rojo. Debe $%d." % -Juego.dinero)
	await h.hud.dialogo("Don Rigoberto (arrendador)", lineas)
	var r: int = await h.hud.elegir("Responder a Don Rigoberto", "", ["Le pago apenas me llegue el sueldo del viernes.", "Don Rigoberto, estoy en un turno… lo llamo luego.", "¡Ya le dije que le pago!"])
	match r:
		0:
			Juego.flags["arrendador_promesa"] = true
			await h.hud.dialogo("Don Rigoberto (arrendador)", ["Bueno… el viernes. Ni un día más, ¿oyó? Y riegue las matas."])
		1:
			await h.hud.dialogo("Don Rigoberto (arrendador)", ["Siempre está en un turno. ¡Los doctores también pagan arriendo!"])
		_:
			Juego.flags["arrendador_promesa"] = true
			await h.hud.dialogo("Don Rigoberto (arrendador)", ["¡Qué carácter! Si no me paga, le cambio la chapa. Usted verá."])


# --- Dibujos ----------------------------------------------------------------------
## Ascensor del pasillo: dos puertas metálicas con su tablerito.
class Ascensor extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-15, -44, 30, 44), Color("7a8591"))
		draw_rect(Rect2(-13, -40, 13, 40), Color("c3ccd6"))
		draw_rect(Rect2(0, -40, 13, 40), Color("b4bec9"))
		draw_line(Vector2(0, -40), Vector2(0, 0), Color("5d6772"), 1.0)
		draw_rect(Rect2(-5, -48, 10, 4), Color("2b2b2b"))
		draw_rect(Rect2(-3, -47, 2, 2), Color("ff6b3d"))
		draw_rect(Rect2(16, -26, 4, 7), Color("9aa3ad"))
		draw_circle(Vector2(18, -24), 1.0, Color("f1c40f"))


## Humo saliendo de la cocina de la cafetería.
class Humo extends Node2D:
	var _t := 0.0
	func _process(d: float) -> void:
		_t += d
		queue_redraw()
	func _draw() -> void:
		for i in 7:
			var f := fmod(_t * 0.6 + i * 0.37, 1.0)
			var x := sin(_t * 1.3 + i) * 10.0 + (i - 3) * 6.0
			draw_circle(Vector2(x, -f * 70.0), 6.0 + f * 10.0, Color(0.35, 0.35, 0.38, 0.55 * (1.0 - f)))
		var brillo := 0.5 + 0.5 * sin(_t * 9.0)
		draw_circle(Vector2(0, 4), 5.0, Color(1.0, 0.45, 0.1, 0.5 + 0.3 * brillo))
