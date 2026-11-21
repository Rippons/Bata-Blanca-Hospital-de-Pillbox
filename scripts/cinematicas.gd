class_name Cinematicas
extends Node
## Cinemáticas de sucesos e historias del hospital. Cada una mueve a los personajes,
## lleva a Walter (y a la cámara) a donde pasa la escena y al final deja todo como estaba.
##
##  parto           · parto en el ascensor del pasillo
##  fuga_psiq       · un paciente psiquiátrico se escapa por el pasillo
##  alcalde         · visita del alcalde con escolta
##  tormenta        · tormenta eléctrica: lluvia, truenos, apagón y heridos
##  cita_zac        · Diego avisa: ¡Zacarías y Dakota en una cita en la cafetería!
##  cafe_zac        · Zacarías invita a Dakota a un café en recepción (Erina comenta)
##  graduacion_jinu · Jinu aprueba su examen
##  wilder_salva    · Wilder salva a un paciente frente a Salgado
##  despedida_erina · Erina se va de vacaciones y llega Brenda, la suplente
##  ceremonia       · ceremonia de ascenso en dirección
##  final_director  · Salgado se jubila: recorrido final y créditos

var h
var _guardados := {}           # nombre -> [posición, zona, quieto, mirada, visible]
var _temporales: Array = []    # NPC creados solo para la escena
var _sala_antes := ""
var _pos_antes := Vector2.ZERO
var _lluvia: CanvasLayer
var momento := ""              # escena clave en curso (las pruebas toman la captura aquí)

const GRUPO := ["Oscar Andrés Arciniegas Bustos", "Wilson Alejandro Saavedra Arenales",
	"Hugo Orielso Cañas Lozano", "Elkin Sebastian Perez Marquez"]


func _init(hospital) -> void:
	h = hospital


# --- Utilidades -----------------------------------------------------------------
func _o(sala: String) -> Vector2:
	return h.SALAS[sala]["origen"]


func _empezar() -> void:
	h.cinematica_activa = true
	h.walter.bloqueado = true
	h.hud.poner_aviso("")
	_sala_antes = h.sala_actual
	_pos_antes = h.walter.position - _o(_sala_antes)


func _terminar(volver := true) -> void:
	h._enfocar([])
	for n in _guardados.keys():
		_devolver(n)
	for t in _temporales:
		if is_instance_valid(t):
			h._quitar_npc(t)
	_temporales.clear()
	h.walter.camara.position = Vector2(0, -12)
	if volver and h.sala_actual != _sala_antes and _sala_antes != "entrada":
		await h.ir_a_sala(_sala_antes, _pos_antes)
	elif volver and _sala_antes == "entrada":
		await h.ir_a_sala("urgencias", Vector2(240, 200))
	h.walter.visible = true
	h.walter.bloqueado = false
	h.cinematica_activa = false
	h.refrescar_aviso()


func _ir(sala: String, pos: Vector2, mirada := Vector2.DOWN) -> void:
	h._enfocar([])
	h.walter.camara.position = Vector2(0, -12)
	if h.sala_actual == sala:
		h.walter.position = _o(sala) + pos
	else:
		await h.ir_a_sala(sala, pos, true)
	h.walter.bloqueado = true
	h.walter.figura.mirando = mirada
	h.walter.figura.caminar(false, 0.0)


## Lleva un NPC a una posición (en coordenadas de la sala) y lo deja quieto mirando a un lado.
func _mover(nombre: String, sala: String, pos: Vector2, mirada := Vector2.DOWN) -> NPC:
	if not h.npcs.has(nombre):
		return null
	var n: NPC = h.npcs[nombre]
	if not _guardados.has(nombre):
		_guardados[nombre] = [n.position, n.zona_paseo, n.quieto, n.mirada_base, n.visible]
	n.ruta.clear()
	n.guion = false
	n.position = _o(sala) + pos
	n.zona_paseo = Rect2()
	n.quieto = true
	n.visible = true
	n.mirada_base = mirada
	n.mirar_a(n.global_position + mirada)
	return n


func _devolver(nombre: String) -> void:
	if not _guardados.has(nombre) or not h.npcs.has(nombre):
		_guardados.erase(nombre)
		return
	var g: Array = _guardados[nombre]
	var n: NPC = h.npcs[nombre]
	n.position = g[0]
	n.zona_paseo = g[1]
	n.quieto = g[2]
	n.mirada_base = g[3]
	n.visible = g[4]
	n.guion = false
	n.ruta.clear()
	_guardados.erase(nombre)


## Crea un NPC solo para la escena (se borra al terminar).
func _temporal(nombre: String, piel: int, ropa: String, pelo: String, fila: int, sala: String, pos: Vector2, mirada := Vector2.DOWN) -> NPC:
	var n: NPC = h.persona(nombre, piel, ropa, pelo, fila, _o(sala) + pos, Rect2(), [], true)
	n.mirada_base = mirada
	n.mirar_a(n.global_position + mirada)
	_temporales.append(n)
	return n


func _decir(quien: String, lineas: Array) -> void:
	await h.hud.dialogo(quien, lineas)


func _pausa(t: float) -> void:
	await h.get_tree().create_timer(t).timeout


