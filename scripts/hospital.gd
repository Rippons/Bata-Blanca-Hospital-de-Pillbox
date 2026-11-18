extends Sala
## Hospital de Pillbox. Varias salas en la misma escena (cada una en su propia
## zona del mundo); las puertas llevan de una a otra con un fundido.
##   Recepción → Pasillo → 1 Urgencias · 2 Vestidor · 3 Cafetería · 4 Dirección · 5 Consultorios (cerrado)
## Los pacientes de urgencias siguen empeorando aunque Walter esté en otra sala.

const HOSP := "res://arte/interior/Hospital/"
const HOME := "res://arte/interior/Home/"
const MISC := HOSP + "Miscellaneous-Sheet.png"
const PARED := 66.0

## Cada sala: origen en el mundo, tamaño de la vista (cámara) e «interior»: el
## rectángulo real del cuarto (pared + piso). Las salas pequeñas quedan enmarcadas.
const SALAS := {
	"recepcion": {"nombre": "Recepción", "origen": Vector2(0, 0), "tam": Vector2(480, 270),
		"interior": Rect2(0, 18, 480, 252)},
	"pasillo": {"nombre": "Pasillo", "origen": Vector2(0, 1000), "tam": Vector2(960, 270),
		"interior": Rect2(0, 18, 960, 196)},
	"urgencias": {"nombre": "Urgencias", "origen": Vector2(0, 2000), "tam": Vector2(480, 270),
		"interior": Rect2(0, 18, 480, 252), "entrada": Vector2(28, 90)},
	"vestidor": {"nombre": "Vestidor", "origen": Vector2(0, 3000), "tam": Vector2(480, 270),
		"interior": Rect2(112, 40, 256, 180), "entrada": Vector2(340, 112)},
	"cafeteria": {"nombre": "Cafetería", "origen": Vector2(0, 4000), "tam": Vector2(480, 270),
		"interior": Rect2(72, 34, 336, 204), "entrada": Vector2(100, 106)},
	"direccion": {"nombre": "Dirección", "origen": Vector2(0, 5000), "tam": Vector2(480, 270),
		"interior": Rect2(120, 40, 240, 180), "entrada": Vector2(334, 112)},
	"consultorios": {"nombre": "Consultorio", "origen": Vector2(0, 6000), "tam": Vector2(480, 270),
		"interior": Rect2(112, 40, 256, 180), "entrada": Vector2(340, 112)},
}
const ALTO_PARED := 48.0
## Puertas del pasillo: [id de sala, x de la puerta en el pasillo, cartel, x de la puerta dentro del área]
const PUERTAS_PASILLO := [
	["urgencias", 120.0, "1 · URGENCIAS", 28.0],
	["vestidor", 300.0, "2 · VESTIDOR", 340.0],
	["cafeteria", 480.0, "3 · CAFETERÍA", 100.0],
	["direccion", 660.0, "4 · DIRECCIÓN", 334.0],
	["consultorios", 840.0, "5 · CONSULTORIOS", 340.0],
]
const CAMILLAS_X := [150.0, 214.0, 278.0]
const CAMILLA_Y := 116.0

const CASOS := Casos.CASOS
const HERRAMIENTAS := Casos.HERRAMIENTAS
## Nombres de pacientes (no se repiten en el día ni con los NPC del hospital)
const NOMBRES := ["Don Ramiro", "Teresa", "Andrés", "Doña Carmen", "Julio", "Valentina", "Don Héctor", "Camila",
	"Mateo", "Rosa", "Felipe", "Laura", "Daniela", "Tomás", "Isabel", "Martín", "Natalia", "Don Jorge",
	"Lucas", "Mariana", "Esteban", "Doña Inés", "Simón", "Gabriela", "Don Aurelio", "Paula", "Sebastián",
	"Doña Marta", "Iván", "Luisa", "Don Fabio", "Carolina", "Andrea", "Don Rubén", "Manuela", "Óscar"]
const INSUMOS_ROJO := Casos.INSUMOS_ROJO
const CONSEJOS := [
	"Lucía: «Las heridas se cubren con vendaje; la fiebre baja con antipirético».",
	"Lucía: «Si alguien se torció algo, inmovilízalo con una férula».",
	"Lucía: «Vómito y mareo… eso es deshidratación: suero oral».",
	"Lucía: «La epinefrina está en el botiquín rojo. Solo para alergias graves».",
	"Lucía: «Primero examine: el termómetro, el tensiómetro o el glucómetro no mienten».",
	"Lucía: «Si le duele el oído, mire con el otoscopio. Si le silba el pecho, use el estetoscopio».",
	"Lucía: «Un golpe de calor se trata con suero frío del botiquín rojo, y rápido».",
	"Lucía: «Si te equivocas de diagnóstico, el paciente empeora. Lee bien los signos».",
	"Lucía: «Si no desayunaste, la cafetería es la tercera puerta del pasillo».",
]
const ROPAS_PACIENTE := ["casual_blanco", "casual_rojo", "rosa", "fucsia", "naranja", "overol"]


## Paciente en una camilla: personaje acostado, sábana, nombre y barra de estabilidad.
class Paciente extends Node2D:
	var caso: Dictionary
	var nombre := ""
	var estabilidad := 80.0
	var estado := "diagnosticar"     # diagnosticar | tratar | alta
	var fallos := 0
	var se_quejo := false
	var conto_historia := false
	var examinado := false
	var calmado := false               # Walter lo tranquilizó: empeora más lento
	var vigilado_hasta := -1.0         # Lucía lo vigila: no empeora hasta esa hora
	var apariencia := {}               # piel, ropa y pelo (los mismos que tenía en la sala de espera)
	var orientado := false             # Brown ya dio una pista sobre este paciente
	var figura: Personaje

	static func apariencia_al_azar() -> Dictionary:
		var hoja: String = Personaje.PELOS if randf() < 0.5 else Personaje.PELOS2
		var fila: int = randi_range(0, 7) if hoja == Personaje.PELOS else [0, 2, 3, 4].pick_random()
		return {"piel": randi_range(0, 5), "ropa": ROPAS_PACIENTE.pick_random(), "pelo_hoja": hoja, "pelo_fila": fila}

	class Sabana extends Node2D:
		func _draw() -> void:
			draw_rect(Rect2(-11, -22, 22, 16), Color("dfe9f2"))
			draw_rect(Rect2(-11, -22, 22, 3), Color("b9cbe0"))

	func _ready() -> void:
		figura = Personaje.new()
		figura.acostado = true
		if apariencia.is_empty():
			apariencia = Paciente.apariencia_al_azar()
		figura.piel = apariencia["piel"]
		figura.ropa = apariencia["ropa"]
		figura.pelo_hoja = apariencia["pelo_hoja"]
		figura.pelo_fila = apariencia["pelo_fila"]
		figura.position = Vector2(0, -6)
		add_child(figura)
		add_child(Sabana.new())

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var w := 34.0
		var y := -50.0
		var color := Color("4caf50")
		if estabilidad < 30.0:
			color = Color("e53935") if int(Time.get_ticks_msec() / 250.0) % 2 == 0 else Color("7f1d1d")
		elif estabilidad < 60.0:
			color = Color("fbc02d")
		draw_rect(Rect2(-w / 2 - 1, y - 1, w + 2, 5), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w / 2, y, w * estabilidad / 100.0, 3), color)
		var t := nombre + ("  OK" if estado == "alta" else ("  ?" if estado == "diagnosticar" else "  +"))
		draw_string(ThemeDB.fallback_font, Vector2(-w / 2 - 8, y - 3), t, HORIZONTAL_ALIGNMENT_CENTER, w + 16, 6, Color(0.1, 0.1, 0.1))


## Tablón de corcho con papeles (capacitaciones), dibujado por código.
class Tablon extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-24, -34, 48, 30), Color("6b4a2b"))
		draw_rect(Rect2(-22, -32, 44, 26), Color("c8955a"))
		var papeles := [[Rect2(-19, -30, 12, 10), Color("fdf6e3")], [Rect2(-5, -29, 10, 12), Color("fff3b0")],
			[Rect2(7, -30, 12, 9), Color("dff0ff")], [Rect2(-17, -18, 14, 9), Color("ffe0e0")], [Rect2(2, -16, 15, 8), Color("fdf6e3")]]
		for p in papeles:
			draw_rect(p[0], p[1])
			draw_circle(p[0].position + Vector2(p[0].size.x / 2.0, 1.5), 1.2, Color("c0392b"))


## Marca de triaje sobre un paciente en espera: punto de color, nombre y barra.
class MarcaTriaje extends Node2D:
	var color := Color("4caf50")
	var nombre := ""
	var estabilidad := 100.0
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		draw_circle(Vector2(-14, -38), 3.0, Color.BLACK)
		draw_circle(Vector2(-14, -38), 2.2, color)
		draw_string(ThemeDB.fallback_font, Vector2(-10, -36), nombre, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.1, 0.1, 0.1))
		draw_rect(Rect2(-12, -34, 24, 2), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-12, -34, 24 * estabilidad / 100.0, 2), color)


const TRIAJE := {"rojo": Color("e53935"), "amarillo": Color("fbc02d"), "verde": Color("4caf50")}
const PUESTOS_ESPERA := [Vector2(312, 205), Vector2(336, 205), Vector2(392, 205), Vector2(416, 205), Vector2(364, 205), Vector2(440, 205)]

var sala_actual := "recepcion"
var _puerta_consultorios: Node2D
var espera: Array = []          # pacientes en la sala de espera de urgencias
var pacientes: Array = [null, null, null]
var agenda: Array = []          # [{hora, caso, nombre}]
var _ultimo_minuto := 0.0
var _terminando := false
var _cambiando := false
var _rep_inicio := 0
var atendidos := 0
var transferidos := 0
var derivados := 0

# Eventos del día
var evento_pico := -1.0
var apagon := false
var apagon_hora := -1.0
var catelli_estado := ""         # "" | llamado | llego | arreglando
var catelli_llega := 0.0
var catelli_listo := 0.0
var catelli_consejo := 0         # efecto del consejo de esta visita (-1, 0, +1)
var llamado := ""                # "" | rendimiento | derivados
var llamado_hora := -1.0
var llamado_desde := 0.0
var oscuridad: CanvasModulate


func construir() -> void:
	_construir_recepcion()
	_construir_pasillo()
	_construir_urgencias()
	_construir_vestidor()
	_construir_cafeteria()
	_construir_direccion()
	_construir_consultorio()
	origen = Vector2.ZERO
	oscuridad = CanvasModulate.new()
	oscuridad.color = Color.WHITE
	add_child(oscuridad)


var _piso_y := 0.0    # y donde empieza el piso de la sala en construcción


func _empezar_sala(id: String, piso: Rect2) -> Texture2D:
	var s: Dictionary = SALAS[id]
	origen = s["origen"]
	var tam: Vector2 = s["tam"]
	var r: Rect2 = s["interior"]
	var tiles := textura(HOSP + "TilesHospital.png")
	_piso_y = r.position.y + ALTO_PARED
	suelo_color(Rect2(0, 0, tam.x, tam.y), Color("1b2430"))
	suelo(Rect2(r.position.x, _piso_y, r.size.x, r.end.y - _piso_y), tiles, piso)
	suelo(Rect2(r.position.x, r.position.y, r.size.x, ALTO_PARED), tiles, Rect2(16, 80, 48, 48))
	if r.size.x < tam.x:      # sala pequeña: marco alrededor
		var marco := Color("8e99a6")
		suelo_color(Rect2(r.position.x - 3, r.position.y - 3, r.size.x + 6, 3), marco)
		suelo_color(Rect2(r.position.x - 3, r.end.y, r.size.x + 6, 3), marco)
		suelo_color(Rect2(r.position.x - 3, r.position.y, 3, r.size.y), marco)
		suelo_color(Rect2(r.end.x, r.position.y, 3, r.size.y), marco)
	elif r.end.y < tam.y:     # pasillo: zócalo inferior
		suelo_color(Rect2(r.position.x, r.end.y, r.size.x, 3), Color("8e99a6"))
	solido_rect(Rect2(r.position.x, r.position.y - 10, r.size.x, ALTO_PARED + 6))   # pared
	solido_rect(Rect2(r.position.x - 10, r.position.y, 10, r.size.y))               # izquierda
	solido_rect(Rect2(r.end.x, r.position.y, 10, r.size.y))                         # derecha
	solido_rect(Rect2(r.position.x, r.end.y, r.size.x, 10))                         # abajo
	return tiles


## Decoración de pared (sin colisión). «x» centro, «base» y de apoyo.
func deco(region: Rect2, x: float, base: float, hoja := MISC) -> void:
	mueble(hoja, region, Vector2(x, base), false)


## Puerta de regreso al pasillo (en la pared superior) de cada área.
func _puerta_al_pasillo(x: float, sala: String) -> void:
	mueble(HOSP + "DoorsHospital-Sheet.png", Rect2(662, 30, 36, 50), Vector2(x, _piso_y), false)
	zona("volver_%s" % sala, "Volver al pasillo", Rect2(x - 20, _piso_y, 40, 18))


