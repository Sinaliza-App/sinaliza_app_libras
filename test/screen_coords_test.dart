import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hand_landmarker/hand_landmarker.dart';

(double, double, double) toScreenCoords(
  Landmark mark, 
  int cameraRotation, 
  CameraLensDirection lensDirection,
) {
  final double markX = mark.x;
  final double markY = mark.y;
  final double markZ = mark.z;

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

void main() {
  test('Coordenadas em modo selfie frontal (270) mantém orientação vertical', () {
    // No sensor Android frontal montado a 270°:
    // Uma mão erguida verticalmente na tela (dedos para o topo, pulso na base)
    // No sensor:
    // Pulso: markX = 0.40 (perto da base da tela: 1.0 - 0.40 = 0.60 no Y da tela)
    // MCP9:  markX = 0.60 (perto do topo da tela: 1.0 - 0.60 = 0.40 no Y da tela)
    // Centro: markY = 0.50 (centro horizontal: 1.0 - 0.50 = 0.50 no X da tela)
    final wrist = Landmark(0.40, 0.50, 0.0);
    final mcp9 = Landmark(0.60, 0.50, 0.0);

    final ptWrist = toScreenCoords(wrist, 270, CameraLensDirection.front);
    final ptMcp9 = toScreenCoords(mcp9, 270, CameraLensDirection.front);

    // Na tela: ptWrist.Y = 0.60, ptMcp9.Y = 0.40
    // O vetor do pulso para MCP9 aponta para cima (dy negativo)
    final dy = ptMcp9.$2 - ptWrist.$2;
    expect(dy, lessThan(0.0), reason: 'A mão erguida deve apontar para o topo da tela (dy < 0)');

    // O vetor dx deve ser próximo de zero (vertical ereto)
    final dx = ptMcp9.$1 - ptWrist.$1;
    expect(dx.abs(), lessThan(0.01), reason: 'A mão erguida deve ser vertical (dx ~ 0)');
  });
}