## Marca un momento clave. Con diálogos automáticos (pruebas) se detiene un instante.
func _momento(nombre: String) -> void:
	momento = nombre
	if Juego.auto_dialogo:
		await _pausa(1.2)
	momento = ""


func _altavoz(texto: String) -> void:
	Juego.sonido("altavoz", 1.0, -5.0)
	h.hud.mostrar("Altavoz: «%s»" % texto, 4.0)


## Plato con donas (para la cita).
class Donas extends Node2D:
	func _draw() -> void:
		draw_circle(Vector2(0, -22), 7.0, Color("f5f5f5"))
		for k in 3:
			var c := Vector2(-4 + k * 4, -23 + (k % 2) * 2)
			draw_circle(c, 2.6, Color("d98c5f"))
			draw_circle(c, 1.9, [Color("ff7eb6"), Color("6b3e26"), Color("ffe066")][k])
			draw_circle(c, 0.7, Color("f5f5f5"))


## Lluvia y relámpagos sobre toda la pantalla.
class Lluvia extends CanvasLayer:
	var _t := 0.0
	var _gotas: Array = []
	var _flash: ColorRect
	var _capa: Control
	func _ready() -> void:
		layer = 5
		_capa = Control.new()
		_capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_capa.set_anchors_preset(Control.PRESET_FULL_RECT)
		_capa.draw.connect(_dibujar)
		add_child(_capa)
		_flash = ColorRect.new()
		_flash.color = Color(1, 1, 1, 0)
		_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_flash)
		for i in 90:
			_gotas.append(Vector2(randf() * 480.0, randf() * 270.0))
	func _process(d: float) -> void:
		_t += d
		for i in _gotas.size():
			var g: Vector2 = _gotas[i] + Vector2(-60, 260) * d
			if g.y > 270.0:
				g = Vector2(randf() * 540.0, -6.0)
			_gotas[i] = g
		_capa.queue_redraw()
	func _dibujar() -> void:
		_capa.draw_rect(Rect2(0, 0, 480, 270), Color(0.1, 0.15, 0.3, 0.18))
		for g in _gotas:
			_capa.draw_line(g, g + Vector2(-2, 7), Color(0.75, 0.85, 1.0, 0.55), 1.0)
	func relampago() -> void:
		var tw := create_tween()
		_flash.color.a = 0.85
		tw.tween_property(_flash, "color:a", 0.0, 0.5)
		tw.tween_property(_flash, "color:a", 0.6, 0.05)
		tw.tween_property(_flash, "color:a", 0.0, 0.3)


# --- 1. Parto en el ascensor -------------------------------------------------------
func parto() -> void:
	_empezar()
	_altavoz("¡Emergencia en el ascensor del pasillo! Una señora en trabajo de parto quedó atrapada")
	await _pausa(1.2)
	await _ir("pasillo", Vector2(690, 104), Vector2.RIGHT)
	var madre := _temporal("Señora Carmen", 2, "rosa", Personaje.PELOS2, 1, "pasillo", Vector2(712, 94), Vector2.DOWN)
	_mover("Lucía", "pasillo", Vector2(672, 112), Vector2.RIGHT)
	_mover("Cristian Daniel", "pasillo", Vector2(736, 110), Vector2.LEFT)
	h._enfocar([madre])
	Juego.sonido("puerta", 0.6, -4.0)
	h.hud.mostrar("Walter y Cristian abren a la fuerza las puertas del ascensor…", 2.5)
	await _momento("parto")
	await _decir("Señora Carmen", ["¡Doctor! ¡Ya viene! ¡Ya viene el bebé! ¡No aguanto más!"])
	await _decir("Lucía", ["No hay tiempo de subirla a una camilla, doctor. Va a nacer aquí mismo."])
	var preguntas := [
		["¿Qué haces primero?", ["Lavarme las manos y ponerme guantes", "Jalar al bebé", "Esperar a que llegue Catelli"]],
		["La señora grita de dolor:", ["«Respire conmigo: inhale… exhale…»", "«¡Grite más bajito, señora!»", "Darle un analgésico"]],
		["Ya se ve la cabeza del bebé:", ["«Puje en la siguiente contracción, con fuerza»", "«Deje de pujar»", "«Acuéstese boca abajo»"]],
	]
	var correctas := 0
	for q in preguntas:
		var opciones: Array = q[1].duplicate()
		var buena: String = q[1][0]
		opciones.shuffle()
		var r: int = await h.hud.elegir("Parto en el ascensor", q[0], opciones)
		if r >= 0 and opciones[r] == buena:
			correctas += 1
			Juego.sonido("seleccion", 1.2, -10.0)
		else:
			await _decir("Lucía", ["¡No, doctor! Mejor: %s." % buena.to_lower().replace("«", "").replace("»", "")])
	await _pausa(0.5)
	Juego.sonido("llanto", 1.0, -2.0)
	await _pausa(1.0)
	Juego.sonido("llanto", 1.1, -4.0)
	await _decir("Señora Carmen", ["¡Es un niño! ¡Mi bebé! Ay, doctor, ¿cómo se llama usted?", "…Walter. ¡Se va a llamar Walter!"])
	var esposo := _temporal("Don Julio (esposo)", 3, "overol", Personaje.PELOS, 7, "pasillo", Vector2(620, 150), Vector2.RIGHT)
	await esposo.ir_a([_o("pasillo") + Vector2(690, 130)], 90.0, 3.0)
	await _decir("Don Julio (esposo)", ["¡Llegué! ¡Llegué! ¿Qué me perdí?", "…¿Un bebé? ¿YA? ¿En el ascensor? ¿Y se llama Walter?"])
	await _decir("Cristian Daniel", ["Bienvenido a Pillbox, Walter chiquito. Naciste en el ascensor que nunca funciona."])
	Juego.sumar_reputacion(correctas)
	Juego.cambiar_amistad("Lucía", 1)
	Juego.flags["bebe_walter"] = true
	h.hud.mostrar("¡Nació Walter chiquito en el ascensor! (+%d reputación)" % correctas, 4.0)
	await _terminar()


