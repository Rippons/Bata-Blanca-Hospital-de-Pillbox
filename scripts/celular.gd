class_name Celular
extends Control
## Celular de Walter en pantalla, con apps: Mensajes, Tienda, Banco, Transporte, Agenda y Clima.
## El tiempo del juego SIGUE corriendo mientras se usa; Walter se queda quieto.
## Controles: flechas/WASD para moverse, E/Espacio/Enter para abrir, C/Esc para volver o guardarlo.

signal cerrado

const ANCHO := 128.0
const ALTO := 214.0
const X := 340.0
const Y := 30.0
const APPS := [
	["mensajes", "Chats", Color("34c759")],
	["tienda", "Tienda", Color("ff9500")],
	["banco", "Banco", Color("007aff")],
	["transporte", "Viajes", Color("af52de")],
	["agenda", "Agenda", Color("ff3b30")],
	["clima", "Clima", Color("5ac8fa")],
]

var sala               # la sala actual (para bloquear a Walter y mostrar avisos)
var abierto := false
var pantalla := "inicio"
var _chat := -1                       # mensaje abierto en el chat
var _aviso := ""                      # texto de confirmación en la tienda o el transporte
var _marco: Panel
var _pantalla_fondo: ColorRect
var _lbl_hora: Label
var _lbl_titulo: Label
var _contenido: VBoxContainer
var _scroll: ScrollContainer
var _refresco := 0.0


func _ready() -> void:
	visible = false
	theme = Juego.tema
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(X, Y)
	size = Vector2(ANCHO, ALTO)
	_marco = Panel.new()
	_marco.size = size
	_marco.add_theme_stylebox_override("panel", _caja(Color("16181d"), Color("3a3f4a"), 2, 14))
	add_child(_marco)
	_pantalla_fondo = ColorRect.new()
	_pantalla_fondo.position = Vector2(6, 14)
	_pantalla_fondo.size = Vector2(ANCHO - 12, ALTO - 34)
	_pantalla_fondo.color = Color("f2f4f8")
	add_child(_pantalla_fondo)
	var camara := ColorRect.new()          # «notch» con la cámara
	camara.color = Color("16181d")
	camara.position = Vector2(ANCHO / 2.0 - 14, 4)
	camara.size = Vector2(28, 6)
	add_child(camara)
	# Barra de estado: hora en vivo, día y batería
	_lbl_hora = _label("", 6, Color("1c1c1e"))
	_lbl_hora.position = Vector2(10, 15)
	_lbl_hora.size = Vector2(ANCHO - 20, 9)
	add_child(_lbl_hora)
	_lbl_titulo = _label("", 9, Color("1c1c1e"))
	_lbl_titulo.position = Vector2(8, 24)
	_lbl_titulo.size = Vector2(ANCHO - 16, 13)
	_lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_lbl_titulo)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(8, 38)
	_scroll.size = Vector2(ANCHO - 16, ALTO - 60)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_contenido = VBoxContainer.new()
	_contenido.custom_minimum_size = Vector2(ANCHO - 18, 0)
	_contenido.add_theme_constant_override("separation", 3)
	_scroll.add_child(_contenido)
	# Botones de abajo: atrás e inicio
	var atras := _boton_barra("◀", Vector2(14, ALTO - 19), _atras)
	atras.tooltip_text = "Atrás (C / Esc)"
	_boton_barra("●", Vector2(ANCHO / 2.0 - 9, ALTO - 19), func(): _ir("inicio"))
	_boton_barra("✕", Vector2(ANCHO - 32, ALTO - 19), cerrar)