# --- Construcción de cada sala ---------------------------------------------------------
func _construir_recepcion() -> void:
	var tiles := _empezar_sala("recepcion", Rect2(48, 176, 16, 16))
	# piso: borde azul con paneles blancos, como en el pasillo
	suelo(Rect2(0, 66, 480, 204), tiles, Rect2(32, 160, 16, 16))
	suelo(Rect2(16, 82, 176, 112), tiles, Rect2(48, 176, 16, 16))
	suelo(Rect2(288, 82, 176, 112), tiles, Rect2(48, 176, 16, 16))
	suelo(Rect2(16, 210, 176, 44), tiles, Rect2(48, 176, 16, 16))
	suelo(Rect2(288, 210, 176, 44), tiles, Rect2(48, 176, 16, 16))
	# pared: ventanas, letreros, cruz, TV y panel informativo
	mueble(HOSP + "DoorsHospital-Sheet.png", Rect2(87, 17, 65, 63), Vector2(240, PARED), false)
	zona("ir_pasillo", "Ir al pasillo (áreas)", Rect2(212, PARED, 56, 18))
	deco(Rect2(1839, 33, 34, 14), 296, 52)
	cartel("PASILLO · ÁREAS", Vector2(276, 26), Color("1e5a8a"))
	for x in [36.0, 84.0, 396.0, 444.0]:
		deco(Rect2(270, 15, 36, 40), x, 62, HOME + "Windows-Sheet.png")
	deco(Rect2(2993, 18, 30, 33), 150, 64)
	cartel("HOSPITAL DE PILLBOX", Vector2(116, 24), Color("1e5a8a"))
	deco(Rect2(1583, 33, 34, 14), 346, 52)
	deco(Rect2(2103, 36, 18, 10), 190, 46)
	# mostrador con Erina (recepcionista, no camina), monitor y papeles
	var erina := persona("Erina", 1, "fucsia", Personaje.PELOS2, 0, Vector2(240, 140), Rect2(), [], true)
	erina.dialogo_dinamico = _dialogo_erina
	mueble(MISC, Rect2(2819, 15, 122, 45), Vector2(240, 176), true, 30)
	deco(Rect2(569, 21, 14, 18), 206, 150)
	deco(Rect2(1209, 23, 12, 16), 276, 148)
	zona("recepcionista", "Hablar con Erina (recepción)", Rect2(190, 176, 100, 16))
	# sala de espera izquierda
	mueble(HOME + "LivingRoom1-Sheet.png", Rect2(24, 501, 48, 26), Vector2(56, 112), true, 14)
	mueble(HOME + "LivingRoom1-Sheet.png", Rect2(24, 501, 48, 26), Vector2(120, 112), true, 14)
	mueble(MISC, Rect2(929, 15, 62, 25), Vector2(70, 176), true, 12)
	mueble(MISC, Rect2(929, 15, 62, 25), Vector2(140, 176), true, 12)
	mueble(MISC, Rect2(824, 4, 14, 50), Vector2(10, 196), true, 40)
	mueble(MISC, Rect2(54, 18, 20, 30), Vector2(40, 236), true, 12)
	mueble(HOME + "Miscellaneous-Sheet.png", Rect2(591, 35, 35, 21), Vector2(88, 136), true, 10)
	persona("Doña Gloria", 4, "casual_rojo", Personaje.PELOS, 3, Vector2(100, 150), Rect2(20, 128, 170, 30), [
		["Estoy esperando a mi nieto; se torció el tobillo jugando fútbol.", "Ay, doctor, ¿usted cree que demore mucho?"],
		["Este hospital es muy limpio. Se nota que lo cuidan."],
		["Mi nieto quiere ser médico como usted. Le voy a contar que lo conocí."],
		["¿Usted ya almorzó, doctor? Está muy flaquito."],
	])
	persona("Don Ernesto", 5, "overol", Personaje.PELOS, 1, Vector2(100, 200), Rect2(20, 190, 150, 52), [
		["Mi rodilla ya no es lo que era, doctor.", "Pero vengo más por la conversación que por la rodilla, la verdad."],
		["En mis tiempos los médicos usaban corbata debajo de la bata."],
		["Yo fui camionero cuarenta años. Conozco cada hueco de Pillbox."],
		["Hoy el café de la máquina estaba más aguado que nunca, doctor. Avísele a alguien."],
	])
	# lado derecho: dispensador, máquina, plantas y más sillas
	mueble(MISC, Rect2(1333, 20, 22, 27), Vector2(470, 110), true, 12)
	mueble(HOME + "Kitchen-Sheet.png", Rect2(996, 0, 24, 48), Vector2(440, 112), true, 26, Color("ffcc80"))
	cartel("SNACKS", Vector2(428, 112), Color("6b3e00"))
	mueble(MISC, Rect2(929, 15, 62, 25), Vector2(340, 176), true, 12)
	mueble(MISC, Rect2(929, 15, 62, 25), Vector2(410, 176), true, 12)
	mueble(HOME + "LivingRoom1-Sheet.png", Rect2(24, 501, 48, 26), Vector2(352, 112), true, 14)
	persona("Samuel", 0, "casual_blanco", Personaje.PELOS2, 3, Vector2(380, 150), Rect2(296, 128, 130, 30), [
		["Vine a traerle el almuerzo a mi esposa; ella es enfermera aquí.", "Dicen que la cafetería cocina mejor que yo."],
		["¿Usted es nuevo? No lo había visto antes."],
		["Mi esposa dice que el turno de noche es peor. ¿Usted también hace noches?"],
		["Traje arepas para todos los de urgencias. ¿Quiere una, doctor?"],
	])
	var reyes := persona("Alejandro Reyes", 2, "policia", Personaje.PELOS, 0, Vector2(300, 222), Rect2(300, 196, 150, 50))
	reyes.dialogo_dinamico = _dialogo_reyes
	if _pawlak_de_guardia(Juego.dia):
		var rhea := persona("Rhea Pawlak", 0, "policia", Personaje.PELOS2, 0, Vector2(360, 230), Rect2(300, 200, 150, 46))
		rhea.velocidad = 20.0
		rhea.dialogo_dinamico = _dialogo_pawlak_guardia
	mueble(MISC, Rect2(2234, 28, 12, 18), Vector2(316, 112), true, 6)
	mueble(MISC, Rect2(2234, 28, 12, 18), Vector2(166, 236), true, 6)
	for pos in [Vector2(20, 104), Vector2(194, 104), Vector2(286, 104), Vector2(186, 248), Vector2(294, 248), Vector2(462, 248)]:
		mueble(HOME + "Flowers-Sheet.png", Rect2(22, 3, 20, 43), pos, true, 8)
	# salida a la calle
	suelo_color(Rect2(208, 258, 64, 12), Color("6b4a2b"))
	cartel("SALIDA", Vector2(229, 259), Color("f5e6c8"))
	zona("calle", "Salir a la calle", Rect2(208, 248, 64, 22))


func _construir_pasillo() -> void:
	var tiles := _empezar_sala("pasillo", Rect2(32, 160, 16, 16))
	# paneles blancos sobre el piso azul (como el ejemplo)
	for i in 6:
		suelo(Rect2(16 + i * 160, 98, 128, 100), tiles, Rect2(48, 176, 16, 16))
	for p in PUERTAS_PASILLO:
		var x: float = p[1]
		var cerrada: bool = p[0] == "consultorios"
		cerrada = cerrada and Juego.rango == "Interno"
		var puerta := mueble(HOSP + "DoorsHospital-Sheet.png", Rect2(662, 30, 36, 50), Vector2(x, PARED), false, -1.0,
			Color(0.6, 0.6, 0.6) if cerrada else Color.WHITE)
		if p[0] == "consultorios":
			_puerta_consultorios = puerta
		cartel(p[2], Vector2(x + 21, 22), Color("777777") if cerrada else Color("1e5a8a"))
		var etiqueta := "Consultorios (cerrado)" if cerrada else "Entrar: %s" % SALAS[p[0]]["nombre"]
		zona("puerta_%s" % p[0], etiqueta, Rect2(x - 20, PARED, 40, 18))
	# entre puertas: sillas contra la pared y letreros (como el ejemplo)
	var letreros := [Rect2(1583, 33, 34, 14), Rect2(1711, 33, 34, 14), Rect2(1455, 33, 34, 14), Rect2(1839, 33, 34, 14)]
	for i in 3:
		var xm: float = (PUERTAS_PASILLO[i][1] + PUERTAS_PASILLO[i + 1][1]) / 2.0
		mueble(MISC, Rect2(929, 15, 62, 25), Vector2(xm, 92), true, 12)
		deco(letreros[i], xm, 52)
	# Tablón de capacitaciones entre la 4.ª y la 5.ª puerta
	var tablon := Tablon.new()
	tablon.position = Vector2(764, 62) + origen
	mundo.add_child(tablon)
	cartel("CAPACITACIONES", Vector2(742, 20), Color("6b3e00"))
	zona("tablon", "Tablón de capacitaciones", Rect2(736, 66, 56, 26))
	deco(Rect2(2103, 36, 18, 10), 60, 46)
	deco(Rect2(1982, 41, 9, 7), 150, 48)
	deco(Rect2(1209, 23, 12, 16), 330, 50)
	deco(Rect2(1982, 41, 9, 7), 690, 48)
	deco(Rect2(2103, 36, 18, 10), 900, 46)
	mueble(MISC, Rect2(2234, 28, 12, 18), Vector2(28, 90), true, 6)
	mueble(MISC, Rect2(2234, 28, 12, 18), Vector2(932, 90), true, 6)
	var tablero := TableroElectrico.new()
	tablero.position = origen + Vector2(900, 60)
	mundo.add_child(tablero)
	mueble(MISC, Rect2(185, 12, 14, 35), Vector2(560, 196), true, 6)
	mueble(HOME + "Flowers-Sheet.png", Rect2(22, 3, 20, 43), Vector2(944, 200), true, 8)
	# paso a recepción en la pared de abajo
	suelo_color(Rect2(30, 211, 60, 8), Color("6b4a2b"))
	cartel("↓ RECEPCIÓN", Vector2(36, 220), Color("9fc4e8"))
	zona("ir_recepcion", "Volver a recepción", Rect2(30, 196, 60, 18))
	persona("John McClane", 0, "policia", Personaje.PELOS, 0, Vector2(700, 150), Rect2(520, 112, 400, 80), [
		["McClane, policía. Estoy esperando para tomar una declaración.", "Los hospitales me ponen nervioso: demasiados pasillos y ascensores."],
		["¿La cafetería? Tercera puerta. Gracias, doc."],
		["Un consejo de policía viejo: nunca ande descalzo en un edificio grande."],
		{"lineas": ["Llevo dos horas esperando que el testigo despierte.", "¿Usted cree que tarde mucho, doc?"],
		 "opciones": [
			{"texto": "Le aviso apenas despierte.", "amistad": 1, "respuesta": ["Se lo agradezco, Pinkman. Le debo una."]},
			{"texto": "Aquí no se puede fumar, oficial.", "amistad": 0, "respuesta": ["No estoy fumando. Es un chicle.", "…Bueno, ya lo boté."]},
			{"texto": "Eso no es asunto mío.", "amistad": -1, "respuesta": ["Vaya. Qué simpático."]},
		]},
	])
	persona("Paola", 1, "enfermera", Personaje.PELOS2, 4, Vector2(250, 150), Rect2(40, 112, 440, 80), [
		["Voy corriendo a llevar unas muestras al laboratorio.", "¡Ánimo en su primer mes, doctor!"],
		["Si necesita una bata, en el vestidor hay de repuesto."],
		["¡El laboratorio perdió mis muestras otra vez! Voy a repetirlas… ¡otra vez!"],
		["Cristian Daniel dice que es rápido como un rayo. Yo le he ganado tres carreras."],
	])
	var cristian := persona("Cristian Daniel", 3, "overol", Personaje.PELOS, 5, Vector2(420, 170), Rect2(200, 112, 500, 80))
	cristian.dialogo_dinamico = _dialogo_cristian
	persona("Dr. Máximo Stone", 5, "uniforme", Personaje.PELOS, 7, Vector2(340, 170), Rect2(260, 112, 300, 80), [
		["Stone, traumatología. Si llega alguien con un esguince: férula y reposo.", "Y nada de volver a la cancha en una semana."],
		["Este pasillo es más largo que mis turnos, y eso es mucho decir."],
		["Un yeso bien puesto es una obra de arte, Pinkman. Que no se le olvide."],
		["Ayer arreglé una muñeca, dos tobillos y una rodilla. Y ni he almorzado."],
	])
	persona("Dr. Enzo Escobar", 2, "uniforme", Personaje.PELOS, 7, Vector2(620, 150), Rect2(560, 112, 360, 80), [
		["Enzo Escobar, medicina interna. ¿Ya almorzó? Aquí se le olvida a uno comer.", "Un médico con hambre se equivoca más."],
		["Para el azúcar baja, el glucómetro es su mejor amigo."],
		["Medicina interna es como ser detective: todo deja una pista."],
		["¿Sabía que la mitad de los mareos que llegan es por no desayunar?"],
	])
	persona("Diego Quiroz", 0, "enfermera", Personaje.PELOS, 4, Vector2(160, 160), Rect2(40, 112, 300, 80), [
		{"lineas": ["¡Aaay sí, señorita Sheyla, jaja, amo esa broma!", "…Shh, doctor. Lo digo duro para que me oiga el interno Jinu Blake.", "¡Se pone rojo como un tomate cada vez! Jajaja."],
		 "opciones": [
			{"texto": "Jaja, eres terrible.", "amistad": 1, "respuesta": ["¡Lo sé! Mañana le digo que Sheyla preguntó por él."]},
			{"texto": "Pobre Jinu, déjalo en paz.", "amistad": -1, "respuesta": ["Bueno, bueno…", "Pero es que es muy fácil molestarlo, doctor."]},
		]},
		["Ayer le dije a Jinu que Sheyla le había dejado una nota en su casillero.", "¡Revisó el casillero cinco veces! Jajaja."],
		{"lineas": ["¿Me ayuda con una broma para Jinu Blake, doctor?"],
		 "opciones": [
			{"texto": "Dile que Sheyla lo busca en la cafetería.", "amistad": 2, "respuesta": ["¡Jajaja! Usted sí sabe, doctor. Ya vuelvo."]},
			{"texto": "No, estoy trabajando.", "amistad": 0, "respuesta": ["Aburrido… pero responsable. Está bien."]},
		]},
	])
	persona("Sofía", 2, "rosa", Personaje.PELOS, 2, Vector2(760, 170), Rect2(600, 112, 330, 80), [
		["Busco los consultorios, pero dice «cerrado».", "Ah, ¿solo abren cuando hay residentes? Qué lástima."],
		["Mi abuelo está en observación. Dicen que se recupera rápido."],
		["Este hospital tiene más pasillos que un centro comercial."],
	])


