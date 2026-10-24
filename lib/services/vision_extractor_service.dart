import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:hand_landmarker/hand_landmarker.dart';
import 'dart:math' as math;

class VisionExtractorService {
  static final VisionExtractorService _instance = VisionExtractorService._internal();
  factory VisionExtractorService() => _instance;
  VisionExtractorService._internal();

  PoseDetector? _poseDetector;
  HandLandmarkerPlugin? _handLandmarker;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  List<double> _cachedPoseFeatures = List.filled(132, 0.0);
  bool _isPoseProcessing = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final options = PoseDetectorOptions(mode: PoseDetectionMode.stream);
    _poseDetector = PoseDetector(options: options);

    try {
      _handLandmarker = HandLandmarkerPlugin.create(
        numHands: 2,
        minHandDetectionConfidence: 0.35,
      );
    } catch (e) {
      debugPrint("Aviso: Falha ao carregar HandLandmarker. Mãos ficarão zeradas. Erro: $e");
    }

    _isInitialized = true;
    debugPrint("VisionExtractorService inicializado");
  }

  Future<List<double>> processImage(
    CameraImage image, 
    int cameraRotation, {
    bool isMovement = false,
    CameraLensDirection lensDirection = CameraLensDirection.front,
  }) async {
    if (!_isInitialized || _handLandmarker == null) return List.filled(258, 0.0);

    final List<double> rawLeftHand = List.filled(21 * 3, 0.0);
    final List<double> rawRightHand = List.filled(21 * 3, 0.0);

    try {
      final int effectiveRotation = cameraRotation;

      final hands = _handLandmarker!.detect(image, effectiveRotation);

      if (hands.length == 1) {
        final hand = hands.first;
        // No treinamento dos modelos de 258 features (MediaPipe Holistic espelhado),
        // o slot principal para sinais com uma única mão é rawLeftHand (132..194).
        // Preenchemos rawLeftHand para garantir que a predição primária utilize os pesos corretos.
        for (int i = 0; i < 21 && i < hand.landmarks.length; i++) {
          final pt = _toScreenCoords(hand.landmarks[i], cameraRotation, lensDirection);
          final int baseIdx = i * 3;
          rawLeftHand[baseIdx]     = pt.$1;
          rawLeftHand[baseIdx + 1] = pt.$2;
          rawLeftHand[baseIdx + 2] = pt.$3;
        }
      } else if (hands.length >= 2) {
        final ptWrist0 = _toScreenCoords(hands[0].landmarks[0], cameraRotation, lensDirection);
        final ptWrist1 = _toScreenCoords(hands[1].landmarks[0], cameraRotation, lensDirection);
        
        final double sX0 = ptWrist0.$1;
        final double sX1 = ptWrist1.$1;

        // Na câmera frontal espelhada:
        // A mão com menor X na tela (à esquerda visual) é a mão esquerda física do usuário.
        // A mão com maior X na tela (à direita visual) é a mão direita física do usuário.
        final handForLeft = sX0 <= sX1 ? hands[0] : hands[1];
        final handForRight = sX0 <= sX1 ? hands[1] : hands[0];

        for (int i = 0; i < 21; i++) {
          final ptLeft = _toScreenCoords(handForLeft.landmarks[i], cameraRotation, lensDirection);
          final int baseIdxLeft = i * 3;
          rawLeftHand[baseIdxLeft]     = ptLeft.$1;
          rawLeftHand[baseIdxLeft + 1] = ptLeft.$2;
          rawLeftHand[baseIdxLeft + 2] = ptLeft.$3;

          final ptRight = _toScreenCoords(handForRight.landmarks[i], cameraRotation, lensDirection);
          final int baseIdxRight = i * 3;
          rawRightHand[baseIdxRight]     = ptRight.$1;
          rawRightHand[baseIdxRight + 1] = ptRight.$2;
          rawRightHand[baseIdxRight + 2] = ptRight.$3;
        }
      }
    } catch (e) {
      debugPrint("Aviso: Falha ao processar mãos: $e");
      return List.filled(258, 0.0);
    }

    final bool hasLeft = rawLeftHand.any((v) => v != 0.0);
    final bool hasRight = rawRightHand.any((v) => v != 0.0);
    if (!hasLeft && !hasRight) {
      return List.filled(258, 0.0);
    }

    final List<double> finalFeatures = List.filled(258, 0.0);

    // O pose só é necessário para sinais dinâmicos (LSTM).
    // Para o alfabeto estático (MLP), deixar pose zerado garante 100% de estabilidade
    // sem ruídos ou artefatos de estimação do corpo afetando a classificação dos dedos.
    if (isMovement) {
      finalFeatures.setRange(0, 132, _cachedPoseFeatures);

      if (!_isPoseProcessing && _poseDetector != null) {
        _triggerAsyncPoseDetection(image, cameraRotation, lensDirection: lensDirection);
      }
    }

    _normalizeHand(rawLeftHand, finalFeatures, 132);
    _normalizeHand(rawRightHand, finalFeatures, 195);

    return finalFeatures;
  }

  void _triggerAsyncPoseDetection(
    CameraImage image, 
    int cameraRotation, {
    CameraLensDirection lensDirection = CameraLensDirection.front,
  }) async {
    _isPoseProcessing = true;
    try {
      final Uint8List nv21Bytes;
      if (defaultTargetPlatform == TargetPlatform.android && image.planes.length >= 3) {
        final yPlane = image.planes[0];
        final uPlane = image.planes[1];
        final vPlane = image.planes[2];
        final int ySize = yPlane.bytes.length;
        final int uvSize = uPlane.bytes.length + vPlane.bytes.length;
        nv21Bytes = Uint8List(ySize + uvSize);
        nv21Bytes.setRange(0, ySize, yPlane.bytes);
        if (vPlane.bytesPerPixel != null && vPlane.bytesPerPixel! == 2) {
          nv21Bytes.setRange(ySize, ySize + vPlane.bytes.length, vPlane.bytes);
        } else {
          int uvIndex = ySize;
          for (int i = 0; i < vPlane.bytes.length && i < uPlane.bytes.length; i++) {
            nv21Bytes[uvIndex++] = vPlane.bytes[i];
            nv21Bytes[uvIndex++] = uPlane.bytes[i];
          }
        }
      } else {
        final WriteBuffer allBytes = WriteBuffer();
        for (final Plane plane in image.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        nv21Bytes = allBytes.done().buffer.asUint8List();
      }

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final InputImageRotation rotation = InputImageRotationValue.fromRawValue(cameraRotation) 
          ?? InputImageRotation.rotation270deg;

      final inputImage = InputImage.fromBytes(
        bytes: nv21Bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final poses = await _poseDetector!.processImage(inputImage);
      if (poses.isNotEmpty) {
        final pose = poses.first;

        final double uprightW = (cameraRotation == 90 || cameraRotation == 270) ? imageSize.height : imageSize.width;
        final double uprightH = (cameraRotation == 90 || cameraRotation == 270) ? imageSize.width : imageSize.height;

        final List<double> rawPose = List.filled(33 * 4, 0.0);
        for (int i = 0; i < 33; i++) {
          final type = PoseLandmarkType.values[i];
          final landmark = pose.landmarks[type];
          if (landmark != null) {
            final int baseIdx = i * 4;
            final double normX = landmark.x / uprightW;
            final double normY = landmark.y / uprightH;
            final double normZ = landmark.z / uprightW;

            final double screenX = lensDirection == CameraLensDirection.front ? (1.0 - normX) : normX;
            final double screenY = normY;
            final double screenZ = normZ;

            // Coordenadas isotrópicas [0, 1] idênticas ao cv_utils.py original
            rawPose[baseIdx]     = screenX;
            rawPose[baseIdx + 1] = screenY;
            rawPose[baseIdx + 2] = screenZ;
            rawPose[baseIdx + 3] = landmark.likelihood;
          }
        }

        final double lsX = rawPose[11 * 4], lsY = rawPose[11 * 4 + 1], lsZ = rawPose[11 * 4 + 2];
        final double rsX = rawPose[12 * 4], rsY = rawPose[12 * 4 + 1], rsZ = rawPose[12 * 4 + 2];
        final double centerX = (lsX + rsX) / 2.0;
        final double centerY = (lsY + rsY) / 2.0;
        final double centerZ = (lsZ + rsZ) / 2.0;
        final double dx = lsX - rsX, dy = lsY - rsY, dz = lsZ - rsZ;
        final double scale = math.sqrt(dx * dx + dy * dy + dz * dz) + 1e-6;

        final List<double> newPose = List.filled(132, 0.0);
        for (int i = 0; i < 33; i++) {
          final int baseIdx = i * 4;
          newPose[baseIdx]     = (rawPose[baseIdx]     - centerX) / scale;
          newPose[baseIdx + 1] = (rawPose[baseIdx + 1] - centerY) / scale;
          newPose[baseIdx + 2] = (rawPose[baseIdx + 2] - centerZ) / scale;
          newPose[baseIdx + 3] = rawPose[baseIdx + 3];
        }
        _cachedPoseFeatures = newPose;
      }
    } catch (e) {
      debugPrint("Aviso: Falha ao processar pose assíncrona: $e");
    } finally {
      _isPoseProcessing = false;
    }
  }

  void _normalizeHand(List<double> rawHand, List<double> finalFeatures, int offset) {
    final bool hasData = rawHand[0] != 0.0 || rawHand[1] != 0.0;
    if (!hasData) return;

    final double wristX = rawHand[0], wristY = rawHand[1], wristZ = rawHand[2];

    final double mcpX = rawHand[9 * 3] - wristX;
    final double mcpY = rawHand[9 * 3 + 1] - wristY;
    final double mcpZ = rawHand[9 * 3 + 2] - wristZ;
    final double handSize = math.sqrt(mcpX * mcpX + mcpY * mcpY + mcpZ * mcpZ) + 1e-6;

    for (int i = 0; i < 21; i++) {
      final int baseIdx = i * 3;
      final int targetIdx = offset + baseIdx;
      
      final double normX = (rawHand[baseIdx]     - wristX) / handSize;
      final double normY = (rawHand[baseIdx + 1] - wristY) / handSize;
      final double normZ = (rawHand[baseIdx + 2] - wristZ) / handSize;

      if (normX.abs() > 10.0 || normY.abs() > 10.0 || normZ.abs() > 10.0) {
        for(int j = 0; j < 21; j++) {
            finalFeatures[offset + (j * 3)] = 0.0;
            finalFeatures[offset + (j * 3) + 1] = 0.0;
            finalFeatures[offset + (j * 3) + 2] = 0.0;
        }
        return;
      }

      finalFeatures[targetIdx]     = normX;
      finalFeatures[targetIdx + 1] = normY;
      finalFeatures[targetIdx + 2] = normZ;
    }
  }

  (double, double, double) _toScreenCoords(
      dynamic mark, int cameraRotation, CameraLensDirection lensDirection) {
    final double markX = (mark.x as num).toDouble();
    final double markY = (mark.y as num).toDouble();
    final double markZ = (mark.z as num).toDouble();

    final bool isFront = lensDirection == CameraLensDirection.front;

    final double outX;
    final double outY;

    if (isFront) {
      switch (cameraRotation) {
        case 270:
          outX = 1.0 - markY;
          outY = 1.0 - markX;
          break;
        case 90:
          outX = markY;
          outY = markX;
          break;
        case 180:
          outX = 1.0 - markX;
          outY = markY;
          break;
        default:
          outX = markX;
          outY = 1.0 - markY;
      }
    } else {
      switch (cameraRotation) {
        case 90:
          outX = 1.0 - markY;
          outY = markX;
          break;
        case 270:
          outX = markY;
          outY = 1.0 - markX;
          break;
        case 180:
          outX = 1.0 - markX;
          outY = 1.0 - markY;
          break;
        default:
          outX = markX;
          outY = markY;
      }
    }

    return (outX, outY, markZ);
  }

  void dispose() {
    _poseDetector?.close();
    _poseDetector = null;
    _handLandmarker?.dispose();
    _handLandmarker = null;
    _isInitialized = false;
  }
}