func abrir() -> void:
	if abierto:
		return
	abierto = true
	visible = true
	if sala and sala.walter:
		sala.walter.bloqueado = true
	Juego.sonido("seleccion", 1.6, -12.0)
	position = Vector2(X, 270)
	var tw := create_tween()
	tw.tween_property(self, "position:y", Y, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_ir("inicio")


func cerrar() -> void:
	if not abierto:
		return
	abierto = false
	Juego.sonido("blip", 0.8, -12.0)
	var tw := create_tween()
	tw.tween_property(self, "position:y", 270.0, 0.15)
	tw.tween_callback(func(): visible = false)
	if sala and sala.walter:
		sala.walter.bloqueado = false
	cerrado.emit()


func _process(delta: float) -> void:
	if not abierto:
		return
	# La hora corre mientras usas el celular
	_lbl_hora.text = "%s   Día %d · %s          ▮▮▮" % [Juego.hora_texto(), Juego.dia, Juego.nombre_dia().substr(0, 3)]
	_refresco -= delta
	if _refresco <= 0.0:
		_refresco = 0.5
		if pantalla in ["banco", "agenda", "inicio"]:
			_actualizar_dinamico()


# --- Entrada (teclado y ratón) ------------------------------------------------------
func _input(event: InputEvent) -> void:
	if not abierto or not event.is_pressed() or event.is_echo():
		return
	var manejado := true
	if event.is_action_pressed("celular") or event.is_action_pressed("ui_cancel"):
		_atras()
	elif event.is_action_pressed("interactuar") or event.is_action_pressed("ui_accept"):
		var f := get_viewport().gui_get_focus_owner()
		if f is Button and is_ancestor_of(f) and not f.disabled:
			f.pressed.emit()
	elif event.is_action_pressed("arriba"):
		_mover_foco(SIDE_TOP)
	elif event.is_action_pressed("abajo"):
		_mover_foco(SIDE_BOTTOM)
	elif event.is_action_pressed("izquierda"):
		_mover_foco(SIDE_LEFT)
	elif event.is_action_pressed("derecha"):
		_mover_foco(SIDE_RIGHT)
	else:
		manejado = false
	if manejado:
		get_viewport().set_input_as_handled()


func _mover_foco(lado: Side) -> void:
	var f := get_viewport().gui_get_focus_owner()
	if f == null or not is_ancestor_of(f):
		_enfocar_primero()
		return
	var n := f.find_valid_focus_neighbor(lado)
	if n and is_ancestor_of(n):
		n.grab_focus()
		_scroll.ensure_control_visible(n)
		Juego.sonido("blip", 1.5, -18.0)


func _enfocar_primero() -> void:
	for c in _botones(_contenido):
		if not c.disabled:
			c.grab_focus()
			return


func _botones(nodo: Node) -> Array:
	var r: Array = []
	for c in nodo.get_children():
		if c is Button:
			r.append(c)
		r += _botones(c)
	return r


func _atras() -> void:
	match pantalla:
		"inicio": cerrar()
		"chat": _ir("mensajes")
		_: _ir("inicio")


# --- Pantallas ------------------------------------------------------------------
func _ir(p: String, conservar_aviso := false) -> void:
	pantalla = p
	if not conservar_aviso:
		_aviso = ""
	for c in _contenido.get_children():
		c.queue_free()
	_scroll.scroll_vertical = 0
	match p:
		"inicio": _inicio()
		"mensajes": _mensajes()
		"chat": _ver_chat()
		"tienda": _tienda()
		"banco": _banco()
		"transporte": _transporte()
		"agenda": _agenda()
		"clima": _clima()
	await get_tree().process_frame
	_enfocar_primero()


func _inicio() -> void:
	_lbl_titulo.text = "Pillbox OS"
	var fondo_txt := _label("Hola, Dr. Pinkman", 7, Color("6b7280"))
	fondo_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contenido.add_child(fondo_txt)
	var rejilla := GridContainer.new()
	rejilla.columns = 3
	rejilla.add_theme_constant_override("h_separation", 6)
	rejilla.add_theme_constant_override("v_separation", 6)
	_contenido.add_child(rejilla)
	for app in APPS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(32, 38)
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_stylebox_override("normal", _caja(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6))
		b.add_theme_stylebox_override("hover", _caja(Color(0, 0, 0, 0.06), Color(0, 0, 0, 0), 0, 6))
		b.add_theme_stylebox_override("focus", _caja(Color(0, 0, 0, 0.08), Color("007aff"), 1, 6))
		b.add_theme_stylebox_override("pressed", _caja(Color(0, 0, 0, 0.12), Color(0, 0, 0, 0), 0, 6))
		var icono := IconoApp.new()
		icono.tipo = app[0]
		icono.color = app[2]
		icono.position = Vector2(5, 1)
		icono.size = Vector2(22, 22)
		icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icono)
		var nombre := _label(app[1], 5, Color("1c1c1e"))
		nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nombre.position = Vector2(-4, 25)
		nombre.size = Vector2(40, 9)
		nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(nombre)
		if app[0] == "mensajes" and Juego.mensajes_nuevos() > 0:
			var globo := _label(str(Juego.mensajes_nuevos()), 6, Color.WHITE)
			globo.add_theme_stylebox_override("normal", _caja(Color("ff3b30"), Color(0, 0, 0, 0), 0, 5))
			globo.position = Vector2(22, -2)
			globo.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(globo)
		b.pressed.connect(func(): _ir(app[0]))
		rejilla.add_child(b)
	var resumen := _label("", 6, Color("374151"))
	resumen.name = "Resumen"
	resumen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_contenido.add_child(resumen)
	_actualizar_dinamico()