func _construir_urgencias() -> void:
	_empezar_sala("urgencias", Rect2(48, 176, 16, 16))
	_puerta_al_pasillo(28, "urgencias")
	deco(Rect2(2993, 18, 30, 33), 330, 58)
	cartel("URGENCIAS", Vector2(350, 30), Color("1e5a8a"))
	for i in 3:
		var x: float = CAMILLAS_X[i]
		deco(Rect2(295, 21, 52, 23), x, 60)
		mueble(HOSP + "BedHospital-Sheet.png", Rect2(19, 7, 26, 42), Vector2(x, CAMILLA_Y), true, 30)
		mueble(MISC, Rect2(185, 12, 14, 35), Vector2(x + 20, CAMILLA_Y - 14), true, 6)
		zona("camilla%d" % i, "Camilla %d" % (i + 1), Rect2(x - 16, CAMILLA_Y - 8, 32, 24))
	mueble(MISC, Rect2(1333, 20, 22, 27), Vector2(388, 94), true, 14)
	zona("botiquin", "Botiquín", Rect2(374, 86, 28, 26))
	cartel("BOTIQUÍN", Vector2(372, 96), Color("2b2b2b"))
	mueble(MISC, Rect2(1333, 20, 22, 27), Vector2(420, 94), true, 14, Color("ff8a80"))
	zona("botiquin_rojo", "Botiquín rojo", Rect2(406, 86, 28, 26))
	cartel("ROJO", Vector2(412, 96), Color("b71c1c"))
	mueble(MISC, Rect2(1075, 24, 25, 17), Vector2(456, 92), true, 8)
	deco(Rect2(1209, 23, 12, 16), 360, 50)
	mueble(MISC, Rect2(2234, 28, 12, 18), Vector2(64, 90), true, 6)
	var lucia := persona("Lucía", 3, "enfermera", Personaje.PELOS, 6, Vector2(110, 204), Rect2(), [], true)
	lucia.dialogo_dinamico = _dialogo_lucia
	mueble(MISC, Rect2(2563, 15, 122, 45), Vector2(110, 236), true, 30)
	deco(Rect2(569, 21, 14, 18), 84, 214)
	zona("lucia", "Hablar con Lucía", Rect2(60, 236, 100, 16))
	mueble(MISC, Rect2(929, 15, 62, 25), Vector2(330, 222), true, 12)
	mueble(MISC, Rect2(929, 15, 62, 25), Vector2(410, 222), true, 12)
	mueble(HOME + "Flowers-Sheet.png", Rect2(22, 3, 20, 43), Vector2(462, 250), true, 8)
	var brown := persona("Dr. Maximiliano Brown", 0, "uniforme", Personaje.PELOS, 3, Vector2(200, 170), Rect2(130, 150, 140, 40))
	brown.dialogo_dinamico = _dialogo_brown
	if _wilder_redimido():
		var w := persona("Dr. Wilder Noctis", 1, "uniforme", Personaje.PELOS2, 3, Vector2(240, 190), Rect2(200, 176, 100, 30))
		w.dialogo_dinamico = _dialogo_wilder
	persona("Jaiden Mendoza", 3, "policia", Personaje.PELOS2, 2, Vector2(300, 170), Rect2(250, 150, 200, 40), [
		["Agente Jaiden Mendoza. Traje a un herido hace un rato.", "Usted haga su trabajo, doctor; yo me quedo por si acaso."],
		["El café de la cafetería es lo único que me mantiene despierto."],
		["Reyes cuida la entrada y McClane anda por el pasillo. Somos un buen equipo."],
		["Ayer perseguí a un ladrón tres cuadras. Mis rodillas todavía me odian."],
		["Si Reyes le cuenta alguna historia de la academia, no le crea nada."],
	])


func _construir_vestidor() -> void:
	_empezar_sala("vestidor", Rect2(32, 160, 16, 16))
	_puerta_al_pasillo(340, "vestidor")
	cartel("VESTIDOR DEL PERSONAL", Vector2(160, 26), Color("9fc4e8"))
	mueble(HOME + "Bathroom-Sheet.png", Rect2(323, 13, 26, 50), Vector2(132, 132), true, 34)
	mueble(HOME + "Bathroom-Sheet.png", Rect2(323, 13, 26, 50), Vector2(162, 132), true, 34)
	zona("ducha_hospital", "Ducha del personal (15 min)", Rect2(116, 120, 62, 28))
	for i in 5:
		mueble(HOME + "Cupboard-Sheet.png", Rect2(470, 7, 20, 41), Vector2(202 + i * 22, 126), true, 16, Color("b7c7d8"))
	zona("casillero", "Casillero (cambiarse)", Rect2(190, 112, 112, 30))
	mueble(HOME + "Bathroom-Sheet.png", Rect2(35, 24, 26, 28), Vector2(304, 112), true, 12)
	mueble(HOME + "Kitchen1-Sheet.png", Rect2(409, 15, 46, 33), Vector2(240, 196), true, 18, Color("8d9aa8"))
	mueble(MISC, Rect2(2234, 28, 12, 18), Vector2(124, 214), true, 6)
	mueble(HOME + "Flowers-Sheet.png", Rect2(89, 23, 14, 23), Vector2(356, 214), true, 6)
	persona("Dr. Ramírez", 1, "uniforme", Personaje.PELOS, 7, Vector2(290, 180), Rect2(190, 160, 150, 50), [
		["Ramírez, de cirugía. Acabo de salir de una operación de cuatro horas.", "Consejo: báñese antes del turno. Los pacientes lo notan."],
		["El Dr. Salgado empezó como interno, igual que usted."],
		["Cuatro horas de cirugía y la paciente salió perfecta. Esto es lo mejor del trabajo."],
		["Si alguna vez quiere ver una operación, avíseme. Desde lejos, eso sí."],
	])
	var zac := persona("Dr. Zacarías Flores", 1, "uniforme", Personaje.PELOS, 6, Vector2(220, 170), Rect2(186, 150, 160, 56))
	zac.dialogo_dinamico = _dialogo_zacarias


## Tablero eléctrico del pasillo (donde trabaja Paul Catelli).
class TableroElectrico extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-9, -30, 18, 24), Color("9aa3ad"))
		draw_rect(Rect2(-9, -30, 18, 24), Color("5a6470"), false, 1.0)
		draw_rect(Rect2(-6, -27, 12, 4), Color("f1c40f"))
		draw_line(Vector2(-6, -27), Vector2(6, -23), Color.BLACK, 1.0)
		for k in 3:
			draw_rect(Rect2(-6 + k * 4.5, -19, 3, 8), Color("2c3e50"))


## Pizarra con el menú del día (dibujada por código).
class Pizarra extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(-30, -36, 60, 34), Color("6b4a2b"))
		draw_rect(Rect2(-28, -34, 56, 30), Color("2f3b2f"))
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(-26, -26), "MENÚ DEL DÍA", HORIZONTAL_ALIGNMENT_CENTER, 52, 6, Color("f5e6c8"))
		draw_string(f, Vector2(-25, -18), "Sopa de pollo", HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color("e8e8e8"))
		draw_string(f, Vector2(-25, -12), "Arroz y carne", HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color("e8e8e8"))
		draw_string(f, Vector2(-25, -6), "Jugo natural", HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color("ffcf6b"))


## Reloj de pared que marca la hora del juego.
class RelojPared extends Node2D:
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		draw_circle(Vector2.ZERO, 8.0, Color("5a5a5a"))
		draw_circle(Vector2.ZERO, 7.0, Color("fafafa"))
		var m: float = fmod(Juego.minutos, 720.0)
		var ah := m / 720.0 * TAU - PI / 2.0
		var am := fmod(m, 60.0) / 60.0 * TAU - PI / 2.0
		draw_line(Vector2.ZERO, Vector2(cos(ah), sin(ah)) * 4.0, Color.BLACK, 1.2)
		draw_line(Vector2.ZERO, Vector2(cos(am), sin(am)) * 6.0, Color("c0392b"), 1.0)


func _construir_cafeteria() -> void:
	_empezar_sala("cafeteria", Rect2(96, 176, 32, 32))
	_puerta_al_pasillo(100, "cafeteria")
	cartel("CAFETERÍA", Vector2(216, 20), Color("9fc4e8"))
	# pared: ventanas, pizarra, reloj y cuadros
	deco(Rect2(270, 15, 36, 40), 150, 78, HOME + "Windows-Sheet.png")
	deco(Rect2(270, 15, 36, 40), 350, 78, HOME + "Windows-Sheet.png")
	var pizarra := Pizarra.new()
	pizarra.position = origen + Vector2(250, 76)
	mundo.add_child(pizarra)
	var reloj := RelojPared.new()
	reloj.position = origen + Vector2(196, 52)
	add_child(reloj)
	deco(Rect2(41, 7, 14, 17), 296, 66, HOME + "Paintings-Sheet.png")
	deco(Rect2(199, 7, 18, 21), 314, 68, HOME + "Paintings-Sheet.png")
	# cocina contra la pared
	mueble(HOME + "Kitchen-Sheet.png", Rect2(607, 20, 34, 35), Vector2(150, 118), true, 18)
	mueble(HOME + "Kitchen-Sheet.png", Rect2(128, 21, 33, 34), Vector2(184, 118), true, 18)
	deco(Rect2(321, 15, 18, 20), 184, 98, HOME + "Kitchen-Sheet.png")
	mueble(HOME + "Kitchen-Sheet.png", Rect2(1092, 0, 24, 48), Vector2(212, 122), true, 24)
	# barra de servicio con Doña Luz detrás (no camina)
	var luz := persona("Doña Luz", 5, "casual_blanco", Personaje.PELOS2, 4, Vector2(240, 146), Rect2(), [
		{"lineas": ["¡Buenas, doctor! ¿Qué le sirvo hoy?", "La sopa está recién hecha. La receta es de mi abuela."],
		 "opciones": [
			{"texto": "¡Huele delicioso, Doña Luz!", "amistad": 1, "respuesta": ["¡Ay, gracias, mijo! Para usted le pongo más presa."]},
			{"texto": "Solo vengo a mirar.", "amistad": 0, "respuesta": ["Mirar no llena la barriga, doctor."]},
		]},
		["Veinte años cocinando aquí. He visto pasar tres directores y mil internos."],
		["Ese Dr. Noctis se come las galletas de la máquina y no las paga. ¡Yo lo vi!"],
		["Coma bien, doctor. Con hambre nadie salva vidas."],
	], true)
	luz.mirada_base = Vector2.DOWN
	mueble(HOME + "Kitchen-Sheet.png", Rect2(895, 29, 34, 22), Vector2(224, 160), true, 14)
	mueble(HOME + "Kitchen-Sheet.png", Rect2(895, 29, 34, 22), Vector2(258, 160), true, 14)
	deco(Rect2(424, 13, 16, 19), 216, 146, HOME + "Lights-Sheet.png")
	zona("almuerzo", "Almorzar con Doña Luz (20 min)", Rect2(204, 160, 72, 18))
	# máquinas: snacks y bebidas energéticas
	mueble(HOME + "Kitchen-Sheet.png", Rect2(996, 0, 24, 48), Vector2(372, 122), true, 24, Color("ffcc80"))
	cartel("SNACKS", Vector2(361, 124), Color("6b3e00"))
	zona("snacks", "Máquina de snacks", Rect2(358, 116, 28, 24))
	mueble(HOME + "Kitchen-Sheet.png", Rect2(1092, 0, 24, 48), Vector2(392, 122), true, 24, Color("8ef0a0"))
	cartel("ENERGÍA", Vector2(380, 132), Color("0b5d1e"))
	zona("energetica", "Bebida energética (1 por turno)", Rect2(382, 116, 24, 24))
	# mesas
	for pos in [Vector2(126, 214), Vector2(240, 220), Vector2(352, 214)]:
		mueble(HOME + "Kitchen1-Sheet.png", Rect2(409, 15, 46, 33), pos, true, 22)
		mueble(HOME + "Kitchen1-Sheet.png", Rect2(42, 7, 12, 25), pos + Vector2(-30, -4), false)
		mueble(HOME + "Kitchen1-Sheet.png", Rect2(232, 9, 14, 23), pos + Vector2(30, -4), false)
	deco(Rect2(424, 13, 16, 19), 126, 200, HOME + "Lights-Sheet.png")
	# plantas y papelera
	mueble(HOME + "Flowers-Sheet.png", Rect2(22, 3, 20, 43), Vector2(84, 232), true, 8)
	mueble(HOME + "Flowers-Sheet.png", Rect2(22, 3, 20, 43), Vector2(398, 232), true, 8)
	mueble(HOME + "Flowers-Sheet.png", Rect2(89, 23, 14, 23), Vector2(124, 112), true, 6)
	mueble(MISC, Rect2(2234, 28, 12, 18), Vector2(300, 118), true, 6)
	persona("Don Pedro", 0, "naranja", Personaje.PELOS, 4, Vector2(180, 186), Rect2(100, 176, 280, 14), [
		["Aquí el almuerzo es sagrado, doctor.", "Pruebe la sopa: la hace Doña Luz desde hace veinte años."],
		["Vengo todos los días aunque no esté enfermo. ¡Por la comida!"],
		["La sopa de hoy tiene más papa que pollo. Pero igual me la comí."],
		["Dicen que el Dr. Noctis vive en esta cafetería. Yo le he visto dormir aquí."],
	])
	if not _wilder_redimido():
		var wilder := persona("Dr. Wilder Noctis", 1, "uniforme", Personaje.PELOS2, 3, Vector2(330, 186), Rect2(290, 176, 80, 14))
		wilder.dialogo_dinamico = _dialogo_wilder
		wilder.velocidad = 9.0


func _construir_direccion() -> void:
	_empezar_sala("direccion", Rect2(96, 144, 32, 32))
	suelo(Rect2(208, 144, 64, 64), textura(HOME + "Carpet-Sheet.png"), Rect2(128, 0, 64, 64))   # una sola alfombra
	_puerta_al_pasillo(334, "direccion")
	cartel("DIRECCIÓN · DR. ARTURO SALGADO", Vector2(164, 26), Color("9fc4e8"))
	mueble(HOME + "Cupboard-Sheet.png", Rect2(270, 20, 36, 43), Vector2(146, 124), true, 16)
	mueble(HOME + "Cupboard-Sheet.png", Rect2(334, 29, 36, 34), Vector2(184, 124), true, 16)
	deco(Rect2(1, 0, 30, 32), 240, 80, HOME + "Paintings1-Sheet.png")
	deco(Rect2(526, 15, 36, 40), 284, 84, HOME + "Windows-Sheet.png")
	var salgado := persona("Dr. Salgado", 4, "uniforme", Personaje.PELOS, 1, Vector2(240, 162), Rect2(156, 140, 168, 26))
	salgado.velocidad = 14.0
	salgado.dialogo_dinamico = _dialogo_salgado
	mueble(HOME + "LivingRoom-Sheet.png", Rect2(25, 15, 46, 30), Vector2(240, 192), true, 18)
	deco(Rect2(569, 21, 14, 18), 228, 178)
	zona("salgado", "Hablar con el Dr. Salgado", Rect2(204, 192, 72, 18))
	mueble(HOME + "LivingRoom1-Sheet.png", Rect2(233, 97, 15, 46), Vector2(134, 210), true, 30)
	mueble(HOME + "Flowers-Sheet.png", Rect2(22, 3, 20, 43), Vector2(346, 214), true, 8)
	mueble(HOME + "Lights-Sheet.png", Rect2(152, 0, 16, 32), Vector2(306, 128), true, 6)


