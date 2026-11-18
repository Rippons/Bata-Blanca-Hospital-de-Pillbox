# Narrativa — *Bata Blanca: Hospital de Pillbox*

**Taller:** Historia del juego, guion jugable y storyboard · Diseño Multimedia y Videojuegos · FESC · Prof. Yeison Sanabria Ascanio
**Motor:** Godot 4.5 (2D, vista cenital)
**Nivel documentado:** Nivel 1 — *La primera guardia*
**Integrantes:** Oscar Andrés Arciniegas Bustos · Wilson Alejandro Saavedra Arenales · Hugo Orielso Cañas Lozano · Elkin Sebastian Perez Marquez

## Idea del juego

El Dr. **Walter Pinkman** empieza como médico interno en el **Hospital de Pillbox**. Atendiendo casos cada vez menos básicos y ayudando a sus compañeros, gana reputación y confianza para tomar **capacitaciones** que lo hacen subir de rango y elegir especialidad. Su meta final es convertirse en **director del Hospital de Pillbox**. Este taller documenta solo el primer nivel: la primera guardia en urgencias, que termina con su ascenso a **Residente**.

## Archivos

| # | Archivo | Contenido |
|---|---|---|
| 01 | `01_premisa_personajes.md` | Logline, ficha de personaje, campaña completa y nombres definitivos |
| 02 | `02_estructura_curva.md` + `02_curva_tension.png` | Tres actos, 6 beats, curva de tensión, reintentos y rutas |
| 03 | `03_guion_jugable.md` | ESC-01 (intro) y ESC-02 (clímax) en formato de guion jugable |
| 04 | `04_storyboard.pdf` (+ `04_storyboard_p1.png`, `04_storyboard_p2.png`) | 8 viñetas de gameplay con encuadre, acción, audio y transición |
| 05 | `05_mapa_godot_assets.md` | Árbol de nodos Godot 4.5, mapa viñeta → implementación, scripts de ejemplo e inventario de assets |
| — | `fuentes/` | Scripts de Python que generan la curva y el storyboard (editables) |

## Implementado vs. propuesto

Todo el contenido es **Propuesto**. No existe todavía un build del nivel; los scripts del documento 05 son ejemplos de diseño, no código probado en el proyecto.

## Decisiones principales (cada integrante explica una)

| Decisión | Por qué | Responsable de explicarla |
|---|---|---|
| El conflicto es la saturación y el deterioro de los pacientes, no un villano | Se puede representar con una regla (barra de estabilidad) y mantiene el tono esperanzador | Oscar Arciniegas |
| B4 es un respiro donde se ayuda a Lucía | Baja la exigencia para que el jugador vea el botiquín rojo cerrado y obtenga el código que necesitará en el clímax | Wilson Saavedra |
| Transición V05 → V06 por `TimerAmbulancia` y no por cambio de escena | Todas las viñetas ocurren en `nivel_urgencias.tscn` y cambian por estado | Hugo Cañas |
| Ningún paciente muere: se transfiere | Coherente con el tono y evita castigos arbitrarios; aun así hay consecuencia (−5 reputación) | Elkin Perez |

## Matriz historia → requisito → escena → prueba

