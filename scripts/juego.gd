extends Node
## Autoload «Juego»: estado global de la partida.
## Reloj del día, necesidades de Walter, ropa, alarma, reputación,
## transiciones entre escenas y guardado.


# --- Constantes de diseño (ajustables) -----------------------------------
const MINUTOS_JUEGO_POR_SEGUNDO := 1.0           # 1 segundo real = 1 minuto de juego (turno ≈ 12 min reales)
const INICIO_TURNO := 7 * 60 + 30                  # 7:30 AM
const FIN_TURNO := 19 * 60 + 30                    # 7:30 PM
const MINUTOS_VIAJE := 20
const HORA_LIMITE_NOCHE := 26 * 60                 # 2:00 AM: Walter se desmaya
const TURNOS_HASTA_BATA_SUCIA := 3
const RUTA_GUARDADO := "user://partida.json"
const DIAS := ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]

# --- Estado de la partida -------------------------------------------------
var dia := 1
var minutos := 6.0 * 60.0        # minuto del día (puede pasar de 1440 de madrugada)
var higiene := 100.0
var energia := 80.0
var hambre := 60.0               # 100 = lleno, 0 = muerto de hambre
var ropa := "pijama"             # "pijama" | "uniforme"
var turnos_bata := 0             # turnos desde la última lavada
var reputacion := 0
var rango := "Interno"
var especialidad := ""
var horas_estudio := 0.0
var dias_trabajados := 0

## Requisitos para tomar la primera capacitación y ser Residente
const REQ_REPUTACION := 80
const REQ_HORAS_ESTUDIO := 5.0
const REQ_DIAS := 3
const ESPECIALIDADES := ["Urgencias", "Pediatría", "Cirugía"]
var racha_puntual := 0
var retrasos := 0
var alarma_puesta := false
var hora_alarma := 6 * 60
var dinero := 200
var comida := 6                 # comidas en la nevera
var cafetera := false           # desayuno completo en 10 min
var cama_buena := false         # descansa 25 % más
var mensajes: Array = []        # celular: {de, texto, opciones, leido, respondido}
var semana := {"turnos": 0, "atendidos": 0, "transferidos": 0, "retrasos": 0}
var derivados_semana := 0       # pacientes que Walter derivó por no estar seguro
const LIMITE_DERIVADOS := 4     # con tantos en la semana, Salgado llama a Walter y a Noctis
const PAGO_TURNO := {"Interno": 60, "Residente": 110}
const ARRIENDO := 150
var amistad := {}               # nombre del NPC -> 0..10
var favores := {}               # nombre del NPC -> favores que le debe a Walter
var flags := {}                 # marcas de historias y cosas de una vez por día
const AMISTAD_INICIAL := 3

# Banderas del día
var banado_hoy := false
var desayuno_hoy := false
var cenado_hoy := false
var fue_al_hospital := false
var turno_terminado := false
var falto_hoy := false

# Estado de sesión (no se guarda)
var pausado := true              # el reloj solo corre dentro de casa/hospital
var escala_debug := 1.0          # Tab mantiene x10 para pruebas
var punto_entrada := "cama"      # dónde aparece Walter: "cama" | "puerta"
var insumo_cargado := ""
var boost_hasta := -1.0          # bebida energética: camina más rápido hasta esta hora
var respuestas_auto: Array = []  # usado por las pruebas automáticas
var ultimo_resumen := ""         # cómo amaneció Walter (se muestra al despertar)
var auto_dialogo := false        # pruebas: los diálogos no esperan a que se pulse E
var tema: Theme

# Audio
var _musica: AudioStreamPlayer
var _musica_actual := ""
var _sfx: Array = []
var _sfx_i := 0
var _sonidos := {}

var _capa_fundido: CanvasLayer
var _fundido: ColorRect
var _texto_fundido: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_crear_acciones()
	_crear_tema()
	_crear_fundido()
	_crear_audio()


func _process(delta: float) -> void:
	escala_debug = 10.0 if Input.is_action_pressed("acelerar") else 1.0
	if pausado:
		return
	avanzar(delta * MINUTOS_JUEGO_POR_SEGUNDO * escala_debug)


