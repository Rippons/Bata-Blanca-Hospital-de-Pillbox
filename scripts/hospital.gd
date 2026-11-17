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
		"interior": Rect2(104, 40, 272, 186), "entrada": Vector2(128, 112)},
	"direccion": {"nombre": "Dirección", "origen": Vector2(0, 5000), "tam": Vector2(480, 270),
		"interior": Rect2(120, 40, 240, 180), "entrada": Vector2(334, 112)},
	"consultorios": {"nombre": "Consultorios", "origen": Vector2(0, 6000), "tam": Vector2(480, 270),
		"interior": Rect2(0, 18, 480, 252)},
}
const ALTO_PARED := 48.0
## Puertas del pasillo: [id de sala, x de la puerta en el pasillo, cartel, x de la puerta dentro del área]
const PUERTAS_PASILLO := [
	["urgencias", 120.0, "1 · URGENCIAS", 28.0],
	["vestidor", 300.0, "2 · VESTIDOR", 340.0],
	["cafeteria", 480.0, "3 · CAFETERÍA", 128.0],
	["direccion", 660.0, "4 · DIRECCIÓN", 334.0],
	["consultorios", 840.0, "5 · CONSULTORIOS", 0.0],
]
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
	var figura: Personaje

	class Sabana extends Node2D:
		func _draw() -> void:
			draw_rect(Rect2(-11, -22, 22, 16), Color("dfe9f2"))
			draw_rect(Rect2(-11, -22, 22, 3), Color("b9cbe0"))

	func _ready() -> void:
		figura = Personaje.new()
		figura.acostado = true
		figura.piel = randi_range(0, 5)
		figura.ropa = ROPAS_PACIENTE.pick_random()
		if randf() < 0.5:
			figura.pelo_hoja = Personaje.PELOS
			figura.pelo_fila = randi_range(0, 7)
		else:
			figura.pelo_hoja = Personaje.PELOS2
			figura.pelo_fila = [0, 2, 3, 4].pick_random()
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


var sala_actual := "recepcion"
var pacientes: Array = [null, null, null]
var agenda: Array = []          # [{hora, caso, nombre}]
var _ultimo_minuto := 0.0
var _terminando := false
var _cambiando := false
var _rep_inicio := 0
var atendidos := 0
var transferidos := 0


