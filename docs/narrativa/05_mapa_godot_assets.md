# 05 · Mapa técnico (Godot 4.5) y lista de assets

**Nivel:** Nivel 1 — *La primera guardia* · **Estado:** todo **Propuesto** (no hay build del nivel todavía).
Clases verificadas contra la documentación oficial de Godot 4.5: <https://docs.godotengine.org/en/4.5/classes/>.
Convención: `NombreElegido (Clase)`. Los nombres de la izquierda son del equipo; la clase entre paréntesis es el tipo real de Godot.

---

## 1. Organización de archivos

```
res://
├── escenas/
│   ├── nivel_urgencias.tscn      ← nivel completo (V01–V08 son estados de esta escena)
│   ├── walter.tscn               ← jugador
│   ├── paciente.tscn             ← camilla + paciente reutilizable (Ramiro, Teresa, Andrés)
│   └── hud.tscn                  ← interfaz
├── scripts/
│   ├── estado_partida.gd         ← Autoload «EstadoPartida»
│   ├── caso_clinico.gd           ← Resource personalizado (class_name CasoClinico)
│   ├── walter.gd
│   ├── paciente.gd
│   ├── intro_trigger.gd
│   ├── botiquin.gd
│   ├── carro_medicamentos.gd
│   ├── tablon.gd
│   └── nivel_urgencias.gd
├── datos/casos/
│   ├── ramiro.tres  teresa.tres  andres.tres
├── arte/   audio/
```

No se crea un `.tscn` por viñeta: las ocho viñetas ocurren en `nivel_urgencias.tscn` y cambian por **estado** (variables de `EstadoPartida`).

## 2. Árbol de la escena principal

```
NivelUrgencias (Node2D) [nivel_urgencias.gd]
├── Suelo (TileMapLayer)
├── Walter (CharacterBody2D) [walter.gd] [grupo: jugador]
│   ├── Sprite (AnimatedSprite2D)
│   ├── CollisionShape2D
│   └── Camera2D
├── IntroTrigger (Area2D) [intro_trigger.gd]
│   └── CollisionShape2D
├── Salgado (Area2D) + CollisionShape2D + Sprite2D
├── Lucia (Area2D) + CollisionShape2D + Sprite2D
├── Pacientes (Node2D)
│   ├── Ramiro  (instancia de paciente.tscn, caso = ramiro.tres)
│   ├── Teresa  (instancia de paciente.tscn, caso = teresa.tres, visible = false)
│   └── Andres  (instancia de paciente.tscn, caso = andres.tres, visible = false)
├── BotiquinA (Area2D) [botiquin.gd]          + CollisionShape2D + Sprite2D
├── BotiquinRojo (Area2D) [botiquin.gd]       + CollisionShape2D + Sprite2D
├── CarroMedicamentos (Area2D) [carro_medicamentos.gd] + CollisionShape2D
├── Mostrador (Area2D)                        + CollisionShape2D   ← hoja de triaje
├── TablonCapacitaciones (Area2D) [tablon.gd] + CollisionShape2D + Sprite2D
├── TimerAmbulancia (Timer)                   ← wait_time = 10, one_shot = true
├── HUD (CanvasLayer)  ← instancia de hud.tscn
│   ├── Objetivo (Label)
│   ├── Rango (Label)
│   ├── BarraReputacion (ProgressBar)
│   ├── TextoDialogo (RichTextLabel)
│   ├── PanelDiagnostico (PanelContainer)
│   │   └── VBoxContainer → Signos (Label), Opcion1/2/3 (Button)
│   └── PanelCapacitacion (PanelContainer)
│       └── VBoxContainer → Urgencias, Pediatria, Cirugia (Button)
├── SFX (AudioStreamPlayer)
├── Sirena (AudioStreamPlayer2D)   ← ubicada en la entrada de ambulancias
└── AnimationPlayer
```

`paciente.tscn`:

```
Paciente (Area2D) [paciente.gd]
├── CollisionShape2D
├── Camilla (Sprite2D)
├── Cuerpo (Sprite2D)
└── Estabilidad (ProgressBar)   ← min 0, max 100
```

**Configuración en el Inspector:** a cada `CollisionShape2D` asignarle una forma (`RectangleShape2D`/`CircleShape2D`). La máscara de colisión de cada `Area2D` debe incluir la capa del cuerpo de Walter y `monitoring` debe estar activo. Añadir a `Walter` al grupo `jugador`. Registrar `scripts/estado_partida.gd` como Autoload con el nombre `EstadoPartida` (Proyecto → Configuración del proyecto → Globals/Autoload). Crear la acción `interactuar` (tecla E) en el Mapa de entrada.

