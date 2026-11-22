class_name RivalVance
extends Node
## El rival de Walter: el Dr. Bruno Vance, interno arrogante trasladado del Hospital Central.
## Llega el día 3, compite por los ascensos, se burla de Walter un par de veces al día,
## a veces le roba pacientes de la sala de espera y los viernes Salgado compara a los dos.
## Cada vez que Vance le habla a Walter suena su tema: «musica_villano».
## Su historia termina cuando Vance se equivoca con un paciente y Walter decide qué hacer.

const NOMBRE := "Dr. Bruno Vance"
const MUSICA := "villano"

var h
var npc: NPC
var burlas: Array = []          # minutos del día en que viene a molestar
var robo_hora := -1.0
var error_hora := -1.0
var _ocupado := false


func _init(hospital) -> void:
	h = hospital


static func activo() -> bool:
	return Juego.dia >= 3


static func respeto() -> bool:
	return Juego.flags.get("vance_final", "") == "respeto"


func construir() -> void:
	if not activo():
		return
	var o: Vector2 = h.SALAS["urgencias"]["origen"]
	npc = h.persona(NOMBRE, 0, "uniforme", Personaje.PELOS, 7, o + Vector2(250, 176), Rect2(o + Vector2(170, 150), Vector2(120, 44)))
	npc.musica = MUSICA
	npc.velocidad = 30.0
	npc.dialogo_dinamico = _dialogo


func planear() -> void:
	burlas.clear()
	robo_hora = -1.0
	error_hora = -1.0
	if npc == null or not Juego.eventos_aleatorios:
		return
	burlas = [randi_range(9 * 60 + 30, 12 * 60), randi_range(13 * 60 + 30, 17 * 60)]
	if randf() < 0.5:
		robo_hora = randi_range(10 * 60, 16 * 60)
	if Juego.dia >= 8 and not Juego.flags.has("vance_final") and randf() < 0.6:
		error_hora = randi_range(10 * 60, 15 * 60)


## Cada cuadro, desde el hospital.
func revisar() -> void:
	if npc == null or _ocupado or not h.eventos._puede():
		return
	if not Juego.flags.get("vance_intro", false):
		if h.sala_actual == "urgencias" and Juego.eventos_aleatorios:
			_lanzar(intro)
		return
	var m: float = Juego.minutos
	if error_hora > 0.0 and m >= error_hora and h.sala_actual == "urgencias":
		error_hora = -1.0
		_lanzar(se_equivoca)
	elif robo_hora > 0.0 and m >= robo_hora and _paciente_para_robar() != {}:
		robo_hora = -1.0
		_lanzar(robar)
	elif not burlas.is_empty() and m >= burlas[0] and h.sala_actual in ["urgencias", "pasillo", "cafeteria", "recepcion", "vestidor"]:
		burlas.pop_front()
		_lanzar(burla)


func _lanzar(f: Callable) -> void:
	_ocupado = true
	await f.call()
	_ocupado = false


## Pone el tema del villano y devuelve la música que sonaba antes.
func _musica_villano() -> String:
	var antes: String = Juego._musica_actual
	Juego.musica(MUSICA)
	return antes if antes != MUSICA else "hospital"


func _decir(lineas: Array) -> void:
	await h.hud.dialogo(NOMBRE, lineas)


# --- Llegada -------------------------------------------------------------------------
func intro() -> void:
	var c: Cinematicas = h.cin
	c._empezar()
	Juego.flags["vance_intro"] = true
	var antes := _musica_villano()
	var o: Vector2 = h.SALAS["urgencias"]["origen"]
	h.walter.position = o + Vector2(240, 186)
	var sal := c._mover("Dr. Salgado", "urgencias", Vector2(28, 96), Vector2.RIGHT)
	c._mover(NOMBRE, "urgencias", Vector2(28, 110), Vector2.RIGHT)
	h._enfocar([npc])
	sal.ir_a([o + Vector2(200, 170)], 60.0, 4.0)
	await npc.ir_a([o + Vector2(218, 186)], 60.0, 4.0)
	npc.mirar_a(h.walter.global_position)
	sal.mirar_a(h.walter.global_position)
	h.walter.figura.mirando = Vector2.LEFT
	await c._momento("vance")
	await h.hud.dialogo("Dr. Salgado", ["Pinkman, le presento al Dr. Bruno Vance. Viene trasladado del Hospital Central.",
		"Es interno, como usted. Los dos compiten por las mismas capacitaciones. Que gane el mejor."])
	await _decir(["Pinkman, ¿verdad? He oído hablar de ti.", "…Nada impresionante, la verdad.",
		"En el Central yo atendía veinte pacientes por turno. Con los ojos cerrados. Y sin despeinarme."])
	var r: int = await h.hud.elegir("Responder a Bruno Vance", "", [
		"«Bienvenido, Bruno. Aquí trabajamos en equipo.»",
		"«Veinte con los ojos cerrados… se nota en tus pacientes.»",
		"Sonreír y no decir nada"])
	match r:
		0:
			await _decir(["¿En equipo? Qué tierno. Yo trabajo para ganar, Pinkman."])
		1:
			await _decir(["…", "¡Ja! Gracioso. Disfruta tu chiste: va a ser lo único que ganes aquí."])
			Juego.sumar_estres(-2)
		_:
			await _decir(["El silencio de los que saben que van a perder. Me encanta."])
	await h.hud.dialogo("Dr. Salgado", ["(Suspira) Esto va a ser una semana larga."])
	Juego.musica(antes)
	await c._terminar(false)


