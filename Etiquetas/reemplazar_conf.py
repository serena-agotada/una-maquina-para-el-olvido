import os
import random

# === CONFIGURACIÓN ===
CARPETA = "Etiquetas"   # Ruta de la carpeta donde están los .json
PROBABILIDAD = 0.5    # Probabilidad de reemplazo (0.5 = 50%)

# === SCRIPT ===
for archivo in os.listdir(CARPETA):
    if archivo.endswith(".json"):
        ruta = os.path.join(CARPETA, archivo)
        
        with open(ruta, "r", encoding="utf-8") as f:
            contenido = f.read()
        
        # Encontrar todas las posiciones de "Confidence": 5
        partes = contenido.split('"Confidence": 5')
        nuevo_contenido = partes[0]
        
        
        for parte in partes[1:]:
            ran = random.random()

            if ran > 0.5:
                nuevo_contenido += '"Confidence": 5' + parte
            elif ran > 0.35:
                nuevo_contenido += '"Confidence": 4' + parte
            elif ran > 0.2:
                nuevo_contenido += '"Confidence": 3' + parte
            elif ran > 0.1:
                nuevo_contenido += '"Confidence": 2' + parte
            elif ran > 0.07:
                nuevo_contenido += '"Confidence": 1' + parte
            else:
                nuevo_contenido += '"Confidence": 5' + parte
        
        with open(ruta, "w", encoding="utf-8") as f:
            f.write(nuevo_contenido)
        
        print(f"Procesado: {archivo}")
