extends Sala
## Sala de urgencias del Hospital de Pillbox.
## Los pacientes llegan por hora; Walter los examina, diagnostica y trata
## con el insumo correcto antes de que su estabilidad llegue a 0.

const HOSP := "res://arte/interior/Hospital/"
const HOME := "res://arte/interior/Home/"
const PARED := 66.0
const CAMILLAS_X := [150.0, 214.0, 278.0]
const CAMILLA_Y := 116.0

const CASOS := [
	{"diagnostico": "Herida superficial", "signos": "Corte en la palma de la mano, sangrado leve. Está consciente y tranquilo.",
	 "falsos": ["Fractura", "Quemadura"], "insumo": "Vendaje", "deterioro": 0.25, "premio": 10, "inicial": 85.0, "grave": false},
	{"diagnostico": "Fiebre alta", "signos": "Temperatura de 39,5 °C, escalofríos y mucho cansancio.",
	 "falsos": ["Reacción alérgica", "Esguince"], "insumo": "Antipirético", "deterioro": 0.4, "premio": 10, "inicial": 80.0, "grave": false},
	{"diagnostico": "Esguince de tobillo", "signos": "Tobillo hinchado, le duele al apoyar. Se lo torció jugando fútbol.",
	 "falsos": ["Fractura expuesta", "Fiebre alta"], "insumo": "Férula", "deterioro": 0.25, "premio": 10, "inicial": 85.0, "grave": false},
	{"diagnostico": "Deshidratación", "signos": "Boca seca, mareo. Ha vomitado varias veces desde anoche.",
	 "falsos": ["Herida superficial", "Reacción alérgica"], "insumo": "Suero oral", "deterioro": 0.5, "premio": 10, "inicial": 75.0, "grave": false},
	{"diagnostico": "Reacción alérgica grave", "signos": "Ronchas en brazos y cuello, le cuesta respirar. Comió algo con maní hace 10 minutos.",
	 "falsos": ["Fiebre alta", "Deshidratación"], "insumo": "Epinefrina", "deterioro": 1.5, "premio": 15, "inicial": 60.0, "grave": true},
]
const NOMBRES := ["Don Ramiro", "Teresa", "Andrés", "Doña Carmen", "Julio", "Valentina", "Don Héctor", "Camila", "Mateo", "Rosa"]
const INSUMOS_A := ["Vendaje", "Antipirético", "Suero oral", "Férula"]
const CONSEJOS := [
	"Lucía: «Las heridas se cubren con vendaje; la fiebre baja con antipirético».",
	"Lucía: «Si alguien se torció algo, inmovilízalo con una férula».",
	"Lucía: «Vómito y mareo… eso es deshidratación: suero oral».",
	"Lucía: «La epinefrina está en el botiquín rojo. Solo para alergias graves».",
	"Lucía: «Si te equivocas de diagnóstico, el paciente empeora. Lee bien los signos».",
	"Lucía: «Hay snacks en la máquina, por si no desayunaste».",
]


## Paciente en una camilla: dibuja la figura acostada, el nombre y la barra.
class Paciente extends Node2D:
	var caso: Dictionary
	var nombre := ""
	var estabilidad := 80.0
	var estado := "diagnosticar"     # diagnosticar | tratar | alta
	var fallos := 0
	var se_quejo := false
	var figura: PersonaDibujo

	func _ready() -> void:
		figura = PersonaDibujo.new()
		figura.acostado = true
		figura.color_ropa = Color("b7d7c9")
		figura.color_piel = [Color("e0b48a"), Color("c68e5f"), Color("f1c9a5"), Color("8d5a3b")].pick_random()
		figura.color_pelo = [Color("2b1a10"), Color("6b4a2b"), Color("a0a0a0"), Color("1a1a1a")].pick_random()
		figura.position = Vector2(0, -34)
		figura.z_index = 1
		add_child(figura)

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var w := 34.0
		var y := -52.0
		var color := Color("4caf50")
		if estabilidad < 30.0:
			color = Color("e53935") if int(Time.get_ticks_msec() / 250) % 2 == 0 else Color("7f1d1d")
		elif estabilidad < 60.0:
			color = Color("fbc02d")
		draw_rect(Rect2(-w / 2 - 1, y - 1, w + 2, 5), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w / 2, y, w * estabilidad / 100.0, 3), color)
		var f := ThemeDB.fallback_font
		var t := nombre + ("  OK" if estado == "alta" else ("  ?" if estado == "diagnosticar" else "  +"))
		draw_string(f, Vector2(-w / 2 - 6, y - 3), t, HORIZONTAL_ALIGNMENT_CENTER, w + 12, 6, Color(0.1, 0.1, 0.1))