func _construir_consultorio() -> void:
	_empezar_sala("consultorios", Rect2(48, 176, 16, 16))
	_puerta_al_pasillo(340, "consultorios")
	cartel("CONSULTORIO · DR. WALTER PINKMAN", Vector2(150, 26), Color("9fc4e8"))
	mueble(HOSP + "BedHospital-Sheet.png", Rect2(19, 7, 26, 42), Vector2(146, 140), true, 30)
	mueble(MISC, Rect2(185, 12, 14, 35), Vector2(168, 126), true, 6)
	deco(Rect2(1, 0, 30, 32), 230, 80, HOME + "Paintings1-Sheet.png")
	deco(Rect2(295, 21, 52, 23), 150, 80)
	mueble(HOME + "Cupboard-Sheet.png", Rect2(270, 20, 36, 43), Vector2(290, 128), true, 16)
	mueble(HOME + "LivingRoom-Sheet.png", Rect2(25, 15, 46, 30), Vector2(240, 196), true, 18)
	mueble(HOME + "Kitchen1-Sheet.png", Rect2(138, 12, 12, 20), Vector2(240, 176), false)
	deco(Rect2(569, 21, 14, 18), 252, 180)
	zona("escritorio_consultorio", "Revisar historias clínicas (estudiar)", Rect2(212, 176, 56, 30))
	mueble(HOME + "Flowers-Sheet.png", Rect2(22, 3, 20, 43), Vector2(350, 214), true, 8)


# --- Entrada al hospital -------------------------------------------------------------
func posicion_inicial() -> Vector2:
	return Vector2(240, 240)


func al_entrar() -> void:
	sala_actual = "recepcion"
	walter.limitar_camara(_rect_sala("recepcion"))
	_rep_inicio = Juego.reputacion
	_generar_agenda()
	_ultimo_minuto = Juego.minutos
	var notas := Juego.llegar_al_hospital()
	hud.mostrar("Erina: «Buenos días, Dr. Pinkman. Las áreas están por el pasillo; urgencias es la primera puerta».", 4.5)
	for nota in notas:
		hud.mostrar(nota, 4.5)
	walter.actualizar_aspecto()
	Juego.musica("hospital")
	Juego.pausado = false


func _rect_sala(id: String) -> Rect2:
	return Rect2(SALAS[id]["origen"], SALAS[id]["tam"])


func ir_a_sala(destino: String, punto: Vector2) -> void:
	if _cambiando:
		return
	_cambiando = true
	walter.bloqueado = true
	Juego.sonido("puerta", 1.0, -8.0)
	await Juego.fundir(1.0)
	sala_actual = destino
	walter.position = SALAS[destino]["origen"] + punto
	walter.limitar_camara(_rect_sala(destino))
	await get_tree().process_frame
	await Juego.fundir(0.0)
	walter.bloqueado = false
	_cambiando = false
	refrescar_aviso()


func _generar_agenda() -> void:
	var nombres := NOMBRES.duplicate()
	nombres.shuffle()
	var leves := Casos.casos_leves()
	var graves := CASOS.filter(func(c): return c["grave"])
	var hora := 7 * 60 + 45 + randi_range(0, 15)
	var i := 0
	while hora < 18 * 60 + 40 and i < nombres.size():
		var grave := i > 0 and randf() < (0.08 if Juego.dia == 1 else 0.18)
		var caso: Dictionary = graves.pick_random() if grave else leves.pick_random()
		agenda.append({"hora": hora, "caso": caso, "nombre": nombres[i]})
		hora += randi_range(40, 70)
		i += 1
	# Evento «hora pico»: un accidente trae varios pacientes seguidos
	if Juego.eventos_aleatorios and Juego.dia >= 2 and randf() < 0.3 and i + 4 <= nombres.size():
		evento_pico = randi_range(10 * 60, 15 * 60)
		for k in 4:
			agenda.append({"hora": evento_pico + k * 6, "caso": leves.pick_random(), "nombre": nombres[i]})
			i += 1
		agenda.sort_custom(func(x, y): return x["hora"] < y["hora"])
	_agenda_pawlak()
	_planear_eventos()


# --- Bucle ---------------------------------------------------------------------
func _process(_delta: float) -> void:
	if _terminando:
		return
	walter.actualizar_aspecto()
	var dm := Juego.minutos - _ultimo_minuto
	_ultimo_minuto = Juego.minutos
	_eventos()
	_llegadas()
	if dm > 0.0:
		_deterioro(dm * (1.4 if apagon else 1.0))   # sin luz los monitores no ayudan
	_actualizar_lista()
	if Juego.minutos >= Juego.FIN_TURNO:
		_terminar_turno()


func _llegadas() -> void:
	while not agenda.is_empty() and Juego.minutos >= agenda[0]["hora"]:
		if espera.size() >= PUESTOS_ESPERA.size():
			return          # sala de espera llena: el resto espera en recepción
		var a = agenda.pop_front()
		_entra_a_espera(a)


func _triaje(caso: Dictionary) -> String:
	if caso["grave"]:
		return "rojo"
	return "amarillo" if caso["deterioro"] >= 0.5 else "verde"


## El paciente entra por la puerta de urgencias y camina hasta un puesto libre de la sala de espera.
func _entra_a_espera(a: Dictionary) -> void:
	var ocupados: Array = espera.map(func(e): return e["puesto"])
	var puesto := 0
	while ocupados.has(puesto):
		puesto += 1
	var o: Vector2 = SALAS["urgencias"]["origen"]
	var destino: Vector2 = PUESTOS_ESPERA[puesto]
	var ap: Dictionary = a.get("apariencia", Paciente.apariencia_al_azar())
	var n := persona(a["nombre"], ap["piel"], ap["ropa"], ap["pelo_hoja"], ap["pelo_fila"],
		o + Vector2(40, 96), Rect2(o + destino, Vector2(1, 1)))   # origen = 0 aquí: coordenadas del mundo
	n.velocidad = 44.0
	# Ruta: baja por la izquierda, cruza entre las camillas y la enfermería, y llega a su puesto
	n.ruta = [o + Vector2(40, 170), o + Vector2(destino.x, 170), o + destino]
	n.mirada_base = Vector2.DOWN
	var tri := _triaje(a["caso"])
	var marca := MarcaTriaje.new()
	marca.color = TRIAJE[tri]
	marca.nombre = a["nombre"]
	n.add_child(marca)
	var e := {"nombre": a["nombre"], "caso": a["caso"], "estabilidad": float(a["caso"]["inicial"]), "triaje": tri,
		"npc": n, "marca": marca, "puesto": puesto, "apariencia": ap}
	espera.append(e)
	n.dialogo_dinamico = _dialogo_espera.bind(e)
	Juego.sonido("altavoz", 1.0, -8.0 if sala_actual != "urgencias" else -16.0)
	var texto_tri: String = {"rojo": "ROJO, urgente", "amarillo": "amarillo", "verde": "verde"}[tri]
	if sala_actual != "urgencias":
		hud.mostrar("Altavoz: «Dr. Walter Pinkman, paciente en urgencias: triaje %s»." % texto_tri, 4.0)
	else:
		hud.mostrar("Lucía: «Llegó %s. Triaje %s; está en la sala de espera»." % [a["nombre"], texto_tri], 3.5)


func _dialogo_espera(e: Dictionary):
	var libres: Array = []
	for i in 3:
		if pacientes[i] == null:
			libres.append(i)
	var l: Array
	if e["caso"]["grave"]:
		l = ["(%s no puede hablar. Lucía lo marcó en ROJO.)" % e["nombre"]]
	else:
		l = [["Doctor, ¿ya me toca?"], ["¿Falta mucho, doctor? Me siento mal."], ["Perdón, ¿usted me va a atender?"],
			["Llevo rato aquí sentado… ¿me va a ver usted?"], ["Doctor, ¿esto es grave? Dígame la verdad."],
			["Mi mamá me obligó a venir. Yo estaba bien… más o menos."], ["¿Aquí atienden rápido? Me dijeron que sí."],
			["Doctor, le traje una empanada por si tiene hambre. ¿Me atiende primero? Jeje."],
			["Uy, qué frío hace en esta sala."], [e["caso"]["historias"].pick_random()[0] if not e["caso"]["historias"].is_empty() else "…"]].pick_random()
	var opciones: Array = []
	for i in libres:
		opciones.append({"texto": "Pase a la camilla %d." % (i + 1), "efecto": "pasar:%d" % i})
	if libres.is_empty():
		l = l + ["(No hay camillas libres. Atiende o da de alta a alguien primero.)"]
	opciones.append({"texto": "Espere un momento, por favor.", "amistad": 0})
	return {"lineas": l, "opciones": opciones}


## Pasa un paciente de la sala de espera a una camilla.
func _pasar_a_camilla(e: Dictionary, i: int) -> void:
	if pacientes[i] != null or not espera.has(e):
		return
	espera.erase(e)
	_quitar_npc(e["npc"])
	var p := Paciente.new()
	p.caso = e["caso"]
	p.nombre = e["nombre"]
	p.estabilidad = e["estabilidad"]
	p.apariencia = e["apariencia"]
	p.position = SALAS["urgencias"]["origen"] + Vector2(CAMILLAS_X[i], CAMILLA_Y)
	mundo.add_child(p)
	pacientes[i] = p
	interactuables["camilla%d" % i].etiqueta = "Atender a %s" % p.nombre
	Juego.sonido("seleccion", 1.0, -10.0)
	refrescar_aviso()


func _quitar_npc(n: NPC) -> void:
	npcs.erase(n.nombre)
	interactuables.erase(n.zona_hablar.id)
	n.queue_free()


func _deterioro(dm: float) -> void:
	for e in espera.duplicate():
		e["estabilidad"] -= e["caso"]["deterioro"] * dm * 0.5      # en espera empeoran a la mitad
		e["marca"].estabilidad = maxf(e["estabilidad"], 0.0)
		if e["estabilidad"] <= 0.0:
			espera.erase(e)
			_quitar_npc(e["npc"])
			transferidos += 1
			Juego.sumar_reputacion(-5)
			hud.mostrar("Lucía: «%s empeoró en la sala de espera; lo tomó el doctor de turno». (−5 reputación)" % e["nombre"], 4.0)
	for i in 3:
		var p: Paciente = pacientes[i]
		if p == null or p.estado == "alta":
			continue
		if Juego.minutos < p.vigilado_hasta:
			continue
		p.estabilidad -= p.caso["deterioro"] * dm * (0.7 if p.calmado else 1.0)
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
	if apagon:
		tareas.append([("¡Sin luz! Avisar en dirección" if catelli_estado == "" else ("Esperar al electricista" if catelli_estado == "llamado" else "Hablar con Catelli (pasillo)" if catelli_estado == "llego" else "Catelli está arreglando")), false])
	if llamado != "":
		tareas.append(["¡Ir a la dirección!", false])
	for e in espera:
		tareas.append(["Espera: %s (%s)" % [e["nombre"], e["triaje"]], false])
	if tareas.is_empty():
		tareas.append(["Esperar pacientes", false])
	tareas.append(["Turno hasta 7:30 PM", false])
	hud.poner_lista("%s · guardia" % SALAS[sala_actual]["nombre"], tareas)


# --- Interacciones --------------------------------------------------------------
func interactuar(id: String) -> void:
	if _cambiando:
		return
	if id.begins_with("npc:"):
		await hablar_con(id.substr(4))
	elif id.begins_with("camilla"):
		await _camilla(int(id.substr(7)))
	elif id.begins_with("puerta_"):
		var destino := id.substr(7)
		if destino == "consultorios" and Juego.rango == "Interno":
			hud.mostrar("Consultorios externos: se abrirán cuando seas Residente. Mira el tablón de capacitaciones.")
		else:
			await ir_a_sala(destino, SALAS[destino]["entrada"])
	elif id.begins_with("volver_"):
		var desde := id.substr(7)
		for p in PUERTAS_PASILLO:
			if p[0] == desde:
				await ir_a_sala("pasillo", Vector2(p[1], 90))
	else:
		match id:
			"ir_pasillo": await ir_a_sala("pasillo", Vector2(60, 180))
			"ir_recepcion": await ir_a_sala("recepcion", Vector2(240, 92))
			"calle": hud.mostrar("Tu turno termina a las 7:30 PM. Son las %s." % Juego.hora_texto())
			"recepcionista": await hablar_con("Erina")
			"botiquin": await _botiquin(Casos.insumos_botiquin(), "Botiquín")
			"botiquin_rojo": await _botiquin(INSUMOS_ROJO, "Botiquín rojo")
			"casillero": await _casillero()
			"ducha_hospital": await _ducha()
			"almuerzo": await _almorzar()
			"snacks": await _snacks()
			"energetica": await _energetica()
			"lucia": await hablar_con("Lucía")
			"salgado": await hablar_con("Dr. Salgado")
			"tablon": await _tablon()
			"escritorio_consultorio": await _revisar_historias()
	walter.actualizar_aspecto()