# --- Reloj y necesidades --------------------------------------------------
func avanzar(mins: float) -> void:
	minutos += mins
	energia -= 0.10 * mins
	hambre -= 0.12 * mins
	higiene -= 0.05 * mins
	if hambre < 25.0:
		energia -= 0.10 * mins     # con hambre se cansa el doble
	_limitar()


## Para acciones con duración (bañarse, desayunar...): adelanta el reloj.
func pasar_tiempo(mins: float) -> void:
	avanzar(mins)


func _limitar() -> void:
	higiene = clampf(higiene, 0.0, 100.0)
	energia = clampf(energia, 0.0, 100.0)
	hambre = clampf(hambre, 0.0, 100.0)


func hora_texto(m: float = -1.0) -> String:
	if m < 0.0:
		m = minutos
	var total := int(m) % 1440
	var h := total / 60
	var mm := total % 60
	var sufijo := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%02d:%02d %s" % [h12, mm, sufijo]


func nombre_dia() -> String:
	return DIAS[(dia - 1) % 7]


func es_manana() -> bool:
	return not turno_terminado and not falto_hoy and not es_fin_de_semana()


func es_fin_de_semana() -> bool:
	return (dia - 1) % 7 >= 5


func es_viernes() -> bool:
	return (dia - 1) % 7 == 4


func huele_mal() -> bool:
	return higiene < 40.0


func huele_muy_mal() -> bool:
	return higiene < 20.0


func bata_sucia() -> bool:
	return turnos_bata >= TURNOS_HASTA_BATA_SUCIA


func velocidad_walter() -> float:
	var v := 72.0
	if energia < 10.0:
		v = 38.0
	elif energia < 30.0:
		v = 52.0
	if minutos < boost_hasta:
		v *= 1.35
	return v


## Requisitos de la capacitación: lista de [texto, cumplido].
func requisitos_residente() -> Array:
	return [
		["Reputación %d / %d" % [reputacion, REQ_REPUTACION], reputacion >= REQ_REPUTACION],
		["Horas de estudio %.1f / %.0f" % [horas_estudio, REQ_HORAS_ESTUDIO], horas_estudio >= REQ_HORAS_ESTUDIO],
		["Turnos trabajados %d / %d" % [dias_trabajados, REQ_DIAS], dias_trabajados >= REQ_DIAS],
	]


func puede_ser_residente() -> bool:
	if rango != "Interno":
		return false
	for r in requisitos_residente():
		if not r[1]:
			return false
	return true


func sumar_reputacion(n: int) -> void:
	reputacion = maxi(reputacion + n, 0)


# --- Relaciones con los NPC --------------------------------------------------------
func get_amistad(nombre: String) -> int:
	return int(amistad.get(nombre, AMISTAD_INICIAL))


## Cambia la amistad. Subir tiene un tope de +2 por persona y por día.
## Devuelve cuánto cambió de verdad.
func cambiar_amistad(nombre: String, d: int) -> int:
	if d > 0:
		var clave := "amistad_hoy_%s_%d" % [nombre, dia]
		var ya: int = int(flags.get(clave, 0))
		d = mini(d, 2 - ya)
		if d <= 0:
			return 0
		flags[clave] = ya + d
	var antes := get_amistad(nombre)
	amistad[nombre] = clampi(antes + d, 0, 10)
	return int(amistad[nombre]) - antes


## Marca algo como hecho hoy; devuelve true solo la primera vez del día.
func una_vez_hoy(clave: String) -> bool:
	var k := "%s_%d" % [clave, dia]
	if flags.has(k):
		return false
	flags[k] = true
	return true


## Como una_vez_hoy, pero sin marcar: dice si todavía no se ha hecho hoy.
func una_vez_hoy_disponible(clave: String) -> bool:
	return not flags.has("%s_%d" % [clave, dia])


func dar_favor(nombre: String, n: int = 1) -> void:
	favores[nombre] = int(favores.get(nombre, 0)) + n