# --- 2. Fuga de un paciente psiquiátrico ---------------------------------------------
func fuga_psiq() -> void:
	_empezar()
	_altavoz("¡Código gris! Un paciente de observación salió corriendo por el pasillo")
	await _pausa(1.0)
	await _ir("pasillo", Vector2(140, 186), Vector2.RIGHT)
	var o := _o("pasillo")
	var ernesto := _temporal("Don Ernesto", 0, "pijama", Personaje.PELOS, 1, "pasillo", Vector2(80, 150), Vector2.RIGHT)
	var reyes := _mover("Alejandro Reyes", "pasillo", Vector2(40, 150), Vector2.RIGHT)
	var mcc := _mover("John McClane", "pasillo", Vector2(20, 170), Vector2.RIGHT)
	h._enfocar([ernesto])
	await _decir("Don Ernesto", ["¡Los marcianos vienen por mí! ¡Nadie me va a meter en esa máquina de rayos!"])
	if reyes:
		reyes.ir_a([o + Vector2(840, 140)], 70.0, 12.0)
	if mcc:
		mcc.ir_a([o + Vector2(820, 170)], 60.0, 12.0)
	await ernesto.ir_a([o + Vector2(880, 150)], 85.0, 12.0)
	h._enfocar([])
	await _ir("pasillo", Vector2(800, 160), Vector2.RIGHT)
	ernesto.mirar_a(h.walter.global_position)
	await _momento("fuga")
	await _decir("John McClane", ["(Jadeando) Doctor… ese señor corre más que yo… y yo hago ejercicio. A veces."])
	var calmado := false
	for intento in 2:
		var r: int = await h.hud.elegir("Calmar a Don Ernesto", "Está acorralado junto al tablero eléctrico y muy asustado.", [
			"«Don Ernesto, soy el Dr. Pinkman. Aquí nadie le va a hacer daño.»",
			"«¡Agárrenlo!»",
			"«Los marcianos se fueron; los vi irse por la ventana.»"])
		if r == 0:
			calmado = true
			break
		elif r == 2:
			await _decir("Don Ernesto", ["¿De verdad? ¿Por cuál ventana? …¡Mentira! ¡Usted es uno de ellos!"])
		else:
			await _decir("Don Ernesto", ["¡NOOO! ¡Suéltenme!"])
	if calmado:
		await _decir("Don Ernesto", ["…¿Nadie me va a hacer daño?", "Bueno, doctor. Pero usted me acompaña. Y me da gelatina."])
		Juego.sumar_reputacion(2)
		h.hud.mostrar("Calmaste a Don Ernesto sin que nadie saliera herido. (+2 reputación)", 3.5)
	else:
		await _decir("John McClane", ["Bueno… a la antigua. Disculpe, señor."])
		h.hud.mostrar("McClane lo detiene con cuidado. Don Ernesto vuelve a observación, muy ofendido.", 3.5)
	Juego.cambiar_amistad("John McClane", 1)
	Juego.cambiar_amistad("Alejandro Reyes", 1)
	await _terminar()


