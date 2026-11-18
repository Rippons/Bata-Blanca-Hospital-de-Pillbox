class_name Casos
extends RefCounted
## Casos clínicos, herramientas de examen e insumos. Los usan el hospital
## (pacientes) y la casa (preguntas al estudiar).

const HERRAMIENTAS := ["Termómetro", "Estetoscopio", "Tensiómetro", "Otoscopio", "Linterna", "Glucómetro", "Palpar"]
const INSUMOS_A := ["Vendaje", "Antipirético", "Suero oral", "Férula", "Inhalador", "Gotas para el oído",
	"Glucosa oral", "Lavado de ojos", "Medicamento para la presión", "Analgésico", "Crema para quemaduras",
	"Antibiótico", "Antiácido", "Retirar aguijón", "Hielo y observación"]
const INSUMOS_ROJO := ["Epinefrina", "Suero intravenoso frío", "Aspirina y oxígeno"]

## Casos clínicos. «historias»: lo que cuenta el paciente (varias versiones).
## Los graves no pueden hablar: lo cuenta Lucía («relato»). «herramienta» revela el «hallazgo».
const CASOS := [
	{"diagnostico": "Herida superficial", "signos": "Corte en la palma de la mano, sangrado leve.",
	 "historias": [["Estaba picando cebolla y se me resbaló el cuchillo.", "Sangra un poquito, pero me asusté mucho."],
		["Me corté abriendo una lata de atún, doctor. ¡Qué vergüenza!"]],
	 "herramienta": "Linterna", "hallazgo": "Corte limpio y poco profundo, sin nada adentro.",
	 "falsos": ["Fractura", "Quemadura"], "insumo": "Vendaje", "deterioro": 0.25, "premio": 3, "inicial": 85.0, "grave": false},
	{"diagnostico": "Fiebre alta", "signos": "Cara roja, escalofríos y mucho cansancio.",
	 "historias": [["Desde anoche tengo escalofríos y me duele todo el cuerpo."],
		["Mi mamá dice que estoy ardiendo, pero yo tengo frío.", "¿Eso es normal, doctor?"]],
	 "herramienta": "Termómetro", "hallazgo": "Temperatura de 39,5 °C.",
	 "falsos": ["Reacción alérgica", "Esguince de tobillo"], "insumo": "Antipirético", "deterioro": 0.4, "premio": 3, "inicial": 80.0, "grave": false},
	{"diagnostico": "Esguince de tobillo", "signos": "Tobillo hinchado y morado.",
	 "historias": [["Estaba jugando fútbol, pisé mal y sonó un «crac».", "Ahora no puedo apoyar el pie."],
		["Me bajé mal del bus y se me dobló el tobillo."]],
	 "herramienta": "Palpar", "hallazgo": "Duele al tocar, pero el hueso está en su lugar.",
	 "falsos": ["Fractura expuesta", "Fiebre alta"], "insumo": "Férula", "deterioro": 0.25, "premio": 3, "inicial": 85.0, "grave": false},
	{"diagnostico": "Deshidratación", "signos": "Boca seca, ojos hundidos y mareo.",
	 "historias": [["Vomité toda la noche y hoy no aguanto ni el agua.", "Me mareo cada vez que me paro."]],
	 "herramienta": "Tensiómetro", "hallazgo": "Presión baja (90/60) y pulso rápido.",
	 "falsos": ["Herida superficial", "Reacción alérgica"], "insumo": "Suero oral", "deterioro": 0.5, "premio": 3, "inicial": 75.0, "grave": false},
	{"diagnostico": "Otitis", "signos": "Se toca el oído y tiene algo de fiebre.",
	 "historias": [["Me duele muchísimo el oído derecho desde ayer.", "Casi no pude dormir, doctor."],
		["Me metí a la piscina el fin de semana y ahora me duele el oído."]],
	 "herramienta": "Otoscopio", "hallazgo": "Tímpano rojo e inflamado.",
	 "falsos": ["Herida superficial", "Presión alta"], "insumo": "Gotas para el oído", "deterioro": 0.3, "premio": 3, "inicial": 85.0, "grave": false},
	{"diagnostico": "Crisis de asma", "signos": "Respira rápido y se le oye un silbido.",
	 "historias": [["Subí corriendo las escaleras y me empezó a silbar el pecho.", "Se me quedó el inhalador en la casa."]],
	 "herramienta": "Estetoscopio", "hallazgo": "Silbidos (sibilancias) en ambos pulmones.",
	 "falsos": ["Fiebre alta", "Deshidratación"], "insumo": "Inhalador", "deterioro": 0.6, "premio": 3, "inicial": 75.0, "grave": false},
	{"diagnostico": "Presión alta", "signos": "Cara roja y dolor de cabeza fuerte.",
	 "historias": [["Me duele la nuca y veo como lucecitas.", "Hoy se me olvidó la pastilla de la presión."]],
	 "herramienta": "Tensiómetro", "hallazgo": "Presión de 170/100.",
	 "falsos": ["Azúcar baja", "Otitis"], "insumo": "Medicamento para la presión", "deterioro": 0.4, "premio": 3, "inicial": 80.0, "grave": false},
	{"diagnostico": "Azúcar baja", "signos": "Sudor frío, temblor y algo de confusión.",
	 "historias": [["Soy diabético y no alcancé a desayunar.", "Estoy sudando y me tiemblan las manos."]],
	 "herramienta": "Glucómetro", "hallazgo": "Glucosa en 52 mg/dL: muy baja.",
	 "falsos": ["Presión alta", "Fiebre alta"], "insumo": "Glucosa oral", "deterioro": 0.6, "premio": 3, "inicial": 75.0, "grave": false},
	{"diagnostico": "Cuerpo extraño en el ojo", "signos": "Ojo rojo y lloroso; no lo puede abrir.",
	 "historias": [["Estaba lijando una mesa y me entró algo al ojo.", "¡No puedo dejar de llorar!"]],
	 "herramienta": "Linterna", "hallazgo": "Una astilla pequeña sobre el ojo derecho.",
	 "falsos": ["Otitis", "Reacción alérgica"], "insumo": "Lavado de ojos", "deterioro": 0.3, "premio": 3, "inicial": 85.0, "grave": false},
	{"diagnostico": "Reacción alérgica grave", "signos": "Ronchas, labios hinchados; casi no puede respirar.",
	 "historias": [], "relato": "Comió algo con maní hace diez minutos y se le está cerrando la garganta. ¡No puede hablar!",
	 "herramienta": "Estetoscopio", "hallazgo": "Silbidos fuertes: la vía aérea se está cerrando.",
	 "falsos": ["Crisis de asma", "Deshidratación"], "insumo": "Epinefrina", "deterioro": 1.0, "premio": 6, "inicial": 60.0, "grave": true},
	{"diagnostico": "Golpe de calor", "signos": "Piel muy caliente y seca; está desorientado.",
	 "historias": [], "relato": "Lo trajeron de una obra: estuvo horas bajo el sol y se desmayó. Apenas responde.",
	 "herramienta": "Termómetro", "hallazgo": "Temperatura de 41 °C.",
	 "falsos": ["Azúcar baja", "Otitis"], "insumo": "Suero intravenoso frío", "deterioro": 0.9, "premio": 6, "inicial": 60.0, "grave": true},
	{"diagnostico": "Migraña", "signos": "Dolor de cabeza fuerte de un solo lado; le molesta la luz.",
	 "historias": [["Me late la cabeza del lado derecho desde la mañana.", "Hasta la luz del celular me duele."],
		["Siempre que duermo poco me da este dolor de cabeza horrible."]],
	 "herramienta": "Linterna", "hallazgo": "Pupilas normales, pero la luz le molesta muchísimo.",
	 "falsos": ["Presión alta", "Otitis"], "insumo": "Analgésico", "deterioro": 0.3, "premio": 3, "inicial": 85.0, "grave": false},
	{"diagnostico": "Quemadura leve", "signos": "Mano roja y con ampollas pequeñas.",
	 "historias": [["Estaba fritando plátanos y me saltó el aceite.", "¡Arde muchísimo, doctor!"],
		["Agarré la olla sin trapo. No pregunte por qué."]],
	 "herramienta": "Linterna", "hallazgo": "Piel roja con ampollas pequeñas, sin zonas negras.",
	 "falsos": ["Herida superficial", "Reacción alérgica"], "insumo": "Crema para quemaduras", "deterioro": 0.3, "premio": 3, "inicial": 85.0, "grave": false},
	{"diagnostico": "Infección urinaria", "signos": "Ardor al orinar y ganas de ir al baño a cada rato.",
	 "historias": [["Me arde cuando voy al baño y voy cada diez minutos.", "Me da pena decirlo, doctor…"]],
	 "herramienta": "Palpar", "hallazgo": "Dolor al presionar la parte baja del abdomen.",
	 "falsos": ["Apendicitis", "Gastritis"], "insumo": "Antibiótico", "deterioro": 0.25, "premio": 3, "inicial": 85.0, "grave": false},
	{"diagnostico": "Gastritis", "signos": "Ardor en la boca del estómago después de comer.",
	 "historias": [["Comí bandeja paisa con mucho ají y ahora me arde el estómago.", "Y anoche también, y antier…"],
		["Tomo mucho café en el trabajo y me quema por dentro."]],
	 "herramienta": "Palpar", "hallazgo": "Duele al presionar arriba del ombligo.",
	 "falsos": ["Apendicitis", "Infección urinaria"], "insumo": "Antiácido", "deterioro": 0.2, "premio": 3, "inicial": 85.0, "grave": false},
	{"diagnostico": "Picadura de abeja", "signos": "Brazo hinchado y rojo en un punto.",
	 "historias": [["Estaba en el parque y me picó una abeja.", "No soy alérgico… creo."]],
	 "herramienta": "Linterna", "hallazgo": "El aguijón todavía está clavado en la piel.",
	 "falsos": ["Reacción alérgica grave", "Quemadura leve"], "insumo": "Retirar aguijón", "deterioro": 0.25, "premio": 3, "inicial": 85.0, "grave": false},
	{"diagnostico": "Faringitis", "signos": "Le duele la garganta al tragar y tiene fiebre.",
	 "historias": [["Me duele la garganta como si tragara vidrio.", "Mi hijo tuvo lo mismo la semana pasada."]],
	 "herramienta": "Linterna", "hallazgo": "Garganta roja con puntos blancos.",
	 "falsos": ["Otitis", "Fiebre alta"], "insumo": "Antibiótico", "deterioro": 0.3, "premio": 3, "inicial": 85.0, "grave": false},
	{"diagnostico": "Golpe en la cabeza", "signos": "Chichón en la frente; está mareado pero despierto.",
	 "historias": [["Me levanté rápido y me di contra un estante.", "Vi estrellitas, doctor, como en las caricaturas."]],
	 "herramienta": "Linterna", "hallazgo": "Pupilas iguales y reaccionan bien a la luz.",
	 "falsos": ["Migraña", "Presión alta"], "insumo": "Hielo y observación", "deterioro": 0.3, "premio": 3, "inicial": 80.0, "grave": false},
	{"diagnostico": "Infarto", "signos": "Dolor fuerte en el pecho que se va al brazo izquierdo; sudor frío.",
	 "historias": [], "relato": "Empezó a quejarse del pecho mientras jugaba dominó. Está muy pálido y sudando.",
	 "herramienta": "Tensiómetro", "hallazgo": "Presión baja y pulso irregular.",
	 "falsos": ["Crisis de asma", "Gastritis"], "insumo": "Aspirina y oxígeno", "deterioro": 1.1, "premio": 6, "inicial": 60.0, "grave": true},
]
## Casos que se suman al llegar a Residente, según la especialidad elegida.
const ESPECIALIDAD := {
	"Urgencias": {
		"insumos": ["Kit de sutura"],
		"casos": [
			{"diagnostico": "Fractura de brazo", "signos": "Brazo deformado; no lo puede mover.",
			 "historias": [["Me caí de la bicicleta y apoyé mal el brazo.", "¡Sonó horrible, doctor!"]],
			 "herramienta": "Palpar", "hallazgo": "El hueso se mueve donde no debe; dolor muy fuerte.",
			 "falsos": ["Esguince de tobillo", "Herida superficial"], "insumo": "Férula", "deterioro": 0.35, "premio": 4, "inicial": 80.0, "grave": false},
			{"diagnostico": "Corte profundo", "signos": "Herida en el antebrazo que no para de sangrar.",
			 "historias": [["Se rompió una ventana y me corté al cerrarla.", "Ya empapé tres toallas…"]],
			 "herramienta": "Linterna", "hallazgo": "Corte profundo, bordes abiertos: hay que cerrarlo.",
			 "falsos": ["Herida superficial", "Quemadura"], "insumo": "Kit de sutura", "deterioro": 0.6, "premio": 4, "inicial": 75.0, "grave": false},
		]},
	"Pediatría": {
		"insumos": ["Nebulización", "Loción calmante"],
		"casos": [
			{"diagnostico": "Bronquiolitis", "signos": "Bebé que respira rápido y tose mucho.",
			 "historias": [["(La mamá) Mi bebé respira rapidito y no quiere comer.", "Tiene tos desde hace tres días."]],
			 "herramienta": "Estetoscopio", "hallazgo": "Silbidos y ruiditos suaves en los dos pulmones.",
			 "falsos": ["Crisis de asma", "Fiebre alta"], "insumo": "Nebulización", "deterioro": 0.5, "premio": 4, "inicial": 75.0, "grave": false},
			{"diagnostico": "Varicela", "signos": "Niño con granitos que pican por todo el cuerpo.",
			 "historias": [["(El papá) Le salieron granitos por todos lados y no deja de rascarse.", "En su colegio hay otros niños igual."]],
			 "herramienta": "Linterna", "hallazgo": "Ampollitas pequeñas en distintas etapas.",
			 "falsos": ["Reacción alérgica", "Fiebre alta"], "insumo": "Loción calmante", "deterioro": 0.2, "premio": 4, "inicial": 85.0, "grave": false},
		]},
	"Cirugía": {
		"insumos": ["Remitir a cirugía"],
		"casos": [
			{"diagnostico": "Apendicitis", "signos": "Dolor de barriga abajo a la derecha, con fiebre.",
			 "historias": [["Me duele la barriga desde anoche; empezó en el ombligo.", "Ahora me duele aquí abajo, a la derecha."]],
			 "herramienta": "Palpar", "hallazgo": "Dolor fuerte al soltar la presión del lado derecho.",
			 "falsos": ["Deshidratación", "Fiebre alta"], "insumo": "Remitir a cirugía", "deterioro": 0.5, "premio": 4, "inicial": 75.0, "grave": false},
			{"diagnostico": "Hernia", "signos": "Bulto en la ingle que molesta al hacer fuerza.",
			 "historias": [["Levanté un bulto de cemento y me salió esto en la ingle.", "Cuando toso se hace más grande."]],
			 "herramienta": "Palpar", "hallazgo": "Bulto blando que aumenta al toser.",
			 "falsos": ["Esguince de tobillo", "Herida superficial"], "insumo": "Remitir a cirugía", "deterioro": 0.25, "premio": 4, "inicial": 85.0, "grave": false},
		]},
}


## Insumos del botiquín normal (incluye los de la especialidad de Walter).
static func insumos_botiquin() -> Array:
	var l: Array = INSUMOS_A.duplicate()
	if ESPECIALIDAD.has(Juego.especialidad):
		for x in ESPECIALIDAD[Juego.especialidad]["insumos"]:
			if not l.has(x):
				l.append(x)
	return l


## Casos que pueden llegar hoy (los leves base + los de la especialidad).
static func casos_leves() -> Array:
	var l: Array = CASOS.filter(func(c): return not c["grave"])
	if ESPECIALIDAD.has(Juego.especialidad):
		l = l + ESPECIALIDAD[Juego.especialidad]["casos"]
		l = l + ESPECIALIDAD[Juego.especialidad]["casos"]    # más probables
	return l