# --- Burlas ------------------------------------------------------------------------------
func burla() -> void:
	var c: Cinematicas = h.cin
	var sala: String = h.sala_actual
	c._empezar()
	var antes := _musica_villano()
	var o: Vector2 = h.SALAS[sala]["origen"]
	var w: Vector2 = h.walter.position - o
	var inicio: Vector2 = h.SALAS[sala].get("entrada", w + Vector2(-90.0 if w.x > 140.0 else 90.0, 0))
	c._mover(NOMBRE, sala, inicio, Vector2.RIGHT)
	h._enfocar([npc])
	var lado := 22.0 if w.x < 400.0 else -22.0
	await npc.ir_a([o + w + Vector2(lado, 0)], 85.0, 4.0)
	npc.mirar_a(h.walter.global_position)
	h.walter.figura.mirando = npc.global_position - h.walter.global_position
	await c._momento("vance")
	await _decir(_linea_burla())
	var r: int = await h.hud.elegir("Responder a Bruno Vance", "", [
		"Ignorarlo y seguir trabajando",
		"«Mejor atiende a tus pacientes, Bruno.»",
		"«¿Apostamos? El que atienda más esta semana gana.»"])
	match r:
		0:
			Juego.sumar_estres(2)
			await _decir(["¿Me ignoras? Ese es el sonido de alguien que sabe que tengo razón."] if not respeto()
				else ["Bien. Concéntrate. Así me gusta… digo, así es más divertido ganarte."])
		1:
			Juego.sumar_estres(-1)
			await _decir(["…Touché, Pinkman. Touché.", "¡Pero esto no se queda así!"] if not respeto()
				else ["Ja. Eso mismo te iba a decir yo."])
		2:
			Juego.flags["vance_apuesta"] = true
			Juego.sumar_estres(1)
			await _decir(["¿Una apuesta? ¡Acepto! El viernes Salgado decide.", "Ve practicando tu cara de perdedor."])
	await npc.ir_a([o + inicio], 90.0, 4.0)
	Juego.musica(antes)
	await c._terminar(false)


func _linea_burla() -> Array:
	var l: Array = []
	if respeto():
		l = [["Pinkman. ¿Cuántos llevas hoy? Yo cuatro. No es que esté contando… sí estoy contando."],
			["Oye… lo del otro día. Gracias. Pero no te acostumbres: sigo queriendo ganarte."],
			["Hoy traje dos cafés. Uno es para ti. No digas nada o lo retiro."]]
	else:
		l = [["Pinkman. ¿Otra vez tú? Pensé que ya te habían devuelto a la facultad."],
			["Atendí tres pacientes mientras tú buscabas el estetoscopio. Muajaja."],
			["¿Sabías que en el Central me decían «el Rayo»? A ti aquí te dicen «el que está en el pasillo»."],
			["Salgado me sonrió hoy. A ti nunca te sonríe. Solo digo."]]
		if Juego.huele_mal():
			l.append(["¿Ese olor? Ah, eres tú. Hay duchas en el vestidor, ¿sabías?"])
		if Juego.estres >= Juego.ESTRES_ALTO:
			l.append(["Te tiemblan las manos, Pinkman. Así no se sutura. Mírame a mí: pulso de cirujano."])
		if Juego.bata_sucia():
			l.append(["Bonita bata. ¿Es de la colección «tres turnos sin lavar»?"])
		if Juego.semana["retrasos"] > 0:
			l.append(["Llegaste tarde esta semana. Yo llego a las 6:00. Y traigo café… solo para mí."])
		if Juego.rango != "Interno":
			l.append(["%s, ¿eh? Disfrútalo mientras dure. Ya voy detrás de ti." % Juego.rango])
		if Juego.get_amistad("Gianna") >= 4:
			l.append(["La chef nueva te sonríe mucho. Seguro le das lástima."])
	return l.pick_random()


