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
var npcs := {}             # nombre -> NPC
var origen := Vector2.ZERO  # desplazamiento de la sala que se está construyendo
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


## Efecto de una respuesta elegida en un diálogo (lo maneja cada sala).
func efecto_npc(_nombre: String, _efecto: String) -> void:
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
	nodo.position = pos + origen
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
	forma.position = r.get_center() + origen
	cuerpo.add_child(forma)
	add_child(cuerpo)


## Zona interactuable (en coordenadas de la sala).
func zona(id: String, etiqueta: String, r: Rect2) -> Interactuable:
	var it := Interactuable.new()
	it.position = r.get_center() + origen
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
	l.position = pos + origen
	add_child(l)
	return l


func suelo(destino: Rect2, tex: Texture2D, region: Rect2) -> void:
	fondo.agregar(Rect2(destino.position + origen, destino.size), tex, region)


func suelo_color(destino: Rect2, color: Color) -> void:
	fondo.agregar_color(Rect2(destino.position + origen, destino.size), color)


## NPC con nombre y diálogos. «pos» y «paseo» en coordenadas de la sala.
## Si «paseo» está vacío o «quieto» es true, no camina.
func persona(nombre: String, piel: int, ropa: String, pelo_hoja: String, pelo_fila: int, pos: Vector2,
		paseo := Rect2(), lineas: Array = [], quieto := false) -> NPC:
	var n := NPC.new()
	n.configurar(nombre, piel, ropa, pelo_hoja, pelo_fila)
	n.position = pos + origen
	n.quieto = quieto or paseo.size == Vector2.ZERO
	if paseo.size != Vector2.ZERO:
		n.zona_paseo = Rect2(paseo.position + origen, paseo.size)
	n.lineas = lineas
	n.zona_hablar.usado.connect(_on_usado)
	n.efecto_dialogo.connect(efecto_npc)
	interactuables[n.zona_hablar.id] = n.zona_hablar
	npcs[nombre] = n
	mundo.add_child(n)
	return n


## Habla con un NPC por su nombre (lo usan las zonas de los mostradores).
func hablar_con(nombre: String) -> void:
	if npcs.has(nombre):
		await npcs[nombre].hablar(hud, walter.global_position)


## Persona decorativa sin diálogo (MetroCity). «pos» en coordenadas de la sala.
func npc(piel: int, ropa: String, pelo_hoja: String, pelo_fila: int, pos: Vector2, mirando := Vector2.DOWN) -> Personaje:
	var p := Personaje.new()
	p.piel = piel
	p.ropa = ropa
	p.pelo_hoja = pelo_hoja
	p.pelo_fila = pelo_fila
	p.mirando = mirando
	p.position = pos + origen
	mundo.add_child(p)
	return p


func muros_borde(alto_pared: float, tam := Vector2(480, 270)) -> void:
	solido_rect(Rect2(0, 0, tam.x, ALTO_HUD + alto_pared - 4))   # pared superior
	solido_rect(Rect2(-10, 0, 10, tam.y))                         # izquierda
	solido_rect(Rect2(tam.x, 0, 10, tam.y))                       # derecha
	solido_rect(Rect2(0, tam.y, tam.x, 10))                       # abajo


# --- Señales ------------------------------------------------------------------
func _on_usado(id: String) -> void:
	if hud.ocupado():
		return
	interactuar(id)


func _on_objetivo_cambiado(obj: Interactuable) -> void:
	hud.poner_aviso(obj.etiqueta if obj else "")


func refrescar_aviso() -> void:
	_on_objetivo_cambiado(walter.objetivo)
