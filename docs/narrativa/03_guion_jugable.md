# 03 · Guion jugable de dos escenas

**Nivel:** Nivel 1 — *La primera guardia* · **Estado:** Propuesto
Nombres, objetos y variables iguales a `01_premisa_personajes.md`.

---

## Regla común: ciclo de atención a un paciente

Se usa en ESC-01 (Don Ramiro) y se vuelve a exigir en ESC-02 (Andrés). Así el clímax no introduce nada nuevo.

1. **Examinar:** Walter entra al área de la camilla y pulsa **E** (acción `interactuar`). Se abre el panel de diagnóstico con los **signos** del caso.
2. **Diagnosticar:** el jugador elige 1 de 3 botones. Correcto → el panel se cierra y el objetivo cambia a «Busca el insumo». Incorrecto → estabilidad −10 y puede volver a elegir.
3. **Tomar insumo:** en el botiquín correspondiente pulsa **E**. Walter carga **un solo insumo** (icono sobre su cabeza).
4. **Aplicar:** vuelve a la camilla y pulsa **E**. Si el insumo coincide con el caso, la estabilidad sube a 100 y el caso se marca resuelto.

| Caso | Signos visibles | Diagnóstico correcto | Insumo y botiquín |
|---|---|---|---|
| Don Ramiro | Corte en la palma, sangrado leve, consciente | Herida superficial | Vendaje · botiquín A |
| Teresa | Temperatura 39,5 °C, escalofríos, cansancio | Fiebre alta | Antipirético · botiquín A |
| Andrés | Ronchas en brazos y cuello, dificultad para respirar, comió maní hace 10 min | Reacción alérgica grave | Epinefrina · botiquín rojo (1 dosis) |

---

## ESC-01 · La primera guardia (introducción)

| Campo | Desarrollo del equipo |
|---|---|
| **ID, nombre y ubicación** | ESC-01 · La primera guardia · Lugar: entrada y camilla 1 de la sala de urgencias del Hospital de Pillbox. |
| **Propósito / beat relacionado** | El jugador debe comprender que su meta es atender bien a los pacientes para poder tomar una capacitación, y aprender el ciclo de atención. Beats: **B1** y **B2**. |
| **Trigger y precondición** | Ocurre cuando Walter entra al área `IntroTrigger` (puerta de urgencias) y se cumple `intro_vista == false`. |
| **Acción del jugador** | Puede moverse libremente (no se le quita el control), acercarse a Salgado, mirar el tablón de capacitaciones bloqueado y atender a Don Ramiro. Controles: **WASD/flechas** moverse, **E** interactuar, **1–3** o clic para elegir diagnóstico. |
| **Diálogo / texto** | Salgado: «Bienvenido a Pillbox, Pinkman. Hoy cubres urgencias con Lucía». Salgado: «Si haces bien tu guardia, el tablón de capacitaciones se abre para ti». Lucía: «Don Ramiro, camilla 1. Se cortó cocinando». Objetivo en HUD: **«Atiende a Don Ramiro (camilla 1)»**. Al acercarse al tablón: «Bloqueado · Requisito: reputación 30 y terminar la guardia». |
| **Respuesta del sistema** | Se muestra el diálogo en `TextoDialogo`, se marca `intro_vista = true`, la camilla 1 se resalta con un contorno y aparece la barra de estabilidad de Ramiro (empieza en 80, baja 0,5/s). Al resolver: `caso_ramiro_resuelto = true`, reputación +10 (o +5 si falló un diagnóstico), objetivo cambia a «Espera al siguiente paciente». |
| **Cámara / audio / SFX** | Encuadre: cámara cenital que sigue a Walter; la puerta, el tablón y la camilla 1 caben en la misma pantalla. Sonido: ambiente suave de hospital; «bip» al abrir el panel; tono de confirmación al estabilizar. Alternativa visual: todo diálogo va con texto y el acierto se ve en la barra verde llena. |
| **Salida / fallo / reentrada** | Avanza a B3 si `caso_ramiro_resuelto == true` (Teresa entra 3 s después). Si falla el diagnóstico: estabilidad −10, texto «Eso no encaja con los signos. Revisa otra vez» y puede reintentar; la barra de Ramiro no llega a 0 en este beat (mínimo 20). Al volver a pasar por la puerta **no** se repite la bienvenida porque `intro_vista` ya es verdadero; el objetivo sigue visible en el HUD mientras no se complete. |