# --- 3. Visita del alcalde ---------------------------------------------------------
func alcalde() -> void:
	_empezar()
	Juego.flags["ev_alcalde"] = true
	_altavoz("Atención, personal: el alcalde de Pillbox está llegando al hospital. ¡Sonrían!")
	await _pausa(1.2)
	await _ir("entrada", h.SALAS["entrada"]["entrada"], Vector2.RIGHT)
	_mover("Dr. Salgado", "entrada", Vector2(200, 162), Vector2.RIGHT)
	var ext: Exterior = h.exterior
	var autos: Array = []
	Juego.sonido("sirena", 1.3, -12.0)
	autos.append(ext.vehiculo("patrulla", true, 2.4, 330.0))
	await _pausa(0.5)
	autos.append(ext.vehiculo("auto4", true, 2.4, 262.0))
	await _pausa(0.5)
	autos.append(ext.vehiculo("patrulla", true, 2.4, 190.0))
	await _pausa(2.4)
	Juego.sonido("puerta", 0.9, -8.0)
	var alc := _temporal("Alcalde Rodrigo Ferrer", 1, "casual_blanco", Personaje.PELOS, 1, "entrada", Vector2(290, 160), Vector2.LEFT)
	h._enfocar([alc])
	await _momento("alcalde")
	await _decir("Alcalde Rodrigo Ferrer", ["¡Doctor Salgado! ¡Qué hospital tan… tan… limpio!", "¿Y este joven? ¿El famoso Dr. Pinkman? Me han hablado mucho de usted."])
	await _decir("Dr. Salgado", ["(En voz baja) Pinkman, sea amable. Este señor decide el presupuesto."])
	var r: int = await h.hud.elegir("El alcalde pregunta", "«Dígame, doctor: ¿qué es lo que más necesita este hospital?»", [
		"Más enfermeras y personal",
		"Un ascensor que funcione",
		"Que nos suban el sueldo"])
	match r:
		0:
			await _decir("Alcalde Rodrigo Ferrer", ["Más personal… Muy sensato. Lo anoto, doctor."])
			Juego.sumar_reputacion(3)
			h.hud.mostrar("Respuesta de líder. Salgado asiente orgulloso. (+3 reputación)", 3.5)
		1:
			await _decir("Alcalde Rodrigo Ferrer", ["¿El ascensor? ¡Ja! Me contaron lo del capitán Rojas.", "Le mandaré a alguien que no sea… Catelli."])
			Juego.sumar_reputacion(2)
			h.hud.mostrar("El alcalde se rió. A Catelli no le va a gustar. (+2 reputación)", 3.5)
		_:
			await _decir("Alcalde Rodrigo Ferrer", ["…Ejem. El sueldo. Claro. Lo… estudiaremos."])
			await _decir("Dr. Salgado", ["(Tapándose la cara) Pinkman…"])
			Juego.sumar_reputacion(-1)
	for a in autos:
		if is_instance_valid(a):
			a.queue_free()
	await _terminar()


# --- 4. Tormenta eléctrica ---------------------------------------------------------
func tormenta() -> void:
	_empezar()
	if not _lluvia:
		_lluvia = Lluvia.new()
		h.add_child(_lluvia)
	Juego.sonido("trueno", 1.0, -2.0)
	_lluvia.relampago()
	_altavoz("Tormenta eléctrica sobre Pillbox. Personal: prepárense para heridos")
	await _pausa(1.0)
	await _ir("entrada", h.SALAS["entrada"]["entrada"], Vector2.DOWN)
	await _pausa(0.8)
	Juego.sonido("trueno", 0.85, 0.0)
	_lluvia.relampago()
	await _momento("tormenta")
	await _decir("Cristian Daniel", ["¡Doctor! ¡Se cayó un árbol en la avenida! Vienen dos heridos."])
	await _pausa(0.6)
	Juego.sonido("trueno", 0.7, 0.0)
	_lluvia.relampago()
	await _terminar()
	if not h.apagon:
		h._iniciar_apagon()
	var hora: float = Juego.minutos
	h.agenda.append({"hora": hora + 3.0, "caso": h.eventos._caso("Golpe en la cabeza"), "nombre": "Ramiro (tormenta)"})
	h.agenda.append({"hora": hora + 6.0, "caso": h.eventos._caso("Herida superficial"), "nombre": "Lina (tormenta)"})
	h.agenda.sort_custom(func(x, y): return x["hora"] < y["hora"])


## Truenos de vez en cuando mientras llueve.
func _process(delta: float) -> void:
	if _lluvia and randf() < delta * 0.08:
		Juego.sonido("trueno", randf_range(0.7, 1.1), -6.0)
		_lluvia.relampago()


# --- 5. Cita de Zacarías y Dakota en la cafetería -------------------------------
func cita_zac() -> void:
	if h.sala_actual != "urgencias":
		h.eventos._programar("cita_zac", int(Juego.minutos) + 10)
		return
	_empezar()
	Juego.flags["ev_cita_zac"] = true
	var diego := _mover("Diego Quiroz", "urgencias", Vector2(36, 100), Vector2.RIGHT)
	if diego:
		h._enfocar([diego])
		await diego.ir_a([h.walter.position + Vector2(-20, 0)], 110.0, 3.0)
		diego.mirar_a(h.walter.global_position)
	await _decir("Diego Quiroz", ["¡WALTER! ¡WALTER, TIENES QUE VER ESTO!", "¡Ven a la cafetería, rápido! ¡Sin hacer ruido!"])
	await _ir("cafeteria", Vector2(206, 188), Vector2.LEFT)
	_mover("Diego Quiroz", "cafeteria", Vector2(186, 190), Vector2.LEFT)
	_mover("Doña Luz", "cafeteria", Vector2(240, 146), Vector2.LEFT)
	var zac := _mover("Dr. Zacarías Flores", "cafeteria", Vector2(100, 210), Vector2.RIGHT)
	var dak: NPC = _mover("Dakota", "cafeteria", Vector2(152, 210), Vector2.LEFT)
	if dak == null:
		dak = _temporal("Dakota", 0, "hoja:dakota", "", 0, "cafeteria", Vector2(152, 210), Vector2.LEFT)
	var donas := Donas.new()
	donas.position = _o("cafeteria") + Vector2(126, 215)
	h.mundo.add_child(donas)
	h._enfocar([zac, dak])
	await _decir("Diego Quiroz", ["(Susurrando) ¡Mire, mire! ¡Zacarías y la oficial Dakota! ¡Una cita! ¡CON DONAS!"])
	await _momento("cita")
	await _decir("Dr. Zacarías Flores", ["E-esta… esta dona tiene chispitas. Como… como tus ojos. N-no, tus ojos no tienen chispitas. Perdón."])
	await _decir("Dakota", ["(Mordiendo una dona) Mmm.", "…Me gustan las chispitas.", "Y tus ojos también me gustan. Cállate. No dije nada."])
	await _decir("Doña Luz", ["(A Walter, bajito) Ay, doctor, ya van por la tercera dona y él todavía no se ha comido la primera."])
	await _decir("Dr. Zacarías Flores", ["Dakota, yo… quería preguntarte si… si el sábado…"])
	await _decir("Dakota", ["Sí.", "…No has terminado la pregunta. Igual es sí."])
	Juego.sonido("exito", 1.1, -8.0)
	await _decir("Diego Quiroz", ["(Secándose una lágrima) No estoy llorando. Es el azúcar de las donas. Se me metió en el ojo."])
	await _decir("Dakota", ["(Sin voltear) Los veo a los dos detrás de la barra.", "…Hola, Dr. Pinkman. Hola, Quiroz."])
	await _decir("Dr. Zacarías Flores", ["¡¿D-doctor?! ¡¿Desde cuándo están ahí?!"])
	Juego.cambiar_amistad("Dr. Zacarías Flores", 1)
	Juego.cambiar_amistad("Dakota", 1)
	donas.queue_free()
	await _terminar()