## 3. Mapa viñeta → implementación (plantilla 6.2)

| Viñeta / escena narrativa | Archivo .tscn / nodo (clase) | Recurso / evento / estado | Prueba y estado real |
|---|---|---|---|
| **V01 / ESC-01 / B1** | `nivel_urgencias.tscn` / IntroTrigger (Area2D), TextoDialogo (RichTextLabel), Objetivo (Label), TablonCapacitaciones (Area2D) | Señal `body_entered` → si `intro_vista == false` muestra diálogo de Salgado, marca `intro_vista = true` y fija objetivo. | Entrar con Walter muestra la bienvenida **una sola vez**; volver a cruzar la puerta no la repite; otro cuerpo no la dispara. **Propuesto.** |
| **V02 / ESC-01 / B2** | `paciente.tscn` / Ramiro (Area2D), Estabilidad (ProgressBar); `hud.tscn` / PanelDiagnostico (PanelContainer), Opcion1–3 (Button) | Acción `interactuar` dentro del área → abre panel con `caso.signos`. Señal `pressed` de cada Button → compara con `caso.diagnostico_correcto`. | Elegir «Fractura» baja la estabilidad 10 y deja el panel abierto; elegir «Herida superficial» lo cierra. La barra de Ramiro nunca baja de 20. **Propuesto.** |
| **V03 / ESC-01 / B2** | BotiquinA (Area2D); Ramiro (Area2D) | `Walter.insumo_cargado = "vendaje"`; al aplicar en Ramiro → `caso_ramiro_resuelto = true`, `reputacion += 10` (o +5 si hubo fallo). | Aplicar «antipirético» a Ramiro no lo resuelve y gasta el insumo; aplicar «vendaje» lo deja en 100. **Propuesto.** |
| **V04 / B3** | Teresa (Area2D, instancia de `paciente.tscn`); Mostrador (Area2D) | `visible = true` y `activo = true` 3 s después de resolver a Ramiro. Interactuar con Mostrador → `triaje_firmado = true`, `confianza += 1` (una sola vez). | La barra de Teresa baja 1/s; firmar el triaje dos veces solo suma 1. Si su barra llega a 0 → transferida, `reputacion -= 5`. **Propuesto.** |
| **V05 / B4** | CarroMedicamentos (Area2D), Lucia (Area2D), BotiquinRojo (Area2D) | Ordenar 3 insumos (3 interacciones con el carro, cada una en su cajón) → `ayuda_lucia = true`, `confianza += 1`, `botiquin_rojo_abierto = true`; `TimerAmbulancia.start()`. | Antes de ayudar, interactuar con el botiquín rojo muestra «Necesitas el código»; después se abre. El timer arranca una sola vez. **Propuesto.** |
| **V06 / ESC-02 / B5** | TimerAmbulancia (Timer), Sirena (AudioStreamPlayer2D), Andres (Area2D), Teresa (Area2D) | Señal `timeout` → `Andres.activo = true`, `Sirena.play()`. Si `confianza == 2` → `Teresa.congelado = true`; si no, Teresa baja 0,5/s. | Con confianza 2 la barra de Teresa no cambia durante B5; con confianza 1 sí baja. La sirena se oye más fuerte cerca de la entrada. **Propuesto.** |
| **V07 / ESC-02 / B5** | BotiquinRojo (Area2D), Andres (Area2D), AnimationPlayer | `Walter.insumo_cargado = "epinefrina"` (1 dosis). Al aplicar → `caso_andres_resuelto = true`, `reputacion += 15`. Si la barra llega a 0 → `nivel_urgencias.gd` recarga el punto de control de B5. | Una alineación diagnóstico/insumo incorrecta **no** completa el caso. Aplicar la epinefrina a otro paciente la pierde y lo indica. **Propuesto.** |
| **V08 / ESC-02 / B6** | TablonCapacitaciones (Area2D), PanelCapacitacion (PanelContainer), Urgencias/Pediatria/Cirugia (Button), Rango (Label) | Si `caso_andres_resuelto` y `reputacion >= 30` → tablón habilitado. Señal `pressed` → `especialidad = "<elegida>"`, `rango = "Residente"`. | Con reputación 25 el tablón sigue bloqueado y aparece «Repite el turno». El panel no se abre si `especialidad != ""`. **Propuesto.** |

## 4. Scripts de ejemplo (Godot 4.5, GDScript)

### 4.1 `estado_partida.gd` (Autoload `EstadoPartida`)