**Por qué funciona.** La meta (capacitación) se ve en el tablón bloqueado; la regla (estabilidad que baja) se aprende con un caso que no castiga; la salida depende de un estado comprobable (`caso_ramiro_resuelto`).

---

## ESC-02 · La ambulancia (clímax y consecuencia)

| Campo | Desarrollo del equipo |
|---|---|
| **ID, nombre y ubicación** | ESC-02 · La ambulancia · Lugar: camilla 3 (junto a la entrada de ambulancias) y botiquín rojo de la sala de urgencias. |
| **Propósito / beat relacionado** | El jugador debe aplicar el ciclo de atención bajo la presión más alta, usando el código del botiquín rojo que obtuvo al ayudar a Lucía, y ver la consecuencia en su ascenso. Beats: **B5** y **B6**. |
| **Trigger y precondición** | Ocurre cuando termina `TimerAmbulancia` (10 s) y se cumple `ayuda_lucia == true` (el temporizador se inicia al terminar B4). |
| **Acción del jugador** | Puede examinar a Andrés, diagnosticar, ir al botiquín rojo (ya abierto), tomar la epinefrina y aplicarla. También puede ir a revisar a Teresa, que sigue en observación. Controles: los mismos de ESC-01. |
| **Diálogo / texto** | Lucía: «¡Ambulancia! Andrés, 24 años. Le cuesta respirar». Andrés (al examinar): «Comí algo con maní… me pica todo». Si `confianza == 2` — Lucía: «Yo me quedo con Teresa, ve tú». Si `confianza < 2` — Lucía: «Tengo que ir al mostrador, ¡no descuides a Teresa!». Objetivo en HUD: **«Estabiliza a Andrés (camilla 3)»**. Al resolver, Salgado: «Así se trabaja en Pillbox. Elige tu capacitación». |
| **Respuesta del sistema** | Aparece Andrés en la camilla 3 con estabilidad 60 que baja 3/s. Teresa vuelve a bajar 0,5/s **salvo** si `confianza == 2` (su barra se congela). Si el diagnóstico y el insumo son correctos: estabilidad de Andrés a 100, `caso_andres_resuelto = true`, reputación +15. Entonces, si `reputacion >= 30`, el tablón cambia de gris a dorado y se abre `PanelCapacitacion` con tres botones: **Urgencias, Pediatría, Cirugía**. Al elegir: `especialidad` asignada y `rango = "Residente"` en el HUD. |
| **Cámara / audio / SFX** | Encuadre: la cámara sigue a Walter, pero la camilla 3 y el botiquín rojo deben verse en el mismo encuadre (están a pocos pasos); la barra de Andrés nunca queda tapada por el panel. Sonido: sirena posicional (`AudioStreamPlayer2D`) que viene de la entrada de ambulancias; latido acelerado cuando la barra de Andrés < 30; tono de confirmación al estabilizar; fanfarria corta al subir de rango. Alternativa visual: borde rojo parpadeante en la barra crítica y texto «¡Crítico!». |
| **Salida / fallo / reentrada** | Avanza (fin del nivel) si `caso_andres_resuelto == true` **y** se elige una capacitación. Si falla el diagnóstico: estabilidad −10 y reintenta. La epinefrina es **una sola dosis**: si se aplica a otro paciente se pierde y el sistema lo indica («Ese insumo no corresponde. La epinefrina se perdió»); en ese caso, y si la barra de Andrés llega a 0, se reinicia desde el **punto de control de B5**, con el botiquín rojo recargado. Si `reputacion < 30` al resolver a Andrés, Salgado dice «Aún no estás listo. Repite el turno» y se reinicia desde B3. El cierre no se dispara dos veces: `PanelCapacitacion` solo se abre si `especialidad == ""`. |

**Por qué funciona.** El clímax usa el ciclo aprendido en ESC-01, la prioridad aprendida en B3 y el código de B4. La consecuencia (subir de rango) responde directamente al objetivo planteado en ESC-01 (el tablón bloqueado).