func _accion(minutos_accion: int, texto: String) -> void:
	walter.bloqueado = true
	Juego.pausado = true
	Juego.pasar_tiempo(minutos_accion)
	await Juego.fundido_accion(texto)
	Juego.pausado = false
	walter.bloqueado = false


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
		# 1) El paciente cuenta qué le pasó (los graves no pueden: lo cuenta Lucía)
		if not p.conto_historia:
			p.conto_historia = true
			if p.nombre == "Rhea Pawlak":
				await _historia_pawlak()
			elif p.caso["historias"].is_empty():
				await hud.dialogo("Lucía", [p.caso["relato"]], -1.0, false)
			else:
				await hud.dialogo(p.nombre, p.caso["historias"].pick_random(), -1.0, false)
				if not is_instance_valid(p) or pacientes[i] != p:
					return
				var c: int = await hud.elegir("Responder a %s" % p.nombre, "", ["Tranquilo, se va a poner bien.", "Rápido, que tengo más pacientes."])
				if c == 0:
					p.calmado = true
					await hud.dialogo(p.nombre, ["Gracias, doctor… ya me siento más tranquilo."], -1.0, false)
				elif c == 1:
					await hud.dialogo(p.nombre, ["…Está bien, doctor. Perdón."], -1.0, false)
			if not is_instance_valid(p) or pacientes[i] != p:
				return
		# 2) Examinar con una herramienta
		if not p.examinado:
			var herr: Array = HERRAMIENTAS.duplicate()
			herr.append("Ir directo al diagnóstico")
			var h: int = await hud.elegir("Examinar a %s" % p.nombre, "Signos: %s\n¿Con qué lo examinas?" % p.caso["signos"], herr)
			if h < 0 or not is_instance_valid(p) or pacientes[i] != p:
				return
			if h < HERRAMIENTAS.size():
				Juego.pasar_tiempo(2)
				if herr[h] == p.caso["herramienta"]:
					p.examinado = true
					Juego.sonido("seleccion", 1.3, -10.0)
				else:
					hud.mostrar("Con %s no encuentras nada raro. Prueba otra cosa." % herr[h].to_lower())
					return
		# 3) Diagnóstico
		var texto := "Signos: %s" % p.caso["signos"]
		if p.examinado:
			texto += "\n%s: %s" % [p.caso["herramienta"], p.caso["hallazgo"]]
		var opciones: Array = [p.caso["diagnostico"]] + p.caso["falsos"]
		opciones.shuffle()
		opciones.append("Derivar a otro médico (no estoy seguro)")
		var r: int = await hud.elegir("Diagnóstico de %s" % p.nombre, texto, opciones)
		if r < 0 or not is_instance_valid(p) or pacientes[i] != p:
			return
		if r == opciones.size() - 1:
			_derivar(i, "el médico de turno")
			return
		if opciones[r] == p.caso["diagnostico"]:
			p.estado = "tratar"
			hud.mostrar("Diagnóstico: %s. Ahora trae el insumo adecuado del botiquín." % p.caso["diagnostico"])
		else:
			p.fallos += 1
			p.estabilidad = maxf(p.estabilidad - 10.0, 1.0)
			Juego.sonido("error", 1.0, -8.0)
			hud.mostrar("Eso no encaja con los signos. %s empeoró un poco. Revisa otra vez." % p.nombre)
			_orientar_fallo(p)
		return
	if Juego.insumo_cargado == "":
		hud.mostrar("%s necesita tratamiento (%s). Busca el insumo en un botiquín." % [p.nombre, p.caso["diagnostico"]])
		return
	if Juego.insumo_cargado == p.caso["insumo"]:
		var premio: int = int(p.caso["premio"]) if p.fallos == 0 else 1
		Juego.sumar_reputacion(premio)
		Juego.insumo_cargado = ""
		p.estado = "alta"
		p.estabilidad = 100.0
		atendidos += 1
		Juego.sonido("exito", 1.0, -8.0)
		hud.mostrar("¡%s está estable! (+%d reputación)" % [p.nombre, premio])
		await get_tree().create_timer(2.5).timeout
		if pacientes[i] == p:
			_liberar(i)
	else:
		Juego.sonido("error", 1.0, -8.0)
		var quien: String = ["Lucía", "Dr. Maximiliano Brown"].pick_random()
		hud.mostrar("%s: «Eso no era. Para %s se usa %s. Vuelva al botiquín»." % [quien, p.caso["diagnostico"].to_lower(), p.caso["insumo"].to_lower()], 4.5)
		hud.mostrar("%s no sirve para %s. Se desperdició el insumo." % [Juego.insumo_cargado, p.caso["diagnostico"].to_lower()])
		Juego.insumo_cargado = ""


## Lucía o Brown orientan a Walter cuando se equivoca de diagnóstico (sin darle la respuesta).
func _orientar_fallo(p: Paciente) -> void:
	var quien: String = ["Lucía", "Dr. Maximiliano Brown"].pick_random()
	if not p.examinado:
		hud.mostrar("%s: «Antes de adivinar, examínelo. Pruebe con: %s»." % [quien, p.caso["herramienta"].to_lower()], 4.5)
	else:
		hud.mostrar("%s: «Fíjese en lo que encontró: %s ¿Qué enfermedad da eso?»" % [quien, p.caso["hallazgo"].to_lower()], 4.5)


## Derivar: Walter no está seguro y pasa el paciente a otro médico. Suma al contador de derivados.
func _derivar(i: int, a_quien: String) -> void:
	var p: Paciente = pacientes[i]
	if p == null:
		return
	Juego.derivados_semana += 1
	derivados += 1
	Juego.sonido("seleccion", 0.8, -10.0)
	hud.mostrar("Derivaste a %s con %s. (Derivados esta semana: %d)" % [p.nombre, a_quien, Juego.derivados_semana], 3.5)
	if Juego.derivados_semana >= Juego.LIMITE_DERIVADOS:
		Juego.flags["llamado_derivados"] = true
	_liberar(i)


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
		await _accion(10, "10 minutos después…")
		Juego.ropa = "uniforme"
		hud.mostrar("Te pusiste una bata del hospital.")


func _ducha() -> void:
	var r: int = await hud.elegir("Ducha del personal", "Bañarte aquí te quita tiempo del turno.", ["Bañarme (15 min)", "Cancelar"])
	if r == 0:
		await _accion(15, "15 minutos después…")
		Juego.higiene = 100.0
		hud.mostrar("Te bañaste en el hospital. Mejor tarde que nunca.")


func _almorzar() -> void:
	var r: int = await hud.elegir("Cafetería", "Menú del día: sopa, arroz, pollo y jugo.", ["Almorzar (20 min)", "Cancelar"])
	if r == 0:
		await _accion(20, "20 minutos después…")
		Juego.hambre = minf(Juego.hambre + 45.0, 100.0)
		Juego.energia = minf(Juego.energia + 5.0, 100.0)
		hud.mostrar("Almorzaste bien. (+hambre, +energía)")


func _snacks() -> void:
	var r: int = await hud.elegir("Máquina de snacks", "Un paquete de galletas y un jugo.", ["Comer algo (5 min)", "Cancelar"])
	if r == 0:
		Juego.pasar_tiempo(5)
		Juego.hambre = minf(Juego.hambre + 20.0, 100.0)
		hud.mostrar("Comiste algo rápido. (+hambre)")


func _energetica() -> void:
	if not Juego.una_vez_hoy_disponible("energetica"):
		hud.mostrar("Ya tomaste una bebida energética en este turno. Más no es bueno para el corazón.", 3.5)
		return
	var r: int = await hud.elegir("Bebida energética", "+15 % de energía y, durante 1 minuto, caminas más rápido. Solo 1 por turno.",
		["Tomar una (2 min)", "Cancelar"])
	if r != 0:
		return
	Juego.una_vez_hoy("energetica")
	Juego.pasar_tiempo(2)
	Juego.energia = minf(Juego.energia + 15.0, 100.0)
	Juego.boost_hasta = Juego.minutos + 60.0
	Juego.sonido("exito", 1.5, -8.0)
	hud.mostrar("¡Glu, glu! Te sientes con energía. (+15 % energía, más velocidad por 1 minuto)", 3.0)


func _pendientes() -> int:
	var n := espera.size()
	for p in pacientes:
		if p and p.estado != "alta":
			n += 1
	return n


func _dialogo_erina():
	var l: Array = []
	var n := _pendientes()
	if n > 0:
		l = ["Doctor, hay %d paciente(s) esperando en urgencias." % n, "Es la primera puerta del pasillo. ¡Corra!"]
	else:
		l = [["Todo tranquilo por ahora, doctor.", "Si tiene hambre, la cafetería es la tercera puerta."],
			["¿Sabía que el Dr. Salgado llega todos los días a las 6 en punto?", "Nunca lo he visto llegar tarde."],
			["Hoy los policías Reyes, Mendoza y McClane están de guardia aquí.", "Con ellos uno se siente más seguro."]].pick_random()
	# Con buena amistad, Erina avisa qué trae el próximo paciente
	if Juego.get_amistad("Erina") >= 5 and not agenda.is_empty():
		var a: Dictionary = agenda[0]
		l = l + ["Ah, y le cuento en secreto: a las %s llega %s." % [Juego.hora_texto(a["hora"]), a["nombre"]],
			"Llamaron antes. Dicen que tiene: %s" % a["caso"]["signos"].to_lower()]
	return {"lineas": l, "opciones": [
		{"texto": "Gracias, Erina. Eres la mejor.", "amistad": 1, "respuesta": ["¡Ay, doctor! Para eso estoy."]},
		{"texto": "¿Cómo va tu día?", "amistad": 1, "respuesta": ["Pues entre llamadas y formularios…", "Pero usted es de los pocos que pregunta. Gracias."]},
		{"texto": "Hasta luego.", "amistad": 0},
	]}


func _dialogo_lucia():
	var l: Array
	if Juego.huele_mal():
		l = ["Doctor, se lo digo con cariño…", "En el vestidor hay una ducha. Úsela, por favor."]
	elif Juego.energia < 25.0:
		l = ["Se ve agotado, doctor.", "Duerma más esta noche, o mañana no rendirá."]
	elif espera.any(func(e): return e["triaje"] == "rojo"):
		l = ["¡Doctor, hay un paciente en ROJO en la sala de espera!", "Los rojos primero, luego los amarillos y al final los verdes."]
	elif _pendientes() > 0:
		l = ["Tenemos pacientes esperando, doctor.", "Recuerde: los rojos primero, luego amarillos y verdes."]
	else:
		l = [CONSEJOS.pick_random().trim_prefix("Lucía: «").trim_suffix("».")]
	var opciones: Array = []
	# Pedirle que vigile al paciente más delicado
	var peor := -1
	for i in 3:
		var p: Paciente = pacientes[i]
		if p and p.estado != "alta" and Juego.minutos >= p.vigilado_hasta:
			if peor == -1 or p.estabilidad < pacientes[peor].estabilidad:
				peor = i
	if peor != -1:
		opciones.append({"texto": "¿Puedes vigilar a %s mientras traigo el insumo?" % pacientes[peor].nombre, "efecto": "vigilar:%d" % peor})
	opciones.append({"texto": "Gracias por todo, Lucía.", "amistad": 1, "respuesta": ["Para eso estamos, doctor. Usted va muy bien."]})
	opciones.append({"texto": "¿Algún consejo?", "amistad": 0, "respuesta": [CONSEJOS.pick_random().trim_prefix("Lucía: «").trim_suffix("».")]})
	return {"lineas": l, "opciones": opciones}


func _dialogo_salgado():
	var especial = _dialogo_salgado_eventos()
	if not (especial is Dictionary and especial.is_empty()):
		return especial
	var l := ["Pinkman. Lleva %d de reputación." % Juego.reputacion,
		"%d día(s) seguidos puntual y %d retraso(s)." % [Juego.racha_puntual, Juego.retrasos]]
	if Juego.rango != "Interno":
		l.append("Como Residente de %s, espero mucho de usted. No me decepcione." % Juego.especialidad)
	elif Juego.puede_ser_residente():
		l.append("Ya cumple los requisitos. Vaya al tablón de capacitaciones del pasillo.")
	else:
		l.append("Para su primera capacitación necesita %d de reputación, %.0f horas de estudio y %d turnos." % [Juego.REQ_REPUTACION, Juego.REQ_HORAS_ESTUDIO, Juego.REQ_DIAS])
		l.append("Revise el tablón del pasillo; ahí está todo.")
	if Juego.huele_mal():
		l.append("Y por favor… báñese. Un médico también se cuida a sí mismo.")
	var pregunta := _salgado_pregunta_wilder()
	if not pregunta.is_empty():
		return {"lineas": l + pregunta["lineas"], "opciones": pregunta["opciones"]}
	return {"lineas": l, "opciones": [
		{"texto": "Gracias, doctor. Daré lo mejor.", "amistad": 1, "respuesta": ["Eso espero. En este hospital todos empezamos desde abajo."]},
		{"texto": "¿Cómo llegó usted a director?", "amistad": 1, "respuesta": ["Puntualidad, estudio y nunca dejar solo a un paciente.", "Y aguantar a gente como Noctis, claro."]},
		{"texto": "Me retiro, doctor.", "amistad": 0},
	]}


func _dialogo_cristian():
	var l: Array = [["Llevo diez años de camillero. Me conozco cada baldosa de este pasillo.", "La tercera de la izquierda está floja, ojo."],
		["Si un paciente no puede caminar, me llaman a mí. ¡Rápido como un rayo!"]].pick_random()
	var opciones: Array = []
	if Juego.insumo_cargado == "" and _pendientes() > 0:
		opciones.append({"texto": "Cristian, ¿me traes un insumo del botiquín?", "efecto": "cristian_insumo"})
	opciones.append({"texto": "¡Diez años! Qué experiencia.", "amistad": 1, "respuesta": ["¡Y ni una camilla volteada! Bueno… solo una."]})
	opciones.append({"texto": "Sigue con lo tuyo.", "amistad": 0})
	return {"lineas": l, "opciones": opciones}


func _dialogo_wilder():
	var hist = _dialogo_wilder_historia()
	if not (hist is Dictionary and hist.is_empty()):
		return hist
	if _wilder_redimido():
		var opc: Array = []
		if _pendientes() > 0 and Juego.una_vez_hoy_disponible("wilder_ayuda"):
			opc.append({"texto": "Wilder, ¿me ayudas con un paciente?", "efecto": "wilder_ayuda"})
		opc.append({"texto": "¡Mírate, trabajando!", "amistad": 1, "respuesta": ["¡Lo sé! Hasta yo estoy sorprendido."]})
		return {"lineas": [["¡Mírame, Walter! ¡Trabajando! En urgencias y todo."],
			["Resulta que ayudar a la gente se siente bien. ¿Quién lo diría?"],
			["Bueno, igual me tomo mi siestita de 5 minutos. Esta vez son 5 de verdad."]].pick_random(), "opciones": opc}
	var l: Array = [["¡Te juro que mañana sí trabajaré, Walter, promesa de garrita!"],
		["Shh… estoy en mi descanso. Llevo en mi descanso desde las ocho.", "¿Qué hora es? No me digas, prefiero no saberlo."],
		["Si Salgado pregunta, estoy atendiendo a un paciente… en la cafetería.", "El paciente soy yo: tengo hambre crónica."],
		["Una siestita de cinco minutos y vuelvo.", "Bueno… de cincuenta."]].pick_random()
	var opciones: Array = []
	if Juego.una_vez_hoy_disponible("cubrir_wilder"):
		l = l + ["Oye, Walter… ¿me cubres un ratito? Si Salgado pasa, dile que estoy con un paciente."]
		opciones.append({"texto": "Está bien, te cubro (−20 min).", "amistad": 2, "efecto": "cubrir_wilder",
			"respuesta": ["¡Eres un ángel con bata! Te debo una, promesa de garrita."]})
		opciones.append({"texto": "Ni loco. Ve a trabajar.", "amistad": -1, "respuesta": ["Uy… qué carácter. Ya voy, ya voy… mañana."]})
	if int(Juego.favores.get("Dr. Wilder Noctis", 0)) > 0 and _pendientes() > 0:
		opciones.append({"texto": "Wilder, me debes una: atiende a un paciente.", "efecto": "favor_wilder"})
	opciones.append({"texto": "Jaja, típico.", "amistad": 0, "respuesta": ["Típico y feliz, Walter."]})
	return {"lineas": l, "opciones": opciones}


