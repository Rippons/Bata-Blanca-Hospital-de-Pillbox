class_name Minijuego
extends CanvasLayer
## Minijuegos clínicos que aparecen sobre la pantalla mientras el reloj se detiene.
##   sutura · cerrar una herida: pulsa E cuando la aguja cruza la línea de la herida (5 puntos)
##   rcp    · reanimación: pulsa E cuando el anillo coincide con el pecho, al ritmo (12 compresiones)
##   pulso  · tomar el pulso: cuenta los latidos durante 6 segundos y elige cuántos fueron
## Se juegan con E, Espacio o clic. En las pruebas automáticas se juegan solos.

signal terminado(valor: float)

static var activo := ""          # minijuego en pantalla (las pruebas toman la captura aquí)

const ANCHO := 300.0
const ALTO := 170.0
const CAJA := Rect2((480.0 - ANCHO) / 2.0, 46.0, ANCHO, ALTO)

var tipo := ""
var paciente := ""
var _lienzo: Control
var _titulo: Label
var _texto: Label
var _t := 0.0
var _listo := false
# sutura
var _punto := 0
var _aciertos: Array = []
var _aguja := 0.0
var _vel_aguja := 1.6
# rcp
const RCP_PERIODO := 0.545       # 110 compresiones por minuto
const RCP_TOTAL := 12
var _comp := 0
var _buenas := 0
var _ultimo_golpe := -10.0
var _marca := ""
var _marca_t := 0.0
# pulso
var _latidos := 0
var _latidos_dados := 0
var _periodo_pulso := 0.7
var _destello := 0.0


## Juega uno y devuelve la calidad: 0.0 (mal) … 1.0 (perfecto). Para «pulso», 1.0 si acertó.
static func jugar(padre: Node, tipo_: String, paciente_: String) -> float:
	var m := Minijuego.new()
	m.tipo = tipo_
	m.paciente = paciente_
	var estaba := Juego.pausado
	Juego.pausado = true
	padre.add_child(m)
	activo = tipo_
	var valor: float = await m.terminado
	activo = ""
	m.queue_free()
	Juego.pausado = estaba
	if tipo_ == "pulso" and valor >= 0.0:
		valor = await _preguntar_pulso(padre, m._latidos, valor)
	return valor


## Después de contar, Walter dice cuántos latidos fueron.
static func _preguntar_pulso(padre: Node, latidos: int, auto: float) -> float:
	if Juego.auto_dialogo:
		return auto
	var opciones: Array = [latidos, latidos - 2, latidos + 2, latidos + 4]
	opciones.shuffle()
	var textos: Array = opciones.map(func(n): return "%d latidos (%d por minuto)" % [n, n * 10])
	var r: int = await padre.hud.elegir("Tomar el pulso", "¿Cuántos latidos contaste en 6 segundos?", textos)
	return 1.0 if r >= 0 and opciones[r] == latidos else 0.0


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.55)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	_lienzo = Control.new()
	_lienzo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lienzo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lienzo.draw.connect(_dibujar)
	add_child(_lienzo)
	_titulo = _etiqueta(Vector2(CAJA.position.x, CAJA.position.y + 4), 10, Color("ffd166"))
	_texto = _etiqueta(Vector2(CAJA.position.x, CAJA.end.y - 22), 8, Color.WHITE)
	match tipo:
		"sutura":
			_titulo.text = "Suturar a %s" % paciente
			_texto.text = "Pulsa E cuando la aguja cruce la herida (5 puntos)"
			_aciertos = []
		"rcp":
			_titulo.text = "¡%s entró en paro! RCP" % paciente
			_texto.text = "Pulsa E cuando el anillo llegue al pecho: al ritmo, 12 veces"
		"pulso":
			_titulo.text = "Tomar el pulso a %s" % paciente
			_texto.text = "Cuenta los latidos durante 6 segundos…"
			_periodo_pulso = 60.0 / randi_range(66, 118)
			_latidos = int(floor(6.0 / _periodo_pulso))
	await get_tree().create_timer(0.4).timeout
	_listo = true
	if Juego.auto_dialogo:
		_jugar_solo()