func construir() -> void:
	_construir_recepcion()
	_construir_pasillo()
	_construir_urgencias()
	_construir_vestidor()
	_construir_cafeteria()
	_construir_direccion()
	origen = Vector2.ZERO


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
	# mostrador con Marta, monitor y papeles
	npc(1, "fucsia", Personaje.PELOS2, 0, Vector2(240, 140))
	mueble(MISC, Rect2(2819, 15, 122, 45), Vector2(240, 176), true, 30)
	deco(Rect2(569, 21, 14, 18), 206, 150)
	deco(Rect2(1209, 23, 12, 16), 276, 148)
	zona("recepcionista", "Hablar con Marta (recepción)", Rect2(190, 176, 100, 16))
	# sala de espera izquierda
	mueble(HOME + "LivingRoom1-Sheet.png", Rect2(24, 501, 48, 26), Vector2(56, 112), true, 14)
	mueble(HOME + "LivingRoom1-Sheet.png", Rect2(24, 501, 48, 26), Vector2(120, 112), true, 14)
	mueble(MISC, Rect2(929, 15, 62, 25), Vector2(70, 176), true, 12)
	mueble(MISC, Rect2(929, 15, 62, 25), Vector2(140, 176), true, 12)
	mueble(MISC, Rect2(824, 4, 14, 50), Vector2(10, 196), true, 40)
	mueble(MISC, Rect2(54, 18, 20, 30), Vector2(40, 236), true, 12)
	mueble(HOME + "Miscellaneous-Sheet.png", Rect2(591, 35, 35, 21), Vector2(88, 136), true, 10)
	npc(4, "casual_rojo", Personaje.PELOS, 3, Vector2(58, 168))
	npc(2, "overol", Personaje.PELOS2, 3, Vector2(126, 104))
	# lado derecho: dispensador, máquina, plantas y más sillas
	mueble(MISC, Rect2(1333, 20, 22, 27), Vector2(470, 110), true, 12)
	mueble(HOME + "Kitchen-Sheet.png", Rect2(996, 0, 24, 48), Vector2(440, 112), true, 26, Color("ffcc80"))
	cartel("SNACKS", Vector2(428, 112), Color("6b3e00"))
	mueble(MISC, Rect2(929, 15, 62, 25), Vector2(340, 176), true, 12)
	mueble(MISC, Rect2(929, 15, 62, 25), Vector2(410, 176), true, 12)
	mueble(HOME + "LivingRoom1-Sheet.png", Rect2(24, 501, 48, 26), Vector2(352, 112), true, 14)
	npc(0, "rosa", Personaje.PELOS, 5, Vector2(400, 168))
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
		mueble(HOSP + "DoorsHospital-Sheet.png", Rect2(662, 30, 36, 50), Vector2(x, PARED), false, -1.0,
			Color(0.6, 0.6, 0.6) if cerrada else Color.WHITE)
		cartel(p[2], Vector2(x + 21, 22), Color("777777") if cerrada else Color("1e5a8a"))
		var etiqueta := "Consultorios (cerrado)" if cerrada else "Entrar: %s" % SALAS[p[0]]["nombre"]
		zona("puerta_%s" % p[0], etiqueta, Rect2(x - 20, PARED, 40, 18))
	# entre puertas: sillas contra la pared y letreros (como el ejemplo)
	var letreros := [Rect2(1583, 33, 34, 14), Rect2(1711, 33, 34, 14), Rect2(1455, 33, 34, 14), Rect2(1839, 33, 34, 14)]
	for i in 4:
		var xm: float = (PUERTAS_PASILLO[i][1] + PUERTAS_PASILLO[i + 1][1]) / 2.0
		mueble(MISC, Rect2(929, 15, 62, 25), Vector2(xm, 92), true, 12)
		deco(letreros[i], xm, 52)
	deco(Rect2(2103, 36, 18, 10), 60, 46)
	deco(Rect2(1982, 41, 9, 7), 150, 48)
	deco(Rect2(1209, 23, 12, 16), 330, 50)
	deco(Rect2(1982, 41, 9, 7), 690, 48)
	deco(Rect2(2103, 36, 18, 10), 900, 46)
	mueble(MISC, Rect2(2234, 28, 12, 18), Vector2(28, 90), true, 6)
	mueble(MISC, Rect2(2234, 28, 12, 18), Vector2(932, 90), true, 6)
	mueble(MISC, Rect2(185, 12, 14, 35), Vector2(560, 196), true, 6)
	mueble(HOME + "Flowers-Sheet.png", Rect2(22, 3, 20, 43), Vector2(944, 200), true, 8)
	# paso a recepción en la pared de abajo
	suelo_color(Rect2(30, 211, 60, 8), Color("6b4a2b"))
	cartel("↓ RECEPCIÓN", Vector2(36, 220), Color("9fc4e8"))
	zona("ir_recepcion", "Volver a recepción", Rect2(30, 196, 60, 18))
	npc(2, "rosa", Personaje.PELOS, 2, Vector2(560, 160), Vector2.LEFT)
	npc(5, "enfermera", Personaje.PELOS2, 4, Vector2(250, 150), Vector2.RIGHT)


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
	npc(3, "enfermera", Personaje.PELOS, 6, Vector2(110, 204))
	mueble(MISC, Rect2(2563, 15, 122, 45), Vector2(110, 236), true, 30)
	deco(Rect2(569, 21, 14, 18), 84, 214)
	zona("lucia", "Hablar con Lucía", Rect2(60, 236, 100, 16))
	mueble(MISC, Rect2(929, 15, 62, 25), Vector2(330, 222), true, 12)
	mueble(MISC, Rect2(929, 15, 62, 25), Vector2(410, 222), true, 12)
	mueble(HOME + "Flowers-Sheet.png", Rect2(22, 3, 20, 43), Vector2(462, 250), true, 8)


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
	npc(1, "uniforme", Personaje.PELOS, 7, Vector2(290, 180), Vector2.LEFT)


