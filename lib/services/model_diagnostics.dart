import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'model_service.dart';

class ModelDiagnostics {
  static Future<Map<String, dynamic>> diagnoseModel() async {
    return {
      'modelLoaded': ModelService.isLoaded,
      'lastError': ModelService.lastError,
      'inputShape': _getInputShape(),
      'outputShape': _getOutputShape(),
      'recommendations': _getRecommendations(),
    };
  }

  static List<int>? _getInputShape() {
    try {
      final interpreter = _getInterpreter();
      if (interpreter == null) return null;
      return interpreter.getInputTensor(0).shape;
    } catch (e) {
      debugPrint('Error getting input shape: $e');
      return null;
    }
  }

  static List<int>? _getOutputShape() {
    try {
      final interpreter = _getInterpreter();
      if (interpreter == null) return null;
      return interpreter.getOutputTensor(0).shape;
    } catch (e) {
      debugPrint('Error getting output shape: $e');
      return null;
    }
  }

  static String _getRecommendations() {
    final error = ModelService.lastError ?? '';

    if (error.contains('LSTM') || error.contains('Select')) {
      return 'Model uses unsupported ops. Reconvert to TFLite with builtin_ops_list or use quantized model.';
    }
    if (error.contains('failed precondition')) {
      return 'Model tensor mismatch. Check input/output shapes match expected values.';
    }
    if (error.contains('FileNotFound')) {
      return 'Model file not found at $kModelPath. Verify assets/models/ contains sign_model.tflite.';
    }
    if (error.contains('memory')) {
      return 'Memory error. Consider reducing number of threads or model size.';
    }
    return 'Model initialized successfully.';
  }

  static Interpreter? _getInterpreter() {
    try {
      // Access via reflection since _interpreter is private
      return null; // Would need to expose from ModelService
    } catch (_) {
      return null;
    }
  }
}
