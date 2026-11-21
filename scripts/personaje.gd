class_name Personaje
extends Node2D
## Personaje armado por capas con los sprites de MetroCity (JIK-A-4):
## sombra + cuerpo (tono de piel) + ropa + pelo.
## Cada hoja tiene 24 columnas de 32×32: 0-5 abajo, 6-11 derecha, 12-17 arriba, 18-23 izquierda.
## El origen (0, 0) está en los pies.

const BASE := "res://arte/personajes/"
const CUERPO := BASE + "metrocity1/CharacterModel/Character Model.png"
const SOMBRA := BASE + "metrocity1/CharacterModel/Shadow.png"
const PELOS := BASE + "metrocity1/Hair/Hairs.png"         # 8 filas
const PELOS2 := BASE + "metrocity2/Hair.png"              # 5 filas
## Pelo de los oficiales del LSPD ya recortado debajo de la gorra:
## 0 Reyes (castaño) · 1 McClane (negro con canas) · 2 Mendoza (castaño) · 3 Pawlak (castaño claro, largo)
const PELOS_LSPD := BASE + "propios/pelos_lspd.png"
const PELO_STONE := BASE + "propios/pelo_stone.png"        # peinado antiguo de Walter en aguamarina
const TRAJES := BASE + "metrocity2/Suit1.png"             # 0 blanco · 1 rosa · 2 azul · 3 celeste · 4 fucsia
const TRAJES_B := BASE + "metrocity2/Suit.png"            # 0 policía · 1 rojo · 2 overol · 3 naranja
const OUTFIT := BASE + "metrocity1/Outfits/Outfit%d.png"  # 1..6, una fila

## Ropa predefinida: [hoja, fila]
const ROPAS := {
	"uniforme": [TRAJES, 2],    # uniforme médico azul
	"pijama": [TRAJES, 0],      # camiseta blanca y pantalón oscuro
	"enfermera": [TRAJES, 3],
	"rosa": [TRAJES, 1],
	"fucsia": [TRAJES, 4],
	"naranja": [TRAJES_B, 3],
	"policia": [TRAJES_B, 0],
	"rojo": [TRAJES_B, 1],
	"overol": [TRAJES_B, 2],
	"casual_blanco": ["o5", 0],
	"casual_rojo": ["o6", 0],
}

## Personajes propios del equipo: una sola hoja de 3 columnas × 4 filas, cuadros de 20×32.
## Filas: 0 abajo · 1 izquierda · 2 izquierda (otra versión) · 3 arriba. La derecha es la izquierda en espejo.
## Se usan con ropa = "hoja:<id>".
const HOJAS := {
	"dakota": BASE + "propios/dakota.png",
	"jinu": BASE + "propios/jinu_blake.png",
	"sheyla": BASE + "propios/sheyla_escobedo.png",
	"marcos": BASE + "propios/marcos_rojas.png",
}
## Hojas exclusivas de Walter Pinkman (formato MetroCity: 24 cuadros de 32×32 en una fila,
## con cuerpo, ropa, pelo y barba ya unidos). Si «unico» es true se usan en vez de las capas.
const WALTER := {
	"uniforme": BASE + "walter/walter_bata.png",
	"uniforme_sucia": BASE + "walter/walter_bata_sucia.png",
	"pijama": BASE + "walter/walter_pijama.png",
}
const PASOS_HOJA := [1, 0, 0, 1, 2, 2]   # cuadro de la hoja según la fase de la caminata

@export var piel := 0                 # 0..5
@export var ropa := "uniforme"
@export var pelo_hoja := PELOS
@export var pelo_fila := 0
@export var tinte_ropa := Color.WHITE
@export var olor := 0                 # 0 nada · 1 huele · 2 huele mucho
@export var unico := false             # true solo para Walter: usa sus hojas exclusivas

var mirando := Vector2.DOWN
var acostado := false

var _sombra: Sprite2D
var _cuerpo: Sprite2D
var _ropa: Sprite2D
var _pelo: Sprite2D
var _efecto: Node2D
var _cuadro := 0.0
var _col_dir := 0             # columna base de la dirección actual
var _texturas := {}


class EfectoOlor extends Node2D:
	var nivel := 0
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		if nivel > 0:
			queue_redraw()
	func _draw() -> void:
		if nivel == 0:
			return
		var n := 2 if nivel == 1 else 4
		for i in n:
			var fase := _t * 1.6 + i * 1.7
			var subida := fmod(fase, 3.0) / 3.0
			var x := -8.0 + i * 5.0 + sin(fase * 2.0) * 2.0
			var y := -30.0 - subida * 12.0
			var c := Color(0.45, 0.72, 0.2, 0.8 * (1.0 - subida))
			draw_arc(Vector2(x, y), 2.0, PI * 0.2, PI * 1.2, 6, c, 1.0)
			draw_arc(Vector2(x + 2.0, y - 3.0), 2.0, PI * 1.2, PI * 2.2, 6, c, 1.0)