# --- Extra: Zacarías invita a Dakota a un café (recepción) -------------------------
func cafe_zac() -> void:
	if not h.npcs.has("Dakota"):
		return
	_empezar()
	Juego.flags["ev_cafe_zac"] = true
	await _decir("Dr. Zacarías Flores", ["…¿Sabe qué, doctor? Dakota está en recepción ahora mismo.", "Si no lo hago ya, no lo hago nunca. ¡Acompáñeme!"])
	await _ir("recepcion", Vector2(272, 142), Vector2.DOWN)
	var dak := _mover("Dakota", "recepcion", Vector2(420, 226), Vector2.LEFT)
	var zac := _mover("Dr. Zacarías Flores", "recepcion", Vector2(238, 96), Vector2.DOWN)
	if h.npcs.has("Erina"):
		h.npcs["Erina"].mirar_a(h.walter.global_position)
	await _decir("Erina", ["(A Walter, bajito) ¿Y eso? ¿Zacarías saliendo del vestidor peinado?", "Jaja… el león salió a cazar."])
	h._enfocar([zac])
	var o := _o("recepcion")
	await zac.ir_a([o + Vector2(330, 112), o + Vector2(330, 206), o + Vector2(396, 226)], 45.0, 8.0)
	zac.mirar_a(dak.global_position)
	dak.mirar_a(zac.global_position)
	h._enfocar([zac, dak])
	await _decir("Dr. Zacarías Flores", ["O-oficial Dakota. Buenas… buenas tardes. Soy Zacarías. Flores. Doctor Flores. Zacarías.", "Quería… ¿le gustaría… un café? Conmigo. Un café conmigo. Yo invito. El café."])
	await _decir("Dakota", ["…", "(Mirando al piso) ¿U-un café? ¿Conmigo?", "Ejem. Digo. Sí. Un café está… aceptable."])
	await _momento("cafe")
	await _decir("Erina", ["(Susurrando) ¡Doctor! ¡Mire a Dakota! ¡Se puso roja!", "Yo no sabía que Dakota, con lo seria y gótica que es, también tenía corazón…", "¡Es igual de tímida y tierna que Zacarías! Ay, me muero."])
	await _decir("Dakota", ["…Y deja de mirarme así, Erina. Te estoy oyendo."])
	await _decir("Dr. Zacarías Flores", ["¡S-sí! ¡Café! Mañana le… le digo la hora. ¡Gracias! ¡Adiós! ¡Digo, hasta luego!"])
	Juego.sonido("exito", 1.2, -10.0)
	await zac.ir_a([o + Vector2(330, 206), o + Vector2(330, 112), o + Vector2(238, 80)], 70.0, 6.0)
	Juego.cambiar_amistad("Dr. Zacarías Flores", 1)
	Juego.cambiar_amistad("Erina", 1)
	await _terminar(false)


