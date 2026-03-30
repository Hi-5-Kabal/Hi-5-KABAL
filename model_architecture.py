from abc import ABC, abstractmethod
import numpy as np
import tensorflow as tf

# 1. La Interfaz (Subject)
class ISignLanguageModel(ABC):
    @abstractmethod
    def predict(self, sequence):
        pass

# 2. El Objeto Real (RealSubject)
class RealSignModel(ISignLanguageModel):
    def __init__(self, model_path):
        print("Cargando modelo pesado desde disco... por favor espere.")
        self._model = tf.keras.models.load_model(model_path)
        print("Modelo cargado exitosamente.")

    def predict(self, sequence):
        # Expandimos dimensiones para que Keras lo entienda (1, 30, 1662)
        res = self._model.predict(np.expand_dims(sequence, axis=0))
        return res[0]

# 3. El Proxy
class SignModelProxy(ISignLanguageModel):
    def __init__(self, model_path):
        self._model_path = model_path
        self._real_model = None  # Lazy Loading (Carga perezosa)

    def predict(self, sequence):
        # Solo cargamos el modelo real cuando se necesita la primera predicción
        if self._real_model is None:
            self._real_model = RealSignModel(self._model_path)
        
        # Validación extra: El Proxy verifica que los datos sean correctos
        if len(sequence) != 30:
            print("Error: La secuencia debe tener 30 frames.")
            return None
            
        return self._real_model.predict(sequence)