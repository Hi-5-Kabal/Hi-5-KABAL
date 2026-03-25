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


# 2. Loop principal
cap = cv2.VideoCapture(0)

with mp_holistic.Holistic(min_detection_confidence=0.5, min_tracking_confidence=0.5) as holistic:
    print("Iniciando cámara... presiona 'q' para salir.")
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret: break

        image, results = mediapipe_detection(frame, holistic)
        print(results)

        #draw landmarks
        draw_styled_landmarks(image, results)

        cv2.imshow('OpenCV Feed', image)

        #if results.face_landmarks:
            # Imprime solo los primeros 5 puntos para no saturar la consola
            #print(results.face_landmarks.landmark[:5]) 
        #else:
            #print("No se detecta rostro")

        if cv2.waitKey(10) & 0xFF == ord('q'):
            break

        ##EXTRACT KEYPOINTS VALUES
        pose=[]
        for res in results.pose_landmarks.landmark:
            test = np.array([res.x, res.y, res.z, res.visibility])
            pose.append(test)
        
        #cada landmark debe tener x, y, z si no pues se rellena con ceros
        #para manejar los errores de si el sistema no detecta manos se crea un array con ceros
        #i.e. incluso si no hay face marks vamos a pasar x un array del mismo tam
        def extract_keypoints(results):
            pose = np.array([[res.x, res.y, res.z, res.visibility] for res in results.pose_landmarks.landmark]).flatten() if results.pose_landmarks else np.zeros(132)
            face = np.array([[res.x, res.y, res.z] for res in results.face_landmarks.landmark]).flatten() if results.face_landmarks else np.zeros(1404)
            lh = np.array([[res.x, res.y, res.z] for res in results.left_hand_landmarks.landmark]).flatten() if results.left_hand_landmarks else np.zeros(21*3)
            rh = np.array([[res.x, res.y, res.z] for res in results.right_hand_landmarks.landmark]).flatten() if results.right_hand_landmarks else np.zeros(21*3)
            return np.concatenate([pose, face, lh, rh]) #concatenar toods los resultados o sea queda como un arreglo enorme
        
        result_test = extract_keypoints(results)

        #len(results.left_hand_landmarks.landmark)*3 -> debería imprimir 63

        np.zeros(21*3)



        
        
        """
        Sección 4
        Setup folders for collection
        """

        #path donde se encuentra los datos exportados
        DATA_PATH = os.path.join('MP_DATA')

        #Acciones que vamos a detectar 
        actions = np.array(['hola', 'yo', 'estudio', 'ingenieria', 'en', 'computacion', 'gracias', 'adios', 'teamo'])

        #30 videos de data
        no_sequence = 30

        #Los videos seran de 30 frames de 
        sequence_lenght = 30

        #crear los folders necesarios para guardar nuestros datos para el modelo
        for action in actions:
            for sequence in range(no_sequence):
                try:
                    os.makedirs(os.path.join(DATA_PATH, action, str(sequence)))
                except:
                    pass
    cap.release()
    cv2.destroyAllWindows()

    #lIMPIAR agregado para mac
    for i in range(1, 10):
        cv2.waitKey(1)


        # """
        # Sección 5
        # Collect Keypoint Values for Training and Testing

        # """
        # cap = cv2.VideoCapture(0)
        # with mp_holistic.Holistic(min_detection_confidence=0.5, min_tracking_confidence=0.5) as holistic:

        #     for action in actions:
        #         for sequence in range(no_sequence):
        #             for frame_num in range(sequence_lenght):

        #                 #Read feed        
        #                 ret, frame = cap.read()

        #                 #Make detectionss
        #                 image, results = mediapipe_detection(frame, holistic)
        #                 print(results)

        #                 draw_styled_landmarks(image, results)

                        #Apply collection Logic
        #                 

        #                 cv2.imshow('OpenCV Feed', image)

        #         if cv2.waitKey(10) & 0xFF == ord('q'):
        #             break
        #         cap.release()
        #         cv2.destroyAllWindows()
         