# --- 6. Graduación de Jinu ---------------------------------------------------------
func graduacion_jinu() -> void:
	if not h.npcs.has("Jinu Blake"):
		return
	_empezar()
	Juego.flags["ev_graduacion_jinu"] = true
	_altavoz("Personal disponible, al tablón del pasillo. El Dr. Brown tiene un anuncio")
	await _pausa(1.0)
	await _ir("pasillo", Vector2(764, 186), Vector2.UP)
	_mover("Dr. Maximiliano Brown", "pasillo", Vector2(764, 120), Vector2.DOWN)
	_mover("Jinu Blake", "pasillo", Vector2(740, 150), Vector2.RIGHT)
	_mover("Sheyla Escobedo", "pasillo", Vector2(712, 150), Vector2.RIGHT)
	_mover("Diego Quiroz", "pasillo", Vector2(800, 152), Vector2.LEFT)
	_mover("Lucía", "pasillo", Vector2(820, 172), Vector2.LEFT)
	h._enfocar([h.npcs["Jinu Blake"]])
	await _decir("Dr. Maximiliano Brown", ["Atención. Jinu Blake presentó el examen de internado.", "Nota: 4,8 sobre 5. La más alta de su promoción."])
	Juego.sonido("aplausos", 1.0, -4.0)
	await _momento("graduacion")
	await _decir("Jinu Blake", ["¿¡4,8!? ¡No puede ser! ¡Gracias, gracias!", "Dr. Pinkman, usted me enseñó a no temblar con el estetoscopio. Y Sheyla… Sheyla me enseñó todo lo demás."])
	await _decir("Sheyla Escobedo", ["Comprendo que esperaba un 5.", "…Era estadísticamente probable que aprobaras. Pero igual estoy orgullosa."])
	await _decir("Diego Quiroz", ["(Llorando a mares) ¡Mi muchacho! ¡Yo lo vi crecer!", "…No estoy llorando. Es alergia. A los graduados."])
	await _decir("Lucía", ["Diego, lo conoces hace dos semanas."])
	Juego.cambiar_amistad("Jinu Blake", 2)
	Juego.sumar_reputacion(1)
	h.hud.mostrar("¡Jinu aprobó! Le ayudaste a llegar ahí. (+1 reputación)", 3.5)
	await _terminar()


# --- 7. Wilder salva a un paciente ---------------------------------------------------
func wilder_salva() -> void:
	if not h.npcs.has("Dr. Wilder Noctis"):
		return
	_empezar()
	Juego.flags["ev_wilder_salva"] = true
	await _ir("urgencias", Vector2(200, 186), Vector2.RIGHT)
	var paciente := _temporal("Señor Arturo", 1, "casual_rojo", Personaje.PELOS, 1, "urgencias", Vector2(360, 196), Vector2.DOWN)
	h._enfocar([paciente])
	await _decir("Señor Arturo", ["Enfermera… me siento… raro…"])
	paciente.figura.acostado = true
	Juego.sonido("error", 0.6, -4.0)
	h.hud.mostrar("¡El señor Arturo se desplomó en la sala de espera!", 2.5)
	var w := _mover("Dr. Wilder Noctis", "urgencias", Vector2(40, 110), Vector2.RIGHT)
	h._enfocar([w])
	await w.ir_a([_o("urgencias") + Vector2(336, 196)], 110.0, 4.0)
	w.mirar_a(paciente.global_position)
	await _decir("Dr. Wilder Noctis", ["¡Yo me encargo! Pulso débil, respira… le bajó el azúcar.", "¡Glucosa, rápido! Señor Arturo, quédese conmigo, ¿sí?"])
	await _pausa(0.8)
	paciente.figura.acostado = false
	await _decir("Señor Arturo", ["…¿Qué pasó? ¿Quién es usted, ángel rubio?"])
	var sal := _mover("Dr. Salgado", "urgencias", Vector2(40, 100), Vector2.RIGHT)
	await sal.ir_a([_o("urgencias") + Vector2(300, 170)], 60.0, 4.0)
	sal.mirar_a(w.global_position)
	await _momento("wilder")
	await _decir("Dr. Salgado", ["¿Noctis? ¿Usted? ¿TRABAJANDO? ¿Antes de que alguien se lo pidiera?", "…Voy a necesitar sentarme."])
	await _decir("Dr. Wilder Noctis", ["Se lo dije, doctor: promesa de garrita.", "(A Walter) Gracias por no rendirte conmigo, Walter."])
	Juego.cambiar_amistad("Dr. Wilder Noctis", 2)
	Juego.flags["wilder_heroe"] = true
	await _terminar()


# --- 8. Erina se va de vacaciones (llega Brenda) -------------------------------------
func despedida_erina() -> void:
	_empezar()
	Juego.flags["ev_despedida_erina"] = true
	Juego.flags["erina_vacaciones"] = [Juego.dia + 3, Juego.dia + 7]
	await _ir("recepcion", Vector2(240, 206), Vector2.UP)
	_mover("Diego Quiroz", "recepcion", Vector2(196, 196), Vector2.UP)
	_mover("Jinu Blake", "recepcion", Vector2(286, 196), Vector2.UP)
	_mover("Lucía", "recepcion", Vector2(316, 206), Vector2.UP)
	await _momento("despedida")
	await _decir("Erina", ["¡Bueno! Mañana empiezo mis vacaciones. ¡Una semana en la playa!", "Les dejo a Brenda, mi prima. Es un amor… aunque se confunde un poquito."])
	await _decir("Diego Quiroz", ["¡Te compramos un regalo! Es un flotador de flamenco. Lo infló Jinu. Casi se desmaya."])
	await _decir("Jinu Blake", ["(Mareado) Valió la pena."])
	Juego.sonido("aplausos", 1.1, -8.0)
	await _decir("Erina", ["¡Ay, los voy a extrañar! Dr. Pinkman, cuide a Brenda, ¿sí? Y no deje que Diego le enseñe bromas."])
	Juego.cambiar_amistad("Erina", 1)
	await _terminar()


## Recepcionista de hoy: Erina o Brenda (si Erina está de vacaciones).
static func erina_de_vacaciones() -> bool:
	var v = Juego.flags.get("erina_vacaciones", [])
	return v is Array and v.size() == 2 and Juego.dia >= int(v[0]) and Juego.dia <= int(v[1])