# --- Dormir y nuevo día -----------------------------------------------------
## Devuelve un texto que resume cómo amaneció Walter.
func dormir(desmayado: bool = false) -> String:
	var hora_dormir := minutos
	var con_pijama := ropa == "pijama"
	var desperto_tarde := false
	var despertar: float
	if alarma_puesta and not desmayado:
		despertar = float(hora_alarma)
	else:
		despertar = float(randi_range(7 * 60 + 15, 8 * 60 + 30))
		desperto_tarde = true
	var horas := (despertar + 1440.0 - hora_dormir) / 60.0
	if hora_dormir >= 1440.0:          # se durmió después de medianoche
		horas = (despertar - (hora_dormir - 1440.0)) / 60.0
	horas = clampf(horas, 0.0, 12.0)

	var recuperacion := horas * 12.5
	if not con_pijama:
		recuperacion *= 0.8
	if cama_buena:
		recuperacion *= 1.25
	energia = clampf(energia + recuperacion, 0.0, 100.0)
	hambre = clampf(hambre - horas * 2.0, 0.0, 100.0)
	higiene = clampf(higiene - 8.0, 0.0, 100.0)

	dia += 1
	minutos = despertar
	banado_hoy = false
	desayuno_hoy = false
	cenado_hoy = false
	fue_al_hospital = false
	turno_terminado = false
	falto_hoy = false
	alarma_puesta = false
	insumo_cargado = ""
	punto_entrada = "cama"
	var extra := _nuevo_dia()
	guardar()

	var t := "Dormiste %.1f horas." % horas
	if desmayado:
		t = "Te quedaste dormido en cualquier parte. " + t
	if desperto_tarde:
		t += " No sonó ninguna alarma: ¡son las %s!" % hora_texto()
	else:
		t += " Sonó la alarma: %s." % hora_texto()
	if not con_pijama:
		t += " Dormir sin pijama no te dejó descansar bien."
	return t + extra


# --- Dinero, semana y mensajes --------------------------------------------------------
func pago_por_turno() -> int:
	return int(PAGO_TURNO.get(rango, 60))


## Cosas que pasan al empezar un día nuevo: arriendo los lunes y mensajes nuevos.
func _nuevo_dia() -> String:
	var t := ""
	if (dia - 1) % 7 == 0 and dia > 1:
		dinero -= ARRIENDO
		t += " Se pagó el arriendo de la semana (−$%d)." % ARRIENDO
		if dinero < 0:
			t += " ¡Quedaste en deuda!"
		mensaje("Banco", "Se debitaron $%d del arriendo. Saldo: $%d." % [ARRIENDO, dinero])
	if es_fin_de_semana():
		t += " Hoy es %s: no hay turno." % nombre_dia()
	_mensajes_del_dia()
	return t


func mensaje(de: String, texto: String, opciones: Array = []) -> void:
	mensajes.push_front({"de": de, "texto": texto, "opciones": opciones, "leido": false, "respondido": false})
	if mensajes.size() > 12:
		mensajes.resize(12)


func mensajes_nuevos() -> int:
	return mensajes.filter(func(m): return not m["leido"]).size()


func _mensajes_del_dia() -> void:
	var pool: Array = [
		["Mamá", "¿Estás comiendo bien, mijo? Te quiero mucho.", [
			{"texto": "Sí, mamá, tranquila.", "efecto": ""},
			{"texto": "La verdad, la nevera está vacía…", "efecto": "mama_dinero"}]],
		["Mamá", "¡Mi hijo el doctor! Ya les conté a todas mis amigas.", []],
		["Mamá", "Acuérdate de poner la alarma, que tú eres muy dormilón.", []],
		["Dr. Wilder Noctis", "Walter… ¿tienes algo para dormir? No es para mí. Es para un amigo. El amigo soy yo.", []],
		["Diego Quiroz", "Le dije a Jinu que Sheyla lo invitó a almorzar. ¡Lleva una hora esperando en la cafetería! Jajaja", []],
		["Erina", "¡Buenos días, doctor! Hoy hay sopa de pollo en la cafetería.", []],
	]
	if get_amistad("Lucía") >= 5:
		pool.append(["Lucía", "¡Buen trabajo ayer, doctor! Le guardé un café en la enfermería.", []])
	if flags.get("zac_final", "") == "bien":
		pool.append(["Dr. Zacarías Flores", "¡El café con la oficial Dakota fue increíble! Gracias por el consejo, doctor.", []])
	var m: Array = pool.pick_random()
	mensaje(m[0], m[1], m[2])


