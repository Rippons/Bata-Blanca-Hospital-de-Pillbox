class_name HUD
extends CanvasLayer
## Interfaz: reloj, necesidades, checklist, mensajes, aviso de interacción
## y menú de opciones (elegir) que se usa en toda la partida.

signal opcion_elegida(indice: int)

var raiz: Control
var lbl_dia: Label
var lbl_hora: Label
var lbl_estado: Label
var lbl_carga: Label
var barras := {}
var panel_lista: PanelContainer
var lbl_lista_titulo: Label
var lbl_lista: Label
var panel_msg: PanelContainer
var lbl_msg: Label
var lbl_aviso: Label
var panel_menu: PanelContainer
var lbl_menu_titulo: Label
var lbl_menu_texto: Label
var caja_botones: VBoxContainer

var _cola_mensajes: Array = []
var _mostrando := false
var _menu_abierto := false
var _botones: Array = []


func _ready() -> void:
	layer = 10
	raiz = Control.new()
	raiz.theme = Juego.tema
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)
	_crear_barra_superior()
	_crear_necesidades()
	_crear_lista()
	_crear_mensajes()
	_crear_menu()


func _process(_delta: float) -> void:
	lbl_dia.text = "Día %d · %s" % [Juego.dia, Juego.nombre_dia()]
	lbl_hora.text = Juego.hora_texto()
	lbl_hora.add_theme_color_override("font_color", Color("ffcf6b") if Juego.escala_debug > 1.0 else Color.WHITE)
	lbl_estado.text = "%s · Reputación %d" % [Juego.rango, Juego.reputacion]
	lbl_carga.text = "Llevas: %s" % Juego.insumo_cargado if Juego.insumo_cargado != "" else ""
	_poner_barra("Higiene", Juego.higiene)
	_poner_barra("Energía", Juego.energia)
	_poner_barra("Hambre", Juego.hambre)


# --- Checklist ----------------------------------------------------------------
func poner_lista(titulo: String, tareas: Array) -> void:
	lbl_lista_titulo.text = titulo
	var lineas: Array = []
	for t in tareas:
		lineas.append(("[x] " if t[1] else "[ ] ") + t[0])
	lbl_lista.text = "\n".join(lineas)
	panel_lista.visible = not tareas.is_empty()


# --- Aviso de interacción -------------------------------------------------------
func poner_aviso(texto: String) -> void:
	lbl_aviso.text = ("E: " + texto) if texto != "" else ""
	lbl_aviso.visible = texto != ""


# --- Mensajes (cola) -------------------------------------------------------------
func mostrar(texto: String, segundos: float = 3.5) -> void:
	_cola_mensajes.append([texto, segundos])
	if not _mostrando:
		_siguiente_mensaje()


func _siguiente_mensaje() -> void:
	if _cola_mensajes.is_empty():
		_mostrando = false
		panel_msg.visible = false
		return
	_mostrando = true
	var m = _cola_mensajes.pop_front()
	lbl_msg.text = m[0]
	panel_msg.visible = true
	await get_tree().create_timer(m[1]).timeout
	_siguiente_mensaje()


func ocupado() -> bool:
	return _menu_abierto


# --- Menú de opciones -------------------------------------------------------------
## Muestra un menú y devuelve el índice elegido (-1 si se cancela con Esc).
func elegir(titulo: String, texto: String, opciones: Array) -> int:
	if not Juego.respuestas_auto.is_empty():
		var auto = Juego.respuestas_auto.pop_front()
		var r: int = opciones.find(auto) if auto is String else int(auto)
		print("[auto] ", titulo, " -> ", opciones[r] if r >= 0 and r < opciones.size() else "cancelar")
		return r
	var estaba_pausado := Juego.pausado
	Juego.pausado = true
	_menu_abierto = true
	lbl_menu_titulo.text = titulo
	lbl_menu_texto.text = texto
	lbl_menu_texto.visible = texto != ""
	for b in _botones:
		b.queue_free()
	_botones.clear()
	for i in opciones.size():
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, opciones[i]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_opcion.bind(i))
		caja_botones.add_child(b)
		_botones.append(b)
	panel_menu.visible = true
	panel_menu.reset_size()
	panel_menu.position = Vector2((480 - panel_menu.size.x) / 2.0, (250 - panel_menu.size.y) / 2.0)
	if not _botones.is_empty():
		_botones[0].grab_focus()
	var indice: int = await opcion_elegida
	panel_menu.visible = false
	_menu_abierto = false
	Juego.pausado = estaba_pausado
	return indice


func _on_opcion(i: int) -> void:
	opcion_elegida.emit(i)


func _unhandled_input(event: InputEvent) -> void:
	if not _menu_abierto:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_1 and k <= KEY_9 and k - KEY_1 < _botones.size():
			get_viewport().set_input_as_handled()
			_on_opcion(k - KEY_1)
		elif k == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_opcion(-1)