func _ready() -> void:
	_sombra = _capa(SOMBRA)
	_sombra.region_rect = Rect2(0, 0, 32, 32)
	if es_hoja():
		_cuerpo = _capa(HOJAS[ropa.substr(5)])
		_cuerpo.offset = Vector2(-10, -31)
		_efecto = EfectoOlor.new()
		add_child(_efecto)
		_actualizar_cuadro()
		return
	_cuerpo = _capa(CUERPO)
	_ropa = _capa(TRAJES)
	_pelo = _capa(PELOS)
	_efecto = EfectoOlor.new()
	add_child(_efecto)
	aplicar()


func _capa(ruta: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(ruta)
	s.region_enabled = true
	s.centered = false
	s.offset = Vector2(-16, -31)
	add_child(s)
	return s


func _tex(ruta: String) -> Texture2D:
	if not _texturas.has(ruta):
		_texturas[ruta] = load(ruta)
	return _texturas[ruta]


## Vuelve a leer piel, ropa, pelo, tinte y olor.
func aplicar() -> void:
	if _cuerpo == null or es_hoja():
		return
	if usa_walter():
		var clave := ropa
		if ropa == "uniforme" and tinte_ropa != Color.WHITE:
			clave = "uniforme_sucia"
		_cuerpo.texture = _tex(WALTER[clave])
		_ropa.visible = false
		_pelo.visible = false
		_efecto.nivel = olor
		_actualizar_cuadro()
		return
	_cuerpo.texture = _tex(CUERPO)
	_ropa.visible = true
	var r: Array = ROPAS.get(ropa, ROPAS["uniforme"])
	var hoja: String = r[0]
	var fila: int = r[1]
	if hoja.begins_with("o"):
		_ropa.texture = _tex(OUTFIT % int(hoja.substr(1)))
	else:
		_ropa.texture = _tex(hoja)
	_ropa.set_meta("fila", fila)
	_ropa.modulate = tinte_ropa
	_pelo.texture = _tex(pelo_hoja)
	_efecto.nivel = olor
	_actualizar_cuadro()


func caminar(moviendo: bool, delta: float) -> void:
	if moviendo:
		_cuadro = fmod(_cuadro + delta * 10.0, 6.0)
	else:
		_cuadro = 0.0
	_actualizar_cuadro()


## Dirección con un margen, para que no parpadee entre dos direcciones en diagonal.
func _columna_base() -> int:
	var horizontal := absf(mirando.x) > absf(mirando.y) * 1.25
	var vertical := absf(mirando.y) > absf(mirando.x) * 1.25
	if horizontal:
		_col_dir = 6 if mirando.x > 0.0 else 18
	elif vertical:
		_col_dir = 12 if mirando.y < 0.0 else 0
	return _col_dir


func usa_walter() -> bool:
	return unico and WALTER.has(ropa)


func es_hoja() -> bool:
	return ropa.begins_with("hoja:") and HOJAS.has(ropa.substr(5))


func _actualizar_cuadro() -> void:
	if es_hoja():
		var base := _columna_base()
		var fila := 0
		match base:
			6, 18: fila = 1
			12: fila = 3
		_cuerpo.flip_h = base == 6
		_cuerpo.region_rect = Rect2(PASOS_HOJA[int(_cuadro) % 6] * 20.0, fila * 32.0, 20, 32)
		_sombra.visible = not acostado
		return
	var col := _columna_base() + int(_cuadro)
	if acostado:
		col = 0
	var x := col * 32.0
	if usa_walter():
		_cuerpo.region_rect = Rect2(x, 0, 32, 32)
		_sombra.visible = not acostado
		return
	_cuerpo.region_rect = Rect2(x, piel * 32.0, 32, 32)
	_ropa.region_rect = Rect2(x, int(_ropa.get_meta("fila", 0)) * 32.0, 32, 32)
	_pelo.region_rect = Rect2(x, pelo_fila * 32.0, 32, 32)
	# Con gorra de policía solo se ve el pelo recortado del LSPD (debajo de la gorra)
	_pelo.visible = ropa != "policia" or pelo_hoja == PELOS_LSPD
	_sombra.visible = not acostado
