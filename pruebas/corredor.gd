extends Node

var fallos := 0
var n_captura := 0


func ok(cond: bool, texto: String) -> void:
	print(("  OK   " if cond else "  FALLA ") + texto)
	if not cond:
		fallos += 1


func esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout


func captura(nombre: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://capturas")
	n_captura += 1
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://capturas/%02d_%s.png" % [n_captura, nombre])


func estado() -> String:
	return "día %d %s · hig %.0f · ene %.0f · ham %.0f · ropa %s · rep %d" % [Juego.dia, Juego.hora_texto(), Juego.higiene, Juego.energia, Juego.hambre, Juego.ropa, Juego.reputacion]


func _ready() -> void:
	await esperar(0.3)
	print("== Día 1: mañana en casa")
	Juego.nueva_partida()
	Juego.auto_dialogo = true
	await Juego.ir_a("res://escenas/casa.tscn", "Día 1 · Lunes")
	await esperar(0.5)
	var casa = get_tree().current_scene
	ok(casa.name == "Casa", "arranca en la casa")
	await captura("casa_despertar")
	var m0: float = Juego.minutos
	await casa.interactuar("ducha")
	ok(Juego.higiene == 100.0 and Juego.banado_hoy, "bañarse deja higiene en 100")
	ok(Juego.minutos >= m0 + 15.0, "bañarse gasta 15 min")
	Juego.respuestas_auto = [1]
	await casa.interactuar("comer")
	ok(Juego.desayuno_hoy, "desayuno completo")
	Juego.respuestas_auto = [0]
	await casa.interactuar("armario")
	ok(Juego.ropa == "uniforme", "vestido con bata")
	casa.walter.position = Vector2(452, 92)
	await esperar(0.4)
	await captura("casa_lista")
	print("   ", estado())
	Juego.respuestas_auto = [0]
	await casa.interactuar("puerta")
	await esperar(3.0)

	print("== Día 1: hospital")
	var hosp = get_tree().current_scene
	ok(hosp.name == "Hospital", "llega al hospital")
	ok(hosp.sala_actual == "recepcion", "aparece en la recepción")
	ok(Juego.minutos < Juego.INICIO_TURNO, "llega puntual (%s)" % Juego.hora_texto())
	ok(Juego.racha_puntual == 1, "racha puntual = 1")
	await esperar(0.6)
	await captura("hospital_recepcion")
	await hosp.interactuar("ir_pasillo")
	ok(hosp.sala_actual == "pasillo", "recepción → pasillo")
	hosp.walter.position = hosp.SALAS["pasillo"]["origen"] + Vector2(400, 150)
	await esperar(0.6)
	await captura("hospital_pasillo")
	for area in ["vestidor", "cafeteria", "direccion"]:
		await hosp.interactuar("puerta_" + area)
		ok(hosp.sala_actual == area, "pasillo → " + area)
		hosp.walter.position = hosp.SALAS[area]["origen"] + hosp.SALAS[area]["entrada"] + Vector2(-20, 40)
		await esperar(0.5)
		await captura("hospital_" + area)
		await hosp.interactuar("volver_" + area)
		ok(hosp.sala_actual == "pasillo", area + " → pasillo")
	ok(hosp.npcs.has("Erina") and hosp.npcs["Erina"].quieto, "Erina en recepción (no camina)")
	for nombre in ["Alejandro Reyes", "Jaiden Mendoza", "John McClane"]:
		ok(hosp.npcs.has(nombre) and hosp.npcs[nombre].figura.ropa == "policia", "policía " + nombre)
	await hosp.interactuar("npc:John McClane")
	await hosp.interactuar("recepcionista")
	var mc = hosp.npcs["John McClane"]
	var p0: Vector2 = mc.position
	await esperar(6.0)
	ok(mc.position.distance_to(p0) > 3.0, "los NPC caminan (McClane se movió %.0f px)" % mc.position.distance_to(p0))
	for nombre in ["Dr. Maximiliano Brown", "Dr. Máximo Stone", "Dr. Enzo Escobar", "Dr. Zacarías Flores", "Dr. Wilder Noctis", "Cristian Daniel", "Iván Rojas"]:
		ok(hosp.npcs.has(nombre), "NPC " + nombre)
	await hosp.interactuar("npc:Dr. Wilder Noctis")
	ok(not hosp.npcs["Alejandro Reyes"].figura._pelo.visible, "los policías no muestran pelo sobre la gorra")
	var fig := Personaje.new()
	add_child(fig)
	fig.mirando = Vector2.RIGHT
	fig.caminar(true, 0.0)
	ok(fig._col_dir == 6, "caminar a la derecha usa las columnas 6-11 (miran a la derecha)")
	fig.mirando = Vector2.LEFT
	fig.caminar(true, 0.0)
	ok(fig._col_dir == 18, "caminar a la izquierda usa las columnas 18-23")
	fig.queue_free()
	var erina = hosp.npcs["Erina"]
	ok(erina.figura.mirando == Vector2.DOWN, "Erina vuelve a mirar al mostrador después de hablar")
	var nombres_npc: Array = hosp.npcs.keys()
	ok(nombres_npc.size() >= 20, "%d NPC con nombre en el hospital" % nombres_npc.size())
	await hosp.interactuar("puerta_consultorios")
	ok(hosp.sala_actual == "pasillo", "consultorios está cerrado")
	await hosp.interactuar("puerta_urgencias")
	ok(hosp.sala_actual == "urgencias", "pasillo → urgencias (primera puerta)")
	Juego.minutos = hosp.agenda[0]["hora"] + 1.0
	await esperar(0.3)
	var p = hosp.pacientes[0]
	ok(p != null, "llega el primer paciente a la camilla 1")
	hosp.walter.position = hosp.SALAS["urgencias"]["origen"] + Vector2(150, 136)
	await esperar(0.5)
	await captura("hospital_urgencias")
	var rep: int = Juego.reputacion
	var falso: String = p.caso["falsos"][0]
	var est: float = p.estabilidad
	var otra: String = "Palpar" if p.caso["herramienta"] != "Palpar" else "Termómetro"
	Juego.respuestas_auto = [otra]
	await hosp.interactuar("camilla0")
	ok(p.conto_historia and not p.examinado, "el paciente cuenta su historia; herramienta equivocada no revela nada")
	Juego.respuestas_auto = [p.caso["herramienta"], falso]
	await hosp.interactuar("camilla0")
	ok(p.examinado, "con %s se encuentra: %s" % [p.caso["herramienta"], p.caso["hallazgo"]])
	ok(p.estabilidad <= est - 9.0 and p.fallos == 1, "diagnóstico errado baja estabilidad")
	Juego.respuestas_auto = [p.caso["diagnostico"]]
	await hosp.interactuar("camilla0")
	ok(p.estado == "tratar", "diagnóstico correcto")
	Juego.respuestas_auto = [p.caso["insumo"]]
	await hosp.interactuar("botiquin_rojo" if p.caso["grave"] else "botiquin")
	ok(Juego.insumo_cargado == p.caso["insumo"], "toma el insumo %s" % p.caso["insumo"])
	await hosp.interactuar("camilla0")
	ok(Juego.reputacion == rep + int(p.caso["premio"] / 2), "paciente estable, premio a la mitad por el fallo (rep %d)" % Juego.reputacion)
	await esperar(3.0)
	ok(hosp.pacientes[0] == null, "camilla liberada")
	# segundo paciente: se deja transferir
	Juego.minutos = hosp.agenda[0]["hora"] + 1.0
	await esperar(0.3)
	var rep2: int = Juego.reputacion
	Juego.minutos += 400.0
	await esperar(0.3)
	ok(hosp.transferidos >= 1 and Juego.reputacion <= rep2 - 5, "paciente desatendido se transfiere (−5)")
	print("   ", estado())
	Juego.minutos = Juego.FIN_TURNO
	await esperar(4.0)

	print("== Día 1: noche en casa")
	casa = get_tree().current_scene
	ok(casa.name == "Casa" and Juego.turno_terminado, "vuelve a casa tras el turno")
	ok(Juego.turnos_bata == 1, "la bata suma un turno")
	await captura("casa_noche")
	Juego.respuestas_auto = [0]
	await casa.interactuar("comer")
	ok(Juego.cenado_hoy, "cenó")
	Juego.respuestas_auto = [1]
	await casa.interactuar("armario")
	ok(Juego.ropa == "pijama", "pijama puesta")
	Juego.respuestas_auto = [1]
	await casa.interactuar("despertador")
	ok(Juego.alarma_puesta and Juego.hora_alarma == 360, "alarma a las 6:00")
	print("   ", estado())
	Juego.respuestas_auto = [0]
	await casa.interactuar("cama")
	await esperar(3.5)

	print("== Día 2: sin alarma ni ducha")
	ok(Juego.dia == 2 and Juego.minutos >= 360.0 and Juego.minutos < 370.0, "amanece el día 2 a las 6:00 (%s)" % Juego.hora_texto())
	ok(Juego.hay_partida_guardada(), "se guardó la partida al dormir")
	print("   ", Juego.ultimo_resumen)
	casa = get_tree().current_scene
	Juego.higiene = 15.0
	Juego.minutos = 7 * 60 + 40
	await esperar(0.5)
	ok(casa.walter.figura.olor == 2, "con higiene baja se ve el olor")
	casa.walter.position = Vector2(200, 150)
	await esperar(0.6)
	await captura("casa_olor")
	Juego.reputacion = 40
	var rep3: int = Juego.reputacion
	Juego.respuestas_auto = [0]
	await casa.interactuar("puerta")
	await esperar(3.0)
	ok(Juego.retrasos == 1, "llegar 8:00 cuenta como retraso")
	ok(Juego.reputacion <= rep3 - 10, "retraso + pijama + olor bajan reputación (%d → %d)" % [rep3, Juego.reputacion])
	await esperar(0.5)
	await captura("hospital_tarde")

	print("== Carga de partida")
	var dia_guardado: int = Juego.dia
	Juego.dia = 99
	ok(Juego.cargar() and Juego.dia == dia_guardado, "cargar() recupera el día guardado")

	print("RESULTADO: %d fallo(s)" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)