```gdscript
extends Node

var reputacion := 0
var confianza := 0
var rango := "Interno"
var especialidad := ""

var flags := {
	"intro_vista": false,
	"caso_ramiro_resuelto": false,
	"caso_teresa_resuelto": false,
	"triaje_firmado": false,
	"ayuda_lucia": false,
	"botiquin_rojo_abierto": false,
	"caso_andres_resuelto": false,
}

func sumar_reputacion(cantidad: int) -> void:
	reputacion = maxi(reputacion + cantidad, 0)

func puede_capacitarse() -> bool:
	return flags["caso_andres_resuelto"] and reputacion >= 30
```

### 4.2 `caso_clinico.gd` (Resource personalizado)

```gdscript
class_name CasoClinico
extends Resource

@export var nombre := ""
@export_multiline var signos := ""
@export var opciones: PackedStringArray = []
@export var diagnostico_correcto := ""
@export var insumo := ""
@export var estabilidad_inicial := 80.0
@export var velocidad_deterioro := 0.5   # puntos por segundo
@export var estabilidad_minima := 0.0    # Ramiro usa 20 para no castigar en el tutorial
@export var reputacion_premio := 10
```

| Archivo | nombre | diagnostico_correcto | insumo | estabilidad_inicial | velocidad_deterioro | estabilidad_minima | reputacion_premio |
|---|---|---|---|---|---|---|---|
| `ramiro.tres` | Don Ramiro | Herida superficial | vendaje | 80 | 0,5 | 20 | 10 |
| `teresa.tres` | Teresa | Fiebre alta | antipirético | 80 | 1,0 | 0 | 10 |
| `andres.tres` | Andrés | Reacción alérgica grave | epinefrina | 60 | 3,0 | 0 | 15 |

> Valores iniciales de diseño: deben ajustarse en pruebas con jugadores.

### 4.3 `paciente.gd`

```gdscript
extends Area2D

signal caso_resuelto(paciente: Area2D)
signal paciente_transferido(paciente: Area2D)

@export var caso: CasoClinico
@export var activo := false

var estabilidad := 0.0
var congelado := false
var diagnostico_ok := false
var fallos := 0
var resuelto := false

@onready var barra: ProgressBar = $Estabilidad

func _ready() -> void:
	estabilidad = caso.estabilidad_inicial
	barra.value = estabilidad

func _process(delta: float) -> void:
	if not activo or resuelto or congelado:
		return
	estabilidad = maxf(estabilidad - caso.velocidad_deterioro * delta, caso.estabilidad_minima)
	barra.value = estabilidad
	if estabilidad <= 0.0:
		activo = false
		paciente_transferido.emit(self)

func elegir_diagnostico(opcion: String) -> bool:
	if opcion == caso.diagnostico_correcto:
		diagnostico_ok = true
		return true
	fallos += 1
	estabilidad = maxf(estabilidad - 10.0, caso.estabilidad_minima)
	barra.value = estabilidad
	return false

func aplicar_insumo(insumo: String) -> bool:
	if resuelto or not diagnostico_ok or insumo != caso.insumo:
		return false
	resuelto = true
	estabilidad = 100.0
	barra.value = estabilidad
	var premio: int = caso.reputacion_premio if fallos == 0 else int(caso.reputacion_premio / 2.0)
	EstadoPartida.sumar_reputacion(premio)
	caso_resuelto.emit(self)
	return true
```

### 4.4 `intro_trigger.gd` (ESC-01)

```gdscript
extends Area2D

@onready var texto: RichTextLabel = $"../HUD/TextoDialogo"
@onready var objetivo: Label = $"../HUD/Objetivo"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if EstadoPartida.flags["intro_vista"] or not body.is_in_group("jugador"):
		return
	EstadoPartida.flags["intro_vista"] = true
	texto.text = "Salgado: Bienvenido a Pillbox, Vega. Hoy cubres urgencias con Lucía."
	texto.show()
	objetivo.text = "Objetivo: Atiende a Don Ramiro (camilla 1)"
```

> La señal se conecta por código; no conectarla además desde el editor al mismo método. Al guardar `intro_vista` en el Autoload, la bandera no se reinicia si se recarga la escena desde el punto de control de B5.

**Alcance de los ejemplos.** No incluyen el movimiento de Walter, el HUD completo, el guardado en disco ni la lógica del carro de medicamentos; esas partes quedan como tareas de implementación.

## 5. Inventario de assets