func _mensajes() -> void:
	_lbl_titulo.text = "Mensajes"
	if Juego.mensajes.is_empty():
		_contenido.add_child(_texto("No tienes mensajes."))
		return
	for i in mini(Juego.mensajes.size(), 12):
		var m: Dictionary = Juego.mensajes[i]
		var t: String = m["texto"]
		var b := _boton_fila(("● " if not m["leido"] else "") + str(m["de"]), t.substr(0, 34) + ("…" if t.length() > 34 else ""))
		b.pressed.connect(func():
			_chat = i
			_ir("chat"))
		_contenido.add_child(b)


func _ver_chat() -> void:
	if _chat < 0 or _chat >= Juego.mensajes.size():
		_ir("mensajes")
		return
	var m: Dictionary = Juego.mensajes[_chat]
	m["leido"] = true
	_lbl_titulo.text = str(m["de"])
	_contenido.add_child(_burbuja(str(m["texto"]), false))
	if m.get("respuesta_texto", "") != "":
		_contenido.add_child(_burbuja(str(m["respuesta_texto"]), true))
	if m.get("resultado", "") != "":
		_contenido.add_child(_burbuja(str(m["resultado"]), false))
	if not m["opciones"].is_empty() and not m["respondido"]:
		_contenido.add_child(_texto("Responder:"))
		for o in m["opciones"]:
			var b := _boton_fila(str(o["texto"]), "")
			b.pressed.connect(func():
				m["respondido"] = true
				m["respuesta_texto"] = str(o["texto"])
				m["resultado"] = Juego.efecto_mensaje(str(o["efecto"]))
				Juego.sonido("blip", 1.3, -10.0)
				_ir("chat"))
			_contenido.add_child(b)


func _tienda() -> void:
	_lbl_titulo.text = "Tienda"
	_contenido.add_child(_texto("Saldo: $%d" % Juego.dinero))
	if _aviso != "":
		_contenido.add_child(_burbuja(_aviso, false))
	for a in Juego.articulos_tienda():
		var b := _boton_fila("%s · $%d" % [a[1], a[2]], str(a[3]))
		b.disabled = Juego.dinero < int(a[2])
		b.pressed.connect(func():
			_aviso = Juego.comprar(a[0])
			if sala:
				sala.hud.mostrar(_aviso, 3.0)
			_ir("tienda", true))
		_contenido.add_child(b)


func _banco() -> void:
	_lbl_titulo.text = "Banco de Pillbox"
	var saldo := _label("", 14, Color("1c1c1e") if Juego.dinero >= 0 else Color("ff3b30"))
	saldo.name = "Saldo"
	saldo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contenido.add_child(saldo)
	var info := _label("", 6, Color("374151"))
	info.name = "Info"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_contenido.add_child(info)
	_actualizar_dinamico()


