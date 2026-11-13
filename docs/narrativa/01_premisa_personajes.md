# 01 · Premisa y personajes

**Juego:** *Bata Blanca: Hospital de Pillbox* (2D, vista cenital, Godot 4.5)
**Nivel elegido:** Nivel 1 — *La primera guardia* (sala de urgencias del Hospital de Pillbox)
**Estado general:** todo lo de este documento es **Propuesto**; aún no existe build del nivel.

---

## 1. Historia y mecánica (relación con la sección 1 del taller)

| Promesa de la historia | Acción / regla | Señal visible en el build |
|---|---|---|
| Walter asciende en el área médica atendiendo bien a sus pacientes | Examinar al paciente, elegir el diagnóstico entre tres opciones y aplicar el insumo correcto | La barra de **estabilidad** del paciente se llena en verde y la barra de **reputación** del HUD sube |
| Walter ayuda a sus compañeros con sus problemas | Ayudar a la enfermera Lucía a ordenar el carro de medicamentos | Lucía entrega el código del **botiquín rojo** y el indicador de **confianza** sube |
| Cada capacitación hace subir de rango | Al cumplir los requisitos se habilita el **tablón de capacitaciones** y se elige una especialidad | El texto de rango del HUD cambia de «Interno» a «Residente» |

**Pregunta de control.** Si se oculta la sinopsis, el jugador entiende jugando que es un médico que atiende pacientes (barras de estabilidad), que lo hace mejor o peor (reputación) y que hay algo que desbloquear (el tablón bloqueado con requisitos visibles).

---

## 2. Premisa de toda la campaña (contexto, no se implementa en este nivel)

Walter Vega empieza como **médico interno** en el Hospital de Pillbox. Su meta de largo plazo es llegar a **director del hospital**. Cada nivel es una guardia; al resolver casos cada vez menos básicos y cumplir requisitos de reputación y confianza, puede tomar una **capacitación** que lo hace subir de rango y lo orienta a una especialidad.

| Rango | Cómo se alcanza | Nivel previsto |
|---|---|---|
| Interno | Inicio del juego | Nivel 1 |
| Residente | Primera capacitación (elige especialidad: Urgencias, Pediatría o Cirugía) | Fin del Nivel 1 |
| Especialista | Segunda capacitación dentro de la especialidad elegida | Nivel 2–3 (propuesto) |
| Jefe de servicio | Reputación alta + resolver el problema de un equipo completo | Nivel 4 (propuesto) |
| Director del Hospital de Pillbox | Evaluación final del Dr. Salgado según reputación y confianza acumuladas | Nivel final (propuesto) |

> Para el taller solo se diseña y documenta el **Nivel 1**. Los rangos siguientes quedan como propuesta de alcance.

---

## 3. Ficha de premisa y personaje (plantilla 2.3)

