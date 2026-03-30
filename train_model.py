import cv2
import mediapipe as mp
import time
import numpy as np
import os

from sklearn.model_selection import train_test_split
from tensorflow.keras.utils import to_categorical
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense, Dropout, BatchNormalization
from tensorflow.keras.callbacks import TensorBoard
from tensorflow.keras.callbacks import EarlyStopping
from tensorflow.keras.optimizers import Adam

DATA_PATH = os.path.join('MP_DATA')
actions = np.array(['hola', 'yo', 'estudio', 'ingenieria', 'en computacion', 'gracias', 'adios', 'te amo'])

no_sequences = 60
sequence_length = 30

#crear mapa de etiquetas
label_map = {label:num for num, label in enumerate(actions)}

#cargar datos a carpetas de memoria

sequences, labels = [], []
for action in actions:
    #filtramos para ignorar archivos ocultos de Mac y asegurar que solo leemos carpetas de secuencias
    dir_content = [f for f in os.listdir(os.path.join(DATA_PATH, action)) if not f.startswith('.')] 
    for sequence in dir_content:
        window = []
        for frame_num in range(sequence_length):
            #Cargamos cada uno de los 30 frames del video actual
            res = np.load(os.path.join(DATA_PATH, action, str(sequence), "{}.npy".format(frame_num)))
            window.append(res)
        sequences.append(window)
        labels.append(label_map[action])

#preparar datos para tensorflow
X = np.array(sequences)
y = to_categorical(labels).astype(int)

#95% entrenamiento, 5% prueba
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.05)

#construcción de la red LSTM
log_dir = os.path.join('Logs')
tb_callback = TensorBoard(log_dir=log_dir)

model = Sequential()
# Capa de normalización para estabilizar los datos de entrada
# Se mantiene en 30 porque es la cantidad de frames por video
model.add(BatchNormalization(input_shape=(30, 1662)))

# Primera capa LSTM con activación tanh para evitar explosión de gradientes
model.add(LSTM(64, return_sequences=True, activation='tanh'))
model.add(Dropout(0.2))

model.add(LSTM(128, return_sequences=True, activation='tanh'))
model.add(Dropout(0.2))

model.add(LSTM(64, return_sequences=False, activation='tanh'))
model.add(Dropout(0.2))

model.add(Dense(64, activation='relu'))
model.add(Dense(32, activation='relu'))
model.add(Dense(actions.shape[0], activation='softmax'))

#compila y entrena
# Usamos un learning rate más bajo para una convergencia más suave
opt = Adam(learning_rate=0.0001)
model.compile(optimizer=opt, loss='categorical_crossentropy', metrics=['categorical_accuracy'])

print("Training...")
# Se aumenta el patience para permitir que el modelo salga de mesetas de aprendizaje
early_callback = EarlyStopping(monitor='loss', patience=30, restore_best_weights=True)
model.fit(X_train, y_train, epochs=500, callbacks=[tb_callback, early_callback])

#guardar el modelo
model.summary()
model.save('modelo.h5')
print("Modelo guardada como modelo.h5")