func _construir_cafeteria() -> void:
	_empezar_sala("cafeteria", Rect2(96, 176, 32, 32))
	_puerta_al_pasillo(128, "cafeteria")
	cartel("CAFETERÍA", Vector2(216, 26), Color("9fc4e8"))
	mueble(HOME + "Kitchen-Sheet.png", Rect2(607, 20, 34, 35), Vector2(184, 124), true, 20)
	mueble(HOME + "Kitchen-Sheet.png", Rect2(128, 21, 33, 34), Vector2(218, 124), true, 20)
	mueble(HOME + "Kitchen-Sheet.png", Rect2(223, 21, 33, 34), Vector2(251, 124), true, 20)
	mueble(HOME + "Kitchen-Sheet.png", Rect2(996, 0, 24, 48), Vector2(282, 128), true, 26)
	deco(Rect2(1583, 33, 34, 14), 218, 74)
	zona("almuerzo", "Almorzar (20 min)", Rect2(166, 120, 130, 26))
	mueble(HOME + "Kitchen-Sheet.png", Rect2(996, 0, 24, 48), Vector2(354, 128), true, 26, Color("ffcc80"))
	zona("snacks", "Máquina de snacks", Rect2(340, 122, 30, 24))
	for pos in [Vector2(170, 200), Vector2(300, 200)]:
		mueble(HOME + "Kitchen1-Sheet.png", Rect2(409, 15, 46, 33), pos, true, 22)
		mueble(HOME + "Kitchen1-Sheet.png", Rect2(42, 7, 12, 25), pos + Vector2(-30, -4), false)
		mueble(HOME + "Kitchen1-Sheet.png", Rect2(232, 9, 14, 23), pos + Vector2(30, -4), false)
	npc(0, "naranja", Personaje.PELOS, 4, Vector2(266, 196), Vector2.RIGHT)
	mueble(HOME + "Flowers-Sheet.png", Rect2(89, 23, 14, 23), Vector2(116, 220), true, 6)


func _construir_direccion() -> void:
	_empezar_sala("direccion", Rect2(96, 144, 32, 32))
	suelo(Rect2(192, 138, 96, 72), textura(HOME + "Carpet-Sheet.png"), Rect2(128, 0, 64, 64))
	_puerta_al_pasillo(334, "direccion")
	cartel("DIRECCIÓN · DR. ARTURO SALGADO", Vector2(164, 26), Color("9fc4e8"))
	mueble(HOME + "Cupboard-Sheet.png", Rect2(270, 20, 36, 43), Vector2(146, 124), true, 16)
	mueble(HOME + "Cupboard-Sheet.png", Rect2(334, 29, 36, 34), Vector2(184, 124), true, 16)
	deco(Rect2(1, 0, 30, 32), 240, 80, HOME + "Paintings1-Sheet.png")
	deco(Rect2(526, 15, 36, 40), 284, 84, HOME + "Windows-Sheet.png")
	npc(4, "uniforme", Personaje.PELOS, 1, Vector2(240, 162))
	mueble(HOME + "LivingRoom-Sheet.png", Rect2(25, 15, 46, 30), Vector2(240, 192), true, 18)
	deco(Rect2(569, 21, 14, 18), 228, 178)
	zona("salgado", "Hablar con el Dr. Salgado", Rect2(204, 192, 72, 18))
	mueble(HOME + "LivingRoom1-Sheet.png", Rect2(233, 97, 15, 46), Vector2(134, 210), true, 30)
	mueble(HOME + "Flowers-Sheet.png", Rect2(22, 3, 20, 43), Vector2(346, 214), true, 8)
	mueble(HOME + "Lights-Sheet.png", Rect2(152, 0, 16, 32), Vector2(306, 128), true, 6)


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
	hud.mostrar("Marta: «Buenos días, Dr. Vega. Las áreas están por el pasillo; urgencias es la primera puerta».", 4.5)
	for nota in notas:
		hud.mostrar(nota, 4.5)
	walter.actualizar_aspecto()
	Juego.pausado = false