func _transporte() -> void:
	_lbl_titulo.text = "Transporte"
	if _aviso != "":
		_contenido.add_child(_burbuja(_aviso, false))
	var t := "Caminando: %d min al hospital." % Juego.MINUTOS_VIAJE
	if Juego.bicicleta:
		t += "\nBicicleta: 12 min (cansa un poco)." + ("\n¡Llanta pinchada! No se puede usar." if Juego.llanta_pinchada else "")
	else:
		t += "\nBicicleta: no tienes ($%d en la Tienda)." % Juego.PRECIO_BICI
	if Juego.auto:
		t += "\nAuto: 8 min, $%d de gasolina. Ojo con los trancones." % Juego.GASOLINA
	else:
		t += "\nAuto: no tienes ($%d en la Tienda)." % Juego.PRECIO_AUTO
	if Juego.medio_hoy != "":
		t += "\n\nHoy llegaste: %s." % {"pie": "caminando", "bici": "en bicicleta", "auto": "en auto"}[Juego.medio_hoy]
	_contenido.add_child(_texto(t))
	if Juego.bicicleta and Juego.llanta_pinchada:
		var b := _boton_fila("Reparar llanta · $%d" % Juego.REPARAR_LLANTA, "El taller la deja lista ya")
		b.disabled = Juego.dinero < Juego.REPARAR_LLANTA
		b.pressed.connect(func():
			_aviso = Juego.comprar("llanta")
			_ir("transporte", true))
		_contenido.add_child(b)
	_contenido.add_child(_texto("Elige cómo ir en el portón de tu casa."))


func _agenda() -> void:
	_lbl_titulo.text = "Agenda"
	var info := _label("", 6, Color("374151"))
	info.name = "Info"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_contenido.add_child(info)
	_actualizar_dinamico()


func _clima() -> void:
	_lbl_titulo.text = "Clima"
	var c: Array = Juego.clima_de_hoy()
	var temp := _label(c[0], 18, Color("1c1c1e"))
	temp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contenido.add_child(temp)
	var estado := _label("Pillbox · " + c[1], 7, Color("374151"))
	estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contenido.add_child(estado)
	_contenido.add_child(_texto(c[2]))


## Textos que cambian con el tiempo (la hora sigue corriendo).
func _actualizar_dinamico() -> void:
	match pantalla:
		"inicio":
			var r = _contenido.find_child("Resumen", true, false)
			if r:
				r.text = "Saldo $%d · Nevera %d\n%s" % [Juego.dinero, Juego.comida, _proximo_evento()]
		"banco":
			var s = _contenido.find_child("Saldo", true, false)
			var i = _contenido.find_child("Info", true, false)
			if s:
				s.text = "$%d" % Juego.dinero
			if i:
				var t := "Sueldo: $%d por turno (%s). Se paga los viernes.\nTurnos esta semana: %d (≈ $%d el viernes).\nArriendo: $%d cada lunes." % [
					Juego.pago_por_turno(), Juego.rango, int(Juego.semana["turnos"]), int(Juego.semana["turnos"]) * Juego.pago_por_turno(), Juego.ARRIENDO]
				if Juego.auto:
					t += "\nGasolina: $%d por viaje." % Juego.GASOLINA
				if Juego.dinero < 0:
					t += "\n¡Estás en rojo! Don Rigoberto va a llamar."
				i.text = t
		"agenda":
			var a = _contenido.find_child("Info", true, false)
			if a:
				var t := "%s, día %d · %s\nTurno: 7:30 AM a 7:30 PM\n%s\n\n%s · Reputación %d" % [
					Juego.nombre_dia(), Juego.dia, Juego.hora_texto(), _proximo_evento(), Juego.rango, Juego.reputacion]
				if Juego.rango == "Interno":
					t += "\nPara ser Residente:"
					for req in Juego.requisitos_residente():
						t += "\n%s %s" % ["✔" if req[1] else "·", req[0]]
				a.text = t


func _proximo_evento() -> String:
	if Juego.es_fin_de_semana():
		return "Hoy es día libre."
	if Juego.es_manana():
		var falta := Juego.INICIO_TURNO - Juego.minutos
		return "El turno empieza en %d min." % int(falta) if falta > 0 else "¡Vas tarde al turno!"
	return "Turno terminado. A descansar."


