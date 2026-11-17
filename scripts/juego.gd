extends Node
## Autoload «Juego»: estado global de la partida.
## Reloj del día, necesidades de Walter, ropa, alarma, reputación,
## transiciones entre escenas y guardado.

signal mensaje(texto: String)

# --- Constantes de diseño (ajustables) -----------------------------------
const MINUTOS_JUEGO_POR_SEGUNDO := 10.0 / 60.0   # 1 min real = 10 min de juego
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
var racha_puntual := 0
var retrasos := 0
var alarma_puesta := false
var hora_alarma := 6 * 60

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
var respuestas_auto: Array = []  # usado por las pruebas automáticas
var ultimo_resumen := ""         # cómo amaneció Walter (se muestra al despertar)
var tema: Theme

var _capa_fundido: CanvasLayer
var _fundido: ColorRect
var _texto_fundido: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_crear_acciones()
	_crear_tema()
	_crear_fundido()


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
	return not turno_terminado and not falto_hoy


func huele_mal() -> bool:
	return higiene < 40.0


func huele_muy_mal() -> bool:
	return higiene < 20.0


func bata_sucia() -> bool:
	return turnos_bata >= TURNOS_HASTA_BATA_SUCIA


func velocidad_walter() -> float:
	if energia < 10.0:
		return 38.0
	if energia < 30.0:
		return 52.0
	return 72.0


func sumar_reputacion(n: int) -> void:
	reputacion = maxi(reputacion + n, 0)


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
	return t


# --- Llegada y salida del hospital --------------------------------------------
## Devuelve la lista de comentarios al llegar (retraso, pijama, olor...).
func llegar_al_hospital() -> Array:
	fue_al_hospital = true
	var notas: Array = []
	if minutos > INICIO_TURNO:
		var tarde := int(minutos - INICIO_TURNO)
		retrasos += 1
		racha_puntual = 0
		var castigo := 5 if tarde <= 30 else 10
		sumar_reputacion(-castigo)
		notas.append("Dr. Salgado: «Vega, llegó %d minutos tarde. El turno empieza a las 7:30». (−%d reputación)" % [tarde, castigo])
	else:
		racha_puntual += 1
		if racha_puntual % 5 == 0:
			sumar_reputacion(5)
			notas.append("Dr. Salgado: «%d días seguidos puntual. Así me gusta». (+5 reputación)" % racha_puntual)
	if ropa == "pijama":
		sumar_reputacion(-3)
		notas.append("Lucía: «¡Doctor, vino en pijama!». Ve al casillero a ponerte una bata. (−3 reputación)")
	elif bata_sucia():
		sumar_reputacion(-1)
		notas.append("Lucía: «Esa bata ya pide lavadora, doctor». (−1 reputación)")
	if huele_muy_mal():
		sumar_reputacion(-2)
		notas.append("Lucía se tapa la nariz: «Doctor… ¿se bañó hoy?». (−2 reputación)")
	return notas


func terminar_turno() -> void:
	turno_terminado = true
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


func hay_partida_guardada() -> bool:
	return FileAccess.file_exists(RUTA_GUARDADO)


func guardar() -> void:
	var datos := {
		"dia": dia, "minutos": minutos, "higiene": higiene, "energia": energia,
		"hambre": hambre, "ropa": ropa, "turnos_bata": turnos_bata,
		"reputacion": reputacion, "rango": rango, "racha_puntual": racha_puntual,
		"retrasos": retrasos, "hora_alarma": hora_alarma,
	}
	var f := FileAccess.open(RUTA_GUARDADO, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(datos, "\t"))


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
	return true


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
		"interactuar": [KEY_E, KEY_SPACE], "acelerar": [KEY_TAB],
	}
	for accion in mapa:
		if not InputMap.has_action(accion):
			InputMap.add_action(accion)
		for tecla in mapa[accion]:
			var ev := InputEventKey.new()
			ev.physical_keycode = tecla
			InputMap.action_add_event(accion, ev)