func _rect_sala(id: String) -> Rect2:
	return Rect2(SALAS[id]["origen"], SALAS[id]["tam"])


func ir_a_sala(destino: String, punto: Vector2) -> void:
	if _cambiando:
		return
	_cambiando = true
	walter.bloqueado = true
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


# --- Bucle ---------------------------------------------------------------------
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
		p.position = SALAS["urgencias"]["origen"] + Vector2(CAMILLAS_X[libre], CAMILLA_Y)
		mundo.add_child(p)
		pacientes[libre] = p
		interactuables["camilla%d" % libre].etiqueta = "Atender a %s" % p.nombre
		refrescar_aviso()
		if sala_actual != "urgencias":
			hud.mostrar("Altavoz: «Dr. Walter Vega, se le necesita en urgencias%s»." % (" de inmediato" if a["caso"]["grave"] else ""), 4.0)
		elif a["caso"]["grave"]:
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
	hud.poner_lista("%s · guardia" % SALAS[sala_actual]["nombre"], tareas)


# --- Interacciones --------------------------------------------------------------
func interactuar(id: String) -> void:
	if _cambiando:
		return
	if id.begins_with("camilla"):
		await _camilla(int(id.substr(7)))
	elif id.begins_with("puerta_"):
		var destino := id.substr(7)
		if destino == "consultorios":
			hud.mostrar("Consultorios externos: se abrirán cuando seas Residente.")
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
			"recepcionista": _marta()
			"botiquin": await _botiquin(INSUMOS_A, "Botiquín")
			"botiquin_rojo": await _botiquin(["Epinefrina"], "Botiquín rojo")
			"casillero": await _casillero()
			"ducha_hospital": await _ducha()
			"almuerzo": await _almorzar()
			"snacks": await _snacks()
			"lucia": _lucia()
			"salgado": _salgado()
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
	if Juego.insumo_cargado == "":
		hud.mostrar("%s necesita tratamiento (%s). Busca el insumo en un botiquín." % [p.nombre, p.caso["diagnostico"]])
		return
	if Juego.insumo_cargado == p.caso["insumo"]:
		var premio: int = p.caso["premio"] if p.fallos == 0 else int(p.caso["premio"] / 2.0)
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


func _marta() -> void:
	var esperando := 0
	for p in pacientes:
		if p and p.estado != "alta":
			esperando += 1
	if esperando > 0:
		hud.mostrar("Marta: «Hay %d paciente(s) en urgencias, doctor. Primera puerta del pasillo»." % esperando, 4.0)
	else:
		hud.mostrar("Marta: «Todo tranquilo por ahora. La cafetería es la tercera puerta, por si acaso».", 4.0)


func _lucia() -> void:
	if Juego.huele_mal():
		hud.mostrar("Lucía: «Doctor, se lo digo con cariño: en el vestidor hay ducha».", 4.0)
		return
	if Juego.energia < 25.0:
		hud.mostrar("Lucía: «Se ve agotado, doctor. Duerma más esta noche».", 4.0)
		return
	hud.mostrar(CONSEJOS.pick_random(), 4.0)


func _salgado() -> void:
	var t := "Dr. Salgado: «Vega, lleva %d de reputación, %d día(s) seguidos puntual y %d retraso(s)." % [Juego.reputacion, Juego.racha_puntual, Juego.retrasos]
	if Juego.reputacion >= 30:
		t += " Va por buen camino para su primera capacitación»."
	else:
		t += " Necesita 30 de reputación para pensar en una capacitación»."
	hud.mostrar(t, 5.0)


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
