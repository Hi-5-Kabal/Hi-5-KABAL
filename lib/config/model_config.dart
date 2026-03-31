/// TFLite Model Configuration
///
/// Model Details:
/// - Input: [1, 30, 1662] (1 batch, 30 timesteps, 1662 features)
/// - Output: [1, 8] (8 sign language classes)
/// - Features: MediaPipe Holistic (pose + face + hands)
///
/// Flex ops support enabled in tflite_flutter_plus with useFlexDelegate=true
/// Model converted with: SELECT_TF_OPS + TFLITE_BUILTINS

class ModelConfig {
  static const String modelPath = 'assets/models/sign_model.tflite';
  static const int inputTimesteps = 30;
  static const int inputFeatures = 1662;
  static const int numOutputClasses = 8;
  static const double confidenceThreshold = 0.70;
  static const int numThreads = 2;

  static const List<String> outputLabels = [
    'hola',
    'yo',
    'estudio',
    'ingenieria',
    'en computacion',
    'gracias',
    'adios',
    'te amo',
  ];

  // Expected input shape for model validation
  static const List<int> expectedInputShape = [1, inputTimesteps, inputFeatures];

  // Expected output shape
  static const List<int> expectedOutputShape = [1, numOutputClasses];
}