var pacientes: Array = [null, null, null]
var agenda: Array = []          # [{hora, caso, nombre}]
var _ultimo_minuto := 0.0
var _terminando := false
var _rep_inicio := 0
var atendidos := 0
var transferidos := 0
var lucia: PersonaDibujo


func construir() -> void:
	var tiles := textura(HOSP + "TilesHospital.png")
	fondo.agregar(Rect2(0, PARED, 480, 270 - PARED), tiles, Rect2(48, 176, 16, 16))
	fondo.agregar(Rect2(256, 176, 168, 94), tiles, Rect2(32, 160, 16, 16))       # sala de espera
	fondo.agregar(Rect2(0, ALTO_HUD, 480, PARED - ALTO_HUD), tiles, Rect2(16, 80, 48, 48))
	muros_borde(PARED - ALTO_HUD)
	var misc := HOSP + "Miscellaneous-Sheet.png"

	# Salida y casillero
	mueble(HOSP + "DoorsHospital-Sheet.png", Rect2(662, 30, 36, 50), Vector2(28, PARED), false)
	zona("salida", "Salir del hospital", Rect2(8, PARED, 40, 18))
	mueble(HOME + "Cupboard-Sheet.png", Rect2(470, 7, 20, 41), Vector2(66, 100), true, 16)
	zona("casillero", "Casillero (batas)", Rect2(52, 84, 30, 30))

	# Cruz y cartel
	mueble(misc, Rect2(2993, 18, 30, 33), Vector2(214, 58), false)
	cartel("URGENCIAS", Vector2(234, 30), Color("1e5a8a"))

	# Camillas con portasuero
	for i in 3:
		var x: float = CAMILLAS_X[i]
		mueble(HOSP + "BedHospital-Sheet.png", Rect2(19, 7, 26, 42), Vector2(x, CAMILLA_Y), true, 30)
		mueble(misc, Rect2(185, 12, 14, 35), Vector2(x + 20, CAMILLA_Y - 14), true, 6)
		zona("camilla%d" % i, "Camilla %d" % (i + 1), Rect2(x - 16, CAMILLA_Y - 8, 32, 24))

	# Botiquines y máquina de snacks
	mueble(misc, Rect2(1333, 20, 22, 27), Vector2(388, 94), true, 14)
	zona("botiquin", "Botiquín", Rect2(374, 86, 28, 26))
	cartel("BOTIQUÍN", Vector2(372, 96), Color("2b2b2b"))
	mueble(misc, Rect2(1333, 20, 22, 27), Vector2(420, 94), true, 14, Color("ff8a80"))
	zona("botiquin_rojo", "Botiquín rojo", Rect2(406, 86, 28, 26))
	cartel("ROJO", Vector2(412, 96), Color("b71c1c"))
	mueble(HOME + "Kitchen-Sheet.png", Rect2(996, 0, 24, 48), Vector2(458, 104), true, 28, Color("ffcc80"))
	zona("snacks", "Máquina de snacks", Rect2(444, 98, 30, 24))

	# Sala de espera
	mueble(misc, Rect2(929, 15, 62, 25), Vector2(300, 214), true, 12)
	mueble(misc, Rect2(929, 15, 62, 25), Vector2(380, 214), true, 12)

	# Recepción con Lucía detrás
	lucia = PersonaDibujo.new()
	lucia.color_ropa = Color("7cc6c0")
	lucia.color_pantalon = Color("7cc6c0").darkened(0.2)
	lucia.color_pelo = Color("5a2d0c")
	lucia.position = Vector2(110, 204)
	mundo.add_child(lucia)
	mueble(misc, Rect2(2563, 15, 122, 45), Vector2(110, 236), true, 30)
	zona("lucia", "Hablar con Lucía", Rect2(60, 236, 100, 16))


func posicion_inicial() -> Vector2:
	return Vector2(28, 90)


func al_entrar() -> void:
	_rep_inicio = Juego.reputacion
	_generar_agenda()
	_ultimo_minuto = Juego.minutos
	for nota in Juego.llegar_al_hospital():
		hud.mostrar(nota, 4.5)
	hud.mostrar("Atiende a los pacientes que lleguen. Tu turno termina a las 7:30 PM.", 4.0)
	walter.actualizar_aspecto()
	Juego.pausado = false