| Historia / ESC / V | Requisito funcional | Escena / nodo | Prueba | Estado |
|---|---|---|---|---|
| ESC-01 / V01 | **RF-N01:** el sistema debe mostrar la bienvenida de Salgado una sola vez cuando Walter cruza la puerta | `nivel_urgencias.tscn` / IntroTrigger (Area2D) | Entrar, salir y volver a entrar: el diálogo aparece una vez | Propuesto |
| ESC-01 / V02 | **RF-N02:** el sistema debe abrir el panel de diagnóstico con los signos del caso cuando Walter interactúa con una camilla activa | `paciente.tscn` / Paciente (Area2D) + `hud.tscn` / PanelDiagnostico | Pulsar E lejos de la camilla no abre el panel; cerca sí | Propuesto |
| ESC-01 / V02–V03 | **RF-N03:** el sistema debe restar 10 de estabilidad ante un diagnóstico incorrecto y resolver el caso solo con diagnóstico e insumo correctos | `paciente.gd` | Diagnóstico erróneo → −10; insumo erróneo → no resuelve | Propuesto |
| B3 / V04 | **RF-N04:** el sistema debe transferir al paciente y restar 5 de reputación cuando su estabilidad llega a 0 | `paciente.gd` + `nivel_urgencias.gd` | Dejar caer la barra de Teresa: aparece «transferido» y reputación −5 | Propuesto |
| B4 / V05 | **RF-N05:** el sistema debe abrir el botiquín rojo solo cuando `ayuda_lucia == true` | BotiquinRojo (Area2D) / `botiquin.gd` | Antes de ayudar: «Necesitas el código»; después: se abre | Propuesto |
| ESC-02 / V06 | **RF-N06:** el sistema debe congelar la barra de Teresa durante B5 cuando `confianza == 2` | `nivel_urgencias.gd` / Teresa (Area2D) | Con confianza 2 la barra no cambia; con 1 baja 0,5/s | Propuesto |
| ESC-02 / V07 | **RF-N07:** el sistema debe reiniciar desde el punto de control de B5 si la estabilidad de Andrés llega a 0 | `nivel_urgencias.gd` | Dejar caer la barra de Andrés: reinicia en la llegada de la ambulancia sin repetir B1–B4 | Propuesto |
| ESC-02 / V08 | **RF-N08:** el sistema debe habilitar el tablón y asignar `rango = "Residente"` cuando `caso_andres_resuelto` y `reputacion >= 30` | TablonCapacitaciones (Area2D) + PanelCapacitacion | Con reputación 25 sigue bloqueado; con 35 se abre una sola vez | Propuesto |

## Cómo publicar (Actividad F)

```bash
git status
git add docs/narrativa/
git diff --cached --stat
git commit -m "docs(narrativa): define premisa, guion y storyboard de la primera guardia"
git push origin nombre-de-la-rama
```

Se usa `docs` y no `feat` porque nada de esto está implementado todavía. Después del push, abrir el enlace de la carpeta y del commit desde otra cuenta del equipo para verificar el acceso.

| Campo | Desarrollo del equipo |
|---|---|
| Repositorio | <https://github.com/Rippons/Bata-Blanca-Hospital-de-Pillbox> |
| Rama | `main` |
| Carpeta | [`docs/narrativa/`](https://github.com/Rippons/Bata-Blanca-Hospital-de-Pillbox/tree/main/docs/narrativa) |
| Commit y enlace | `e1d9684` · <https://github.com/Rippons/Bata-Blanca-Hospital-de-Pillbox/commit/e1d9684acf245955c459266b05c998bd284e6a84> |
| Integrante que verificó el acceso | __________ |
| Cambio pendiente y justificación | Conseguir licencias de AS-08, AS-09, AS-11 y AS-14 antes de integrarlos al build |

## Lista de chequeo (8.8)

| Criterio | Estado | Dónde se ve |
|---|---|---|
| Meta observable, conflicto, consecuencias, tono y acción relacionada | Sí | 01, sección 3 |
| Planteamiento, escalada, clímax preparado y consecuencia | Sí | 02, secciones 1 y 3 |
| Beats identificados; tensión y dificultad justificadas; respiro y reintento | Sí | 02, secciones 2–4 |
| Intro y clímax con trigger, acción, respuesta, salida y variantes | Sí | 03 |
| 6–8 viñetas legibles con cámara, acción, señal, audio y transición | Sí (8) | 04 |
| Nodos reales; nombres propios distinguidos de clases; eventos y estados | Sí | 05, secciones 2–4 |
| Assets con uso, archivo, origen, licencia, responsable y pendientes | Sí | 05, sección 5 |
| Personajes y reglas consistentes; historia → RF → escena → prueba | Sí | este README |
| Editables, exportaciones, README, commit publicado y enlaces | Sí (falta anotar quién verificó el acceso) | Actividad F |
| Distinguen propuesta de implementación | Sí | todos los archivos |

**Cierre del equipo.** Mejora prioritaria: implementar `paciente.gd` y el panel de diagnóstico (V02–V03), porque todo el nivel depende de ese ciclo. Responsable de consolidarla: __________. Archivo o escena afectada: `escenas/paciente.tscn`, `escenas/hud.tscn`.
