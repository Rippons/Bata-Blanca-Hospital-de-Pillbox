extends Node

var fallos := 0
var n_captura := 0


func ok(cond: bool, texto: String) -> void:
	print(("  OK   " if cond else "  FALLA ") + texto)
	if not cond:
		fallos += 1


func esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout


## Toma una captura cuando una cinemática llega a su momento clave.
func vigilar_momento(hosp, nombre: String, archivo: String) -> void:
	var t := 0.0
	while t < 40.0:
		if is_instance_valid(hosp) and hosp.cin and hosp.cin.momento == nombre:
			await esperar(0.5)
			await captura(archivo)
			return
		await esperar(0.1)
		t += 0.1


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
	Juego.eventos_aleatorios = false
	await Juego.ir_a("res://escenas/casa.tscn", "Día 1 · Lunes")
	await esperar(0.5)
	var casa = get_tree().current_scene
	ok(casa.name == "Casa", "arranca en la casa")
	await captura("casa_despertar")
	var m0: float = Juego.minutos
	await casa.interactuar("ducha")
	ok(Juego.higiene == 100.0 and Juego.banado_hoy, "bañarse deja higiene en 100")
	ok(Juego.minutos >= m0 + 15.0, "bañarse gasta 15 min")
	var comida0: int = Juego.comida
	Juego.respuestas_auto = [1]
	await casa.interactuar("comer")
	ok(Juego.desayuno_hoy, "desayuno completo")
	ok(Juego.comida == comida0 - 1, "desayunar gasta una comida de la nevera")
	ok(Juego.mensajes_nuevos() >= 1, "hay un mensaje nuevo de mamá en el celular")
	Juego.respuestas_auto = [0]
	await casa.interactuar("armario")
	ok(Juego.ropa == "uniforme", "vestido con bata")
	casa.walter.position = Vector2(452, 92)
	await esperar(0.4)
	await captura("casa_lista")
	print("   ", estado())
	await casa.interactuar("puerta")
	await esperar(2.5)
	var frente = get_tree().current_scene
	ok(frente.name == "FrenteCasa", "al salir aparece el frente de la casa")
	ok(Juego._musica_actual == "barrio", "afuera suena la música del barrio")
	ok(frente.interactuables.has("arbol") and frente.interactuables.has("calle"), "hay árbol grande y portón")
	await esperar(0.6)
	await captura("frente_casa")
	Juego.respuestas_auto = [0]
	await frente.interactuar("calle")
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
	var v0: float = Juego.velocidad_walter()
	var en0: float = Juego.energia
	Juego.respuestas_auto = [0]
	await hosp.interactuar("energetica")
	ok(Juego.velocidad_walter() > v0 and Juego.energia >= minf(en0 + 14.0, 100.0), "la bebida energética da energía y velocidad")
	Juego.respuestas_auto = [0]
	await hosp.interactuar("energetica")
	ok(Juego.flags.has("energetica_%d" % Juego.dia), "solo una bebida energética por turno")
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
	for nombre in ["Dr. Maximiliano Brown", "Dr. Máximo Stone", "Dr. Enzo Escobar", "Dr. Zacarías Flores", "Dr. Wilder Noctis", "Cristian Daniel", "Diego Quiroz"]:
		ok(hosp.npcs.has(nombre), "NPC " + nombre)
	await hosp.interactuar("npc:Dr. Wilder Noctis")
	ok(hosp.npcs["Alejandro Reyes"].figura._pelo.visible, "a los policías se les ve el pelo bajo la gorra")
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
	ok(hosp.espera.size() == 1 and hosp.pacientes[0] == null, "el paciente llega a la sala de espera, no directo a la camilla (%d en espera)" % hosp.espera.size())
	var e0: Dictionary = hosp.espera[0]
	ok(e0["triaje"] in ["verde", "amarillo", "rojo"], "Lucía le asigna triaje %s" % e0["triaje"])
	for k in 12:
		await esperar(1.0)
		if e0["npc"].position.distance_to(hosp.SALAS["urgencias"]["origen"] + hosp.PUESTOS_ESPERA[e0["puesto"]]) < 6.0:
			break
	var dist: float = e0["npc"].position.distance_to(hosp.SALAS["urgencias"]["origen"] + hosp.PUESTOS_ESPERA[e0["puesto"]])
	ok(dist < 6.0, "camina hasta su puesto en la sala de espera (a %.0f px)" % dist)
	await captura("sala_espera")
	Juego.respuestas_auto = ["Pase a la camilla 1."]
	await hosp.hablar_con(e0["nombre"])
	var p = hosp.pacientes[0]
	ok(p != null and hosp.espera.is_empty(), "Walter lo pasa a la camilla 1")
	ok(p.figura.piel == e0["apariencia"]["piel"] and p.figura.ropa == e0["apariencia"]["ropa"] and p.figura.pelo_fila == e0["apariencia"]["pelo_fila"],
		"en la camilla se ve igual que en la sala de espera")
	ok(int(p.caso["premio"]) <= 6, "un paciente da como máximo %d de reputación" % int(p.caso["premio"]))
	hosp.walter.position = hosp.SALAS["urgencias"]["origen"] + Vector2(150, 136)
	await esperar(0.5)
	await captura("hospital_urgencias")
	var rep: int = Juego.reputacion
	var falso: String = p.caso["falsos"][0]
	var est: float = p.estabilidad
	Juego.amistad["Lucía"] = 5
	Juego.respuestas_auto = [0]
	await hosp.interactuar("lucia")
	ok(p.vigilado_hasta > Juego.minutos, "con amistad, Lucía vigila al paciente (no empeora)")
	var otra: String = "Palpar" if p.caso["herramienta"] != "Palpar" else "Termómetro"
	Juego.respuestas_auto = [0, otra]
	await hosp.interactuar("camilla0")
	ok(p.conto_historia and not p.examinado, "el paciente cuenta su historia; herramienta equivocada no revela nada")
	ok(p.calmado or p.caso["grave"], "responder «Tranquilo…» calma al paciente")
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
	ok(Juego.reputacion == rep, "paciente estable; con un fallo no suma reputación (rep %d)" % Juego.reputacion)
	await esperar(3.0)
	ok(hosp.pacientes[0] == null, "camilla liberada")
	# Wilder: cubrirlo da un favor; cobrarlo hace que atienda a un paciente
	Juego.flags.erase("cubrir_wilder_%d" % Juego.dia)
	Juego.favores["Dr. Wilder Noctis"] = 0
	var m_w: float = Juego.minutos
	Juego.respuestas_auto = ["Está bien, te cubro (−20 min)."]
	await hosp.interactuar("npc:Dr. Wilder Noctis")
	ok(int(Juego.favores.get("Dr. Wilder Noctis", 0)) == 1 and Juego.minutos >= m_w + 20.0, "cubrir a Wilder: −20 min y te debe un favor")
	Juego.minutos = hosp.agenda[0]["hora"] + 1.0
	await esperar(0.3)
	hosp._pasar_a_camilla(hosp.espera[0], 0)
	var at0: int = hosp.atendidos
	Juego.respuestas_auto = ["Wilder, me debes una: atiende a un paciente."]
	await hosp.interactuar("npc:Dr. Wilder Noctis")
	ok(hosp.atendidos == at0 + 1 and int(Juego.favores["Dr. Wilder Noctis"]) == 0, "Wilder paga el favor atendiendo a un paciente")
	await esperar(2.5)
	# Brown orienta y derivar suma al contador
	Juego.minutos = hosp.agenda[0]["hora"] + 1.0
	await esperar(0.3)
	hosp._pasar_a_camilla(hosp.espera[0], 1)
	var q = hosp.pacientes[1]
	Juego.respuestas_auto = ["Dr. Brown, ¿me orienta con %s?" % q.nombre]
	await hosp.hablar_con("Dr. Maximiliano Brown")
	ok(q.orientado, "el Dr. Brown orienta con un paciente")
	var der0: int = Juego.derivados_semana
	Juego.respuestas_auto = [q.caso["herramienta"], "Derivar a otro médico (no estoy seguro)"]
	if not q.caso["historias"].is_empty():
		Juego.respuestas_auto.push_front(0)       # los graves no hablan: no hay pregunta para calmarlo
	await hosp.interactuar("camilla1")
	ok(hosp.pacientes[1] == null and Juego.derivados_semana == der0 + 1, "derivar libera la camilla y suma un derivado")
	# Diego: responder cambia la amistad
	var a_d: int = Juego.get_amistad("Diego Quiroz")
	Juego.respuestas_auto = ["Jaja, eres terrible."]
	await hosp.interactuar("npc:Diego Quiroz")
	ok(Juego.get_amistad("Diego Quiroz") == a_d + 1, "responder a Diego sube la amistad")
	# Personajes nuevos con hoja propia
	ok(hosp.npcs.has("Jinu Blake") and hosp.npcs["Jinu Blake"].figura.es_hoja(), "Jinu Blake está en el pasillo con su sprite propio")
	ok(hosp.npcs.has("Sheyla Escobedo"), "Sheyla Escobedo estudia en la cafetería")
	Juego.respuestas_auto = ["¡Bienvenido, Jinu! Cuenta conmigo."]
	await hosp.hablar_con("Jinu Blake")
	Juego.respuestas_auto = ["Se te nota un poquito, Jinu."]
	await hosp.hablar_con("Jinu Blake")
	ok(Juego.get_amistad("Jinu Blake") >= 2, "Jinu se lleva bien con Walter")
	Juego.respuestas_auto = ["Hablaré con él."]
	var sh: Dictionary = hosp._dialogo_sheyla()
	ok(str(sh["lineas"][0]).begins_with("Sheyla") or str(sh["lineas"][0]).begins_with("Comprendo"), "Sheyla habla como nerd")
	var enojo: Dictionary = hosp._dialogo_sheyla()
	ok(str(enojo["lineas"][0]).contains("Diego Quiroz"), "Sheyla se enoja con Diego por las bromas")
	# Cinemática de la broma
	await hosp.ir_a_sala("pasillo", hosp.npcs["Diego Quiroz"].position + Vector2(-20, 0))
	await hosp.hablar_con("Diego Quiroz")          # turno 1: anécdota
	Juego.respuestas_auto = ["Dile que Sheyla lo busca en la cafetería."]
	await hosp.hablar_con("Diego Quiroz")          # turno 2: la broma
	var t_c := 0.0
	while not hosp.cinematica_activa and t_c < 2.0:
		await esperar(0.1)
		t_c += 0.1
	ok(hosp.cinematica_activa, "empieza la cinemática de la broma")
	var vio_cafe := false
	t_c = 0.0
	while hosp.cinematica_activa and t_c < 40.0:
		await esperar(0.2)
		t_c += 0.2
		if not vio_cafe and hosp.sala_actual == "cafeteria" and hosp.npcs["Jinu Blake"].ruta.size() <= 1:
			vio_cafe = true
			await captura("cinematica_broma")
		if t_c > 2.9 and t_c < 3.2:
			await captura("cinematica_camara")
	ok(not hosp.cinematica_activa and t_c < 25.0, "la cinemática termina rápido (%.1f s) sin que Diego se trabe" % t_c)
	var jin: NPC = hosp.npcs["Jinu Blake"]
	var o_c: Vector2 = hosp.SALAS["cafeteria"]["origen"]
	ok(hosp.sala_actual == "cafeteria" and jin.position.distance_to(o_c + Vector2(282, 206)) < 6.0, "Jinu termina junto a Sheyla en la cafetería")
	ok(Juego.flags.get("jinu_sheyla", false) and not hosp.walter.bloqueado, "Jinu y Sheyla estudian juntos y Walter vuelve a moverse")
	ok(hosp.npcs["Diego Quiroz"].position.y < 2000.0, "Diego vuelve al pasillo")
	await captura("jinu_y_sheyla")
	# Policías nuevos
	ok(hosp._visita_marcos(3) and not hosp._visita_marcos(4), "el capitán Rojas visita cada 3 días")
	ok(hosp._dakota_en_recepcion(2) and hosp._dakota_en_recepcion(3), "Dakota aparece en recepción algunos días")
	var dm: Dictionary = hosp._dialogo_marcos()
	ok(str(dm["lineas"][0]).contains("Marcos Rojas"), "el capitán se presenta y pregunta por sus oficiales")
	var a_r: int = Juego.get_amistad("John McClane")
	hosp.efecto_npc("Capitán Marcos Rojas", "marcos:mcclane")
	ok(Juego.get_amistad("John McClane") == a_r - 1, "acusar a McClane con el capitán le baja la amistad")
	# segundo paciente: se deja transferir
	Juego.minutos = hosp.agenda[0]["hora"] + 1.0
	await esperar(0.3)
	Juego.reputacion = 20
	var rep2: int = Juego.reputacion
	Juego.minutos += 1000.0
	await esperar(0.3)
	ok(hosp.transferidos >= 1 and Juego.reputacion <= rep2 - 5, "paciente desatendido se transfiere (−5)")
	print("   ", estado())
	Juego.minutos = Juego.FIN_TURNO
	await esperar(4.0)

	print("== Día 1: noche en casa")
	var frente_n = get_tree().current_scene
	ok(frente_n.name == "FrenteCasa" and Juego.turno_terminado, "vuelve al frente de su casa tras el turno")
	ok(frente_n.walter.position.y > 200.0, "llega por el portón")
	Juego.minutos = maxf(Juego.minutos, 19 * 60 + 50)
	await esperar(0.8)
	await captura("frente_casa_noche")
	await frente_n.interactuar("puerta_casa")
	await esperar(2.5)
	casa = get_tree().current_scene
	ok(casa.name == "Casa", "entra a la casa")
	ok(Juego.turnos_bata == 1, "la bata suma un turno")
	await captura("casa_noche")
	Juego.respuestas_auto = [0]
	await casa.interactuar("comer")
	ok(Juego.cenado_hoy, "cenó")
	var h0: float = Juego.horas_estudio
	Juego.respuestas_auto = [1, 0]
	await casa.interactuar("escritorio")
	ok(Juego.horas_estudio >= h0 + 1.0, "estudiar 1 hora suma horas de estudio (%.1f h)" % Juego.horas_estudio)
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
	await casa.interactuar("puerta")
	await esperar(2.5)
	Juego.respuestas_auto = [0]
	await get_tree().current_scene.interactuar("calle")
	await esperar(3.0)
	ok(Juego.retrasos == 1, "llegar 8:00 cuenta como retraso")
	ok(Juego.reputacion <= rep3 - 10, "retraso + pijama + olor bajan reputación (%d → %d)" % [rep3, Juego.reputacion])
	await esperar(0.5)
	await captura("hospital_tarde")

	print("== Eventos: apagón, Catelli, llamadas del director y hora pico")
	var h2 = get_tree().current_scene
	h2._iniciar_apagon()
	await esperar(1.0)
	ok(h2.apagon and h2.oscuridad.color.r < 0.5, "apagón: se oscurece el hospital")
	Juego.respuestas_auto = ["Llamemos al electricista, doctor."]
	await h2.hablar_con("Dr. Salgado")
	ok(h2.catelli_estado == "llamado", "Salgado llama a Paul Catelli")
	Juego.minutos = h2.catelli_llega + 1.0
	await esperar(0.4)
	ok(h2.npcs.has("Paul Catelli"), "Paul Catelli llega al pasillo")
	Juego.respuestas_auto = ["Revise todo el tablero, no solo el fusible."]
	await h2.hablar_con("Paul Catelli")
	ok(h2.catelli_estado == "arreglando" and int(Juego.flags.get("catelli_calidad", 0)) == 1, "un buen consejo mejora el trabajo de Catelli")
	Juego.minutos = h2.catelli_listo + 1.0
	await esperar(1.2)
	ok(not h2.apagon and not h2.npcs.has("Paul Catelli") and h2.oscuridad.color.r > 0.9, "vuelve la luz y Catelli se va")
	h2.apagon_hora = -1.0                 # que no vuelva a fallar al azar durante el resto de la prueba
	Juego.flags.erase("catelli_fallo")
	Juego.derivados_semana = Juego.LIMITE_DERIVADOS
	Juego.flags["llamado_derivados"] = true
	await esperar(0.4)
	ok(h2.llamado == "derivados" and h2.npcs.has("Dr. Wilder Noctis (llamado)"), "muchos derivados: llaman a Walter y a Noctis a la dirección")
	var r_ll: int = Juego.reputacion
	Juego.respuestas_auto = ["Tiene razón, doctor. Voy a mejorar."]
	await h2.hablar_con("Dr. Salgado")
	ok(h2.llamado == "" and Juego.derivados_semana == 0 and Juego.reputacion <= maxi(r_ll - 3, 0), "llamado de atención: −3 reputación")
	h2._llamar_a_direccion("rendimiento")
	Juego.respuestas_auto = ["Bien, aprendiendo mucho."]
	await h2.hablar_con("Dr. Salgado")
	ok(h2.llamado == "", "el director llama para hablar del rendimiento")
	h2.evento_pico = Juego.minutos
	await esperar(0.3)
	ok(h2.evento_pico < 0.0, "hora pico: aviso de accidente")

	print("== ESC-02: la ambulancia")
	var cama := 2
	for k in [2, 1, 0]:
		if h2.pacientes[k] == null:
			cama = k
			break
	Juego.amistad["Lucía"] = 0
	h2.iniciar_ambulancia(cama)
	var t_a := 0.0
	var vio_entrada := false
	while h2.ambulancia_estado != "activa" and t_a < 30.0:
		await esperar(0.2)
		t_a += 0.2
		if not vio_entrada and h2.sala_actual == "entrada" and t_a > 6.2:
			vio_entrada = true
			await captura("ambulancia_llega")
	ok(vio_entrada, "Walter sale a la entrada y llega la ambulancia")
	ok(h2.ambulancia_estado == "activa" and h2.sala_actual == "urgencias", "Cristian Daniel lleva a Andrés a urgencias")
	var andres = h2.pacientes[cama]
	ok(andres != null and andres.nombre == "Andrés" and andres.caso["insumo"] == "Epinefrina", "Andrés queda en la camilla %d" % (cama + 1))
	ok(h2.npcs["Cristian Daniel"].position.distance_to(h2.SALAS["urgencias"]["origen"] + Vector2(h2.CAMILLAS_X[cama] + 26.0, h2.CAMILLA_Y + 18.0)) < 6.0, "Cristian se queda junto a la camilla")
	ok(h2.codigo_rojo != "", "sin amistad con Lucía, el botiquín rojo tiene clave")
	await captura("ambulancia_urgencias")
	Juego.respuestas_auto = ["0-0-0"]
	await h2.interactuar("botiquin_rojo")
	ok(Juego.insumo_cargado == "" and h2.codigo_rojo != "", "con la clave equivocada no se abre")
	Juego.respuestas_auto = [h2.codigo_rojo, "Epinefrina"]
	await h2.interactuar("botiquin_rojo")
	ok(Juego.insumo_cargado == "Epinefrina" and h2.epinefrina == 0, "con la clave de Lucía se toma la única dosis de epinefrina")
	Juego.respuestas_auto = ["Estetoscopio", "Reacción alérgica grave"]
	await h2.interactuar("camilla%d" % cama)
	ok(andres.estado == "tratar", "diagnóstico: reacción alérgica grave")
	var rep_a: int = Juego.reputacion
	await h2.interactuar("camilla%d" % cama)
	ok(h2.ambulancia_estado == "resuelta" and Juego.reputacion >= rep_a + 8, "Andrés se estabiliza: +4 del caso y +4 extra")
	ok(h2.npcs["Cristian Daniel"].position.y < 2000.0 and not h2.npcs["Cristian Daniel"].quieto, "Cristian vuelve a su ronda")
	h2._epinefrina_perdida()
	ok(h2.epinefrina_repuesto > 0.0, "si se desperdicia la epinefrina, Cristian trae otra dosis")
	h2.epinefrina_repuesto = -1.0
	h2.ambulancia_estado = ""

	print("== Eventos nuevos")
	var evh: EventosHospital = h2.eventos
	var esperar_hasta := func(cond: Callable, limite: float) -> void:
		var tt := 0.0
		while not cond.call() and tt < limite:
			await esperar(0.2)
			tt += 0.2
	# 4. Falta de insumos
	evh.iniciar("insumos")
	var falta: String = evh.agotado
	ok(falta != "", "falta un insumo en el botiquín: %s" % falta)
	Juego.respuestas_auto = [evh.etiqueta_insumo(falta), "Cancelar"]
	await h2.interactuar("botiquin")
	ok(Juego.insumo_cargado == "", "el insumo agotado no se puede tomar")
	Juego.respuestas_auto = ["Cristian, ¿me traes %s de la farmacia?" % falta.to_lower()]
	await h2.hablar_con("Cristian Daniel")
	ok(evh.agotado_vuelve > 0.0, "Cristian va a la farmacia")
	Juego.minutos = evh.agotado_vuelve + 1.0
	await esperar(0.3)
	ok(evh.agotado == "", "Cristian trae el insumo")
	# 9. Estetoscopio escondido
	evh.iniciar("estetoscopio")
	Juego.respuestas_auto = ["Le voy a contar a Sheyla."]
	await h2.hablar_con("Diego Quiroz")
	await esperar(0.5)
	ok(not evh.sin_estetoscopio, "Diego devuelve el estetoscopio (y Sheyla lo regaña)")
	# 2. Paciente que se escapa
	h2._entra_a_espera({"nombre": "Prueba Fuga", "caso": Casos.casos_leves()[0]})
	evh.fuga = {}
	for e in h2.espera.duplicate():
		if e["nombre"] != "Prueba Fuga":
			pass
	evh.iniciar("fuga")
	var fugado: String = evh.fuga.get("nombre", "")
	ok(fugado != "" and h2.npcs.has(fugado) and h2.npcs[fugado].position.y < 2000.0, "un paciente se va por el pasillo")
	Juego.respuestas_auto = ["¡McClane, ayúdeme a detenerlo!"]
	await h2.hablar_con(fugado)
	await esperar_hasta.call(func(): return evh.fuga.is_empty(), 8.0)
	ok(evh.fuga.is_empty() and h2.espera.any(func(e): return e["nombre"] == fugado), "McClane lo trae de vuelta a la sala de espera")
	# 3. Inspección
	evh.iniciar("inspeccion")
	ok(h2.npcs.has("Inspectora Valdés"), "llega la inspectora al pasillo")
	evh.inspectora_evalua = Juego.minutos
	await esperar_hasta.call(func(): return not h2.npcs.has("Inspectora Valdés"), 5.0)
	ok(Juego.flags.has("inspeccion_resultado"), "la inspectora da su resultado (%s)" % Juego.flags.get("inspeccion_resultado", "?"))
	# 1. Incendio
	evh.iniciar("incendio")
	ok(evh.incendio == "humo", "sale humo de la cafetería")
	Juego.respuestas_auto = ["¡Evacuemos a recepción, ahora!"]
	h2.hablar_con("Lucía")
	var vio_bomberos := false
	var t_f := 0.0
	while (evh.incendio != "listo" or h2.cinematica_activa) and t_f < 30.0:
		await esperar(0.2)
		t_f += 0.2
		if not vio_bomberos and h2.sala_actual == "entrada" and t_f > 4.0:
			vio_bomberos = true
			await captura("evento_bomberos")
	ok(evh.incendio == "listo" and not h2.cinematica_activa, "evacuación y llegan los bomberos")
	# 7. Examen de Brown
	Juego.respuestas_auto = [0, 0, 0]
	await evh.iniciar("examen")
	ok(not h2.cinematica_activa and h2.npcs["Dr. Maximiliano Brown"].position.y > 1999.0, "examen sorpresa de Brown y todos vuelven a su sitio")
	# 6. Detenido con Dakota (día 2: Dakota está en recepción)
	evh.iniciar("detenido")
	ok(h2.espera.any(func(e): return e["nombre"] == "Detenido (LSPD)") or h2.agenda.any(func(a): return a["nombre"] == "Detenido (LSPD)"), "Dakota trae a un detenido")
	ok(h2.npcs["Dakota"].position.y > 1999.0, "Dakota lo custodia en urgencias")
	evh.paciente_curado("Detenido (LSPD)")
	ok(h2.npcs["Dakota"].position.y < 1000.0, "al curarlo, Dakota vuelve a recepción")
	# 10. Pawlak herida
	evh.iniciar("pawlak_herida")
	ok(evh.pawlak_herida and h2.npcs["Alejandro Reyes"].position.y > 1999.0, "Rhea Pawlak llega herida y Reyes la acompaña")
	Juego.respuestas_auto = ["Respira, Reyes. Está en buenas manos."]
	await h2.hablar_con("Alejandro Reyes")
	evh.paciente_curado("Oficial Rhea Pawlak")
	ok(not evh.pawlak_herida and h2.npcs["Alejandro Reyes"].position.y < 1000.0, "Reyes vuelve a la entrada")
	# 12. Calor
	evh.iniciar("calor")
	Juego.respuestas_auto = ["Un jugo de maracuyá, por favor."]
	await h2.hablar_con("Doña Luz")
	ok(evh.calor and evh.jugo_tomado, "ola de calor: jugo gratis de Doña Luz")
	# 14. Mamá
	evh.iniciar("mama")
	Juego.respuestas_auto = ["¡Gracias, mamá! Me lo como ya."]
	await h2.hablar_con("Mamá de Walter")
	ok(Juego.hambre >= 99.0, "mamá trae almuerzo")
	var de_erina = evh.dialogo("Erina")
	ok(de_erina is Array and str(de_erina[0]).contains("mamá"), "Erina comenta la visita de mamá")
	# 15. Arrendador
	var plata: int = Juego.dinero
	Juego.dinero = -50
	Juego.respuestas_auto = [0]
	await evh.iniciar("arrendador")
	ok(Juego.flags.get("arrendador_promesa", false), "llama el arrendador por la deuda")
	Juego.dinero = plata
	# 5. Ascensor
	evh.iniciar("ascensor")
	ok(evh.ascensor == "atrapado", "el capitán queda atrapado en el ascensor")
	evh.catelli_llega = Juego.minutos
	await esperar(0.3)
	ok(h2.npcs.has("Paul Catelli"), "llega Paul Catelli")
	Juego.respuestas_auto = ["Catelli, usted es el mejor electricista de Pillbox. Demuéstrelo."]
	await h2.hablar_con("Paul Catelli")
	await esperar_hasta.call(func(): return evh.ascensor == "listo" and not h2.npcs.has("Paul Catelli"), 5.0)
	ok(evh.ascensor == "listo" and h2.npcs.has("Capitán Marcos Rojas"), "Catelli lo saca y el capitán da las gracias")
	# 11. Accidente grande
	var vio_acc := false
	evh.iniciar("accidente")
	var t_c2 := 0.0
	while not h2.agenda.any(func(a): return str(a["nombre"]).contains("accidente")) and t_c2 < 30.0:
		await esperar(0.2)
		t_c2 += 0.2
		if not vio_acc and h2.sala_actual == "entrada" and t_c2 > 6.0:
			vio_acc = true
			await captura("evento_accidente")
	ok(h2.agenda.filter(func(a): return str(a["nombre"]).contains("accidente")).size() == 3, "accidente grande: llegan tres heridos")
	# 8. Cumpleaños de Erina
	evh.iniciar("cumple_erina")
	Juego.respuestas_auto = ["¡Sí! Démelo, Doña Luz."]
	await h2.hablar_con("Doña Luz")
	ok(evh.pastel, "Doña Luz entrega el pastel")
	Juego.respuestas_auto = ["Erina, ¿me ayudas a buscar una historia clínica en el archivo?"]
	await h2.hablar_con("Erina")
	ok(evh.distraida, "Walter distrae a Erina")
	await h2.ir_a_sala("recepcion", Vector2(240, 200))
	Juego.minutos = 15 * 60 + 1
	var vio_fiesta := false
	var t_b := 0.0
	while evh.cumple != "listo" and t_b < 10.0:
		await esperar(0.1)
		t_b += 0.1
		if not vio_fiesta and h2.cinematica_activa:
			vio_fiesta = true
			await esperar(0.2)
			await captura("evento_cumple_erina")
	await esperar_hasta.call(func(): return not h2.cinematica_activa, 5.0)
	ok(evh.cumple == "listo" and Juego.get_amistad("Erina") >= 2, "fiesta sorpresa para Erina")

	print("== Aspecto: Stone y policías")
	ok(h2.npcs["Dr. Máximo Stone"].figura.pelo_hoja == Personaje.PELO_STONE and h2.npcs["Dr. Máximo Stone"].figura.piel == 0, "Stone: piel blanca y pelo aguamarina")
	ok(h2.npcs["Alejandro Reyes"].figura._pelo.visible and h2.npcs["Alejandro Reyes"].figura.pelo_hoja == Personaje.PELOS_LSPD, "los policías tienen pelo bajo la gorra")
	print("== Más ambulancias")
	ok(h2.dias_de_ambulancia(1).size() == 2 and h2.dias_de_ambulancia(1).all(func(x): return x >= 8 and x <= 12), "2 ambulancias por semana, de lunes a viernes")
	var cama2 := -1
	for k in [2, 1, 0]:
		if h2.pacientes[k] == null:
			cama2 = k
			break
	if cama2 == -1:
		h2._liberar(2)
		cama2 = 2
	h2.amb = {}
	h2.iniciar_ambulancia(cama2)
	var t_a2 := 0.0
	while h2.ambulancia_estado != "activa" and t_a2 < 30.0:
		await esperar(0.2)
		t_a2 += 0.2
	var p2 = h2.pacientes[cama2]
	ok(p2 != null and p2.nombre != "Andrés" and p2.caso["grave"], "otra ambulancia trae un grave distinto (%s)" % (p2.nombre if p2 else "?"))
	await captura("ambulancia_2")
	p2.estabilidad = 0.5
	await esperar_hasta.call(func(): return h2.ambulancia_estado == "perdida", 6.0)
	ok(h2.ambulancia_estado == "perdida" and not h2.npcs.has(h2.PARAMEDICA), "si el paciente se pierde, el paramédico se va")
	h2.ambulancia_estado = ""
	print("== Cinemáticas")
	Juego.respuestas_auto = [0, 0, 0]
	vigilar_momento(h2, "parto", "cin_parto")
	await evh.iniciar("parto")
	ok(Juego.flags.get("bebe_walter", false) and not h2.cinematica_activa, "parto en el ascensor: nace Walter chiquito")
	Juego.respuestas_auto = [0]
	vigilar_momento(h2, "fuga", "cin_fuga")
	await evh.iniciar("fuga_psiq")
	ok(not h2.cinematica_activa and not h2.npcs.has("Don Ernesto"), "fuga de Don Ernesto: se calma y vuelve")
	Juego.respuestas_auto = [0]
	vigilar_momento(h2, "alcalde", "cin_alcalde")
	await evh.iniciar("alcalde")
	ok(Juego.flags.get("ev_alcalde", false) and not h2.cinematica_activa, "visita del alcalde")
	vigilar_momento(h2, "tormenta", "cin_tormenta")
	await evh.iniciar("tormenta")
	ok(h2.apagon and h2.agenda.any(func(a): return str(a["nombre"]).contains("tormenta")), "tormenta: se va la luz y llegan heridos")
	await esperar(1.0)   # deja terminar el oscurecimiento del apagón antes de restaurar la luz
	h2.cin._lluvia.queue_free()
	h2.cin._lluvia = null
	h2.apagon = false
	h2.oscuridad.color = Color.WHITE
	Juego.flags["zac_novios"] = true
	await h2.ir_a_sala("urgencias", Vector2(240, 180))
	evh.iniciar("cita_zac")
	var vio_cita := false
	var t_ci := 0.0
	while not Juego.flags.get("ev_cita_zac", false) or h2.cinematica_activa:
		await esperar(0.1)
		t_ci += 0.1
		if not vio_cita and h2.cin.momento == "cita":
			vio_cita = true
			await esperar(0.5)
			await captura("cin_cita_zac_dakota")
		if t_ci > 30.0:
			break
	ok(Juego.flags.get("ev_cita_zac", false) and vio_cita and h2.npcs["Dr. Zacarías Flores"].position.y < 4000.0, "Diego avisa y se ve la cita de Zacarías y Dakota")
	Juego.flags.erase("zac_novios")
	await h2.ir_a_sala("vestidor", Vector2(300, 180))
	if h2.npcs.has("Dakota"):
		h2.cin.cafe_zac()
		var vio_cafe2 := false
		var t_cf := 0.0
		while not Juego.flags.get("ev_cafe_zac", false) or h2.cinematica_activa:
			await esperar(0.1)
			t_cf += 0.1
			if not vio_cafe2 and h2.cin.momento == "cafe":
				vio_cafe2 = true
				await esperar(0.5)
				await captura("cin_cafe_zac_recepcion")
			if t_cf > 30.0:
				break
		ok(h2.sala_actual == "recepcion" and h2.npcs["Dr. Zacarías Flores"].position.y > 2999.0, "Zacarías invita a Dakota en recepción y vuelve al vestidor")
	Juego.flags["jinu_sheyla"] = true
	vigilar_momento(h2, "graduacion", "cin_graduacion_jinu")
	await evh.iniciar("graduacion_jinu")
	ok(Juego.flags.get("ev_graduacion_jinu", false) and not h2.cinematica_activa, "graduación de Jinu")
	vigilar_momento(h2, "wilder", "cin_wilder")
	await evh.iniciar("wilder_salva")
	ok(Juego.flags.get("ev_wilder_salva", false) and not h2.cinematica_activa, "Wilder salva a un paciente frente a Salgado")
	vigilar_momento(h2, "despedida", "cin_despedida_erina")
	await evh.iniciar("despedida_erina")
	var dia_e: int = Juego.dia
	Juego.dia = dia_e + 4
	ok(Cinematicas.erina_de_vacaciones(), "Erina se va de vacaciones (llega Brenda)")
	Juego.dia = dia_e

	print("== Capacitación y ascenso")
	Juego.respuestas_auto = ["Cerrar"]
	await h2.interactuar("tablon")
	ok(Juego.rango == "Interno", "sin requisitos no se puede ascender")
	Juego.reputacion = 90
	Juego.horas_estudio = 5.0
	Juego.dias_trabajados = 3
	ok(not Juego.puede_ser_residente(), "con 90 de reputación ya no alcanza (ahora se piden 150)")
	Juego.reputacion = 160
	Juego.horas_estudio = 8.0
	Juego.dias_trabajados = 6
	ok(Juego.puede_ser_residente(), "con 150+ de reputación, 8 h y 6 turnos se cumplen los requisitos")
	Juego.respuestas_auto = ["Pediatría"]
	await h2.interactuar("tablon")
	ok(Juego.rango == "Residente" and Juego.especialidad == "Pediatría", "asciende a Residente de Pediatría")
	ok(Casos.casos_leves().any(func(c): return c["diagnostico"] == "Bronquiolitis"), "llegan casos de Pediatría")
	ok(Casos.insumos_botiquin().has("Nebulización"), "el botiquín tiene los insumos de la especialidad")
	await h2.interactuar("ir_pasillo")
	await h2.interactuar("puerta_consultorios")
	ok(h2.sala_actual == "consultorios", "el consultorio se abre al ser Residente")
	h2.walter.position = h2.SALAS["consultorios"]["origen"] + Vector2(300, 170)
	await esperar(0.5)
	await captura("consultorio")

	print("== Historias de Zacarías y Wilder")
	var dia_real: int = Juego.dia
	Juego.respuestas_auto = ["Invítala a un café."]
	await h2.hablar_con("Dr. Zacarías Flores")
	ok(h2._etapa("zac") == 1, "Zacarías: el consejo abre su historia")
	await h2.hablar_con("Dr. Zacarías Flores")
	ok(h2._etapa("zac") == 1, "Zacarías: la historia espera al día siguiente")
	Juego.dia += 1
	Juego.respuestas_auto = ["¡Es una señal! Háblale mañana."]
	await h2.hablar_con("Dr. Zacarías Flores")
	ok(h2._etapa("zac") == 2, "Zacarías: día 2 de la historia")
	Juego.dia += 1
	await h2.hablar_con("Dr. Zacarías Flores")
	ok(Juego.flags.get("zac_final", "") == "bien", "Zacarías: con buenos consejos, Dakota acepta el café")
	Juego.respuestas_auto = ["Sí, está atendiendo a un paciente."]
	await h2.hablar_con("Dr. Salgado")
	ok(h2._etapa("wil") == 1 and Juego.flags.get("wil_camino", "") == "encubierto", "Wilder: Salgado pregunta y Walter lo encubre")
	Juego.dia += 1
	Juego.favores["Dr. Wilder Noctis"] = 0
	await h2.hablar_con("Dr. Wilder Noctis")
	ok(h2._etapa("wil") == 2 and int(Juego.favores["Dr. Wilder Noctis"]) == 1, "Wilder: agradece y queda debiendo un favor")
	Juego.dia += 1
	await h2.hablar_con("Dr. Wilder Noctis")
	ok(h2._wilder_redimido(), "Wilder: decide trabajar en urgencias")
	Juego.dia += 1
	Juego.respuestas_auto = ["Claro, te presto mis apuntes."]
	await h2.hablar_con("Dr. Wilder Noctis")
	ok(h2._etapa("wil") == 4, "Wilder: pide ayuda para estudiar")
	Juego.dia += 1
	await h2.hablar_con("Dr. Wilder Noctis")
	ok(h2._etapa("wil") == 5, "Wilder: saca 4 de 5 en el repaso de Brown")
	# Zacarías: regalo y cita
	Juego.respuestas_auto = ["Llévale donas. A los policías les encantan."]
	await h2.hablar_con("Dr. Zacarías Flores")
	ok(h2._etapa("zac") == 4, "Zacarías: pide consejo para el regalo")
	Juego.dia += 1
	await h2.hablar_con("Dr. Zacarías Flores")
	ok(Juego.flags.get("zac_novios", false), "Zacarías: con donas, él y Dakota son novios")
	# Rhea Pawlak y Alejandro Reyes
	ok(not h2._pawlak_de_guardia(7), "sin interés, Rhea no viene a hacer guardia")
	Juego.dia = 3
	Juego.flags["pawlak_conocida"] = true
	Juego.respuestas_auto = ["Está bien. Pregúntale tú mismo cuando venga."]
	await h2.hablar_con("Alejandro Reyes")
	ok(Juego.flags.get("reyes_consejo", "") == "hablar", "día 3: Reyes pregunta por Rhea y pide consejo")
	Juego.dia = 5
	Juego.flags["pawlak_visitas"] = 1
	Juego.respuestas_auto = ["Es buen tipo. Él también pregunta por ti."]
	await h2._historia_pawlak()
	ok(h2._pawlak_interes() == "si", "día 5: Rhea pregunta por Reyes y Walter la anima")
	ok(h2._pawlak_de_guardia(7) and h2._pawlak_de_guardia(10), "desde el día 7, Rhea viene a hacer guardia con Reyes cada pocos días")
	Juego.dia = 2
	h2.agenda.clear()
	h2._agenda_pawlak()
	ok(h2.agenda.size() == 1 and h2.agenda[0]["nombre"] == "Rhea Pawlak", "el día 2 Rhea llega como paciente (caída en moto)")
	h2.agenda.clear()
	Juego.dia = dia_real

	print("== Carga de partida")
	var dia_guardado: int = Juego.dia
	Juego.dia = 99
	ok(Juego.cargar() and Juego.dia == dia_guardado, "cargar() recupera el día guardado")
	ok(Juego.get_amistad("Lucía") == 5, "la amistad se guarda y se carga")

	print("== Dinero, celular y fin de semana")
	Juego.nueva_partida()
	Juego.auto_dialogo = true
	await Juego.ir_a("res://escenas/casa.tscn", "")
	await esperar(0.5)
	var c2 = get_tree().current_scene
	Juego.respuestas_auto = [1, "Mercado de la semana ($90)", 3]
	await c2.celular()
	ok(Juego.dinero == 110 and Juego.comida == 12, "comprar mercado por el celular (−$90, +6 comidas)")
	Juego.respuestas_auto = [0, 0, 1, 3]
	await c2.celular()
	ok(Juego.mensajes_nuevos() == 0, "leer el mensaje lo marca como leído")
	print("== Celular en pantalla, bicicleta y auto")
	var cel: Celular = c2.hud.celular
	cel.abrir()
	await esperar(0.4)
	ok(cel.abierto and c2.walter.bloqueado, "el celular se abre en pantalla y Walter se queda quieto")
	var m_cel: float = Juego.minutos
	await esperar(1.5)
	ok(Juego.minutos > m_cel + 0.5, "el tiempo sigue corriendo con el celular abierto")
	ok(c2.hud.ocupado(), "con el celular abierto no se interactúa con otras cosas")
	await captura("celular_inicio")
	Juego.dinero = 3000
	cel._ir("tienda")
	await esperar(0.3)
	await captura("celular_tienda")
	for nombre in ["Bicicleta", "Auto usado"]:
		for b in cel._botones(cel._contenido):
			if b.text.begins_with(nombre):
				b.pressed.emit()
				break
		await esperar(0.3)
	ok(Juego.bicicleta and Juego.auto and Juego.dinero == 3000 - Juego.PRECIO_BICI - Juego.PRECIO_AUTO, "comprar bicicleta y auto en la tienda del celular")
	cel._ir("banco")
	await esperar(0.6)
	await captura("celular_banco")
	cel._ir("mensajes")
	await esperar(0.3)
	var botones_msg: Array = cel._botones(cel._contenido)
	if not botones_msg.is_empty():
		botones_msg[0].pressed.emit()
		await esperar(0.4)
		ok(cel.pantalla == "chat", "abrir un chat en la app de mensajes")
		await captura("celular_chat")
	cel.cerrar()
	await esperar(0.4)
	ok(not cel.abierto and not c2.walter.bloqueado, "guardar el celular devuelve el control")
	ok(Juego.medios_de_viaje().size() == 3, "en el portón hay 3 formas de ir: a pie, bici y auto")
	var m_v: float = Juego.minutos
	var d_v: int = Juego.dinero
	Juego.viajar("auto")
	ok(Juego.dinero == d_v - Juego.GASOLINA and (Juego.minutos - m_v == 8.0 or Juego.minutos - m_v == 25.0), "en auto: 8 min (o trancón de 25) y $10 de gasolina")
	Juego.minutos = m_v
	Juego.dinero = d_v
	Juego.medio_hoy = ""
	Juego.semana = {"turnos": 5, "atendidos": 20, "transferidos": 1, "retrasos": 0}
	var din0: int = Juego.dinero
	var ev: Array = Juego.evaluacion_semanal()
	ok(Juego.dinero == din0 + 5 * 60 and int(Juego.semana["turnos"]) == 0, "evaluación del viernes: sueldo de 5 turnos ($300)")
	ok(str(ev[2]).contains("Excelente"), "con 20 atendidos la nota es Excelente")
	Juego.dia = 6
	ok(Juego.es_fin_de_semana() and not Juego.es_manana(), "el sábado no hay turno")
	Juego.minutos = 10 * 60
	var din1: int = Juego.dinero
	await c2.interactuar("puerta")
	await esperar(2.5)
	var fr2 = get_tree().current_scene
	ok(fr2._bici != null and fr2._auto != null, "la bici y el auto se ven frente a la casa")
	await captura("frente_con_vehiculos")
	Juego.respuestas_auto = ["Ir al mercado: 6 comidas por $70 (1 h)"]
	await get_tree().current_scene.interactuar("calle")
	ok(Juego.dinero == din1 - 70 and Juego.comida == 18, "el sábado se puede ir al mercado")
	Juego.minutos = 12 * 60 + 5
	await esperar(0.5)
	ok(not Juego.falto_hoy, "el fin de semana no cuenta como falta")
	Juego.dia = 7
	Juego.minutos = 22 * 60
	var din2: int = Juego.dinero
	Juego.alarma_puesta = true
	Juego.dormir()
	ok(Juego.nombre_dia() == "Lunes" and Juego.dinero == din2 - Juego.ARRIENDO, "el lunes se cobra el arriendo")

	print("== Ascenso hasta Director y final")
	Juego.dia = 9
	Juego.minutos = 9 * 60
	await Juego.ir_a("res://escenas/hospital.tscn", "")
	await esperar(2.0)
	var h3 = get_tree().current_scene
	Juego.rango = "Residente"
	Juego.reputacion = 360
	Juego.horas_estudio = 16.0
	Juego.dias_trabajados = 15
	Juego.respuestas_auto = ["Tomar la capacitación (1 h 30 min)"]
	await h3.interactuar("tablon")
	ok(Juego.rango == "Especialista", "asciende a Especialista (con ceremonia)")
	Juego.reputacion = 700
	Juego.horas_estudio = 24.0
	Juego.dias_trabajados = 25
	Juego.respuestas_auto = ["Cerrar"]
	await h3.interactuar("tablon")
	ok(Juego.rango == "Especialista", "Jefe de servicio pide un equipo de amigos")
	for n in ["Lucía", "Erina", "Cristian Daniel", "Diego Quiroz", "Jinu Blake", "Doña Luz"]:
		Juego.amistad[n] = 6
	Juego.respuestas_auto = ["Tomar la capacitación (1 h 30 min)"]
	h3.interactuar("tablon")
	var vio_cer := false
	var t_ce := 0.0
	while Juego.rango != "Jefe de servicio" or h3.cinematica_activa:
		await esperar(0.1)
		t_ce += 0.1
		if not vio_cer and h3.cin.momento == "ceremonia":
			vio_cer = true
			await esperar(0.5)
			await captura("cin_ceremonia_ascenso")
		if t_ce > 30.0:
			break
	ok(Juego.rango == "Jefe de servicio" and Juego.pago_por_turno() == 220, "asciende a Jefe de servicio")
	Juego.reputacion = 1000
	Juego.horas_estudio = 32.0
	Juego.dias_trabajados = 35
	Juego.respuestas_auto = ["Ir a la evaluación final", 0]
	h3.interactuar("tablon")
	var vio_cred := false
	var t_fi := 0.0
	while not Juego.flags.get("final_visto", false) or h3.cinematica_activa:
		await esperar(0.1)
		t_fi += 0.1
		if not vio_cred and h3.cin.momento == "creditos":
			vio_cred = true
			await esperar(0.3)
			await captura("cin_creditos")
		if t_fi > 90.0:
			break
	ok(Juego.rango == "Director" and Juego.flags.get("final_visto", false), "final: Walter es Director del Hospital de Pillbox")

	print("RESULTADO: %d fallo(s)" % fallos)
	get_tree().quit(1 if fallos > 0 else 0)