# --- Le roba un paciente --------------------------------------------------------------------
func _paciente_para_robar() -> Dictionary:
	var mejor := {}
	for e in h.espera:
		if not e["caso"]["grave"] and (mejor.is_empty() or e["estabilidad"] < mejor["estabilidad"]):
			mejor = e
	return mejor


func robar() -> void:
	var e := _paciente_para_robar()
	if e.is_empty():
		return
	Juego.flags["vance_semana"] = int(Juego.flags.get("vance_semana", 0)) + 1
	if h.sala_actual != "urgencias":
		h.espera.erase(e)
		h._quitar_npc(e["npc"])
		h.hud.mostrar("Lucía: «Doctor, el Dr. Vance se llevó a %s de la sala de espera. Dice que “usted estaba muy lento”»." % e["nombre"], 4.5)
		return
	var c: Cinematicas = h.cin
	c._empezar()
	var antes := _musica_villano()
	var o: Vector2 = h.SALAS["urgencias"]["origen"]
	c._mover(NOMBRE, "urgencias", Vector2(28, 100), Vector2.RIGHT)
	var paciente: NPC = e["npc"]
	h._enfocar([npc, paciente])
	await npc.ir_a([paciente.position + Vector2(-16, 0)], 95.0, 4.0)
	npc.mirar_a(h.walter.global_position)
	await c._momento("vance")
	await _decir(["¡Este paciente es mío, Pinkman!", "Tú sigue… mirando. Se te da muy bien."] if not respeto()
		else ["Este lo atiendo yo, Pinkman. Tú tienes las camillas llenas. De nada."])
	h.espera.erase(e)
	h._quitar_npc(paciente)
	await npc.ir_a([o + Vector2(28, 100)], 90.0, 4.0)
	Juego.sumar_estres(2 if not respeto() else 0)
	Juego.musica(antes)
	await c._terminar(false)


# --- Duelo de los viernes -------------------------------------------------------------------
func fin_del_turno() -> void:
	if npc != null:
		Juego.flags["vance_semana"] = int(Juego.flags.get("vance_semana", 0)) + randi_range(3, 6)


func duelo_semanal(atendidos_walter: int) -> void:
	if npc == null or not Juego.flags.get("vance_intro", false):
		return
	var v: int = int(Juego.flags.get("vance_semana", 0))
	var apuesta: bool = Juego.flags.get("vance_apuesta", false)
	var antes := _musica_villano()
	await h.hud.dialogo("Dr. Salgado", ["Y la comparación que el Dr. Vance me pide cada viernes…",
		"Pacientes de la semana: Pinkman %d, Vance %d." % [atendidos_walter, v]])
	if atendidos_walter > v:
		await _decir(["¡¿Qué?! ¡Imposible! ¡Seguro contaron mal!", "…La próxima semana no te va a ir tan bien, Pinkman."] if not respeto()
			else ["Bien jugado, Pinkman. La próxima es mía."])
		Juego.sumar_reputacion(2 + (2 if apuesta else 0))
		Juego.sumar_estres(-3)
		h.hud.mostrar("¡Le ganaste a Vance esta semana! (+%d reputación)" % (2 + (2 if apuesta else 0)), 4.0)
	elif atendidos_walter < v:
		await _decir(["¡Muajajaja! ¿Lo ves, Pinkman? Soy el mejor interno de Pillbox.", "Puedes llorar en el vestidor. Hay pañuelos."] if not respeto()
			else ["Esta semana gané yo. Pero no fue fácil: me hiciste sudar."])
		Juego.sumar_estres(4)
		if apuesta:
			Juego.sumar_reputacion(-1)
	else:
		await _decir(["¿Empate? Odio los empates. ¡Exijo revancha!"])
	Juego.flags["vance_semana"] = 0
	Juego.flags["vance_apuesta"] = false
	Juego.musica(antes)


