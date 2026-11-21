"""Genera la música y los efectos de sonido del juego (estilo chiptune / 16 bits).

Todo el audio es sintetizado por código, así que es original y sin problemas de licencia.
Uso:  python3 herramientas/generar_audio.py      (escribe en audio/)
"""
import os
import wave
import numpy as np

SR = 22050
SALIDA = os.path.join(os.path.dirname(__file__), "..", "audio")

NOTAS = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6,
         "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def hz(nota: str) -> float:
    """'A4' -> 440.0"""
    nombre, octava = nota[:-1], int(nota[-1])
    n = NOTAS[nombre] + (octava + 1) * 12
    return 440.0 * 2 ** ((n - 69) / 12)


def onda(tipo: str, f: float, n: int, ciclo: float = 0.5) -> np.ndarray:
    t = np.arange(n) / SR
    fase = (t * f) % 1.0
    if tipo == "seno":
        return np.sin(2 * np.pi * f * t)
    if tipo == "triangulo":
        return 4 * np.abs(fase - 0.5) - 1
    if tipo == "cuadrada":
        return np.where(fase < ciclo, 1.0, -1.0)
    if tipo == "ruido":
        return np.random.uniform(-1, 1, n)
    raise ValueError(tipo)


def envolvente(n: int, a: float, d: float, s: float, r: float) -> np.ndarray:
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    s_n = max(n - a_n - d_n - r_n, 0)
    e = np.concatenate([
        np.linspace(0, 1, a_n, endpoint=False),
        np.linspace(1, s, d_n, endpoint=False),
        np.full(s_n, s),
        np.linspace(s, 0, r_n),
    ])
    return np.pad(e, (0, max(n - len(e), 0)))[:n]