# --- Capacitaciones ---------------------------------------------------------------
func _tablon() -> void:
	if Juego.rango != "Interno":
		await hud.elegir("Tablón de capacitaciones",
			"Ya eres %s de %s. Las próximas capacitaciones (Especialista) llegarán pronto." % [Juego.rango, Juego.especialidad], ["Cerrar"])
		return
	var lineas: Array = ["Primera capacitación: Interno → Residente"]
	for r in Juego.requisitos_residente():
		lineas.append(("[x] " if r[1] else "[ ] ") + r[0])
	var texto := "\n".join(lineas)
	if not Juego.puede_ser_residente():
		texto += "\nEstudia en el escritorio de tu casa, atiende bien y sé puntual."
		await hud.elegir("Tablón de capacitaciones", texto, ["Cerrar"])
		return
	var opciones: Array = Juego.ESPECIALIDADES.duplicate()
	opciones.append("Todavía no")
	var r: int = await hud.elegir("Tablón de capacitaciones", texto + "\n¡Cumples los requisitos! Elige tu especialidad:", opciones)
	if r < 0 or r >= Juego.ESPECIALIDADES.size():
		return
	var esp: String = Juego.ESPECIALIDADES[r]
	await _accion(60, "Capacitación en %s…\n1 hora después" % esp)
	Juego.rango = "Residente"
	Juego.especialidad = esp
	Juego.sonido("exito", 1.0, -4.0)
	await hud.dialogo("Dr. Salgado", ["¡Felicitaciones, Dr. Pinkman!", "Desde hoy es Residente de %s." % esp,
		"Su consultorio ya está abierto: quinta puerta del pasillo.", "Y no se le suba a la cabeza: mañana a las 7:30, como siempre."])
	if _puerta_consultorios:
		_puerta_consultorios.modulate = Color.WHITE
		for c in _puerta_consultorios.get_children():
			c.modulate = Color.WHITE
	interactuables["puerta_consultorios"].etiqueta = "Entrar: Consultorio"
	refrescar_aviso()
	hud.mostrar("Ahora eres Residente de %s. Llegarán casos nuevos de tu especialidad." % esp, 4.5)


func _revisar_historias() -> void:
	var r: int = await hud.elegir("Historias clínicas", "Revisar casos también cuenta como estudio (%.1f h)." % Juego.horas_estudio,
		["Revisar 30 minutos", "Ahora no"])
	if r == 0:
		await _accion(30, "Revisando historias… 30 minutos después")
		Juego.horas_estudio += 0.5
		hud.mostrar("Repasaste casos. Horas de estudio: %.1f." % Juego.horas_estudio, 3.0)


# --- Eventos: hora pico, apagón y llamadas del director -----------------------------------
func _planear_eventos() -> void:
	if not Juego.eventos_aleatorios:
		return
	var calidad := int(Juego.flags.get("catelli_calidad", 0))
	var prob_apagon := maxf(0.06, 0.30 - 0.06 * calidad)
	if Juego.dia >= 2 and randf() < prob_apagon:
		apagon_hora = randi_range(9 * 60, 16 * 60)
	# El director llama cada 2 o 3 días para hablar del rendimiento
	var ultima := int(Juego.flags.get("director_ultima_llamada", 0))
	if Juego.dia >= 2 and Juego.dia - ultima >= randi_range(2, 3):
		llamado_hora = randi_range(11 * 60, 17 * 60)


func _eventos() -> void:
	var m := Juego.minutos
	if evento_pico > 0.0 and m >= evento_pico:
		evento_pico = -1.0
		Juego.sonido("altavoz", 0.9, -6.0)
		hud.mostrar("Altavoz: «¡Atención! Accidente en la avenida: llegan varios heridos a urgencias»." , 4.5)
	if apagon_hora > 0.0 and m >= apagon_hora and not apagon:
		apagon_hora = -1.0
		_iniciar_apagon()
	if catelli_estado == "llamado" and m >= catelli_llega:
		_llega_catelli()
	if catelli_estado == "arreglando" and m >= catelli_listo:
		_termina_arreglo()
	if llamado_hora > 0.0 and m >= llamado_hora and llamado == "":
		llamado_hora = -1.0
		_llamar_a_direccion("rendimiento")
	if Juego.flags.get("llamado_derivados", false) and llamado == "":
		Juego.flags.erase("llamado_derivados")
		_llamar_a_direccion("derivados")
	if llamado == "rendimiento" and m - llamado_desde > 90.0:
		llamado = ""
		Juego.sumar_reputacion(-2)
		hud.mostrar("Dr. Salgado (por el altavoz): «Pinkman, lo esperé y no vino». (−2 reputación)", 4.0)


func _iniciar_apagon() -> void:
	apagon = true
	catelli_estado = ""
	Juego.sonido("error", 0.5, -4.0)
	create_tween().tween_property(oscuridad, "color", Color(0.32, 0.34, 0.48), 0.8)
	hud.mostrar("¡Se fue la luz! Los monitores están apagados y los pacientes empeoran más rápido.", 4.5)
	hud.mostrar("Lucía: «¡Doctor, avise en dirección para que llamen al electricista!»", 4.0)


func _llega_catelli() -> void:
	catelli_estado = "llego"
	var o: Vector2 = SALAS["pasillo"]["origen"]
	var c := persona("Paul Catelli", 2, "overol", Personaje.PELOS, 3, o + Vector2(880, 100), Rect2(), [], true)
	c.position = o + Vector2(880, 100)
	c.mirada_base = Vector2.DOWN
	c.dialogo_dinamico = _dialogo_catelli
	Juego.sonido("altavoz", 1.0, -8.0)
	hud.mostrar("Altavoz: «Llegó el electricista, Paul Catelli. Está en el pasillo, junto al tablero»." , 4.0)


func _termina_arreglo() -> void:
	catelli_estado = ""
	apagon = false
	create_tween().tween_property(oscuridad, "color", Color.WHITE, 0.8)
	Juego.sonido("exito", 0.8, -6.0)
	hud.mostrar("Paul Catelli: «¡Listo! Luz como en Navidad. De nada, ¿eh? Nadie me da las gracias en este hospital»." , 4.5)
	if npcs.has("Paul Catelli"):
		_quitar_npc(npcs["Paul Catelli"])
	# ¿Vuelve a fallar hoy? Depende de la calidad acumulada y del consejo de esta visita
	var calidad := int(Juego.flags.get("catelli_calidad", 0))
	var prob_falla := clampf(0.45 - 0.08 * calidad - 0.15 * catelli_consejo, 0.05, 0.7)
	if randf() < prob_falla and Juego.minutos < Juego.FIN_TURNO - 120.0:
		apagon_hora = Juego.minutos + randf_range(40.0, 90.0)
		Juego.flags["catelli_fallo"] = true


func _dialogo_catelli():
	var otra_vez: bool = Juego.flags.get("catelli_fallo", false)
	var l: Array
	if otra_vez:
		l = ["¿OTRA VEZ? ¡Carajo! Esto no fue mi culpa, ¿eh? Es el edificio, que es más viejo que Salgado.",
			"Bueno, a ver qué hizo este tablero ahora…"]
	else:
		l = [["Paul Catelli, el mejor electricista de Pillbox. De nada por venir tan rápido.", "¡Maldita sea, qué porquería de cableado tienen aquí!"],
			["¿Usted es el doctorcito que manda a llamar? Ya, ya, aquí está el experto.", "Este tablero es un desastre. Menos mal que vine yo."]].pick_random()
	return {"lineas": l, "opciones": [
		{"texto": "Revise todo el tablero, no solo el fusible.", "efecto": "catelli:1", "amistad": 0,
			"respuesta": ["¿Me va a enseñar a mí? …Bueno, ya que lo dice, lo reviso todo. Pero porque yo quiero."]},
		{"texto": "Use cables nuevos; los viejos están pelados.", "efecto": "catelli:1", "amistad": 0,
			"respuesta": ["Cables nuevos… cuestan plata, doctor. Pero bueno, los pongo. Que lo pague Salgado."]},
		{"texto": "Usted es el mejor electricista de Pillbox.", "efecto": "catelli:0", "amistad": 2,
			"respuesta": ["¡POR FIN alguien con criterio en este hospital! Ya mismo lo arreglo."]},
		{"texto": "Hágalo rápido y ya, tenemos pacientes.", "efecto": "catelli:-1", "amistad": -1,
			"respuesta": ["¿Rápido? ¿Usted me está apurando a MÍ? Bueno, rápido será… después no se queje."]},
	]}


func _llamar_a_direccion(tipo: String) -> void:
	llamado = tipo
	llamado_desde = Juego.minutos
	if tipo == "rendimiento":
		Juego.flags["director_ultima_llamada"] = Juego.dia
	Juego.sonido("altavoz", 1.0, -4.0)
	if tipo == "derivados":
		hud.mostrar("Altavoz: «Dr. Walter Pinkman y Dr. Wilder Noctis, preséntense en la dirección. ¡YA!»", 5.0)
		var o: Vector2 = SALAS["direccion"]["origen"]
		if not npcs.has("Dr. Wilder Noctis (llamado)"):
			var w := persona("Dr. Wilder Noctis (llamado)", 1, "uniforme", Personaje.PELOS2, 3, o + Vector2(200, 214), Rect2(), [], true)
			w.position = o + Vector2(200, 214)
			w.mirada_base = Vector2.UP
			w.dialogo_dinamico = func(): return ["Shh… Salgado está furioso. No me mires, Walter."]
	else:
		hud.mostrar("Altavoz: «Dr. Walter Pinkman, por favor preséntese en la dirección»." , 4.5)


## Lo que dice Salgado si hay un apagón o un llamado pendiente ({} si no hay nada especial).
func _dialogo_salgado_eventos():
	if apagon and catelli_estado == "":
		return {"lineas": ["¡Pinkman! Se fue la luz otra vez. Los monitores no sirven sin corriente."], "opciones": [
			{"texto": "Llamemos al electricista, doctor.", "efecto": "llamar_catelli", "respuesta": ["Ya mismo llamo a Paul Catelli. Es… especial, pero hace su trabajo."]},
			{"texto": "Primero reviso a los pacientes.", "amistad": 0, "respuesta": ["Bien, pero vuelva pronto: sin luz no aguantamos mucho."]},
		]}
	if llamado == "derivados":
		return {"lineas": ["Pinkman. Noctis. Siéntense.", "%d pacientes derivados esta semana, Pinkman. ¿Usted es médico o recepcionista?" % Juego.derivados_semana,
			"Y usted, Noctis… a usted ni lo voy a mirar."], "opciones": [
			{"texto": "Tiene razón, doctor. Voy a mejorar.", "efecto": "regano:mejorar"},
			{"texto": "No estaba seguro de los diagnósticos.", "efecto": "regano:inseguro"},
			{"texto": "¡Fue culpa de Noctis!", "efecto": "regano:culpa"},
		]}
	if llamado == "rendimiento":
		return {"lineas": ["Pase, Pinkman. Lo llamé para saber cómo le va.",
			"Hoy lleva %d paciente(s) atendido(s), %d transferido(s) y %d derivado(s)." % [atendidos, transferidos, derivados],
			"Dígame con sinceridad: ¿cómo se ha sentido?"], "opciones": [
			{"texto": "Bien, aprendiendo mucho.", "amistad": 1, "efecto": "rendimiento:bien"},
			{"texto": "Cansado, la verdad.", "amistad": 0, "efecto": "rendimiento:cansado"},
			{"texto": "Con muchas ganas de ascender.", "amistad": 1, "efecto": "rendimiento:ascender"},
		]}
	return {}


# --- Historias de personajes ------------------------------------------------------
## Las historias avanzan una etapa por día (como mínimo) según las respuestas.
func _etapa(clave: String) -> int:
	return int(Juego.flags.get(clave + "_etapa", 0))


func _puede_avanzar(clave: String) -> bool:
	return Juego.dia > int(Juego.flags.get(clave + "_dia", 0))


func _avanzar(clave: String, etapa: int) -> void:
	Juego.flags[clave + "_etapa"] = etapa
	Juego.flags[clave + "_dia"] = Juego.dia