## Respuestas a mensajes del celular.
func efecto_mensaje(efecto: String) -> String:
	match efecto:
		"mama_dinero":
			if una_vez_hoy("mama_dinero") and not flags.has("mama_dio_dinero_semana_%d" % ((dia - 1) / 7)):
				flags["mama_dio_dinero_semana_%d" % ((dia - 1) / 7)] = true
				dinero += 50
				return "Mamá: «¡Ay, mijo! Te mandé $50 para mercado. Come bien»."
			return "Mamá: «Ya te mandé esta semana, mijo. Administra bien»."
	return ""


## Evaluación del viernes: nota, comentario de Salgado, bono y sueldo.
func evaluacion_semanal() -> Array:
	var s := semana
	var puntaje: int = int(s["atendidos"]) * 2 - int(s["transferidos"]) * 3 - int(s["retrasos"]) * 4 - derivados_semana * 2
	var nota := "Debe mejorar"
	var bono_rep := 0
	if puntaje >= 30:
		nota = "Excelente"
		bono_rep = 10
	elif puntaje >= 15:
		nota = "Bien"
		bono_rep = 5
	elif puntaje < 0:
		nota = "Mal"
		bono_rep = -5
	sumar_reputacion(bono_rep)
	var sueldo: int = int(s["turnos"]) * pago_por_turno()
	dinero += sueldo
	var lineas := ["Pinkman, es viernes: hora de su evaluación semanal.",
		"Turnos: %d · Atendidos: %d · Transferidos: %d · Derivados: %d · Retrasos: %d." % [s["turnos"], s["atendidos"], s["transferidos"], derivados_semana, s["retrasos"]],
		"Nota de la semana: %s. (%+d reputación)" % [nota, bono_rep],
		"Su sueldo de la semana: $%d. Ya está en su cuenta." % sueldo]
	match nota:
		"Excelente": lineas.append("Así se trabaja en Pillbox. Estoy orgulloso.")
		"Bien": lineas.append("Buen trabajo. Puede dar más.")
		"Mal": lineas.append("Esto no puede repetirse. La próxima semana lo quiero puntual y atento.")
		_: lineas.append("Hay cosas por mejorar. Confío en usted.")
	mensaje("Banco", "Pago de nómina: +$%d. Saldo: $%d." % [sueldo, dinero])
	semana = {"turnos": 0, "atendidos": 0, "transferidos": 0, "retrasos": 0}
	derivados_semana = 0
	derivados_semana = 0
	return lineas


# --- Llegada y salida del hospital --------------------------------------------
## Devuelve la lista de comentarios al llegar (retraso, pijama, olor...).
func llegar_al_hospital() -> Array:
	fue_al_hospital = true
	var notas: Array = []
	if minutos > INICIO_TURNO:
		var tarde := int(minutos - INICIO_TURNO)
		retrasos += 1
		semana["retrasos"] += 1
		racha_puntual = 0
		var castigo := 5 if tarde <= 30 else 10
		sumar_reputacion(-castigo)
		notas.append("Dr. Salgado: «Pinkman, llegó %d minutos tarde. El turno empieza a las 7:30». (−%d reputación)" % [tarde, castigo])
	else:
		racha_puntual += 1
		if racha_puntual % 5 == 0:
			sumar_reputacion(5)
			notas.append("Dr. Salgado: «%d días seguidos puntual. Así me gusta». (+5 reputación)" % racha_puntual)
	if ropa == "pijama":
		sumar_reputacion(-3)
		notas.append("Lucía: «¡Doctor, vino en pijama!». En el vestidor (2.ª puerta del pasillo) hay batas. (−3 reputación)")
	elif bata_sucia():
		sumar_reputacion(-1)
		notas.append("Lucía: «Esa bata ya pide lavadora, doctor». (−1 reputación)")
	if huele_muy_mal():
		sumar_reputacion(-2)
		notas.append("Lucía se tapa la nariz: «Doctor… ¿se bañó hoy?». (−2 reputación)")
	return notas


func terminar_turno() -> void:
	turno_terminado = true
	dias_trabajados += 1
	semana["turnos"] += 1
	if ropa == "uniforme":
		turnos_bata += 1


