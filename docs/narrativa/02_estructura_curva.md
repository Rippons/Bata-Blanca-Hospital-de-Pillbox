# 02 · Estructura del nivel y curva de tensión

**Nivel:** Nivel 1 — *La primera guardia* · **Estado:** Propuesto
**Gráfico:** `02_curva_tension.png` (la numeración B1–B6 coincide con esta tabla)

## 1. Estructura en tres actos

| Acto / función | Beat | Qué pasa |
|---|---|---|
| I. Planteamiento / llamada | **B1** | El Dr. Salgado recibe a Walter y le asigna la guardia. Se ve el tablón de capacitaciones **bloqueado**. |
| I. Umbral / aprendizaje | **B2** | Primer caso básico (Don Ramiro). Se aprende el ciclo **examinar → diagnosticar → insumo → aplicar** sin presión real. |
| II. Pruebas / escalada | **B3** | Llega Teresa con fiebre; su barra baja más rápido. Lucía pide (opcional) firmar la hoja de triaje. Hay que priorizar. |
| II. Preparación de la prueba (respiro) | **B4** | Pausa: Lucía está sobrecargada y el carro de medicamentos está desordenado. Ayudarla da el **código del botiquín rojo**. |
| III. Clímax / prueba decisiva | **B5** | Llega Andrés en ambulancia con una reacción alérgica grave. Hay que aplicar todo lo aprendido y usar el botiquín rojo. |
| III. Desenlace / retorno | **B6** | Salgado evalúa la guardia. Si se cumplen los requisitos, se elige la primera capacitación y Walter sube a **Residente**. |

## 2. Tabla de beats (plantilla 3.3)

| Beat / acto | Qué cambia y qué hace el jugador | Tensión / dificultad y motivo | Señal / condición de avance |
|---|---|---|---|
| **B1 / I** | Walter entra a urgencias; Salgado le da la bienvenida y el objetivo. El jugador se mueve y lee. | **Tensión 2 / dificultad 1.** Hay expectativa (primera guardia, tablón bloqueado) pero ningún riesgo. | `intro_vista = true`; objetivo en HUD: «Atiende a Don Ramiro (camilla 1)». |
| **B2 / I** | Examina a Don Ramiro, elige «Herida superficial», toma vendaje del botiquín A y lo aplica. | **Tensión 3 / dificultad 2.** La barra de Ramiro baja muy lento (no puede llegar a 0 antes de 90 s): enseña la regla sin castigar. | `caso_ramiro_resuelto = true`; reputación +10 (o +5 si hubo un diagnóstico incorrecto). |
| **B3 / II** | Teresa entra con fiebre alta; su barra baja el doble de rápido. Lucía pide firmar la hoja de triaje en el mostrador (opcional, +1 confianza). El jugador decide el orden. | **Tensión 4 / dificultad 3.** Primera vez con tiempo real en contra y una decisión de prioridad. | `caso_teresa_resuelto = true`: Teresa queda **en observación** con estabilidad 70 (o es transferida si su barra llegó a 0). Si firmó: `triaje_firmado = true`, confianza +1. |
| **B4 / II (respiro)** | Lucía cuenta que está cubriendo doble turno y el carro de medicamentos está revuelto. El jugador ordena 3 insumos en su cajón correcto. | **Tensión 2 / dificultad 1.** Baja la exigencia para que el jugador **lea** el espacio: ve el botiquín rojo cerrado y entiende para qué es. Prepara B5. | `ayuda_lucia = true`; confianza +1; Lucía entrega el código → `botiquin_rojo_abierto = true`. |
| **B5 / III (clímax)** | Suena la sirena; Andrés llega a la camilla 3 con ronchas y dificultad para respirar. Examina, elige «Reacción alérgica grave», saca epinefrina del botiquín rojo y la aplica. Teresa sigue **en observación**: su barra vuelve a bajar lentamente durante B5. | **Tensión 5 / dificultad 4.** La barra de Andrés es la más rápida y el botiquín rojo tiene **una sola dosis**: no se puede improvisar. Si `confianza = 2`, Lucía sostiene a Teresa. | `caso_andres_resuelto = true`. Si la barra de Andrés llega a 0 → reintento desde el punto de control de B5. |
| **B6 / III** | Salgado revisa la guardia. Si `reputacion >= 30`, el tablón se ilumina y el jugador elige Urgencias, Pediatría o Cirugía. | **Tensión 2 / dificultad 1.** Cierre: la respuesta del mundo confirma la promesa (subir de rango). | `especialidad` asignada; `rango = "Residente"`; pantalla de fin de nivel. Si `reputacion < 30`: «Repite la guardia» desde B3. |

## 3. Lectura de la curva

- **Ascenso justificado (B2 → B3):** pasa de un paciente que casi no se deteriora a dos frentes a la vez (Teresa + petición de Lucía). Sube la tensión porque por primera vez algo se puede perder.
- **Descenso justificado (B3 → B4):** el respiro **no elimina el conflicto**: Lucía está sobrecargada y el botiquín rojo está cerrado. Baja la exigencia motriz para que el jugador observe y entienda que el código lo necesitará después.
- **Clímax preparado (B5):** exige el ciclo aprendido en B2, la prioridad aprendida en B3 y el código obtenido en B4. No aparece ninguna mecánica nueva.
- **Tensión ≠ dificultad:** en B1 la tensión es 2 con dificultad 1 (expectativa sin riesgo); en B5 ambas suben, pero la tensión la aporta sobre todo la sirena y la dosis única, no más pacientes.

## 4. Reintento y recuperación

| Situación | Qué pasa | Señal |
|---|---|---|
| Diagnóstico incorrecto | La estabilidad baja 10 puntos y se puede volver a elegir. La reputación del caso baja de +10 a +5. | Texto: «Eso no encaja con los signos. Revisa otra vez». SFX grave + borde rojo en el panel. |
| Estabilidad de Ramiro o Teresa llega a 0 | Paciente transferido; reputación −5; el nivel continúa. | Barra roja parpadeante; Lucía: «Lo está tomando el doctor de turno». |
| Estabilidad de Andrés llega a 0 | Se reinicia desde el **punto de control de B5** (llegada de la ambulancia), sin repetir B1–B4. | Fundido corto + texto «Inténtalo otra vez: revisa los signos y el botiquín rojo». |
| Reputación < 30 al final | Salgado no habilita el tablón; se repite la guardia desde **B3**. | Salgado: «Buen esfuerzo, pero aún no estás listo. Repite el turno». |

## 5. Rutas posibles

- **Ruta principal:** B1 → B2 → B3 (atiende a Teresa y firma el triaje) → B4 → B5 (Lucía sostiene a Teresa) → B6.
- **Bifurcación en B3:** si no firma el triaje, `confianza` queda en 1 tras B4 y en B5 la barra de Teresa sigue bajando mientras atiende a Andrés (más difícil). Ambas ramas se reúnen en **B5**.