func _etiqueta(pos: Vector2, tam: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(ANCHO, 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	add_child(l)
	return l


## Pruebas: se juega solo durante un momento y devuelve lo que pida la prueba («mini:0.3»).
func _jugar_solo() -> void:
	var valor := 1.0
	if not Juego.respuestas_auto.is_empty() and str(Juego.respuestas_auto[0]).begins_with("mini:"):
		valor = float(str(Juego.respuestas_auto.pop_front()).substr(5))
	for k in 5:
		_golpe_auto(valor)
		await get_tree().create_timer(0.22).timeout
	print("[auto] minijuego %s -> %.1f" % [tipo, valor])
	terminado.emit(valor)


func _golpe_auto(valor: float) -> void:
	match tipo:
		"sutura":
			if _aciertos.size() < 5:
				_aciertos.append(randf() < valor)
		"rcp":
			_comp += 1
			_buenas += 1 if randf() < valor else 0
			_marca = "¡Bien!"
			_marca_t = 0.3
		"pulso":
			_destello = 1.0
	_lienzo.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_marca_t -= delta
	_destello = maxf(_destello - delta * 4.0, 0.0)
	if not _listo or Juego.auto_dialogo:
		_lienzo.queue_redraw()
		return
	match tipo:
		"sutura":
			_aguja += delta * _vel_aguja
		"pulso":
			var n := int(floor(_t / _periodo_pulso))
			if n > _latidos_dados and _latidos_dados < _latidos:
				_latidos_dados = n
				_destello = 1.0
				Juego.sonido("latido", 1.0, -4.0)
			if _t >= 6.0:
				_listo = false
				terminado.emit(1.0)
	_lienzo.queue_redraw()


func _input(event: InputEvent) -> void:
	if not _listo or Juego.auto_dialogo:
		return
	var pulso: bool = event.is_action_pressed("interactuar") or event.is_action_pressed("ui_accept") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not pulso:
		return
	get_viewport().set_input_as_handled()
	match tipo:
		"sutura":
			_puntada()
		"rcp":
			_compresion()


# --- Sutura ---------------------------------------------------------------------------
func _herida_y(x: float) -> float:
	# la herida es una línea un poco inclinada en el centro de la caja
	return CAJA.position.y + 82.0 + (x - CAJA.get_center().x) * 0.18


func _x_punto(i: int) -> float:
	return CAJA.position.x + 70.0 + i * 40.0


func _y_aguja() -> float:
	return CAJA.position.y + 82.0 + sin(_aguja) * 34.0


func _puntada() -> void:
	var x := _x_punto(_punto)
	var bien := absf(_y_aguja() - _herida_y(x)) <= 6.0
	_aciertos.append(bien)
	Juego.sonido("aguja" if bien else "error", 1.0 if bien else 1.4, -6.0 if bien else -12.0)
	_punto += 1
	_vel_aguja += 0.45
	_aguja = randf() * TAU
	if _punto >= 5:
		_listo = false
		await get_tree().create_timer(0.6).timeout
		terminado.emit(_aciertos.count(true) / 5.0)


# --- RCP ---------------------------------------------------------------------------------
func _fase_rcp() -> float:
	return fmod(_t, RCP_PERIODO) / RCP_PERIODO      # 0 → el anillo empieza grande; 1 → toca el pecho


func _compresion() -> void:
	var fase := _fase_rcp()
	var error_s := minf(fase, 1.0 - fase) * RCP_PERIODO     # distancia al momento justo
	_comp += 1
	_ultimo_golpe = _t
	if error_s <= 0.12:
		_buenas += 1
		_marca = "¡Bien!"
		Juego.sonido("latido", 1.3, -4.0)
	else:
		_marca = "Fuera de ritmo"
		Juego.sonido("blip", 0.6, -10.0)
	_marca_t = 0.4
	if _comp >= RCP_TOTAL:
		_listo = false
		await get_tree().create_timer(0.5).timeout
		terminado.emit(float(_buenas) / RCP_TOTAL)


# --- Dibujo ------------------------------------------------------------------------------
func _dibujar() -> void:
	var c := _lienzo
	c.draw_rect(CAJA, Color(0.08, 0.1, 0.14, 0.96))
	c.draw_rect(CAJA, Color("9fc4e8"), false, 1.0)
	match tipo:
		"sutura":
			_dibujar_sutura(c)
		"rcp":
			_dibujar_rcp(c)
		"pulso":
			_dibujar_pulso(c)


func _dibujar_sutura(c: Control) -> void:
	var piel := Rect2(CAJA.position + Vector2(30, 36), Vector2(ANCHO - 60, 92))
	c.draw_rect(piel, Color("e0a982"))
	var x0 := piel.position.x + 16
	var x1 := piel.end.x - 16
	c.draw_line(Vector2(x0, _herida_y(x0)), Vector2(x1, _herida_y(x1)), Color("8b1a1a"), 3.0)
	c.draw_line(Vector2(x0, _herida_y(x0) + 1), Vector2(x1, _herida_y(x1) + 1), Color("c62828"), 1.0)
	for i in 5:
		var x := _x_punto(i)
		var y := _herida_y(x)
		if i < _aciertos.size():
			var col := Color("2e7d32") if _aciertos[i] else Color("e53935")
			c.draw_line(Vector2(x - 5, y - 6), Vector2(x + 5, y + 6), col, 2.0)
			c.draw_line(Vector2(x + 5, y - 6), Vector2(x - 5, y + 6), col, 2.0)
		else:
			c.draw_circle(Vector2(x, y), 2.0, Color(1, 1, 1, 0.5))
	if _punto < 5 and not Juego.auto_dialogo:
		var xa := _x_punto(_punto)
		var ya := _y_aguja()
		c.draw_rect(Rect2(xa - 9, _herida_y(xa) - 6, 18, 12), Color(0.3, 1.0, 0.4, 0.18))
		c.draw_line(Vector2(xa, ya - 9), Vector2(xa, ya + 5), Color("eceff1"), 2.0)
		c.draw_arc(Vector2(xa + 3, ya + 5), 3.0, 0.0, PI, 6, Color("eceff1"), 1.5)
		c.draw_line(Vector2(xa, ya - 9), Vector2(xa - 14, ya - 20), Color("4fc3f7"), 1.0)
	_texto_abajo(c, "Puntos: %d / 5" % _aciertos.count(true))


func _dibujar_rcp(c: Control) -> void:
	var centro := CAJA.get_center() + Vector2(0, -4)
	# pecho
	c.draw_rect(Rect2(centro - Vector2(46, 30), Vector2(92, 60)), Color("e0a982"))
	c.draw_line(centro + Vector2(0, -26), centro + Vector2(0, 26), Color("c08a66"), 1.0)
	c.draw_circle(centro, 10.0, Color("ef5350"))
	c.draw_circle(centro, 10.0, Color.WHITE, false, 1.5)
	# anillo que se encoge al ritmo
	if not Juego.auto_dialogo:
		var r := lerpf(42.0, 10.0, _fase_rcp())
		c.draw_arc(centro, r, 0.0, TAU, 40, Color("ffd166"), 2.0)
	# monitor
	var base := CAJA.position + Vector2(24, 40)
	for k in 30:
		var x := base.x + k * 2.0
		var y := base.y + (-8.0 if (k + int(_t * 20.0)) % 15 == 0 else 0.0)
		c.draw_line(Vector2(x, base.y), Vector2(x, y), Color("66bb6a"), 1.0)
	if _marca_t > 0.0:
		c.draw_string(ThemeDB.fallback_font, centro + Vector2(54, 4), _marca, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			Color("66bb6a") if _marca == "¡Bien!" else Color("ef5350"))
	_texto_abajo(c, "Compresiones: %d / %d   ·   A ritmo: %d" % [_comp, RCP_TOTAL, _buenas])


func _dibujar_pulso(c: Control) -> void:
	var centro := CAJA.get_center() + Vector2(0, -6)
	# muñeca y dedos de Walter
	c.draw_rect(Rect2(centro - Vector2(90, 16), Vector2(180, 32)), Color("c68b62"))
	for k in 2:
		c.draw_rect(Rect2(centro + Vector2(-10 + k * 12, -24), Vector2(9, 20)), Color("f1c9a5"))
	var r := 4.0 + _destello * 7.0
	c.draw_circle(centro + Vector2(-2, 10), r, Color(1, 0.3, 0.3, 0.35 + _destello * 0.6))
	var queda := maxf(6.0 - _t, 0.0)
	c.draw_rect(Rect2(CAJA.position + Vector2(40, 132), Vector2((ANCHO - 80) * queda / 6.0, 4)), Color("4fc3f7"))
	_texto_abajo(c, "Tiempo: %.1f s" % queda)


func _texto_abajo(c: Control, t: String) -> void:
	c.draw_string(ThemeDB.fallback_font, Vector2(CAJA.position.x, CAJA.position.y + 26), t, HORIZONTAL_ALIGNMENT_CENTER, ANCHO, 8, Color("9fb3c8"))