static func dialogo_brenda():
	return [["¡Bienvenido al Hospital de Pillbox! ¿Viene a… a qué viene? Ah, usted trabaja aquí. Perdón, Dr. Pinkerton.",
		"Pinkman. Eso. Lo anoté al revés."],
		["Hoy mandé a un señor con dolor de muela a la cafetería. ¿Eso estuvo mal? Doña Luz le dio sopa."],
		["Erina me dejó una lista de 40 cosas. Ya hice la número 1: sonreír. Voy bien."],
		["Contesté el teléfono y dije «Pizzería Pillbox». Costumbre de mi otro trabajo."]].pick_random()


# --- 9. Ceremonia de ascenso -------------------------------------------------------
func ceremonia(rango: String) -> void:
	_empezar()
	await _ir("direccion", Vector2(240, 196), Vector2.UP)
	_mover("Dr. Salgado", "direccion", Vector2(240, 162), Vector2.DOWN)
	var invitados := {"Lucía": Vector2(176, 200), "Dr. Maximiliano Brown": Vector2(200, 214), "Erina": Vector2(280, 214),
		"Diego Quiroz": Vector2(304, 200), "Jinu Blake": Vector2(158, 214), "Cristian Daniel": Vector2(322, 214)}
	for n in invitados:
		_mover(n, "direccion", invitados[n], Vector2.UP)
	h._enfocar([h.npcs["Dr. Salgado"]])
	var esp: String = Juego.especialidad
	var titulo := rango + (" de " + esp if esp != "" and rango != "Director" else "")
	await _decir("Dr. Salgado", ["Atención, por favor.", "Hoy el Dr. Walter Pinkman deja de ser %s." % _rango_anterior(rango),
		"Por su trabajo con los pacientes y con sus compañeros, desde hoy es: %s." % titulo,
		"Aquí tiene su nuevo carné, doctor. No lo pierda: el último que lo perdió fue Noctis."])
	Juego.sonido("aplausos", 1.0, -2.0)
	h.hud.mostrar("Nuevo carné: Dr. Walter Pinkman · %s" % titulo, 4.0)
	await _momento("ceremonia")
	await _decir("Lucía", ["¡Felicitaciones, doctor! Sabía que llegaría lejos desde el día que vino en pijama."])
	if h.npcs.has("Jinu Blake"):
		await _decir("Jinu Blake", ["¡Usted es mi ejemplo, Dr. Pinkman! ¡Algún día quiero un carné así!"])
	await _decir("Diego Quiroz", ["¡Discurso! ¡Discurso! …¿No? Bueno, yo aplaudo más fuerte."])
	await _terminar()


func _rango_anterior(r: String) -> String:
	var i: int = Juego.RANGOS.find(r)
	return Juego.RANGOS[i - 1] if i > 0 else "Interno"


# --- 10. Final: Walter, Director del Hospital de Pillbox -------------------------------
func final_director() -> void:
	_empezar()
	await _ir("direccion", Vector2(240, 196), Vector2.UP)
	_mover("Dr. Salgado", "direccion", Vector2(240, 162), Vector2.DOWN)
	await _decir("Dr. Salgado", ["Pinkman. Siéntese. No, mejor quédese de pie: esto es importante.",
		"Treinta y dos años dirigiendo este hospital. Ya es hora de que me jubile y me dedique a mis orquídeas.",
		"La junta y yo estuvimos de acuerdo: el próximo Director del Hospital de Pillbox es usted."])
	var r: int = await h.hud.elegir("Dr. Salgado", "«¿Acepta, Dr. Pinkman?»", ["Acepto. Cuidaré este hospital como usted lo hizo.", "¿Yo? … Sí. ¡Sí, acepto!"])
	await _decir("Dr. Salgado", ["Lo sabía. Llegó aquí como un interno que se dormía con el despertador…" if r == 0 else "Esa cara de susto es la misma del primer día. Me alegra.",
		"…y se va a quedar con mi oficina. Cuídela. Y cuide a su gente: ellos son el hospital.", "Vamos, despídase de todos antes de sentarse en esa silla."])
	# Recorrido final
	await _recorrido("recepcion", Vector2(240, 206), [
		["Erina", ["¡Director Pinkman! Suena precioso. ¡Voy a anunciarlo por el altavoz cada vez que pueda!"]],
		["Alejandro Reyes", [_linea_reyes()]],
	])
	await _recorrido("pasillo", Vector2(400, 186), [
		["Diego Quiroz", ["¡Mi director! ¿Ahora sí me deja poner música en el pasillo?"]],
		["Jinu Blake", ["Algún día voy a ser como usted, Director. Sheyla dice que estadísticamente es posible."]],
	])
	await _recorrido("urgencias", Vector2(200, 186), [
		["Lucía", ["Urgencias va a seguir funcionando como reloj, Director. Usted nos enseñó."]],
		["Dr. Maximiliano Brown", ["Pinkman, el mejor interno que entrené. No se lo diga a nadie."]],
		["Cristian Daniel", ["¡Las camillas siempre listas, jefe!"]],
	])
	await _recorrido("vestidor", Vector2(300, 186), [["Dr. Zacarías Flores", [_linea_zacarias()]]])
	await _recorrido("cafeteria", Vector2(206, 188), [
		["Doña Luz", ["El director come gratis. Bueno, los martes. No abuse, mijo."]],
		["Dr. Wilder Noctis", [_linea_wilder()]],
	])
	await _ir("direccion", Vector2(240, 166), Vector2.DOWN)
	Juego.rango = "Director"
	Juego.flags["final_visto"] = true
	Juego.sonido("aplausos", 1.0, 0.0)
	await _decir("Dr. Salgado", ["Bienvenido a su oficina, Director Walter Pinkman."])
	await creditos()
	Juego.guardar()
	h.hud.mostrar("¡Felicitaciones, Director Pinkman! Puedes seguir jugando: el hospital es tuyo.", 5.0)
	await _terminar(false)


