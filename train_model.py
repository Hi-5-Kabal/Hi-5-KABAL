import cv2
import mediapipe as mp
import time
import numpy as np
import os

from sklearn.model_selection import train_test_split
from tensorflow.keras.utils import to_categorical
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import LSTM, Dense
from tensorflow.keras.callbacks import TensorBoard

DATA_PATH = os.path.join('MP_DATA')
actions = np.array(['hola', 'yo', 'estudio', 'ingenieria', 'en computacion', 'gracias', 'adios', 'te amo'])
no_sequences = 30
sequence_length = 30

#crear mapa de etiquetas
label_map = {label:num for num, label in enumerate(actions)}

#cargar datos a carpetas de memoria

sequences, labels = [], []
for action in actions:
    dir_content = [f for f in os.listdir(os.path.join(DATA_PATH, action)) if not f.startswith('.')] 
    for sequence in dir_content:
        window = []
        for frame_num in range(sequence_length):
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
model.add(LSTM(64, return_sequences=True, activation='relu', input_shape=(30,1662)))
model.add(LSTM(128, return_sequences=True, activation='relu'))
model.add(LSTM(64, return_sequences=False, activation='relu'))
model.add(Dense(64, activation='relu'))
model.add(Dense(32, activation='relu'))
model.add(Dense(actions.shape[0], activation='softmax'))

#compila y entrena
model.compile(optimizer='Adam', loss='categorical_crossentropy', metrics=['categorical_accuracy'])

print("Training...")
model.fit(X_train, y_train, epochs=2000, callbacks=[tb_callback])

#guardar el modelo
model.summary()
model.save('modelo.h5')
print("Modelo guardada como modelo.h5")