func faltar_al_turno() -> void:
	falto_hoy = true
	racha_puntual = 0
	sumar_reputacion(-15)


# --- Partida: nueva, guardar, cargar ------------------------------------------------
func nueva_partida() -> void:
	dia = 1
	minutos = 6.0 * 60.0
	higiene = 70.0
	energia = 80.0
	hambre = 55.0
	ropa = "pijama"
	turnos_bata = 0
	reputacion = 0
	rango = "Interno"
	racha_puntual = 0
	retrasos = 0
	alarma_puesta = false
	hora_alarma = 6 * 60
	banado_hoy = false
	desayuno_hoy = false
	cenado_hoy = false
	fue_al_hospital = false
	turno_terminado = false
	falto_hoy = false
	insumo_cargado = ""
	punto_entrada = "cama"
	ultimo_resumen = ""
	amistad = {}
	favores = {}
	flags = {}
	especialidad = ""
	horas_estudio = 0.0
	dias_trabajados = 0
	dinero = 200
	comida = 6
	cafetera = false
	cama_buena = false
	mensajes = [{"de": "Mamá", "texto": "¡Mucha suerte en tu primer día, mijo! Estoy muy orgullosa de ti.", "opciones": [], "leido": false, "respondido": false}]
	semana = {"turnos": 0, "atendidos": 0, "transferidos": 0, "retrasos": 0}
	derivados_semana = 0


func hay_partida_guardada() -> bool:
	return FileAccess.file_exists(RUTA_GUARDADO)


func guardar() -> void:
	var datos := {
		"dia": dia, "minutos": minutos, "higiene": higiene, "energia": energia,
		"hambre": hambre, "ropa": ropa, "turnos_bata": turnos_bata,
		"reputacion": reputacion, "rango": rango, "racha_puntual": racha_puntual,
		"retrasos": retrasos, "hora_alarma": hora_alarma,
		"amistad": amistad, "favores": favores, "flags": _flags_persistentes(),
		"especialidad": especialidad, "horas_estudio": horas_estudio, "dias_trabajados": dias_trabajados,
		"dinero": dinero, "comida": comida, "cafetera": cafetera, "cama_buena": cama_buena,
		"mensajes": mensajes, "semana": semana, "derivados_semana": derivados_semana,
	}
	var f := FileAccess.open(RUTA_GUARDADO, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(datos, "\t"))


## Solo se guardan las marcas de historia (las de «hoy» no hacen falta).
func _flags_persistentes() -> Dictionary:
	var f := {}
	var diaria := RegEx.create_from_string("_\\d+$")
	for k in flags:
		if diaria.search(str(k)) == null:
			f[k] = flags[k]
	return f


func cargar() -> bool:
	if not hay_partida_guardada():
		return false
	var f := FileAccess.open(RUTA_GUARDADO, FileAccess.READ)
	if f == null:
		return false
	var datos = JSON.parse_string(f.get_as_text())
	if typeof(datos) != TYPE_DICTIONARY:
		return false
	nueva_partida()
	dia = int(datos.get("dia", 1))
	minutos = float(datos.get("minutos", 360.0))
	higiene = float(datos.get("higiene", 70.0))
	energia = float(datos.get("energia", 80.0))
	hambre = float(datos.get("hambre", 55.0))
	ropa = str(datos.get("ropa", "pijama"))
	turnos_bata = int(datos.get("turnos_bata", 0))
	reputacion = int(datos.get("reputacion", 0))
	rango = str(datos.get("rango", "Interno"))
	racha_puntual = int(datos.get("racha_puntual", 0))
	retrasos = int(datos.get("retrasos", 0))
	hora_alarma = int(datos.get("hora_alarma", 360))
	especialidad = str(datos.get("especialidad", ""))
	dinero = int(datos.get("dinero", 200))
	comida = int(datos.get("comida", 6))
	cafetera = bool(datos.get("cafetera", false))
	cama_buena = bool(datos.get("cama_buena", false))
	mensajes = datos.get("mensajes", [])
	semana = datos.get("semana", semana)
	derivados_semana = int(datos.get("derivados_semana", 0))
	horas_estudio = float(datos.get("horas_estudio", 0.0))
	dias_trabajados = int(datos.get("dias_trabajados", 0))
	amistad = datos.get("amistad", {})
	favores = datos.get("favores", {})
	flags = datos.get("flags", {})
	return true