# --- Construcción de la interfaz -----------------------------------------------------
func _panel(fondo: Color = Color(0.08, 0.1, 0.14, 0.86)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _label(texto: String = "", tam: int = 8) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	return l


func _crear_barra_superior() -> void:
	var barra := _panel()
	barra.position = Vector2(0, 0)
	barra.size = Vector2(480, 18)
	raiz.add_child(barra)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	barra.add_child(fila)
	lbl_dia = _label()
	lbl_hora = _label("", 10)
	lbl_carga = _label()
	lbl_carga.add_theme_color_override("font_color", Color("9fe3a0"))
	lbl_estado = _label()
	var relleno := Control.new()
	relleno.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(lbl_hora)
	fila.add_child(lbl_dia)
	fila.add_child(lbl_carga)
	fila.add_child(relleno)
	fila.add_child(lbl_estado)
	for l in [lbl_dia, lbl_carga, lbl_estado]:
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _crear_necesidades() -> void:
	var p := _panel()
	p.position = Vector2(3, 214)
	raiz.add_child(p)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 2)
	p.add_child(grid)
	var colores := {"Higiene": Color("5fb3e8"), "Energía": Color("f0c24a"), "Hambre": Color("e8835f")}
	for nombre in colores:
		var l := _label(nombre, 7)
		l.custom_minimum_size = Vector2(32, 0)
		grid.add_child(l)
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(70, 7)
		pb.show_percentage = false
		pb.max_value = 100
		var fondo := StyleBoxFlat.new()
		fondo.bg_color = Color(1, 1, 1, 0.15)
		var relleno := StyleBoxFlat.new()
		relleno.bg_color = colores[nombre]
		pb.add_theme_stylebox_override("background", fondo)
		pb.add_theme_stylebox_override("fill", relleno)
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(pb)
		barras[nombre] = [pb, relleno, colores[nombre]]


func _poner_barra(nombre: String, valor: float) -> void:
	var b = barras[nombre]
	b[0].value = valor
	b[1].bg_color = Color("e04848") if valor < 25.0 else b[2]


func _crear_lista() -> void:
	panel_lista = _panel()
	panel_lista.position = Vector2(372, 196)
	panel_lista.custom_minimum_size = Vector2(104, 0)
	panel_lista.resized.connect(func(): panel_lista.position.y = 266 - panel_lista.size.y)
	raiz.add_child(panel_lista)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	panel_lista.add_child(v)
	lbl_lista_titulo = _label("", 8)
	lbl_lista_titulo.add_theme_color_override("font_color", Color("ffcf6b"))
	lbl_lista = _label("", 7)
	v.add_child(lbl_lista_titulo)
	v.add_child(lbl_lista)


func _crear_mensajes() -> void:
	panel_msg = _panel(Color(0.05, 0.07, 0.1, 0.92))
	panel_msg.position = Vector2(110, 222)
	panel_msg.custom_minimum_size = Vector2(256, 0)
	panel_msg.size = Vector2(256, 10)
	panel_msg.visible = false
	raiz.add_child(panel_msg)
	lbl_msg = _label("", 8)
	lbl_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_msg.custom_minimum_size = Vector2(246, 0)
	panel_msg.add_child(lbl_msg)
	panel_msg.resized.connect(func(): panel_msg.position.y = 266 - panel_msg.size.y)

	lbl_aviso = _label("", 8)
	lbl_aviso.add_theme_color_override("font_color", Color("ffcf6b"))
	lbl_aviso.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl_aviso.add_theme_constant_override("outline_size", 3)
	lbl_aviso.position = Vector2(0, 200)
	lbl_aviso.size = Vector2(480, 12)
	lbl_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raiz.add_child(lbl_aviso)


func _crear_menu() -> void:
	panel_menu = _panel(Color(0.06, 0.08, 0.12, 0.96))
	panel_menu.visible = false
	panel_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	raiz.add_child(panel_menu)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.custom_minimum_size = Vector2(220, 0)
	panel_menu.add_child(v)
	lbl_menu_titulo = _label("", 10)
	lbl_menu_titulo.add_theme_color_override("font_color", Color("ffcf6b"))
	lbl_menu_texto = _label("", 8)
	lbl_menu_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_menu_texto.custom_minimum_size = Vector2(220, 0)
	caja_botones = VBoxContainer.new()
	caja_botones.add_theme_constant_override("separation", 2)
	v.add_child(lbl_menu_titulo)
	v.add_child(lbl_menu_texto)
	v.add_child(caja_botones)
	var ayuda := _label("Números 1-9 o clic · Esc cancela", 7)
	ayuda.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	v.add_child(ayuda)