# --- Piezas de la interfaz ------------------------------------------------------
func _label(t: String, tam: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	return l


func _texto(t: String) -> Label:
	var l := _label(t, 6, Color("374151"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(ANCHO - 20, 0)
	return l


func _burbuja(t: String, mio: bool) -> PanelContainer:
	var p := PanelContainer.new()
	var c := _caja(Color("007aff") if mio else Color("e5e7eb"), Color(0, 0, 0, 0), 0, 6)
	c.content_margin_left = 4
	c.content_margin_right = 4
	c.content_margin_top = 2
	c.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", c)
	var l := _label(t, 6, Color.WHITE if mio else Color("1c1c1e"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(ANCHO - 34, 0)
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_END if mio else Control.SIZE_SHRINK_BEGIN
	return p


func _boton_fila(titulo: String, sub: String) -> Button:
	var b := Button.new()
	b.text = titulo + ("\n" + sub if sub != "" else "")
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(ANCHO - 20, 0)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 6)
	b.add_theme_color_override("font_color", Color("1c1c1e"))
	b.add_theme_color_override("font_hover_color", Color("1c1c1e"))
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.45, 0.7))
	var n := _caja(Color.WHITE, Color("d1d5db"), 1, 4)
	n.content_margin_left = 4
	n.content_margin_top = 2
	n.content_margin_bottom = 2
	var f := n.duplicate()
	f.bg_color = Color("007aff")
	f.border_color = Color("005ecb")
	var d := n.duplicate()
	d.bg_color = Color("eceef2")
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", n)
	b.add_theme_stylebox_override("focus", f)
	b.add_theme_stylebox_override("pressed", f)
	b.add_theme_stylebox_override("disabled", d)
	b.mouse_entered.connect(func(): b.grab_focus())
	return b


func _boton_barra(t: String, pos: Vector2, accion: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.position = pos
	b.size = Vector2(18, 14)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 7)
	b.add_theme_color_override("font_color", Color("d1d5db"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	var vacio := _caja(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4)
	b.add_theme_stylebox_override("normal", vacio)
	b.add_theme_stylebox_override("hover", _caja(Color(1, 1, 1, 0.1), Color(0, 0, 0, 0), 0, 4))
	b.add_theme_stylebox_override("pressed", vacio)
	b.pressed.connect(accion)
	add_child(b)
	return b


func _caja(fondo: Color, borde: Color, grosor: int, radio: int) -> StyleBoxFlat:
	var c := StyleBoxFlat.new()
	c.bg_color = fondo
	c.border_color = borde
	c.set_border_width_all(grosor)
	c.set_corner_radius_all(radio)
	return c


## Íconos de las apps, dibujados con formas simples.
class IconoApp extends Control:
	var tipo := ""
	var color := Color.WHITE
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(_fondo(), r)
		var c := size / 2.0
		var b := Color.WHITE
		match tipo:
			"mensajes":
				draw_rect(Rect2(c + Vector2(-7, -5), Vector2(14, 9)), b)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-3, 4), c + Vector2(-5, 8), c + Vector2(1, 4)]), b)
				for k in 3:
					draw_circle(c + Vector2(-4 + k * 4, -0.5), 1.0, color)
			"tienda":
				draw_rect(Rect2(c + Vector2(-6, -3), Vector2(12, 8)), b)
				draw_arc(c + Vector2(0, -3), 3.5, PI, TAU, 8, b, 1.2)
			"banco":
				draw_circle(c, 7.0, b)
				var l := "$"
				draw_string(ThemeDB.fallback_font, c + Vector2(-2.5, 3.5), l, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
			"transporte":
				draw_arc(c + Vector2(-4, 3), 3.5, 0, TAU, 12, b, 1.4)
				draw_arc(c + Vector2(4, 3), 3.5, 0, TAU, 12, b, 1.4)
				draw_line(c + Vector2(-4, 3), c + Vector2(0, -3), b, 1.4)
				draw_line(c + Vector2(0, -3), c + Vector2(4, 3), b, 1.4)
				draw_line(c + Vector2(-1, -3), c + Vector2(3, -3), b, 1.4)
			"agenda":
				draw_rect(Rect2(c + Vector2(-6, -5), Vector2(12, 11)), b)
				draw_rect(Rect2(c + Vector2(-6, -5), Vector2(12, 3)), Color(0, 0, 0, 0.25))
				draw_string(ThemeDB.fallback_font, c + Vector2(-3, 5), str(Juego.dia % 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, color)
			"clima":
				draw_circle(c + Vector2(-2, -2), 4.0, Color("ffd60a"))
				draw_circle(c + Vector2(2, 3), 3.5, b)
				draw_circle(c + Vector2(-2, 3), 3.0, b)
				draw_rect(Rect2(c + Vector2(-5, 3), Vector2(10, 3)), b)
	func _fondo() -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = color
		s.set_corner_radius_all(6)
		return s
