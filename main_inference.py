import cv2
import numpy as np
import os
import mediapipe as mp
from tensorflow.keras.models import load_model
from abc import ABC, abstractmethod

#proxy ig
class ISignModel(ABC):
    @abstractmethod
    def predict(self, sequence):
        pass

class RealSignModel(ISignModel):
    def __init__(self, model_path):
        print(f"Cargando modelo real desde {model_path}...")
        self._model = load_model(model_path)
    
    def predict(self, sequence):
        #verbose=0 para que no se trabe la consola
        res = self._model.predict(np.expand_dims(sequence, axis=0), verbose=0)
        return res[0]

class SignModelProxy(ISignModel):
    def __init__(self, model_path):
        self._model_path = model_path
        self._real_model = None

    def predict(self, sequence):
        if self._real_model is None:
            self._real_model = RealSignModel(self._model_path)
        return self._real_model.predict(sequence)


actions = np.array(['hola', 'yo', 'estudio', 'ingenieria', 'en computacion', 'gracias', 'adios', 'te amo'])
mp_holistic = mp.solutions.holistic 
mp_drawing = mp.solutions.drawing_utils

def mediapipe_detection(image, model):
    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    image.flags.writeable = False                  
    results = model.process(image)                 
    image.flags.writeable = True                   
    image = cv2.cvtColor(image, cv2.COLOR_RGB2BGR) 
    return image, results

def extract_keypoints(results):
    pose = np.array([[res.x, res.y, res.z, res.visibility] for res in results.pose_landmarks.landmark]).flatten() if results.pose_landmarks else np.zeros(132)
    face = np.array([[res.x, res.y, res.z] for res in results.face_landmarks.landmark]).flatten() if results.face_landmarks else np.zeros(1404)
    lh = np.array([[res.x, res.y, res.z] for res in results.left_hand_landmarks.landmark]).flatten() if results.left_hand_landmarks else np.zeros(21*3)
    rh = np.array([[res.x, res.y, res.z] for res in results.right_hand_landmarks.landmark]).flatten() if results.right_hand_landmarks else np.zeros(21*3)
    return np.concatenate([pose, face, lh, rh])


model_proxy = SignModelProxy('modelo.h5')
sequence = []
sentence = []
predictions = [] 
threshold = 0.8
frame_skip = 0 #Para no saturar el modelo

cap = cv2.VideoCapture(0)

with mp_holistic.Holistic(min_detection_confidence=0.5, min_tracking_confidence=0.5) as holistic:
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret: break

        image, results = mediapipe_detection(frame, holistic)
        
        #Extraer puntos y guardarlos
        keypoints = extract_keypoints(results)
        sequence.append(keypoints)
        sequence = sequence[-30:] 

        #Predicción cada 5 frames para que no sea lento
        frame_skip += 1
        if len(sequence) == 30 and frame_skip % 5 == 0:
            res = model_proxy.predict(sequence)
            predictions.append(np.argmax(res))
            
            #Estabilización: revisamos los últimos 10 resultados
            if len(predictions) >= 10:
                recent_preds = predictions[-10:]
                #si hay consenso en la mayoría
                most_common = max(set(recent_preds), key=recent_preds.count)
                
                if recent_preds.count(most_common) > 7: #70% de seguridad temporal
                    if res[most_common] > threshold: 
                        if len(sentence) > 0:
                            if actions[most_common] != sentence[-1]:
                                sentence.append(actions[most_common])
                        else:
                            sentence.append(actions[most_common])

            if len(sentence) > 5: sentence = sentence[-5:]

        #DIBUJAR INTERFAZ)
        #Dibujamos el fondo de la barra
        cv2.rectangle(image, (0,0), (640, 45), (245, 117, 16), -1)
        
        #Unimos las palabras y las ponemos en la barra
        text_to_show = ' '.join(sentence).upper()
        cv2.putText(image, text_to_show, (15, 33), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255, 255, 255), 2, cv2.LINE_AA)
        
        cv2.imshow('Traductor de Senas - UAM PIS', image)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()