| Campo | Desarrollo del equipo |
|---|---|
| **Nombre del juego y nivel elegido** | *Bata Blanca: Hospital de Pillbox* — Nivel 1 «La primera guardia». |
| **Logline** | Cuando la sala de urgencias del Hospital de Pillbox se satura en su primera guardia, el interno Walter Vega debe estabilizar a sus pacientes pese a los insumos limitados y al tiempo que corre en cada camilla, para evitar que los casos sean transferidos a otro médico y perder la oportunidad de su primera capacitación. |
| **Protagonista / rol controlado** | Nombre: **Dr. Walter Vega**, médico interno. Capacidades: moverse por la sala, **examinar** pacientes, **elegir diagnóstico**, **tomar y aplicar insumos** de los botiquines, **hablar y ayudar** a compañeros. Límites: no puede atender a dos pacientes a la vez, solo carga **un insumo** a la vez y no puede abrir el botiquín rojo sin el código. |
| **Objetivo verificable** | Se considera alcanzado cuando el sistema registra `caso_andres_resuelto = true` **y** `reputacion >= 30`; entonces se habilita el tablón y, al elegir una capacitación, `rango = "Residente"`. |
| **Motivación / cambio esperado** | Desea demostrarle al Dr. Salgado que merece subir de rango. Al final comprende que **no puede solo**: el caso más grave se resuelve porque antes ayudó a Lucía (código del botiquín rojo). |
| **Conflicto y obstáculo** | Se oponen **la saturación de urgencias y el deterioro de los pacientes**: cada paciente tiene una barra de estabilidad que baja con el tiempo, y los insumos son limitados. El jugador lo enfrenta priorizando a quién atender, diagnosticando bien al primer intento y no desperdiciando insumos. No hay villano. |
| **Lo que está en juego** | Si la estabilidad de un paciente llega a 0, el paciente es **transferido** a otro médico (no muere: tono esperanzador) y Walter pierde 5 de reputación. Si termina la guardia con reputación < 30, no puede tomar la capacitación y debe repetir la guardia desde el punto de control. Se comunica con la barra roja parpadeante y el texto de Lucía: «Lo está tomando el doctor de turno». |
| **Aliado / personaje secundario** | **Lucía Mendoza**, enfermera jefe de urgencias. Da el objetivo de cada caso, pide ayuda con el carro de medicamentos y entrega el código del botiquín rojo. Si `confianza = 2`, en el clímax **sostiene** la estabilidad de Teresa, que sigue en observación (su barra deja de bajar). Lucía no diagnostica por el jugador. |
| **Evaluador / mentor** | **Dr. Arturo Salgado**, director actual del Hospital de Pillbox. Abre la guardia (ESC-01) y evalúa al final (B6). |
| **Pacientes del nivel** | **Don Ramiro** (caso básico: corte en la mano), **Teresa** (caso básico: fiebre alta), **Andrés** (caso no básico: reacción alérgica grave, llega en ambulancia). |
| **Tono** | Dos rasgos: **tensión esperanzadora** y **calidez humana**. Visual: sala blanca con luces cálidas; el rojo solo aparece en barras críticas y en el botiquín rojo. Sonoro: ambiente tranquilo de hospital que cambia a una **sirena** cuando llega la ambulancia, y un tono suave de confirmación al estabilizar. Sin sangre explícita ni muertes. |
| **Acciones y límites del alcance** | Verbos del jugador: **moverse, examinar, diagnosticar, tomar insumo, aplicar, hablar, ordenar** (carro). No se incluirá: cirugías detalladas, gestión de varios pisos, combate, muerte de pacientes ni cinemáticas largas. |
| **Estado del prototipo** | Ya existe: nada de este nivel (el equipo tiene experiencia previa con Godot 4.5 en otro proyecto 2D). Propuesta para este nivel: sala de urgencias con 3 camillas, 2 botiquines, carro de medicamentos, tablón y HUD. |
| **Comprobación en pantalla** | El objetivo se entiende al ver el texto de objetivo del HUD («Atiende a Don Ramiro») y las barras de estabilidad sobre cada camilla; su consecuencia se ve en la barra de reputación, en el tablón que pasa de gris a habilitado y en el rango «Residente» del HUD. |

---

## 4. Revisión de la ficha (sección 2.4)

| Relación | ¿Existe en el sistema? | Qué falta construir |
|---|---|---|
| **Objetivo → acción** | Sí, en diseño: diagnosticar + aplicar insumo cambia `estabilidad` y `reputacion`. | Script `paciente.gd` y panel de diagnóstico. |
| **Obstáculo → regla** | Sí, en diseño: `estabilidad` baja cada segundo según `velocidad_deterioro` del caso; insumos limitados por botiquín. | Lógica de deterioro y contador de insumos. |
| **Consecuencia → señal** | Sí, en diseño: barra roja + transferencia; barra de reputación; tablón habilitado; rango en HUD. | HUD y tablón. Ninguna está implementada todavía. |

**Error que evitamos.** «Walter es un médico dedicado» no orienta a nadie. En su lugar: «Walter ve que la barra de Teresa baja mientras Lucía le pide ayuda; el jugador decide si atender primero a Teresa o ir al carro».

---

## 5. Nombres definitivos (no cambiar entre documentos)

- Personajes: **Walter Vega**, **Lucía Mendoza**, **Arturo Salgado**, **Don Ramiro**, **Teresa**, **Andrés**.
- Lugares/objetos: **Hospital de Pillbox**, sala de urgencias, **botiquín A**, **botiquín rojo**, **carro de medicamentos**, **tablón de capacitaciones**.
- Variables de estado: `intro_vista`, `caso_ramiro_resuelto`, `caso_teresa_resuelto`, `triaje_firmado`, `ayuda_lucia`, `botiquin_rojo_abierto`, `caso_andres_resuelto`, `reputacion`, `confianza`, `rango`, `especialidad`.
- Escenas narrativas: **ESC-01** «La primera guardia» (intro) y **ESC-02** «La ambulancia» (clímax).
