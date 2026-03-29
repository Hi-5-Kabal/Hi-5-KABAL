import cv2
import mediapipe as mp
import time
import numpy as np
import os

# 1. Configuración de MediaPipe
mp_holistic = mp.solutions.holistic 
mp_drawing = mp.solutions.drawing_utils 



def mediapipe_detection(image, model):
    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    image.flags.writeable = False                  
    results = model.process(image)                 
    image.flags.writeable = True                   
    image = cv2.cvtColor(image, cv2.COLOR_RGB2BGR) 
    return image, results

def draw_landmarks(image, results):
    if results.face_landmarks:
        mp_drawing.draw_landmarks(image, results.face_landmarks, mp_holistic.FACEMESH_TESSELATION)
    if results.pose_landmarks:
        mp_drawing.draw_landmarks(image, results.pose_landmarks, mp_holistic.POSE_CONNECTIONS)
    if results.left_hand_landmarks:
        mp_drawing.draw_landmarks(image, results.left_hand_landmarks, mp_holistic.HAND_CONNECTIONS)
    if results.right_hand_landmarks:
        mp_drawing.draw_landmarks(image, results.right_hand_landmarks, mp_holistic.HAND_CONNECTIONS)

def draw_styled_landmarks(image, results):
    mp_drawing.draw_landmarks(image, results.face_landmarks, mp_holistic.FACEMESH_TESSELATION, 
                             mp_drawing.DrawingSpec(color=(80,110,10), thickness=1, circle_radius=1), 
                             mp_drawing.DrawingSpec(color=(80,256,121), thickness=1, circle_radius=1)
                             ) 
    # Draw pose connections
    mp_drawing.draw_landmarks(image, results.pose_landmarks, mp_holistic.POSE_CONNECTIONS,
                             mp_drawing.DrawingSpec(color=(80,22,10), thickness=2, circle_radius=4), 
                             mp_drawing.DrawingSpec(color=(80,44,121), thickness=2, circle_radius=2)
                             ) 
    # Draw left hand connections
    mp_drawing.draw_landmarks(image, results.left_hand_landmarks, mp_holistic.HAND_CONNECTIONS, 
                             mp_drawing.DrawingSpec(color=(121,22,76), thickness=2, circle_radius=4), 
                             mp_drawing.DrawingSpec(color=(121,44,250), thickness=2, circle_radius=2)
                             ) 
    # Draw right hand connections  
    mp_drawing.draw_landmarks(image, results.right_hand_landmarks, mp_holistic.HAND_CONNECTIONS, 
                             mp_drawing.DrawingSpec(color=(245,117,66), thickness=2, circle_radius=4), 
                             mp_drawing.DrawingSpec(color=(245,66,230), thickness=2, circle_radius=2)
                             )


#cada landmark debe tener x, y, z si no pues se rellena con ceros
#para manejar los errores de si el sistema no detecta manos se crea un array con ceros
#i.e. incluso si no hay face marks vamos a pasar x un array del mismo tam
def extract_keypoints(results):
    pose = np.array([[res.x, res.y, res.z, res.visibility] for res in results.pose_landmarks.landmark]).flatten() if results.pose_landmarks else np.zeros(132)
    face = np.array([[res.x, res.y, res.z] for res in results.face_landmarks.landmark]).flatten() if results.face_landmarks else np.zeros(1404)
    lh = np.array([[res.x, res.y, res.z] for res in results.left_hand_landmarks.landmark]).flatten() if results.left_hand_landmarks else np.zeros(21*3)
    rh = np.array([[res.x, res.y, res.z] for res in results.right_hand_landmarks.landmark]).flatten() if results.right_hand_landmarks else np.zeros(21*3)
    return np.concatenate([pose, face, lh, rh]) #concatenar toods los resultados o sea queda como un arreglo enorme


"""
Sección 4
Setup folders for collection
"""
#path donde se encuentra los datos exportados
DATA_PATH = os.path.join('MP_DATA')

#Acciones que vamos a detectar 
actions = np.array(['hola', 'yo', 'estudio', 'ingenieria', 'en computacion', 'gracias', 'adios', 'te amo'])

#30 videos de data
no_sequences = 30

#Los videos seran de 30 frames de 
sequence_length = 30

#Folder start
start_folder = 30

#Crear la estructura de carpetas
for action in actions: 
    #Crear la carpeta de la acción si no existe (ej: MP_DATA/hola)
    #exist_ok=True evita que el programa truene si la carpeta ya existe
    os.makedirs(os.path.join(DATA_PATH, action), exist_ok=True)
    
    #Revisar cuál es el número de carpeta más alto para no sobrescribir
    dir_content = os.listdir(os.path.join(DATA_PATH, action))
    dir_folders = [f for f in dir_content if not f.startswith('.')] #Ignorar basura de Mac x los .DS_Store
    
    if len(dir_folders) > 0:
        dirmax = np.max(np.array(dir_folders).astype(int))
    else:
        dirmax = 0

    #Crear las subcarpetas para las nuevas 30 secuencias
    for sequence in range(1, no_sequences + 1):
        os.makedirs(os.path.join(DATA_PATH, action, str(dirmax + sequence)), exist_ok=True)


# 2. Loop principal
cap = cv2.VideoCapture(0)

with mp_holistic.Holistic(min_detection_confidence=0.5, min_tracking_confidence=0.5) as holistic:


    print("Iniciando cámara... presiona 'q' para salir.")
    #while cap.isOpened():
        
        #NEW LOOP
        #Loop through actions i.e. yo, estudio,...
    for action in actions:
        #IMPORTANTE: Aquí buscamos desde qué carpeta empezar a grabar para esta acción
        dir_content = [f for f in os.listdir(os.path.join(DATA_PATH, action)) if not f.startswith('.')]
        #Grabaremos en las últimas 'no_sequences' carpetas creadas
        current_folders = sorted([int(f) for f in dir_content])[-no_sequences:]
        #Loop through sequences - baasically videos (30)
        for sequence in current_folders:
            # Loop through video length aka sequence length - frames of videos
            for frame_num in range(sequence_length):

                # Read feed
                ret, frame = cap.read()
                if not ret: break

                # Make detections
                image, results = mediapipe_detection(frame, holistic)

                # Draw landmarks
                draw_styled_landmarks(image, results)
                
                # NEW Apply wait logic
                if frame_num == 0: # si el frame es 0 -> brake
                    cv2.putText(image, 'STARTING COLLECTION', (120,200), 
                            cv2.FONT_HERSHEY_SIMPLEX, 1, (0,255, 0), 4, cv2.LINE_AA)
                    cv2.putText(image, 'Collecting frames for {} Video Number {}'.format(action, sequence), (15,12), 
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 255), 1, cv2.LINE_AA)
                    # Show to screen
                    cv2.imshow('OpenCV Feed', image)
                    cv2.waitKey(1000)
                else: 
                    cv2.putText(image, 'Collecting frames for {} Video Number {}'.format(action, sequence), (15,12), 
                            cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 255), 1, cv2.LINE_AA)
                    # Show to screen
                    cv2.imshow('OpenCV Feed', image)
                
                # NEW Export keypoints
                keypoints = extract_keypoints(results)
                npy_path = os.path.join(DATA_PATH, action, str(sequence), str(frame_num))
                np.save(npy_path, keypoints)

                if cv2.waitKey(10) & 0xFF == ord('q'):
                    break    ##to get a break between the collections 
    cap.release()
    cv2.destroyAllWindows()
    cv2.waitKey(1)
    #lIMPIAR (4 mac lol)
    for i in range(1, 10):
        cv2.waitKey(1)