# --- Música y sonidos -------------------------------------------------------------
func _crear_audio() -> void:
	_musica = AudioStreamPlayer.new()
	_musica.volume_db = -9.0
	add_child(_musica)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)


func _stream(nombre: String) -> AudioStream:
	if not _sonidos.has(nombre):
		_sonidos[nombre] = load("res://audio/%s.wav" % nombre)
	return _sonidos[nombre]


## Cambia la música con un fundido corto: "casa", "hospital" o "" para silencio.
func musica(nombre: String) -> void:
	if nombre == _musica_actual:
		return
	_musica_actual = nombre
	var tw := create_tween()
	if _musica.playing:
		tw.tween_property(_musica, "volume_db", -40.0, 0.6)
	tw.tween_callback(func():
		if nombre == "":
			_musica.stop()
			return
		var st: AudioStreamWAV = _stream("musica_" + nombre)
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = int(st.get_length() * st.mix_rate)
		_musica.stream = st
		_musica.volume_db = -40.0
		_musica.play())
	if nombre != "":
		tw.tween_property(_musica, "volume_db", -9.0, 0.8)


func sonido(nombre: String, tono: float = 1.0, vol_db: float = -6.0) -> void:
	var p: AudioStreamPlayer = _sfx[_sfx_i]
	_sfx_i = (_sfx_i + 1) % _sfx.size()
	p.stream = _stream(nombre)
	p.pitch_scale = tono
	p.volume_db = vol_db
	p.play()


## Sonidito de voz (estilo retro) al escribir diálogos.
func blip(tono: float) -> void:
	sonido("blip", tono * randf_range(0.96, 1.04), -12.0)


# --- Escenas y fundidos -----------------------------------------------------------
func ir_a(ruta: String, texto: String = "") -> void:
	pausado = true
	await fundir(1.0, texto)
	get_tree().change_scene_to_file(ruta)
	await get_tree().process_frame
	await get_tree().process_frame
	await fundir(0.0)


## Fundido a negro (destino 1.0) o desde negro (destino 0.0), con texto opcional.
func fundir(destino: float, texto: String = "") -> void:
	_texto_fundido.text = texto
	var tw := create_tween()
	tw.tween_property(_fundido, "color:a", destino, 0.45)
	await tw.finished
	if destino >= 1.0 and texto != "":
		await get_tree().create_timer(1.1).timeout


## Fundido corto para acciones con duración («15 minutos después…»).
func fundido_accion(texto: String) -> void:
	await fundir(1.0, texto)
	await fundir(0.0)


func _crear_fundido() -> void:
	_capa_fundido = CanvasLayer.new()
	_capa_fundido.layer = 100
	add_child(_capa_fundido)
	_fundido = ColorRect.new()
	_fundido.color = Color(0, 0, 0, 0)
	_fundido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundido.set_anchors_preset(Control.PRESET_FULL_RECT)
	_capa_fundido.add_child(_fundido)
	_texto_fundido = Label.new()
	_texto_fundido.theme = tema
	_texto_fundido.add_theme_font_size_override("font_size", 12)
	_texto_fundido.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texto_fundido.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto_fundido.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto_fundido.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fundido.add_child(_texto_fundido)


func _crear_tema() -> void:
	tema = Theme.new()
	tema.default_font_size = 8


func _crear_acciones() -> void:
	var mapa := {
		"arriba": [KEY_W, KEY_UP], "abajo": [KEY_S, KEY_DOWN],
		"izquierda": [KEY_A, KEY_LEFT], "derecha": [KEY_D, KEY_RIGHT],
		"interactuar": [KEY_E, KEY_SPACE], "acelerar": [KEY_TAB], "celular": [KEY_C],
	}
	for accion in mapa:
		if not InputMap.has_action(accion):
			InputMap.add_action(accion)
		for tecla in mapa[accion]:
			var ev := InputEventKey.new()
			ev.physical_keycode = tecla
			InputMap.action_add_event(accion, ev)
