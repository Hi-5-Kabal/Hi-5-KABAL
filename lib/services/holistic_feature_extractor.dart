import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_mesh_detection/google_mlkit_face_mesh_detection.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Generates a 1662 feature vector compatible with MediaPipe Holistic layout:
/// pose(33*4 = 132) + face(468*3 = 1404) + leftHand(21*3 = 63) + rightHand(21*3 = 63)
class HolisticFeatureExtractor {
  HolisticFeatureExtractor()
      : _poseDetector = PoseDetector(
          options: PoseDetectorOptions(
            model: PoseDetectionModel.base,
            mode: PoseDetectionMode.stream,
          ),
        ),
        _faceMeshDetector = FaceMeshDetector(
          option: FaceMeshDetectorOptions.faceMesh,
        );

  final PoseDetector _poseDetector;
  final FaceMeshDetector _faceMeshDetector;

  static const int _poseFeatures = 33 * 4;
  static const int _faceFeatures = 468 * 3;
  static const int _handFeatures = 21 * 3;
  static const int totalFeatures = _poseFeatures + _faceFeatures + _handFeatures + _handFeatures;

  Future<void> close() async {
    await _poseDetector.close();
    await _faceMeshDetector.close();
  }

  Future<List<double>?> extract(
    CameraImage cameraImage,
    CameraDescription cameraDescription,
  ) async {
    final inputImage = _toInputImage(cameraImage, cameraDescription);
    if (inputImage == null) return null;

    final features = List<double>.filled(totalFeatures, 0.0);

    final imageSize = inputImage.metadata?.size;
    if (imageSize == null) return null;

    final poses = await _poseDetector.processImage(inputImage);
    if (poses.isNotEmpty) {
      _fillPoseFeatures(features, poses.first, imageSize);
    }

    final meshes = await _faceMeshDetector.processImage(inputImage);
    if (meshes.isNotEmpty) {
      _fillFaceFeatures(features, meshes.first, imageSize);
    }

    // Hands are zero-filled for now. Flutter ML Kit does not provide a hand-landmark detector package.
    // This preserves the expected 1662-dim tensor layout.
    return features;
  }

  void _fillPoseFeatures(List<double> out, Pose pose, Size imageSize) {
    var offset = 0;
    for (final type in PoseLandmarkType.values) {
      final landmark = pose.landmarks[type];
      if (landmark == null) {
        out[offset++] = 0.0;
        out[offset++] = 0.0;
        out[offset++] = 0.0;
        out[offset++] = 0.0;
      } else {
        out[offset++] = landmark.x / imageSize.width;
        out[offset++] = landmark.y / imageSize.height;
        out[offset++] = landmark.z / imageSize.width;
        out[offset++] = landmark.likelihood;
      }
    }
  }

  void _fillFaceFeatures(List<double> out, FaceMesh mesh, Size imageSize) {
    final faceStart = _poseFeatures;

    // Index-safe map to preserve exact point order [0..467]
    final points = List<FaceMeshPoint?>.filled(468, null);
    for (final point in mesh.points) {
      if (point.index >= 0 && point.index < 468) {
        points[point.index] = point;
      }
    }

    var offset = faceStart;
    for (var i = 0; i < 468; i++) {
      final point = points[i];
      if (point == null) {
        out[offset++] = 0.0;
        out[offset++] = 0.0;
        out[offset++] = 0.0;
      } else {
        out[offset++] = point.x / imageSize.width;
        out[offset++] = point.y / imageSize.height;
        out[offset++] = point.z / imageSize.width;
      }
    }
  }

  InputImage? _toInputImage(
    CameraImage image,
    CameraDescription cameraDescription,
  ) {
    final rotation = InputImageRotationValue.fromRawValue(cameraDescription.sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (image.planes.isEmpty) return null;

    final bytes = _concatenatePlanes(image.planes);
    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final bytesBuilder = BytesBuilder(copy: false);
    for (final plane in planes) {
      bytesBuilder.add(plane.bytes);
    }
    return bytesBuilder.toBytes();
  }
}
