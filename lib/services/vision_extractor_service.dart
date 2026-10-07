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

  /// Processa o frame e devolve um array de 258 posições com NORMALIZAÇÃO 3D.
  /// Layout: [pose 33×4=132] [mão_esquerda 21×3=63] [mão_direita 21×3=63] = 258
  /// 
  /// Pipeline idêntico ao Web Dashboard e Python:
  ///   - HandLandmarker roda com rotação nativa via MediaPipe Tasks.
  ///   - Espelhamento frontal inverte apenas o eixo horizontal (1.0 - mark.x).
  ///   - Normalização 3D pelo pulso e MCP9 com escala euclidiana natural.
  ///   - Mãos mapeadas de forma determinística (menor X = esquerda, maior X = direita).
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
      // Para câmeras frontais no Android, o sensorOrientation é 270°.
      // O ângulo horário necessário para alinhar a imagem na vertical (portrait upright)
      // para o MediaPipe Tasks é exatamente cameraRotation (270° no frontal, 90° no traseiro).
      final int effectiveRotation = cameraRotation;

      final hands = _handLandmarker!.detect(image, effectiveRotation);

      if (hands.isNotEmpty && kDebugMode) {
        final pt0 = _toScreenCoords(hands[0].landmarks[0], cameraRotation, lensDirection);
        final pt9 = _toScreenCoords(hands[0].landmarks[9], cameraRotation, lensDirection);
        debugPrint("🖐️ [HandLandmarker] Mãos: ${hands.length} | Pulso: (${pt0.$1.toStringAsFixed(2)}, ${pt0.$2.toStringAsFixed(2)}) | MCP9: (${pt9.$1.toStringAsFixed(2)}, ${pt9.$2.toStringAsFixed(2)}) | dx: ${(pt9.$1 - pt0.$1).toStringAsFixed(3)} | dy: ${(pt9.$2 - pt0.$2).toStringAsFixed(3)}");
      }

      if (hands.length == 1) {
        final hand = hands.first;
        final pt0 = _toScreenCoords(hand.landmarks[0], cameraRotation, lensDirection);
        final double screenX = pt0.$1;

        // Para sinais dinâmicos (LSTM):
        // Se a mão estiver no lado direito da tela (screenX >= 0.40), mapeia para Right Hand (195..257).
        // Se estiver no lado esquerdo (screenX < 0.40), mapeia para Left Hand (132..194).
        // Para Alfabeto estático (!isMovement):
        // O modelo MLP foi treinado com 100% de acurácia no slot 132..194 (leftHandLandmarks no MediaPipe Holistic).
        // Colocamos sempre no slot 132..194.
        final bool assignToRight = isMovement && (screenX >= 0.40);
        final targetList = assignToRight ? rawRightHand : rawLeftHand;

        final handMarks = hand.landmarks;
        for (int i = 0; i < 21 && i < handMarks.length; i++) {
          final pt = _toScreenCoords(handMarks[i], cameraRotation, lensDirection);
          final int baseIdx = i * 3;
          targetList[baseIdx]     = pt.$1;
          targetList[baseIdx + 1] = pt.$2;
          targetList[baseIdx + 2] = pt.$3;
        }
      } else if (hands.length >= 2) {
        final ptWrist0 = _toScreenCoords(hands[0].landmarks[0], cameraRotation, lensDirection);
        final ptWrist1 = _toScreenCoords(hands[1].landmarks[0], cameraRotation, lensDirection);
        final double sX0 = ptWrist0.$1;
        final double sX1 = ptWrist1.$1;

        // Menor screenX = lado esquerdo da tela (mão física esquerda) -> rawLeftHand (132..194).
        // Maior screenX = lado direito da tela (mão física direita) -> rawRightHand (195..257).
        final handForLeft = sX0 <= sX1 ? hands[0] : hands[1];
        final handForRight = sX0 <= sX1 ? hands[1] : hands[0];

        for (int i = 0; i < 21 && i < handForLeft.landmarks.length; i++) {
          final pt = _toScreenCoords(handForLeft.landmarks[i], cameraRotation, lensDirection);
          final int baseIdx = i * 3;
          rawLeftHand[baseIdx]     = pt.$1;
          rawLeftHand[baseIdx + 1] = pt.$2;
          rawLeftHand[baseIdx + 2] = pt.$3;
        }
        for (int i = 0; i < 21 && i < handForRight.landmarks.length; i++) {
          final pt = _toScreenCoords(handForRight.landmarks[i], cameraRotation, lensDirection);
          final int baseIdx = i * 3;
          rawRightHand[baseIdx]     = pt.$1;
          rawRightHand[baseIdx + 1] = pt.$2;
          rawRightHand[baseIdx + 2] = pt.$3;
        }
      }
    } catch (e) {
      debugPrint("Aviso: Falha ao processar mãos: $e");
      return List.filled(258, 0.0);
    }

    // --- 3. NOISE GATE ---
    final bool hasLeft = rawLeftHand.any((v) => v != 0.0);
    final bool hasRight = rawRightHand.any((v) => v != 0.0);
    if (!hasLeft && !hasRight) {
      return List.filled(258, 0.0);
    }

    // --- 4. VETOR FINAL COM NORMALIZAÇÃO GEOMÉTRICA ---
    final List<double> finalFeatures = List.filled(258, 0.0);

    // Para movimento dinâmico (LSTM), utiliza pose cacheada sem travar o stream a 10 FPS
    if (isMovement) {
      finalFeatures.setRange(0, 132, _cachedPoseFeatures);

      // Dispara detecção assíncrona se o detector de pose estiver ocioso
      if (!_isPoseProcessing && _poseDetector != null) {
        _triggerAsyncPoseDetection(image, cameraRotation, lensDirection: lensDirection);
      }
    }

    // 4b. Normalizar Mão Esquerda (slot 132..194)
    _normalizeHand(rawLeftHand, finalFeatures, 132);

    // 4c. Normalizar Mão Direita (slot 195..257)
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

            rawPose[baseIdx]     = lensDirection == CameraLensDirection.front ? (1.0 - normX) : normX;
            rawPose[baseIdx + 1] = normY;
            rawPose[baseIdx + 2] = normZ;
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

  /// Normaliza uma mão de 21 landmarks × 3 e escreve em finalFeatures a partir de offset.
  void _normalizeHand(List<double> rawHand, List<double> finalFeatures, int offset) {
    final bool hasData = rawHand[0] != 0.0 || rawHand[1] != 0.0;
    if (!hasData) return;

    final double wristX = rawHand[0], wristY = rawHand[1], wristZ = rawHand[2];

    // MCP do dedo médio (índice 9) — APÓS subtrair o pulso
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

      // Noise Gate para Tearing de Câmera: Um dedo real não pode estar 10x mais longe que a distância Pulso-MCP.
      // Isso impede que anomalias na imagem gerem falsos positivos
      if (normX.abs() > 10.0 || normY.abs() > 10.0 || normZ.abs() > 10.0) {
        // Se a mão for gigante em relação ao pulso, a leitura foi corrompida.
        // Zera tudo o que já foi preenchido para não enviar lixo para a rede.
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

  /// Converte as coordenadas do HandLandmarker para o sistema de tela do app.
  /// No Android, o sensor da câmera opera em modo paisagem nativo (com sensorOrientation = 270° na frontal e 90° na traseira).
  /// O MediaPipe Tasks retorna os landmarks mapeados de volta ao buffer de entrada cru (sensor space).
  /// Para alinhar perfeitamente com a orientação vertical (retrato selfie espelhado), a transformação é:
  /// Frontal (270°):
  ///   outX = 1.0 - markY (eixo horizontal da tela espelhado)
  ///   outY = 1.0 - markX (eixo vertical da tela)
  /// Traseira (90°):
  ///   outX = 1.0 - markY
  ///   outY = markX
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
        default: // 0
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
        default: // 0
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