func _recorrido(sala: String, pos: Vector2, quienes: Array) -> void:
	await _ir(sala, pos, Vector2.UP)
	for q in quienes:
		if h.npcs.has(q[0]):
			var n: NPC = h.npcs[q[0]]
			if n.global_position.distance_to(_o(sala) + Vector2(240, 135)) > 600.0:
				continue
			n.mirar_a(h.walter.global_position)
			h._enfocar([n])
			await _decir(q[0], q[1])
	h._enfocar([])


func _linea_reyes() -> String:
	if h._pawlak_interes() == "si":
		return "¡Felicitaciones, Director! Rhea le manda saludos… y dice que ya no se va a caer de la moto. Tanto."
	return "¡Felicitaciones, Director! La recepción queda vigilada, como siempre."


func _linea_zacarias() -> String:
	if Juego.flags.get("zac_novios", false):
		return "¡Director! Dakota y yo le guardamos una dona. Con chispitas. Gracias por todo, de verdad."
	return "D-Director… gracias por los consejos. Algún día voy a ser valiente como usted."


func _linea_wilder() -> String:
	if Juego.flags.get("wilder_heroe", false) or h._wilder_redimido():
		return "Director Walter… prometo trabajar todos los días. Promesa de garrita. Esta vez de verdad."
	return "¿Director? ¿Eso significa que ya no me va a delatar? …¿No? Bueno, mañana sí trabajo."


## Créditos finales con el grupo de trabajo.
func creditos() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 30
	h.add_child(capa)
	var fondo := ColorRect.new()
	fondo.color = Color(0.02, 0.04, 0.08, 0.0)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(fondo)
	var caja := VBoxContainer.new()
	caja.position = Vector2(40, 280)
	caja.custom_minimum_size = Vector2(400, 0)
	caja.add_theme_constant_override("separation", 6)
	capa.add_child(caja)
	var lineas: Array = [
		["BATA BLANCA", 22, Color.WHITE], ["Hospital de Pillbox", 10, Color("9fe6ff")], ["", 6, Color.WHITE],
		["Walter Pinkman, Director", 9, Color("ffd166")], ["", 6, Color.WHITE],
		["Un juego de", 8, Color("9fb3c8")]]
	for n in GRUPO:
		lineas.append([n, 9, Color.WHITE])
	lineas += [["", 6, Color.WHITE], ["Multimedia y Videojuegos · FESC", 8, Color("9fb3c8")], ["", 6, Color.WHITE],
		["Personajes", 8, Color("9fb3c8")],
		["Erina · Lucía · Dr. Salgado · Dr. Maximiliano Brown · Cristian Daniel", 7, Color.WHITE],
		["Diego Quiroz · Jinu Blake · Sheyla Escobedo · Doña Luz", 7, Color.WHITE],
		["Dr. Zacarías Flores · Dakota · Dr. Wilder Noctis · Paul Catelli", 7, Color.WHITE],
		["Alejandro Reyes · John McClane · Jaiden Mendoza · Rhea Pawlak · Capitán Marcos Rojas", 7, Color.WHITE],
		["", 6, Color.WHITE], ["Arte: MetroCity de JIK-A-4, con ediciones del equipo", 7, Color("9fb3c8")],
		["Música y sonidos: originales del equipo", 7, Color("9fb3c8")], ["Hecho con Godot 4.5", 7, Color("9fb3c8")],
		["", 10, Color.WHITE], ["¡Gracias por jugar!", 12, Color("ffd166")]]
	for l in lineas:
		var lab := Label.new()
		lab.text = l[0]
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size = Vector2(400, 0)
		lab.add_theme_font_size_override("font_size", l[1])
		lab.add_theme_color_override("font_color", l[2])
		caja.add_child(lab)
	var tw: Tween = h.create_tween()
	tw.tween_property(fondo, "color:a", 0.92, 1.0)
	await tw.finished
	await h.get_tree().process_frame
	var dur := 1.0 if Juego.auto_dialogo else 16.0
	var tw2: Tween = h.create_tween()
	tw2.tween_property(caja, "position:y", 135.0 - caja.size.y, dur)
	await tw2.finished
	await _momento("creditos")
	await _pausa(0.5 if Juego.auto_dialogo else 2.0)
	var tw3: Tween = h.create_tween()
	tw3.tween_property(fondo, "color:a", 0.0, 0.8)
	tw3.parallel().tween_property(caja, "modulate:a", 0.0, 0.8)
	await tw3.finished
	capa.queue_free()
