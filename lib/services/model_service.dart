import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

const List<String> kModelLabels = [
  'hola',
  'yo',
  'estudio',
  'ingenieria',
  'en computacion',
  'gracias',
  'adios',
  'te amo',
];

const int kModelTimesteps = 30;
const int kModelFeatureSize = 1662;
const double kConfidenceThreshold = 0.70;
const String kModelPath = 'assets/models/sign_model.tflite';

class ModelService {
  static Interpreter? _interpreter;
  static final List<List<double>> _sequence = [];
  static String? _lastError;

  static bool get isLoaded => _interpreter != null;
  static String? get lastError => _lastError;

  static Future<void> init() async {
    if (_interpreter != null) return;

    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(kModelPath, options: options);

      _resizeInputIfNeeded();
      _interpreter!.allocateTensors();
      _lastError = null;
      print('""""""""""""-Modelo cargado-""""""""""""""');
    } catch (e) {
      _lastError = _formatError(e.toString());
      _interpreter = null;
      print('❌ Error: $_lastError');
    }
  }

  static String _formatError(String error) {
    if (error.contains('failed precondition')) {
      return 'Asegúrate que useFlexDelegate está habilitado en InterpreterOptions.';
    }
    if (error.contains('FileNotFound')) {
      return 'Archivo no encontrado: $kModelPath';
    }
    return error;
  }

  static void _resizeInputIfNeeded() {
    final inputShape = _interpreter!.getInputTensor(0).shape;
    if (inputShape.length != 3 ||
        inputShape[1] != kModelTimesteps ||
        inputShape[2] != kModelFeatureSize) {
      _interpreter!.resizeInputTensor(0, [1, kModelTimesteps, kModelFeatureSize]);
    }
  }

  static void resetSequence() => _sequence.clear();

  static Future<String?> predict(List<double> frameFeatures) async {
    if (frameFeatures.length != kModelFeatureSize) return null;
    if (_interpreter == null) await init();
    if (_interpreter == null) return null;

    _sequence.add(List<double>.from(frameFeatures));
    if (_sequence.length > kModelTimesteps) _sequence.removeAt(0);
    if (_sequence.length < kModelTimesteps) return null;

    return _runInference();
  }

  static String? _runInference() {
    try {
      final input = [_sequence];
      final output = [List<double>.filled(kModelLabels.length, 0.0)];

      _interpreter!.run(input, output);

      final scores = output.first;
      var maxIdx = 0;
      var maxScore = scores[0];

      for (var i = 1; i < scores.length; i++) {
        if (scores[i] > maxScore) {
          maxScore = scores[i];
          maxIdx = i;
        }
      }

      if (maxScore < kConfidenceThreshold) return null;
      return maxIdx < kModelLabels.length ? kModelLabels[maxIdx] : null;
    } catch (e) {
      _lastError = e.toString();
      return null;
    }
  }
}