def pasa_bajos(x: np.ndarray, corte: float) -> np.ndarray:
    a = np.exp(-2 * np.pi * corte / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def nota_en(pista, inicio_s, dur_s, nota, tipo, vol, adsr=(0.01, 0.1, 0.6, 0.1), ciclo=0.5):
    n = int(dur_s * SR)
    i = int(inicio_s * SR)
    if nota is None or i >= len(pista):
        return
    f = hz(nota) if isinstance(nota, str) else nota
    s = onda(tipo, f, n, ciclo) * envolvente(n, *adsr) * vol
    fin = min(i + n, len(pista))
    pista[i:fin] += s[: fin - i]


def eco(x: np.ndarray, retardo_s: float, realim: float, mezcla: float) -> np.ndarray:
    d = int(retardo_s * SR)
    y = x.copy()
    for k in range(1, 5):
        g = mezcla * realim ** (k - 1)
        y[d * k:] += x[: len(x) - d * k] * g
    return y


def guardar(nombre: str, x: np.ndarray, pico: float = 0.8) -> None:
    x = x / (np.max(np.abs(x)) + 1e-9) * pico
    datos = (x * 32767).astype(np.int16)
    os.makedirs(SALIDA, exist_ok=True)
    ruta = os.path.join(SALIDA, nombre)
    with wave.open(ruta, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(datos.tobytes())
    print(f"{ruta}  {len(x) / SR:.1f} s")


def acorde(raiz_oct: str, intervalos):
    base = hz(raiz_oct)
    return [base * 2 ** (i / 12) for i in intervalos]


# ---------------------------------------------------------------------------------
def musica_hospital() -> np.ndarray:
    """Tranquila: 72 bpm, Do mayor, pads suaves + arpegio de triángulo + melodía seno."""
    bpm = 72
    pulso = 60 / bpm
    compas = 4 * pulso
    progresion = [("C3", [0, 4, 7, 11]), ("A2", [0, 3, 7, 10]), ("F2", [0, 4, 7, 11]), ("G2", [0, 4, 7, 9])]
    compases = 16
    total = int(compases * compas * SR)
    pad = np.zeros(total)
    arp = np.zeros(total)
    bajo = np.zeros(total)
    mel = np.zeros(total)
    melodia = [  # (compás, pulso, duración en pulsos, nota)
        (4, 0, 2, "E5"), (4, 2, 2, "G5"), (5, 0, 3, "E5"), (6, 0, 2, "C5"), (6, 2, 2, "D5"), (7, 0, 4, "B4"),
        (8, 0, 2, "G5"), (8, 2, 2, "A5"), (9, 0, 3, "E5"), (10, 0, 2, "F5"), (10, 2, 2, "E5"), (11, 0, 4, "D5"),
        (12, 0, 2, "E5"), (12, 2, 2, "C5"), (13, 0, 3, "A4"), (14, 0, 2, "C5"), (14, 2, 2, "B4"), (15, 0, 4, "G4"),
    ]
    for c in range(compases):
        raiz, iv = progresion[c % 4]
        frecs = acorde(raiz, iv)
        t0 = c * compas
        for f in frecs:
            nota_en(pad, t0, compas + 0.4, f * 2, "seno", 0.10, (0.8, 0.5, 0.7, 0.8))
            nota_en(pad, t0, compas + 0.4, f * 2 * 1.004, "seno", 0.07, (0.8, 0.5, 0.7, 0.8))
        nota_en(bajo, t0, 2 * pulso, frecs[0], "seno", 0.35, (0.02, 0.3, 0.5, 0.3))
        nota_en(bajo, t0 + 2 * pulso, 2 * pulso, frecs[0] * 1.5, "seno", 0.25, (0.02, 0.3, 0.5, 0.3))
        patron = [0, 1, 2, 3, 2, 1, 2, 3]
        for k, idx in enumerate(patron):
            nota_en(arp, t0 + k * pulso / 2, pulso / 2, frecs[idx] * 4, "triangulo", 0.09, (0.005, 0.15, 0.2, 0.1))
    for comp, p, dur, nota in melodia:
        nota_en(mel, comp * compas + p * pulso, dur * pulso, nota, "seno", 0.16, (0.08, 0.3, 0.6, 0.4))
        nota_en(mel, comp * compas + p * pulso, dur * pulso, hz(nota) * 2, "triangulo", 0.03, (0.08, 0.3, 0.5, 0.4))
    mezcla = pad + arp + bajo + eco(mel, pulso * 0.75, 0.45, 0.35)
    return _cerrar_ciclo(mezcla)


def musica_casa() -> np.ndarray:
    """Hogareña: 96 bpm, Fa mayor, chiptune suave (cuadradas filtradas, bajo y hi-hat)."""
    bpm = 96
    pulso = 60 / bpm
    compas = 4 * pulso
    progresion = [("F2", [0, 4, 7, 11]), ("D2", [0, 3, 7, 10]), ("Bb1", [0, 4, 7, 11]), ("C2", [0, 4, 7, 10])]
    compases = 16
    total = int(compases * compas * SR)
    acordes = np.zeros(total)
    bajo = np.zeros(total)
    mel = np.zeros(total)
    perc = np.zeros(total)
    melodia_base = [  # notas por corcheas (None = silencio), 8 por compás
        ["A4", None, "C5", None, "F5", "E5", "C5", None],
        ["D5", None, "C5", "A4", None, "F4", "A4", None],
        ["Bb4", None, "D5", None, "F5", None, "D5", "C5"],
        ["E5", None, "G5", None, "E5", "C5", None, None],
    ]
    melodia_b = [
        ["C5", "A4", "C5", "F5", None, "G5", "A5", None],
        ["F5", None, "D5", None, "A4", None, "D5", None],
        ["D5", "F5", None, "Bb5", "A5", None, "F5", None],
        ["G5", None, "E5", None, "C5", None, None, None],
    ]
    for c in range(compases):
        raiz, iv = progresion[c % 4]
        frecs = acorde(raiz, iv)
        t0 = c * compas
        for k in range(4):   # acordes en negras, staccato
            for f in frecs[1:]:
                nota_en(acordes, t0 + k * pulso, pulso * 0.45, f * 2, "cuadrada", 0.035, (0.005, 0.08, 0.4, 0.06), 0.25)
        for k, mult in enumerate([1, 1, 1.5, 1, 1, 1, 2, 1.5]):
            nota_en(bajo, t0 + k * pulso / 2, pulso / 2 * 0.8, frecs[0] * mult, "triangulo", 0.30, (0.005, 0.1, 0.6, 0.05))
        for k in range(8):
            vol = 0.018 if k % 2 == 0 else 0.009
            nota_en(perc, t0 + k * pulso / 2, 0.03, 8000.0, "ruido", vol, (0.001, 0.02, 0.0, 0.005))
        if c >= 4:
            frase = melodia_base if (c // 4) % 2 == 1 else melodia_b
            for k, nota in enumerate(frase[c % 4]):
                nota_en(mel, t0 + k * pulso / 2, pulso / 2 * 0.9, nota, "cuadrada", 0.07, (0.005, 0.1, 0.5, 0.05), 0.125)
    acordes = pasa_bajos(acordes, 2500)
    mel = pasa_bajos(mel, 3500)
    mezcla = acordes + bajo + pasa_bajos(perc, 6000) + eco(mel, pulso * 0.75, 0.4, 0.3)
    return _cerrar_ciclo(pasa_bajos(mezcla, 4500))


def musica_barrio() -> np.ndarray:
    """Exterior de la casa: 112 bpm, Sol mayor, alegre y al aire libre (pulsos, bajo saltarín, pajaritos)."""
    bpm = 112
    pulso = 60 / bpm
    compas = 4 * pulso
    progresion = [("G2", [0, 4, 7]), ("E2", [0, 3, 7]), ("C2", [0, 4, 7, 11]), ("D2", [0, 4, 7])]
    compases = 16
    total = int(compases * compas * SR)
    acordes = np.zeros(total)
    bajo = np.zeros(total)
    mel = np.zeros(total)
    perc = np.zeros(total)
    aves = np.zeros(total)
    frase_a = [
        ["B4", "D5", "G5", None, "F#5", None, "D5", None],
        ["E5", None, "G5", "B5", None, "A5", "G5", None],
        ["E5", "G5", None, "C6", "B5", None, "G5", "E5"],
        ["F#5", None, "A5", None, "D5", None, None, None],
    ]
    frase_b = [
        ["D5", None, "B4", "D5", "G5", None, "A5", "B5"],
        ["G5", None, "E5", None, "B4", None, "E5", None],
        ["C5", "E5", "G5", None, "E5", None, "C5", None],
        ["D5", "F#5", "A5", None, "F#5", None, "D5", None],
    ]
    rng = np.random.default_rng(7)
    for c in range(compases):
        raiz, iv = progresion[c % 4]
        frecs = acorde(raiz, iv)
        t0 = c * compas
        for k in (1, 3, 5, 7):   # acordes a contratiempo, como guitarra
            for f in frecs[1:]:
                nota_en(acordes, t0 + k * pulso / 2, pulso * 0.3, f * 2, "cuadrada", 0.03, (0.003, 0.06, 0.3, 0.04), 0.25)
        for k, mult in enumerate([1, 1.5, 2, 1.5]):
            nota_en(bajo, t0 + k * pulso, pulso * 0.7, frecs[0] * mult, "triangulo", 0.28, (0.005, 0.1, 0.5, 0.05))
        for k in range(8):
            vol = 0.02 if k % 2 == 1 else 0.008
            nota_en(perc, t0 + k * pulso / 2, 0.03, 9000.0, "ruido", vol, (0.001, 0.02, 0.0, 0.005))
        nota_en(perc, t0, 0.08, 120.0, "triangulo", 0.25, (0.001, 0.06, 0.0, 0.02))
        nota_en(perc, t0 + 2 * pulso, 0.08, 120.0, "triangulo", 0.2, (0.001, 0.06, 0.0, 0.02))
        if c >= 2:
            frase = frase_a if (c // 4) % 2 == 0 else frase_b
            for k, nota in enumerate(frase[c % 4]):
                nota_en(mel, t0 + k * pulso / 2, pulso / 2 * 0.75, nota, "triangulo", 0.16, (0.003, 0.08, 0.4, 0.05))
                nota_en(mel, t0 + k * pulso / 2, pulso / 2 * 0.5, nota, "cuadrada", 0.03, (0.003, 0.05, 0.2, 0.03), 0.125)
        if c % 3 == 1:   # pajaritos: silbidos cortos que suben
            for j in range(rng.integers(2, 4)):
                ini = t0 + rng.uniform(0, compas - 0.3)
                n = int(0.09 * SR)
                f = np.linspace(rng.uniform(2600, 3200), rng.uniform(3600, 4300), n)
                ph = 2 * np.pi * np.cumsum(f) / SR
                tono = np.sin(ph) * np.hanning(n) * 0.03
                i0 = int(ini * SR)
                aves[i0:i0 + n] += tono[: max(0, min(n, total - i0))]
    acordes = pasa_bajos(acordes, 3000)
    mel = pasa_bajos(mel, 4500)
    mezcla = acordes + bajo + pasa_bajos(perc, 7000) + eco(mel, pulso * 0.5, 0.3, 0.25) + aves
    return _cerrar_ciclo(pasa_bajos(mezcla, 6000))


def sfx_aplausos() -> np.ndarray:
    """Aplausos: muchos chasquidos cortos de ruido, 2.5 s."""
    rng = np.random.default_rng(11)
    total = int(2.5 * SR)
    x = np.zeros(total)
    for _ in range(260):
        i0 = int(rng.uniform(0, 2.3) * SR)
        n = int(0.012 * SR)
        golpe = rng.normal(0, 1, n) * np.exp(-np.linspace(0, 6, n))
        x[i0:i0 + n] += golpe * rng.uniform(0.15, 0.35)
    env = np.minimum(1, np.linspace(0, 2.5, total) / 0.2) * np.minimum(1, (2.5 - np.linspace(0, 2.5, total)) / 0.6)
    return pasa_bajos(x * env, 5000) * 0.6


def sfx_llanto() -> np.ndarray:
    """Llanto de bebé: «uaaa» que sube y baja, dos veces."""
    t = np.arange(int(1.6 * SR)) / SR
    f = 420 + 160 * np.sin(2 * np.pi * 1.25 * t) ** 2
    ph = 2 * np.pi * np.cumsum(f) / SR
    voz = np.sign(np.sin(ph)) * 0.25 + np.sin(ph * 2) * 0.2
    env = (np.sin(np.pi * np.clip(t / 0.8, 0, 1)) + np.sin(np.pi * np.clip((t - 0.8) / 0.8, 0, 1))) * 0.8
    return pasa_bajos(voz * env, 2500) * 0.6


def sfx_trueno() -> np.ndarray:
    """Trueno: estallido de ruido grave con retumbo largo."""
    rng = np.random.default_rng(5)
    total = int(3.0 * SR)
    t = np.arange(total) / SR
    ruido = rng.normal(0, 1, total)
    env = np.exp(-t * 1.4) * (1 + 0.6 * np.sin(2 * np.pi * 3 * t) ** 2)
    env[: int(0.03 * SR)] *= np.linspace(0, 1, int(0.03 * SR))
    return pasa_bajos(ruido * env, 400) * 0.9


def _cerrar_ciclo(x: np.ndarray) -> np.ndarray:
    """Suaviza el punto de bucle con un fundido muy corto."""
    n = int(0.03 * SR)
    x[:n] *= np.linspace(0, 1, n)
    x[-n:] *= np.linspace(1, 0, n)
    return x


# ---------------------------------------------------------------------------------
def blip() -> np.ndarray:
    n = int(0.045 * SR)
    return onda("cuadrada", 600.0, n, 0.5) * envolvente(n, 0.002, 0.03, 0.2, 0.01)


def seleccion() -> np.ndarray:
    x = np.zeros(int(0.12 * SR))
    nota_en(x, 0.0, 0.05, "E6", "cuadrada", 0.5, (0.001, 0.03, 0.4, 0.01), 0.25)
    nota_en(x, 0.05, 0.07, "B6", "cuadrada", 0.5, (0.001, 0.04, 0.3, 0.02), 0.25)
    return x


def altavoz() -> np.ndarray:
    x = np.zeros(int(1.3 * SR))
    for t, nota in [(0.0, "E5"), (0.35, "C5")]:
        nota_en(x, t, 0.9, nota, "seno", 0.6, (0.005, 0.2, 0.4, 0.6))
        nota_en(x, t, 0.9, hz(nota) * 2, "seno", 0.15, (0.005, 0.2, 0.3, 0.6))
    return x


def puerta() -> np.ndarray:
    x = np.zeros(int(0.35 * SR))
    for t in (0.0, 0.12):
        n = int(0.08 * SR)
        s = pasa_bajos(onda("ruido", 0, n), 900) * envolvente(n, 0.001, 0.05, 0.0, 0.02)
        s += onda("seno", 110.0, n) * envolvente(n, 0.001, 0.06, 0.0, 0.02) * 0.6
        i = int(t * SR)
        x[i:i + n] += s
    return x


def alarma() -> np.ndarray:
    x = np.zeros(int(1.0 * SR))
    for k in range(4):
        nota_en(x, k * 0.25, 0.12, "A6", "cuadrada", 0.5, (0.001, 0.02, 0.8, 0.01), 0.5)
    return x


def exito() -> np.ndarray:
    x = np.zeros(int(0.6 * SR))
    for k, nota in enumerate(["C5", "E5", "G5", "C6"]):
        nota_en(x, k * 0.08, 0.25, nota, "cuadrada", 0.35, (0.002, 0.08, 0.4, 0.1), 0.25)
    return x


def error() -> np.ndarray:
    x = np.zeros(int(0.35 * SR))
    nota_en(x, 0.0, 0.14, "E3", "cuadrada", 0.5, (0.002, 0.05, 0.6, 0.03), 0.5)
    nota_en(x, 0.15, 0.18, "C3", "cuadrada", 0.5, (0.002, 0.05, 0.6, 0.05), 0.5)
    return x


if __name__ == "__main__":
    np.random.seed(7)
    guardar("musica_hospital.wav", musica_hospital(), 0.7)
    guardar("musica_casa.wav", musica_casa(), 0.7)
    guardar("musica_barrio.wav", musica_barrio(), 0.7)
    guardar("aplausos.wav", sfx_aplausos(), 0.8)
    guardar("llanto.wav", sfx_llanto(), 0.7)
    guardar("trueno.wav", sfx_trueno(), 0.9)
    guardar("blip.wav", blip(), 0.6)
    guardar("seleccion.wav", seleccion(), 0.5)
    guardar("altavoz.wav", altavoz(), 0.7)
    guardar("puerta.wav", puerta(), 0.7)
    guardar("alarma.wav", alarma(), 0.5)
    guardar("exito.wav", exito(), 0.6)
    guardar("error.wav", error(), 0.5)
