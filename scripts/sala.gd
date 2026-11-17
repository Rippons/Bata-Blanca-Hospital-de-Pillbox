class_name Sala
extends Node2D
## Base para la casa y el hospital: fondo, muros, muebles con colisión,
## objetos interactuables, Walter y HUD.

const ALTO_HUD := 18

var fondo: Fondo
var mundo: Node2D          # contenedor con orden por Y (muebles + personas)
var walter: Walter
var hud: HUD
var interactuables := {}   # id -> Interactuable
var _texturas := {}


func _ready() -> void:
	fondo = Fondo.new()
	add_child(fondo)
	mundo = Node2D.new()
	mundo.y_sort_enabled = true
	add_child(mundo)
	hud = HUD.new()
	add_child(hud)
	construir()
	walter = Walter.new()
	walter.position = posicion_inicial()
	mundo.add_child(walter)
	walter.objetivo_cambiado.connect(_on_objetivo_cambiado)
	al_entrar()


# --- Para sobrescribir en cada sala -------------------------------------------------
func construir() -> void:
	pass


func posicion_inicial() -> Vector2:
	return Vector2(240, 160)


func al_entrar() -> void:
	pass


func interactuar(_id: String) -> void:
	pass


func etiqueta_de(id: String) -> String:
	return interactuables[id].etiqueta if interactuables.has(id) else ""


# --- Utilidades de construcción -----------------------------------------------------
func textura(ruta: String) -> Texture2D:
	if not _texturas.has(ruta):
		_texturas[ruta] = load(ruta)
	return _texturas[ruta]


## Coloca un sprite recortado de una hoja. «pos» es el punto de apoyo (centro de la base).
## Si «solido», crea colisión en la parte baja del mueble.
func mueble(ruta: String, region: Rect2, pos: Vector2, solido := true, alto_colision := -1.0, modulado := Color.WHITE) -> Node2D:
	var nodo := Node2D.new()
	nodo.position = pos
	var s := Sprite2D.new()
	var at := AtlasTexture.new()
	at.atlas = textura(ruta)
	at.region = region
	s.texture = at
	s.centered = false
	s.offset = Vector2(-region.size.x / 2.0, -region.size.y)
	s.modulate = modulado
	nodo.add_child(s)
	if solido:
		var alto := alto_colision if alto_colision > 0.0 else minf(region.size.y * 0.5, 18.0)
		solido_rect(Rect2(pos.x - region.size.x / 2.0 + 1, pos.y - alto, region.size.x - 2, alto))
	mundo.add_child(nodo)
	return nodo


func solido_rect(r: Rect2) -> void:
	var cuerpo := StaticBody2D.new()
	cuerpo.collision_layer = 1
	var forma := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	forma.shape = rect
	forma.position = r.get_center()
	cuerpo.add_child(forma)
	add_child(cuerpo)


## Zona interactuable (en coordenadas de la sala).
func zona(id: String, etiqueta: String, r: Rect2) -> Interactuable:
	var it := Interactuable.new()
	it.position = r.get_center()
	it.configurar(id, etiqueta, Rect2(-r.size / 2.0, r.size))
	it.usado.connect(_on_usado)
	add_child(it)
	interactuables[id] = it
	return it


## Etiqueta de texto pequeña sobre el mundo (carteles).
func cartel(texto: String, pos: Vector2, color := Color("2b2b2b")) -> Label:
	var l := Label.new()
	l.text = texto
	l.theme = Juego.tema
	l.add_theme_font_size_override("font_size", 6)
	l.add_theme_color_override("font_color", color)
	l.position = pos
	add_child(l)
	return l


func muros_borde(alto_pared: float) -> void:
	solido_rect(Rect2(0, 0, 480, ALTO_HUD + alto_pared - 4))   # pared superior
	solido_rect(Rect2(-10, 0, 10, 270))                         # izquierda
	solido_rect(Rect2(480, 0, 10, 270))                         # derecha
	solido_rect(Rect2(0, 270, 480, 10))                         # abajo


# --- Señales ------------------------------------------------------------------
func _on_usado(id: String) -> void:
	if hud.ocupado():
		return
	interactuar(id)


func _on_objetivo_cambiado(obj: Interactuable) -> void:
	hud.poner_aviso(obj.etiqueta if obj else "")


func refrescar_aviso() -> void:
	_on_objetivo_cambiado(walter.objetivo)