# --- Vance se equivoca (fin de su historia) ------------------------------------------------------
func se_equivoca() -> void:
	var c: Cinematicas = h.cin
	c._empezar()
	var antes := _musica_villano()
	Juego.flags["vance_final"] = "pendiente"
	var o: Vector2 = h.SALAS["urgencias"]["origen"]
	var pac := c._temporal("Señora Inés", 3, "rosa", Personaje.PELOS2, 2, "urgencias", Vector2(300, 186), Vector2.LEFT)
	c._mover(NOMBRE, "urgencias", Vector2(276, 186), Vector2.RIGHT)
	h.walter.position = o + Vector2(240, 200)
	h._enfocar([npc, pac])
	await c._momento("vance")
	await h.hud.dialogo("Señora Inés", ["Doctor… estoy sudando frío, me tiemblan las manos… me siento rarísima."])
	await _decir(["Tranquila, señora. Esto es clarísimo: es una alergia. Le pongo epinefrina y listo.", "(A Walter) Mira y aprende, Pinkman."])
	h.hud.mostrar("Sudor frío y temblor… eso parece azúcar baja, no alergia. Si le ponen epinefrina, se va a poner peor.", 4.0)
	var r: int = await h.hud.elegir("Vance se va a equivocar", "¿Qué haces?", [
		"Llevarlo aparte y decirle en voz baja",
		"Dejar que Salgado lo vea equivocarse",
		"No meterme: no es mi paciente"])
	match r:
		0:
			Juego.flags["vance_final"] = "respeto"
			await _decir(["¿Qué quieres, Pinkman? Estoy ocupado gan…", "…", "¿Azúcar baja? Pero… el sudor, el temblor… ay, no. Tienes razón."])
			h.hud.mostrar("Vance le mide la glucosa: 50 mg/dL. Le da glucosa y la señora Inés se recupera.", 3.5)
			await h.hud.dialogo("Señora Inés", ["¡Ay, qué alivio! Gracias, doctores."])
			await _decir(["Pinkman… pudiste dejarme quedar en ridículo. ¿Por qué no lo hiciste?",
				"…Gracias. Sigo queriendo ganarte. Pero ahora va a ser… limpio."])
			Juego.cambiar_amistad(NOMBRE, 3)
			Juego.sumar_reputacion(2)
			Juego.sumar_estres(-5)
		1:
			Juego.flags["vance_final"] = "humillado"
			var sal := c._mover("Dr. Salgado", "urgencias", Vector2(28, 96), Vector2.RIGHT)
			await sal.ir_a([o + Vector2(250, 170)], 80.0, 4.0)
			await h.hud.dialogo("Dr. Salgado", ["¡VANCE! ¿Epinefrina? ¡Esa señora tiene el azúcar en el piso!",
				"Pinkman, encárguese usted. Vance: a mi oficina. Ahora."])
			await _decir(["…Esto no se queda así, Pinkman. ¡Me las vas a pagar!"])
			Juego.sumar_reputacion(3)
			Juego.cambiar_amistad(NOMBRE, -3)
		_:
			Juego.flags["vance_final"] = "ignorado"
			h.hud.mostrar("La señora Inés empeora. Lucía la ve a tiempo y le da glucosa. Salgado se entera de todo.", 4.0)
			await h.hud.dialogo("Lucía", ["Doctor, usted lo vio y no dijo nada… Eso no se hace con un paciente."])
			Juego.sumar_reputacion(-2)
			Juego.sumar_estres(3)
	Juego.musica(antes)
	await c._terminar(false)


# --- Hablar con él (tecla E) -----------------------------------------------------------------
func _dialogo():
	if respeto():
		return [["Pinkman. Esta semana vamos parejos. Me gusta tener un rival de verdad."],
			["No le digas a nadie, pero… tu forma de hablar con los pacientes funciona. La estoy copiando."],
			["Si alguna vez necesitas que te cubra un paciente, avísame. Solo uno. No te emociones."]].pick_random()
	if Juego.flags.get("vance_final", "") == "humillado":
		return [["…No te hablo, Pinkman."], ["Salgado me puso a lavar camillas una semana. Gracias a ti. Muajaj… no, no me da risa."]].pick_random()
	return {"lineas": _linea_burla(), "opciones": [
		{"texto": "«Buen día, Bruno.»", "amistad": 0, "respuesta": ["¿Buen día? Lo será cuando Salgado vea mis números."]},
		{"texto": "«¿Quieres que te enseñe dónde están las duchas?»", "amistad": -1, "respuesta": ["…Muy gracioso. Muy. Gracioso."]},
		{"texto": "«Algún día vamos a ser buenos colegas, ya verás.»", "amistad": 1, "respuesta": ["¿Colegas? …Ja. Ya veremos, Pinkman."]},
	]}
