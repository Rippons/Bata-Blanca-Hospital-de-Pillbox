extends Control
## Pantalla de título: nueva partida o continuar.


func _ready() -> void:
	Juego.pausado = true
	Juego.musica("casa")
	theme = Juego.tema
	var fondo := ColorRect.new()
	fondo.color = Color("12202e")
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var v := VBoxContainer.new()
	v.position = Vector2(140, 60)
	v.size = Vector2(200, 150)
	v.add_theme_constant_override("separation", 6)
	add_child(v)

	var titulo := Label.new()
	titulo.text = "BATA BLANCA"
	titulo.add_theme_font_size_override("font_size", 24)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(titulo)
	var sub := Label.new()
	sub.text = "Hospital de Pillbox"
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Color("7fb6e6"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(Control.new())

	var nueva := Button.new()
	nueva.text = "Nueva partida"
	nueva.pressed.connect(_nueva)
	v.add_child(nueva)
	var continuar := Button.new()
	continuar.text = "Continuar"
	continuar.disabled = not Juego.hay_partida_guardada()
	continuar.pressed.connect(_continuar)
	v.add_child(continuar)
	var salir := Button.new()
	salir.text = "Salir"
	salir.pressed.connect(func(): get_tree().quit())
	v.add_child(salir)

	var ayuda := Label.new()
	ayuda.text = "WASD / flechas: moverse · E: interactuar · C: celular · 1-9: elegir · Tab: acelerar"
	ayuda.add_theme_font_size_override("font_size", 7)
	ayuda.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	ayuda.position = Vector2(0, 250)
	ayuda.custom_minimum_size = Vector2(480, 12)
	ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(ayuda)
	(continuar if not continuar.disabled else nueva).grab_focus()


func _nueva() -> void:
	Juego.nueva_partida()
	Juego.ir_a("res://escenas/casa.tscn", "Día 1 · Lunes")


func _continuar() -> void:
	if Juego.cargar():
		Juego.punto_entrada = "cama"
		Juego.ultimo_resumen = "Partida cargada. Son las %s del día %d." % [Juego.hora_texto(), Juego.dia]
		Juego.ir_a("res://escenas/casa.tscn", "Día %d · %s" % [Juego.dia, Juego.nombre_dia()])