func _generar_agenda() -> void:
	var horas := [8 * 60, 10 * 60 + 30, 13 * 60 + 30, 16 * 60 + 30]
	var n := 3 if Juego.dia == 1 else 4
	var leves := CASOS.filter(func(c): return not c["grave"])
	var graves := CASOS.filter(func(c): return c["grave"])
	var nombres := NOMBRES.duplicate()
	nombres.shuffle()
	var con_grave := Juego.dia >= 2 and randf() < 0.6
	var indice_grave := randi_range(1, n - 1)
	for i in n:
		var caso: Dictionary = graves.pick_random() if (con_grave and i == indice_grave) else leves.pick_random()
		agenda.append({"hora": horas[i] + randi_range(0, 40), "caso": caso, "nombre": nombres[i]})


func _process(_delta: float) -> void:
	if _terminando:
		return
	walter.actualizar_aspecto()
	var dm := Juego.minutos - _ultimo_minuto
	_ultimo_minuto = Juego.minutos
	_llegadas()
	if dm > 0.0:
		_deterioro(dm)
	_actualizar_lista()
	if Juego.minutos >= Juego.FIN_TURNO:
		_terminar_turno()


func _llegadas() -> void:
	while not agenda.is_empty() and Juego.minutos >= agenda[0]["hora"]:
		var libre := pacientes.find(null)
		if libre == -1:
			return          # sala llena: espera a que se libere una camilla
		var a = agenda.pop_front()
		var p := Paciente.new()
		p.caso = a["caso"]
		p.nombre = a["nombre"]
		p.estabilidad = a["caso"]["inicial"]
		p.position = Vector2(CAMILLAS_X[libre], CAMILLA_Y)
		mundo.add_child(p)
		pacientes[libre] = p
		interactuables["camilla%d" % libre].etiqueta = "Atender a %s" % p.nombre
		refrescar_aviso()
		if a["caso"]["grave"]:
			hud.mostrar("Lucía: «¡Doctor, urgente! %s en la camilla %d, le cuesta respirar»." % [p.nombre, libre + 1], 4.0)
		else:
			hud.mostrar("Lucía: «Llegó %s a la camilla %d»." % [p.nombre, libre + 1], 3.0)


func _deterioro(dm: float) -> void:
	for i in 3:
		var p: Paciente = pacientes[i]
		if p == null or p.estado == "alta":
			continue
		p.estabilidad -= p.caso["deterioro"] * dm
		if p.estabilidad <= 0.0:
			transferidos += 1
			Juego.sumar_reputacion(-5)
			hud.mostrar("Lucía: «%s empeoró; lo está tomando el doctor de turno». (−5 reputación)" % p.nombre, 4.0)
			_liberar(i)


func _liberar(i: int) -> void:
	if pacientes[i]:
		pacientes[i].queue_free()
	pacientes[i] = null
	interactuables["camilla%d" % i].etiqueta = "Camilla %d" % (i + 1)
	refrescar_aviso()


func _actualizar_lista() -> void:
	var tareas: Array = []
	for i in 3:
		var p: Paciente = pacientes[i]
		if p and p.estado != "alta":
			var paso := "diagnosticar" if p.estado == "diagnosticar" else "tratar"
			tareas.append(["%s: %s" % [p.nombre, paso], false])
	if tareas.is_empty():
		tareas.append(["Esperar pacientes", false])
	tareas.append(["Turno hasta 7:30 PM", false])
	hud.poner_lista("Guardia · urgencias", tareas)


# --- Interacciones --------------------------------------------------------------
func interactuar(id: String) -> void:
	if id.begins_with("camilla"):
		await _camilla(int(id.substr(7)))
	else:
		match id:
			"botiquin": await _botiquin(INSUMOS_A, "Botiquín")
			"botiquin_rojo": await _botiquin(["Epinefrina"], "Botiquín rojo")
			"casillero": await _casillero()
			"snacks": await _snacks()
			"lucia": _lucia()
			"salida":
				hud.mostrar("Tu turno termina a las 7:30 PM. Son las %s." % Juego.hora_texto())
	walter.actualizar_aspecto()