func _dialogo_zacarias():
	var e := _etapa("zac")
	if e == 0:
		var l: Array = [["¿L-la oficial Dakota del LSPD vino hoy?", "N-no, por nada… solo preguntaba. Ejem."],
			["¿Se me nota que estoy sudando? Es… es el calor del vestidor, s-sí."],
			["Ensayé un saludo para la oficial Dakota: «Hola, Dakota».", "¿Muy directo? ¿Muy aburrido? Ay, me tiemblan las manos."]].pick_random()
		return {"lineas": l + ["Doctor… ¿usted qué haría para hablarle a la oficial Dakota?"], "opciones": [
			{"texto": "Invítala a un café.", "amistad": 1, "efecto": "zac:1:cafe", "respuesta": ["¿Un café? ¿Así de simple?", "…Lo voy a pensar. Gracias, doctor."]},
			{"texto": "Sé tú mismo, Zacarías.", "amistad": 1, "efecto": "zac:1:mismo", "respuesta": ["¿Y-y si yo mismo soy un desastre?", "Bueno… lo intentaré."]},
			{"texto": "Mejor ni lo intentes.", "amistad": -2, "efecto": "zac:1:nada", "respuesta": ["…Tiene razón. Seguro me dice que no."]},
		]}
	if e == 1:
		if not _puede_avanzar("zac"):
			return ["Estoy pensando en lo que me dijo, doctor…", "Mañana. Mañana hago algo. C-creo."]
		return {"lineas": ["¡Doctor! Hoy vi a la oficial Dakota en recepción.", "Me miró y me dijo «hola». ¡ME DIJO HOLA!", "¿Eso significa algo? ¿Qué hago?"], "opciones": [
			{"texto": "¡Es una señal! Háblale mañana.", "amistad": 1, "efecto": "zac:2:valor", "respuesta": ["¡S-sí! ¡Mañana! Ay, no voy a dormir…"]},
			{"texto": "Un «hola» no significa nada.", "amistad": -1, "efecto": "zac:2:miedo", "respuesta": ["…Claro. Tiene razón. Solo fue educada."]},
		]}
	if e == 2:
		if not _puede_avanzar("zac"):
			return ["Mañana es el día, doctor. Mañana. Respire, Zacarías, respire…"]
		var bien: bool = Juego.flags.get("zac_consejo", "") != "nada" and Juego.flags.get("zac_animo", "") == "valor"
		_avanzar("zac", 3)
		Juego.flags["zac_final"] = "bien" if bien else "mal"
		if bien:
			Juego.cambiar_amistad("Dr. Zacarías Flores", 2)
			Juego.sonido("exito", 1.0, -8.0)
			return ["¡DOCTOR! ¡Lo hice!", "Le dije: «Oficial Dakota, ¿le gustaría tomar un café conmigo?».", "¡Y dijo que sí! ¡El sábado! ¡Gracias, gracias, gracias!"]
		return ["Doctor… fui a hablarle a la oficial Dakota.", "Abrí la boca y dije: «Buenas tardes, oficial»… y salí corriendo.", "Bueno. Por lo menos ahora sabe que existo."]
	var final_zac: String = Juego.flags.get("zac_final", "")
	if e == 3 and _puede_avanzar("zac"):
		if final_zac == "bien":
			return {"lineas": ["Doctor, la cita con Dakota es el sábado y no sé qué llevarle.", "¿Flores? ¿Chocolates? ¿Mi currículum? ¡Ayúdeme!"], "opciones": [
				{"texto": "Llévale donas. A los policías les encantan.", "amistad": 1, "efecto": "zac_regalo:donas", "respuesta": ["¡Donas! ¡Es usted un genio, doctor!"]},
				{"texto": "Flores. Nunca fallan.", "amistad": 1, "efecto": "zac_regalo:flores", "respuesta": ["Flores… clásico. Sí, sí, flores."]},
				{"texto": "Ve con tu bata, que vea que eres doctor.", "amistad": 0, "efecto": "zac_regalo:bata", "respuesta": ["¿Con la bata? Bueno… usted sabrá, doctor."]},
			]}
		return {"lineas": ["Doctor… ¿usted cree que debería intentarlo otra vez con Dakota?"], "opciones": [
			{"texto": "¡Claro! Esta vez invítala a un café, sin correr.", "amistad": 1, "efecto": "zac_reintento:si", "respuesta": ["S-sí… esta vez no corro. Lo prometo."]},
			{"texto": "Mejor dale un tiempo.", "amistad": 0, "efecto": "zac_reintento:no", "respuesta": ["Tiene razón… algún día."]},
		]}
	if e == 4 and _puede_avanzar("zac"):
		_avanzar("zac", 5)
		Juego.sonido("exito", 1.0, -8.0)
		match Juego.flags.get("zac_regalo", ""):
			"donas":
				Juego.flags["zac_novios"] = true
				return ["¡Doctor! Le llevé donas a Dakota y casi llora de la emoción.", "Dice que soy el primer hombre que entiende a un policía.", "…¡Somos novios! ¡NOVIOS!"]
			"flores":
				Juego.flags["zac_novios"] = true
				return ["Le llevé flores a Dakota… y resulta que es alérgica.", "Estornudó toda la cita, pero se rió muchísimo.", "¡Y me dio un beso en el cachete! Bueno… estornudó y luego me dio un beso."]
			_:
				return ["Fui con la bata a la cita. Dakota dijo que olía a hospital.", "Pero me dio otra oportunidad. ¡La próxima voy bañado y sin bata!"]
	if e >= 5:
		if Juego.flags.get("zac_novios", false):
			return [["Dakota me espera a la salida del turno. ¡Ya no sudo cuando la veo!"],
				["Dakota dice que el LSPD tiene un concurso de donas. ¡Voy a ir a apoyarla!"],
				["Gracias por todo, doctor. Sin usted seguiría ensayando «Hola, Dakota» en el espejo."]].pick_random()
		if final_zac == "rendido":
			return [["Sigo practicando: «Hola, Dakota». Algún día, doctor. Algún día."],
				["Si la oficial Dakota pregunta por mí, dígale que estoy muy ocupado salvando vidas."]].pick_random()
		return [["Seguimos saliendo con Dakota. Despacito, pero seguimos."], ["Esta vez voy sin bata. Aprendí la lección."]].pick_random()
	# etapa 3 esperando el día siguiente
	if final_zac == "bien":
		return [["Dakota dice que el LSPD tiene un concurso de donas. ¡Voy a ir a apoyarla!"],
			["Ya no sudo tanto cuando la veo. Bueno… un poquito."]].pick_random()
	return [["Sigo practicando: «Hola, Dakota». Algún día, doctor. Algún día."],
		["Si la oficial Dakota pregunta por mí, dígale que estoy muy ocupado salvando vidas."]].pick_random()


func _wilder_redimido() -> bool:
	return _etapa("wil") >= 3 and _etapa("wil") != 9 and Juego.flags.get("wil_camino", "") in ["encubierto", "redimido"]


## Lo que dice Salgado sobre Wilder (pregunta solo una vez, desde el día 2).
func _salgado_pregunta_wilder() -> Dictionary:
	if Juego.dia < 2 or _etapa("wil") != 0:
		return {}
	return {"lineas": ["Pinkman, una pregunta más.", "¿Ha visto al Dr. Noctis trabajando hoy? Sea sincero."], "opciones": [
		{"texto": "Sí, está atendiendo a un paciente.", "amistad": 0, "efecto": "wil:encubierto", "respuesta": ["Mmm… Está bien. Si usted lo dice."]},
		{"texto": "Está en la cafetería, como siempre.", "amistad": 1, "efecto": "wil:delatado", "respuesta": ["Lo sabía. Gracias por su honestidad, Pinkman.", "Desde mañana, Noctis hace turnos dobles."]},
		{"texto": "Prefiero no meterme en eso.", "amistad": 0, "efecto": "wil:neutral", "respuesta": ["Prudente. Ya lo averiguaré yo."]},
	]}


func _dialogo_wilder_historia():
	var e := _etapa("wil")
	var camino: String = Juego.flags.get("wil_camino", "")
	if e == 1 and _puede_avanzar("wil"):
		_avanzar("wil", 2)
		match camino:
			"redimido":
				return []
			"encubierto":
				Juego.dar_favor("Dr. Wilder Noctis")
				Juego.cambiar_amistad("Dr. Wilder Noctis", 2)
				return ["¡Walter! Salgado me contó que dijiste que yo estaba trabajando.", "¡Me salvaste el pellejo! Te debo una… de verdad esta vez."]
			"delatado":
				return {"lineas": ["Turnos dobles, Walter. ¡TURNOS DOBLES!", "Salgado dice que alguien le contó dónde estaba yo…"], "opciones": [
					{"texto": "Te lo merecías, Wilder.", "amistad": -1, "respuesta": ["…Bueno. Puede ser. Pero igual duele."]},
					{"texto": "Lo siento, Wilder.", "amistad": 1, "respuesta": ["Ya, ya… por lo menos así no me aburro."]},
				]}
			_:
				return ["Salgado me tiene en la mira, Walter.", "Ahora tengo que fingir que trabajo con más ganas."]
	if e == 2 and _puede_avanzar("wil") and camino == "encubierto":
		_avanzar("wil", 3)
		return ["Estuve pensando, Walter… tú me cubriste y yo aquí comiendo galletas.", "Desde mañana me verás en urgencias. ¡Promesa de garrita! Esta vez de verdad."]
	if e == 2 and _puede_avanzar("wil") and camino != "encubierto":
		return {"lineas": ["Oye, Walter… los turnos dobles me hicieron pensar.", "Creo que soy… ¿perezoso? ¿Se nota mucho?", "¿Me das una segunda oportunidad?"], "opciones": [
			{"texto": "Claro, empecemos de cero.", "amistad": 2, "efecto": "wil_segunda:si", "respuesta": ["¡Gracias! Mañana me verás en urgencias. ¡Promesa de garrita!"]},
			{"texto": "Demuéstramelo primero.", "amistad": 0, "efecto": "wil_segunda:no", "respuesta": ["Uy… justo. Bueno, seguiré en mi descanso eterno."]},
		]}
	if e == 3 and _puede_avanzar("wil") and _wilder_redimido():
		return {"lineas": ["Walter, tengo una idea loca: quiero ser Residente como tú.", "¿Me ayudas a estudiar? Prometo no dormirme… mucho."], "opciones": [
			{"texto": "Claro, te presto mis apuntes.", "amistad": 2, "efecto": "wil_estudio:si", "respuesta": ["¡Eres el mejor! Voy a subrayar todo con colores."]},
			{"texto": "Primero aprende a llegar a tiempo.", "amistad": -1, "efecto": "wil_estudio:no", "respuesta": ["Auch. Justo pero auch."]},
		]}
	if e == 4 and _puede_avanzar("wil"):
		_avanzar("wil", 5)
		if Juego.flags.get("wil_estudio", "") == "si":
			Juego.sonido("exito", 1.0, -8.0)
			return ["¡WALTER! Brown me hizo un repaso sorpresa y saqué 4 de 5.", "¡Promesa de garrita cumplida! Hasta Salgado me dijo «bien, Noctis»."]
		return ["Estudié solo. Me dormí en la página dos.", "Pero llegué a tiempo tres días seguidos. ¡Eso cuenta!"]
	return {}


func _dialogo_brown():
	var l: Array = [["Maximiliano Brown, de urgencias. Si se le complica un caso, pregúnteme.", "Y lea los signos con calma: el apuro hace equivocarse."],
		["El tensiómetro no miente, Pinkman. Úselo."],
		["Si un paciente no puede hablar, pregúntele a Lucía qué pasó."],
		["Aquí en urgencias uno aprende más en un día que en un mes de libros."],
		["Un buen médico sabe cuándo pedir ayuda. Un mal médico deriva todo."]].pick_random()
	var opciones: Array = []
	var sin_diag: Array = []
	for i in 3:
		var p: Paciente = pacientes[i]
		if p and p.estado == "diagnosticar" and not p.orientado:
			sin_diag.append(i)
	if not sin_diag.is_empty():
		opciones.append({"texto": "Dr. Brown, ¿me orienta con %s?" % pacientes[sin_diag[0]].nombre, "efecto": "brown_orienta:%d" % sin_diag[0]})
	for i in 3:
		if pacientes[i] and pacientes[i].estado != "alta":
			opciones.append({"texto": "¿Puede atender a %s por mí? (cuenta como derivado)" % pacientes[i].nombre, "efecto": "brown_deriva:%d" % i})
			break
	opciones.append({"texto": "Gracias, doctor.", "amistad": 1, "respuesta": ["Siga así, Pinkman."]})
	return {"lineas": l, "opciones": opciones}


# --- Historia de Rhea Pawlak y Alejandro Reyes -------------------------------------------
const CASO_PAWLAK := {"diagnostico": "Raspones por caída", "signos": "Raspones en codo y rodilla; el casco está rayado.",
	"historias": [], "herramienta": "Palpar", "hallazgo": "Raspones superficiales; huesos y articulaciones bien.",
	"falsos": ["Fractura", "Esguince de tobillo"], "insumo": "Vendaje", "deterioro": 0.15, "premio": 3, "inicial": 85.0, "grave": false}


func _pawlak_interes() -> String:
	return Juego.flags.get("pawlak_interes", "")


## Días en que Rhea viene a «reforzar la guardia» con Reyes (desde el día 7, si hay interés).
func _pawlak_de_guardia(d: int) -> bool:
	return d >= 7 and _pawlak_interes() == "si" and (d == 7 or d % 3 == 1 or d % 5 == 0)


## Rhea llega como paciente: días 2 y 5, y luego de vez en cuando («me caí otra vez»).
func _agenda_pawlak() -> void:
	var d := Juego.dia
	var viene := d == 2 or d == 5 or (d >= 8 and d % 3 == 2 and (_pawlak_interes() != "si" or randf() < 0.5))
	if not viene:
		return
	var ap := {"piel": 0, "ropa": "policia", "pelo_hoja": Personaje.PELOS2, "pelo_fila": 0}
	agenda.append({"hora": randi_range(9 * 60, 14 * 60), "caso": CASO_PAWLAK, "nombre": "Rhea Pawlak", "apariencia": ap})
	agenda.sort_custom(func(x, y): return x["hora"] < y["hora"])


## Lo que cuenta Rhea en la camilla según el día y la historia.
func _historia_pawlak() -> void:
	var visitas := int(Juego.flags.get("pawlak_visitas", 0)) + 1
	Juego.flags["pawlak_visitas"] = visitas
	Juego.flags["pawlak_conocida"] = true
	if visitas == 1:
		await hud.dialogo("Rhea Pawlak", ["Oficial Rhea Pawlak, LSPD. Mucho gusto, doctor… ¡ay!",
			"Un perro se me atravesó y me fui al piso con la moto.", "El perro está bien. Yo… más o menos."], -1.0, true)
		return
	if Juego.dia >= 5 and _pawlak_interes() == "":
		await hud.dialogo("Rhea Pawlak", ["Otra vez yo, doctor. Esta vez fue un hueco en la vía. Lo juro.",
			"Oiga… ese oficial de la entrada, Reyes. ¿Es buena gente?"], -1.0, true)
		var r: int = await hud.elegir("Responder a Rhea Pawlak", "", ["Es buen tipo. Él también pregunta por ti.",
			"Es buen policía. Deberías hablarle.", "No lo conozco mucho.", "Concéntrate en tu rodilla, oficial."])
		match r:
			0:
				Juego.flags["pawlak_interes"] = "si"
				Juego.cambiar_amistad("Rhea Pawlak", 2)
				await hud.dialogo("Rhea Pawlak", ["¿En serio? ¿Pregunta por mí?", "…No le diga que se me puso la cara roja, doctor."], -1.0, true)
			1:
				Juego.flags["pawlak_interes"] = "si"
				Juego.cambiar_amistad("Rhea Pawlak", 1)
				await hud.dialogo("Rhea Pawlak", ["Hablarle… sí. Quizás le pida ayuda con algún «caso». Jeje."], -1.0, true)
			2:
				Juego.flags["pawlak_interes"] = "neutral"
				await hud.dialogo("Rhea Pawlak", ["Ah, bueno. No importa. Era curiosidad profesional."], -1.0, true)
			_:
				Juego.flags["pawlak_interes"] = "no"
				Juego.cambiar_amistad("Rhea Pawlak", -1)
				await hud.dialogo("Rhea Pawlak", ["…Sí, señor. Rodilla. Entendido."], -1.0, true)
		return
	if _pawlak_interes() == "si":
		await hud.dialogo("Rhea Pawlak", [["Me caí… otra vez. Jeje. ¿Reyes está de turno hoy? Por nada, por nada."],
			["Esta vez fue una cáscara de banano. En la moto. Sí, es posible.", "¿Reyes está en la entrada? Solo pregunto."]].pick_random(), -1.0, true)
	else:
		await hud.dialogo("Rhea Pawlak", [["Otra caída, doctor. Creo que la moto me odia."],
			["Hoy fue un charco. Un charco enorme. Bueno, mediano."]].pick_random(), -1.0, true)