| ID / uso | Archivo o recurso | Origen / licencia / responsable / estado |
|---|---|---|
| AS-01 / V01–V08: sprites de Walter | Capas en `res://arte/personajes/`: cuerpo `metrocity1/CharacterModel/Character Model.png` (fila 0) + ropa `metrocity2/Suit1.png` (fila 0 uniforme, fila 2 pijama) + pelo `metrocity1/Hair/Hairs.png` (fila 0) | **MetroCity – Free Top Down Character Pack** (JIK-A-4): <https://jik-a-4.itch.io/metrocity-free-topdown-character-pack>. Uso libre, también comercial; crédito apreciado. La bata sucia se muestra tiñendo la ropa · Wilson Saavedra · **Implementado** (`scripts/personaje.gd`) |
| AS-02 / V01, V08: Dr. Salgado | Mismas hojas: piel fila 4, `Suit1` fila 0, pelo canoso (`Hairs` fila 1) | MetroCity (JIK-A-4) · Wilson Saavedra · **Implementado** (Dirección) |
| AS-03 / V04–V06: Lucía | Piel fila 3, `Suit1` fila 3 (uniforme celeste), pelo `Hairs` fila 6 | MetroCity (JIK-A-4) · Wilson Saavedra · **Implementado** (Urgencias) |
| AS-04 / V01–V07: pacientes y Marta (recepción) | Piel aleatoria 0-5, ropa de `Suit1`, `Suit` y `Outfits`, pelo de `Hairs` o `metrocity2/Hair.png` | MetroCity (JIK-A-4) · Wilson Saavedra · **Implementado** |
| AS-05 / todas: suelo y paredes de la sala | `res://arte/interior/Hospital/TilesHospital.png` (TileSet para `Suelo`) | Paquete **MetroCity – Free Top Down Interior Asset Pack** (JIK-A-4): <https://jik-a-4.itch.io/metrocity>. Licencia de la página: **Creative Commons Zero v1.0 (CC0)**. Créditos en `arte/CREDITOS.md` · Elkin Perez · **Validado** (licencia registrada) |
| AS-06 / V02–V07: camillas, puertas, sillas de espera, portasuero, monitor | `res://arte/interior/Hospital/` (`BedHospital-Sheet.png`, `DoorsHospital-Sheet.png`, `Miscellaneous-Sheet.png`) | Mismo paquete Interior (JIK-A-4, CC0). Camillas = `BedHospital-Sheet` (2 orientaciones); puerta de urgencias y entrada de ambulancias = `DoorsHospital-Sheet`; sala de espera = `Miscellaneous-Sheet` · Elkin Perez · **Validado** (licencia registrada) |
| AS-06b / V03, V05, V07, V08: botiquín A, botiquín rojo, carro de medicamentos, tablón | `res://arte/interior/mobiliario_propio.png` | No vienen en el paquete. Arte propio del equipo (se puede partir de `arte/interior/Home/Cupboard-Sheet.png`, CC0, recoloreado) · Elkin Perez · **Propuesto** |
| AS-07 / V02, V08: íconos de insumos (vendaje, antipirético, epinefrina) | `res://arte/insumos.png` | Arte propio · Elkin Perez · **Propuesto** |
| AS-08 / V01–V08: ambiente de hospital | `res://audio/ambiente_hospital.ogg` | Grabación propia o banco externo con licencia registrada · Hugo Cañas · **Pendiente** |
| AS-09 / V06: sirena de ambulancia | `res://audio/sirena.ogg` | Banco externo: registrar enlace, autor y licencia · Hugo Cañas · **Pendiente** |
| AS-10 / V02, V03, V07: bip, confirmación, error | `res://audio/sfx_ui.ogg` | Generado por el equipo (sfxr/jsfxr) · Hugo Cañas · **Propuesto** |
| AS-11 / V06–V07: latido | `res://audio/latido.ogg` | Banco externo o propio · Hugo Cañas · **Pendiente** |
| AS-12 / V08: fanfarria de ascenso | `res://audio/fanfarria.ogg` | Composición propia · Hugo Cañas · **Propuesto** |
| AS-13 / V01–V08: textos y diálogos | `03_guion_jugable.md` → `res://datos/dialogos.json` | Escritos por el equipo · Oscar Arciniegas · **Propuesto** |
| AS-14 / HUD | Fuente tipográfica `res://arte/fuente.ttf` | Fuente con licencia OFL; registrar nombre y enlace · Oscar Arciniegas · **Pendiente** |

> «Gratis» no es lo mismo que «con permiso». Todo recurso externo queda **Pendiente** hasta registrar enlace, autor y licencia.
>
> **Crédito en el juego:** aunque no es obligatorio, se incluirá en la pantalla de créditos: «Personajes e interiores: MetroCity por JIK-A-4 (jik-a-4.itch.io)». Las recoloraciones (batas, uniforme) son obras derivadas hechas por el equipo.