func _camilla(i: int) -> void:
	var p: Paciente = pacientes[i]
	if p == null:
		hud.mostrar("La camilla %d está vacía." % (i + 1))
		return
	if p.estado == "alta":
		return
	if Juego.huele_muy_mal() and not p.se_quejo:
		p.se_quejo = true
		Juego.sumar_reputacion(-1)
		hud.mostrar("%s: «Uf, doctor… ¿usted se bañó?». (−1 reputación)" % p.nombre)
	if p.estado == "diagnosticar":
		var opciones: Array = [p.caso["diagnostico"]] + p.caso["falsos"]
		opciones.shuffle()
		var r: int = await hud.elegir("Examinar a %s" % p.nombre, "Signos: " + p.caso["signos"], opciones)
		if r < 0 or not is_instance_valid(p) or pacientes[i] != p:
			return
		if opciones[r] == p.caso["diagnostico"]:
			p.estado = "tratar"
			hud.mostrar("Diagnóstico: %s. Ahora trae el insumo adecuado del botiquín." % p.caso["diagnostico"])
		else:
			p.fallos += 1
			p.estabilidad = maxf(p.estabilidad - 10.0, 1.0)
			hud.mostrar("Eso no encaja con los signos. %s empeoró un poco. Revisa otra vez." % p.nombre)
		return
	# estado "tratar"
	if Juego.insumo_cargado == "":
		hud.mostrar("%s necesita tratamiento (%s). Busca el insumo en un botiquín." % [p.nombre, p.caso["diagnostico"]])
		return
	if Juego.insumo_cargado == p.caso["insumo"]:
		var premio: int = p.caso["premio"] if p.fallos == 0 else int(p.caso["premio"] / 2)
		Juego.sumar_reputacion(premio)
		Juego.insumo_cargado = ""
		p.estado = "alta"
		p.estabilidad = 100.0
		atendidos += 1
		hud.mostrar("¡%s está estable! (+%d reputación)" % [p.nombre, premio])
		await get_tree().create_timer(2.5).timeout
		if pacientes[i] == p:
			_liberar(i)
	else:
		hud.mostrar("%s no sirve para %s. Se desperdició el insumo." % [Juego.insumo_cargado, p.caso["diagnostico"].to_lower()])
		Juego.insumo_cargado = ""


func _botiquin(insumos: Array, titulo: String) -> void:
	if Juego.insumo_cargado != "":
		var r: int = await hud.elegir(titulo, "Ya llevas %s. Solo puedes cargar un insumo." % Juego.insumo_cargado,
			["Devolver %s" % Juego.insumo_cargado, "Cancelar"])
		if r == 0:
			Juego.insumo_cargado = ""
		return
	var opciones: Array = insumos.duplicate()
	opciones.append("Cancelar")
	var r2: int = await hud.elegir(titulo, "¿Qué insumo tomas?", opciones)
	if r2 >= 0 and r2 < insumos.size():
		Juego.insumo_cargado = insumos[r2]
		hud.mostrar("Tomaste: %s." % Juego.insumo_cargado, 2.0)


func _casillero() -> void:
	if Juego.ropa == "uniforme":
		hud.mostrar("Ya tienes la bata puesta.")
		return
	var r: int = await hud.elegir("Casillero", "Hay batas de repuesto del hospital.", ["Ponerme una bata (10 min)", "Cancelar"])
	if r == 0:
		walter.bloqueado = true
		Juego.pausado = true
		Juego.pasar_tiempo(10)
		await Juego.fundido_accion("10 minutos después…")
		Juego.ropa = "uniforme"
		Juego.pausado = false
		walter.bloqueado = false
		hud.mostrar("Te pusiste una bata del hospital.")


func _snacks() -> void:
	var r: int = await hud.elegir("Máquina de snacks", "Un paquete de galletas y un jugo.", ["Comer algo (5 min)", "Cancelar"])
	if r == 0:
		Juego.pasar_tiempo(5)
		Juego.hambre = minf(Juego.hambre + 20.0, 100.0)
		hud.mostrar("Comiste algo rápido. (+hambre)")


func _lucia() -> void:
	if Juego.huele_mal():
		hud.mostrar("Lucía: «Doctor, se lo digo con cariño: báñese antes de venir».", 4.0)
		return
	if Juego.energia < 25.0:
		hud.mostrar("Lucía: «Se ve agotado, doctor. Duerma más esta noche».", 4.0)
		return
	hud.mostrar(CONSEJOS.pick_random(), 4.0)


func _terminar_turno() -> void:
	_terminando = true
	Juego.pausado = true
	walter.bloqueado = true
	var pendientes := 0
	for p in pacientes:
		if p and p.estado != "alta":
			pendientes += 1
	Juego.terminar_turno()
	var delta_rep := Juego.reputacion - _rep_inicio
	var resumen := "Fin del turno · Atendiste %d · Transferidos %d · Reputación %+d" % [atendidos, transferidos, delta_rep]
	if pendientes > 0:
		resumen += "\n%d paciente(s) quedan con el turno de la noche." % pendientes
	Juego.pasar_tiempo(Juego.MINUTOS_VIAJE)
	Juego.punto_entrada = "puerta"
	Juego.ir_a("res://escenas/casa.tscn", resumen)