func _dialogo_reyes():
	var base: Array = [["Agente Alejandro Reyes. Hoy me toca la guardia de la entrada.", "Si ve algo raro, me avisa. Para eso estamos."],
		["Anoche trajimos a un muchacho que se cayó de la moto.", "Sin casco, claro. Siempre sin casco."],
		["Mendoza está en urgencias y McClane anda por el pasillo. Yo cuido la puerta."],
		["Hoy la ciudad está tranquila. Eso me pone más nervioso que cuando hay caos."],
		["El café de la recepción es horrible. No le diga a Erina que dije eso."]].pick_random()
	if _pawlak_de_guardia(Juego.dia):
		return [["Hoy vino Pawlak a «reforzar la guardia». Jeje.", "Doctor, no me mire así."],
			["Pawlak dice que mi café es horrible. Pero se toma dos."],
			["¿Usted cree que Pawlak viene por mí o por el café? No conteste."]].pick_random()
	if Juego.flags.get("pawlak_conocida", false) and Juego.dia >= 3 and not Juego.flags.has("reyes_consejo"):
		return {"lineas": ["Doctor… la oficial que se cae de la moto. Pawlak.", "¿Usted la atendió? ¿Está bien? Pregunto como compañero, nada más."], "opciones": [
			{"texto": "Está bien. Pregúntale tú mismo cuando venga.", "amistad": 1, "efecto": "reyes:hablar", "respuesta": ["¿Yo? ¿Hablarle? …Bueno. Si vuelve a caerse, le hablo."]},
			{"texto": "Es muy torpe con la moto, jaja.", "amistad": 0, "efecto": "reyes:torpe", "respuesta": ["Jaja, sí… pero es una gran policía, ¿eh?"]},
			{"texto": "Eso es confidencial, Reyes.", "amistad": -1, "efecto": "reyes:confidencial", "respuesta": ["Tiene razón, doctor. Perdón."]},
		]}
	if _pawlak_interes() == "si" and Juego.dia >= 6:
		return [["Pawlak me saludó hoy, doctor. ¡Me saludó primero!"],
			["Creo que le voy a preguntar a Pawlak si quiere patrullar conmigo algún día."]].pick_random()
	return base


func _dialogo_pawlak_guardia():
	return {"lineas": [["Vine a… reforzar la guardia. Sí. Eso.", "Reyes dice que el café de aquí es horrible, pero yo lo encuentro rico."],
		["Hola, doctor. Hoy no me caí. Bueno… casi."],
		["Reyes y yo estamos vigilando la entrada. Muy profesionalmente."]].pick_random(), "opciones": [
		{"texto": "¿Reforzando la guardia, oficial?", "amistad": 1, "respuesta": ["¡Shh! No le diga nada a nadie, doctor."]},
		{"texto": "Cuídate en la moto.", "amistad": 1, "respuesta": ["Siempre, doctor. Bueno, casi siempre."]},
	]}


# --- Efectos de las respuestas -------------------------------------------------------
func efecto_npc(nombre: String, efecto: String) -> void:
	if efecto.begins_with("reyes:"):
		Juego.flags["reyes_consejo"] = efecto.substr(6)
		return
	if efecto.begins_with("zac_regalo:"):
		Juego.flags["zac_regalo"] = efecto.substr(11)
		_avanzar("zac", 4)
		return
	if efecto.begins_with("zac_reintento:"):
		if efecto.ends_with("si"):
			Juego.flags["zac_consejo"] = "cafe"
			Juego.flags["zac_animo"] = "valor"
			_avanzar("zac", 2)
		else:
			Juego.flags["zac_final"] = "rendido"
			_avanzar("zac", 5)
		return
	if efecto.begins_with("wil_segunda:"):
		if efecto.ends_with("si"):
			Juego.flags["wil_camino"] = "redimido"
			_avanzar("wil", 3)
		else:
			_avanzar("wil", 9)
		return
	if efecto.begins_with("wil_estudio:"):
		Juego.flags["wil_estudio"] = efecto.substr(12)
		_avanzar("wil", 4)
		return
	if efecto == "llamar_catelli":
		catelli_estado = "llamado"
		catelli_llega = Juego.minutos + 20.0
		catelli_consejo = 0
		hud.mostrar("Salgado llamó a Paul Catelli. Llega en unos 20 minutos.", 3.0)
		return
	if efecto.begins_with("catelli:"):
		catelli_consejo = int(efecto.substr(8))
		Juego.flags["catelli_calidad"] = clampi(int(Juego.flags.get("catelli_calidad", 0)) + catelli_consejo, 0, 5)
		catelli_estado = "arreglando"
		catelli_listo = Juego.minutos + 30.0
		Juego.flags.erase("catelli_fallo")
		hud.mostrar("Paul Catelli se puso a trabajar en el tablero (30 min).", 3.0)
		return
	if efecto.begins_with("regano:"):
		var tipo := efecto.substr(7)
		await hud.dialogo("Dr. Wilder Noctis", ["¡Pero jefe, si yo ni atiendo pacientes! ¿Cómo voy a derivar?", "…Digo, sí atiendo. Muchísimos. Todo el día."])
		match tipo:
			"mejorar": await hud.dialogo("Dr. Salgado", ["Eso espero. Estudie, pregúntele a Brown y deje de pasarle sus pacientes a otros.", "(−3 reputación)"])
			"inseguro": await hud.dialogo("Dr. Salgado", ["Para eso está el estudio, Pinkman, y para eso está el Dr. Brown.", "Dudar está bien. Derivar todo, no. (−3 reputación)"])
			_:
				Juego.cambiar_amistad("Dr. Wilder Noctis", -2)
				await hud.dialogo("Dr. Salgado", ["¿Culpa de Noctis? Noctis no atiende ni el teléfono.", "Asuma sus errores, Pinkman. (−5 reputación)"])
				Juego.sumar_reputacion(-2)
		Juego.sumar_reputacion(-3)
		Juego.derivados_semana = 0
		llamado = ""
		if npcs.has("Dr. Wilder Noctis (llamado)"):
			_quitar_npc(npcs["Dr. Wilder Noctis (llamado)"])
		return
	if efecto.begins_with("rendimiento:"):
		llamado = ""
		Juego.flags["director_ultima_llamada"] = Juego.dia
		match efecto.substr(12):
			"bien": await hud.dialogo("Dr. Salgado", ["Me alegra. Así empezamos todos: aprendiendo.", "Siga así y pronto lo veo en el tablero de capacitaciones."])
			"cansado":
				var consejo := "Duerma bien y desayune; un médico cansado se equivoca."
				if Juego.energia < 40.0:
					consejo = "Se le nota. Tómese algo en la cafetería, y esta noche a dormir temprano."
				await hud.dialogo("Dr. Salgado", ["Gracias por la sinceridad.", consejo])
			_:
				var reqs := Juego.requisitos_residente()
				var faltan: Array = reqs.filter(func(r): return not r[1]).map(func(r): return r[0])
				if Juego.rango != "Interno":
					await hud.dialogo("Dr. Salgado", ["Ya es Residente. Las siguientes capacitaciones vendrán con el tiempo. Paciencia."])
				elif faltan.is_empty():
					await hud.dialogo("Dr. Salgado", ["Ya cumple todo. Vaya al tablón del pasillo."])
				else:
					await hud.dialogo("Dr. Salgado", ["Me gusta esa actitud. Le falta: " + ", ".join(faltan) + "."])
		return
	if efecto.begins_with("brown_orienta:"):
		var p: Paciente = pacientes[int(efecto.substr(14))]
		if p == null:
			return
		if int(Juego.flags.get("brown_pistas_hoy_%d" % Juego.dia, 0)) >= 3:
			await hud.dialogo("Dr. Maximiliano Brown", ["Ya lo ayudé bastante hoy, Pinkman. Ahora le toca a usted."])
			return
		Juego.flags["brown_pistas_hoy_%d" % Juego.dia] = int(Juego.flags.get("brown_pistas_hoy_%d" % Juego.dia, 0)) + 1
		p.orientado = true
		await hud.dialogo("Dr. Maximiliano Brown", ["A ver… %s: %s" % [p.nombre, p.caso["signos"].to_lower()],
			"Yo lo examinaría con: %s. Lo que encuentre le va a dar la respuesta." % p.caso["herramienta"].to_lower()])
		return
	if efecto.begins_with("brown_deriva:"):
		var i := int(efecto.substr(13))
		if pacientes[i]:
			await hud.dialogo("Dr. Maximiliano Brown", ["Está bien, yo lo atiendo.", "Pero no se acostumbre, Pinkman: derivar mucho se nota."])
			_derivar(i, "el Dr. Brown")
		return
	if efecto.begins_with("pasar:"):
		var i := int(efecto.substr(6))
		for e in espera:
			if e["nombre"] == nombre:
				_pasar_a_camilla(e, i)
				hud.mostrar("%s pasó a la camilla %d." % [nombre, i + 1], 2.5)
				return
		return
	if efecto.begins_with("vigilar:"):
		var i := int(efecto.substr(8))
		var p: Paciente = pacientes[i]
		if p == null:
			return
		if Juego.get_amistad("Lucía") >= 4:
			p.vigilado_hasta = Juego.minutos + 40.0
			await hud.dialogo("Lucía", ["Claro, doctor. Yo cuido a %s; usted vaya tranquilo." % p.nombre])
			hud.mostrar("Lucía vigila a %s durante 40 minutos: no empeorará." % p.nombre, 3.0)
		else:
			await hud.dialogo("Lucía", ["Lo siento, doctor, no puedo dejar la enfermería ahora."])
			hud.mostrar("(Necesitas más amistad con Lucía para pedirle eso.)", 3.0)
	elif efecto.begins_with("zac:"):
		var partes := efecto.split(":")
		if partes[1] == "1":
			Juego.flags["zac_consejo"] = partes[2]
			_avanzar("zac", 1)
		else:
			Juego.flags["zac_animo"] = partes[2]
			_avanzar("zac", 2)
	elif efecto.begins_with("wil:"):
		var camino := efecto.substr(4)
		Juego.flags["wil_camino"] = camino
		_avanzar("wil", 1)
		if camino == "delatado":
			Juego.sumar_reputacion(3)
			Juego.cambiar_amistad("Dr. Wilder Noctis", -3)
			hud.mostrar("(+3 reputación por tu honestidad)", 2.5)
		elif camino == "encubierto":
			Juego.cambiar_amistad("Dr. Wilder Noctis", 2)
	elif efecto == "cubrir_wilder":
		Juego.una_vez_hoy("cubrir_wilder")
		Juego.dar_favor("Dr. Wilder Noctis")
		Juego.flags["wilder_cubierto"] = int(Juego.flags.get("wilder_cubierto", 0)) + 1
		await _accion(20, "Cubriste a Wilder 20 minutos…")
	elif efecto == "wilder_ayuda":
		Juego.una_vez_hoy("wilder_ayuda")
		Juego.dar_favor("Dr. Wilder Noctis")
		await efecto_npc(nombre, "favor_wilder")
	elif efecto == "favor_wilder":
		for i in 3:
			var p: Paciente = pacientes[i]
			if p and p.estado != "alta":
				Juego.favores["Dr. Wilder Noctis"] = int(Juego.favores["Dr. Wilder Noctis"]) - 1
				await hud.dialogo("Dr. Wilder Noctis", ["Ugh… está bien. Un trato es un trato.", "Yo me encargo de %s. ¡No le digas a nadie que trabajé!" % p.nombre])
				p.estado = "alta"
				p.estabilidad = 100.0
				atendidos += 1
				Juego.sumar_reputacion(2)
				hud.mostrar("Wilder atendió a %s por ti. (+2 reputación)" % p.nombre, 3.0)
				await get_tree().create_timer(2.0).timeout
				if pacientes[i] == p:
					_liberar(i)
				return
		if not espera.is_empty():
			var e: Dictionary = espera[0]
			Juego.favores["Dr. Wilder Noctis"] = int(Juego.favores["Dr. Wilder Noctis"]) - 1
			await hud.dialogo("Dr. Wilder Noctis", ["Ugh… está bien. Un trato es un trato.", "Yo atiendo a %s en la sala de espera." % e["nombre"]])
			espera.erase(e)
			_quitar_npc(e["npc"])
			atendidos += 1
			Juego.sumar_reputacion(2)
			hud.mostrar("Wilder atendió a %s por ti. (+2 reputación)" % e["nombre"], 3.0)
	elif efecto == "cristian_insumo":
		if Juego.get_amistad("Cristian Daniel") < 4:
			await hud.dialogo("Cristian Daniel", ["Ahorita no puedo, doctor, ando con una camilla.", "(Necesitas más amistad con Cristian Daniel.)"])
			return
		if not Juego.una_vez_hoy("cristian_insumo"):
			await hud.dialogo("Cristian Daniel", ["Ya le hice un mandado hoy, doctor. ¡Tengo más camillas que llevar!"])
			return
		var todos: Array = Casos.insumos_botiquin() + INSUMOS_ROJO
		var r: int = await hud.elegir("¿Qué insumo te trae Cristian?", "", todos)
		if r >= 0:
			Juego.insumo_cargado = todos[r]
			await hud.dialogo("Cristian Daniel", ["¡Rápido como un rayo! Aquí tiene: %s." % todos[r].to_lower()])


func _terminar_turno() -> void:
	_terminando = true
	Juego.pausado = true
	walter.bloqueado = true
	var pendientes := _pendientes()
	Juego.terminar_turno()
	Juego.semana["atendidos"] += atendidos
	Juego.semana["transferidos"] += transferidos
	if Juego.es_viernes():
		hud.mostrar("Altavoz: «Dr. Walter Pinkman, preséntese en dirección para su evaluación»." , 3.0)
		await get_tree().create_timer(1.0).timeout
		await hud.dialogo("Dr. Salgado", Juego.evaluacion_semanal())
	var delta_rep := Juego.reputacion - _rep_inicio
	var resumen := "Fin del turno · Atendiste %d · Transferidos %d · Reputación %+d" % [atendidos, transferidos, delta_rep]
	if pendientes > 0:
		resumen += "\n%d paciente(s) quedan con el turno de la noche." % pendientes
	Juego.pasar_tiempo(Juego.MINUTOS_VIAJE)
	Juego.punto_entrada = "puerta"
	Juego.ir_a("res://escenas/casa.tscn", resumen)
