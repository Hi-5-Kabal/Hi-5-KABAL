import cv2
import numpy as np
import os
from sklearn.model_selection import train_test_split
from tensorflow.keras.utils import to_categorical
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense
from tensorflow.keras.callbacks import TensorBoard
from tensorflow.keras.optimizers import Adam # Importante para controlar el aprendizaje

# 1. Configuraciones iniciales
DATA_PATH = os.path.join('MP_DATA')
# Asegúrate de que estas acciones coincidan exactamente con tus carpetas
actions = np.array(['hola', 'yo', 'estudio', 'ingenieria', 'en computacion', 'gracias', 'adios', 'te amo'])
no_sequences = 30
sequence_length = 30

# Crear mapa de etiquetas (hola:0, yo:1, etc.)
label_map = {label:num for num, label in enumerate(actions)}

# 2. Carga de datos
sequences, labels = [], []
print("Cargando datos desde MP_DATA...")

for action in actions:
    action_path = os.path.join(DATA_PATH, action)
    # Filtrar solo carpetas numéricas y evitar archivos ocultos de Mac/Windows
    dir_content = [f for f in os.listdir(action_path) if f.isdigit()]
    
    for sequence in dir_content:
        window = []
        for frame_num in range(sequence_length):
            try:
                res = np.load(os.path.join(action_path, sequence, "{}.npy".format(frame_num)))
                window.append(res)
            except Exception as e:
                continue # Si falta un frame, saltamos esa secuencia
        
        if len(window) == sequence_length:
            sequences.append(window)
            labels.append(label_map[action])

# Convertir a arrays de Numpy
X = np.array(sequences)
y = to_categorical(labels).astype(int)

# Dividir datos (95% entrenamiento, 5% prueba)
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.05)

print(f"Datos cargados. Total de secuencias: {len(X)}")

# 3. Construcción de la Red Neuronal LSTM
log_dir = os.path.join('Logs')
tb_callback = TensorBoard(log_dir=log_dir)

model = Sequential()
# Capa 1: Captura patrones iniciales
model.add(LSTM(64, return_sequences=True, activation='relu', input_shape=(30, 1662)))
# Capa 2: Profundiza en la relación temporal
model.add(LSTM(128, return_sequences=True, activation='relu'))
# Capa 3: Condensa la información
model.add(LSTM(64, return_sequences=False, activation='relu'))
# Capas densas para clasificación final
model.add(Dense(64, activation='relu'))
model.add(Dense(32, activation='relu'))
model.add(Dense(actions.shape[0], activation='softmax'))

# 4. Compilación con Learning Rate controlado
# Bajamos el rate a 0.0001 para evitar que la precisión se "atore"
optimizer = Adam(learning_rate=0.0001)
model.compile(optimizer=optimizer, loss='categorical_crossentropy', metrics=['categorical_accuracy'])

# 5. Entrenamiento
print("Entrenando cerebro de IA... observa el 'categorical_accuracy'")
# Con este optimizador, 600-1000 epochs suelen ser suficientes
model.fit(X_train, y_train, epochs=1000, callbacks=[tb_callback])

# 6. Guardado y Resumen
model.summary()
model.save('modelo.h5')
print("---")
print("PROCESO TERMINADO: Modelo guardado como 'modelo.h5'")