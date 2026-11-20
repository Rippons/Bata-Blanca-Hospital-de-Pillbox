extends Control
## Pantalla de título: el frente del Hospital de Pillbox con tráfico, Walter en la entrada y el menú.

var _walter: Personaje
var _t := 0.0
var _titulo: Label


func _ready() -> void:
	Juego.pausado = true
	Juego.musica("hospital")
	theme = Juego.tema
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Escena de fondo
	var ext := Exterior.new()
	ext.trafico = true
	add_child(ext)
	_walter = Personaje.new()
	_walter.unico = true
	_walter.ropa = "uniforme"
	_walter.position = Vector2(240, 214)
	ext.add_child(_walter)

	# Velo suave para que el texto se lea
	var velo := ColorRect.new()
	velo.color = Color(0.05, 0.09, 0.16, 0.18)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(velo)

	# Título sobre el techo del hospital
	var cinta := PanelContainer.new()
	cinta.add_theme_stylebox_override("panel", _caja(Color(0.07, 0.16, 0.28, 0.82), Color("8fd3ff"), 2, 6))
	cinta.position = Vector2(118, 10)
	cinta.custom_minimum_size = Vector2(244, 0)
	add_child(cinta)
	var vt := VBoxContainer.new()
	vt.add_theme_constant_override("separation", 0)
	cinta.add_child(vt)
	_titulo = _texto("BATA BLANCA", 26, Color.WHITE, Color("1b4f80"), 4)
	vt.add_child(_titulo)
	var sub := _texto("✚  HOSPITAL DE PILLBOX  ✚", 9, Color("9fe6ff"), Color("0d2740"), 2)
	vt.add_child(sub)

	# Menú en el jardín izquierdo
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _caja(Color(0.96, 0.98, 1.0, 0.94), Color("2f6ea3"), 2, 6))
	panel.position = Vector2(14, 112)
	panel.custom_minimum_size = Vector2(124, 0)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	var turno := _texto("Turno 7:30 AM", 7, Color("2f6ea3"), Color(0, 0, 0, 0), 0)
	v.add_child(turno)
	var nueva := _boton("Nueva partida", _nueva)
	v.add_child(nueva)
	var continuar := _boton("Continuar", _continuar)
	continuar.disabled = not Juego.hay_partida_guardada()
	v.add_child(continuar)
	v.add_child(_boton("Salir", func(): get_tree().quit()))

	# Créditos y controles sobre la calle
	var franja := ColorRect.new()
	franja.color = Color(0.04, 0.07, 0.12, 0.72)
	franja.position = Vector2(0, 258)
	franja.size = Vector2(480, 12)
	franja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(franja)
	var ayuda := _texto("WASD / flechas: moverse · E: interactuar · C: celular · 1-9: elegir · Tab: acelerar", 7, Color(1, 1, 1, 0.8), Color(0, 0, 0, 0), 0)
	ayuda.position = Vector2(0, 258)
	ayuda.custom_minimum_size = Vector2(480, 12)
	add_child(ayuda)
	(continuar if not continuar.disabled else nueva).grab_focus()


func _process(delta: float) -> void:
	_t += delta
	# Walter mira a los autos de vez en cuando
	var fase := int(_t / 2.5) % 4
	_walter.mirando = [Vector2.DOWN, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT][fase]
	_walter.caminar(false, delta)
	_titulo.position.y = sin(_t * 2.0) * 1.0


func _caja(fondo: Color, borde: Color, grosor: int, radio: int) -> StyleBoxFlat:
	var c := StyleBoxFlat.new()
	c.bg_color = fondo
	c.border_color = borde
	c.set_border_width_all(grosor)
	c.set_corner_radius_all(radio)
	c.content_margin_left = 8
	c.content_margin_right = 8
	c.content_margin_top = 5
	c.content_margin_bottom = 6
	c.shadow_color = Color(0, 0, 0, 0.35)
	c.shadow_size = 3
	c.shadow_offset = Vector2(1, 2)
	return c


func _texto(t: String, tam: int, color: Color, contorno: Color, grosor: int) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	if grosor > 0:
		l.add_theme_color_override("font_outline_color", contorno)
		l.add_theme_constant_override("outline_size", grosor)
	return l


func _boton(t: String, accion: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(108, 18)
	b.add_theme_font_size_override("font_size", 9)
	b.add_theme_color_override("font_color", Color("1b3a5c"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.45, 0.5, 0.6))
	var normal := _caja(Color("e6f1fb"), Color("9cc3e4"), 1, 4)
	normal.shadow_size = 0
	normal.content_margin_top = 2
	normal.content_margin_bottom = 2
	var activo := _caja(Color("2f80c8"), Color("1b4f80"), 1, 4)
	activo.shadow_size = 0
	activo.content_margin_top = 2
	activo.content_margin_bottom = 2
	var apagado := normal.duplicate()
	apagado.bg_color = Color("d5dde5")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", activo)
	b.add_theme_stylebox_override("focus", activo)
	b.add_theme_stylebox_override("pressed", activo)
	b.add_theme_stylebox_override("disabled", apagado)
	b.pressed.connect(accion)
	b.mouse_entered.connect(func(): Juego.sonido("blip", 1.4, -16.0))
	b.focus_entered.connect(func(): Juego.sonido("blip", 1.4, -16.0))
	return b


func _nueva() -> void:
	Juego.sonido("seleccion")
	Juego.nueva_partida()
	Juego.ir_a("res://escenas/casa.tscn", "Día 1 · Lunes")


func _continuar() -> void:
	Juego.sonido("seleccion")
	if Juego.cargar():
		Juego.punto_entrada = "cama"
		Juego.ultimo_resumen = "Partida cargada. Son las %s del día %d." % [Juego.hora_texto(), Juego.dia]
		Juego.ir_a("res://escenas/casa.tscn", "Día %d · %s" % [Juego.dia, Juego.nombre_dia()])
