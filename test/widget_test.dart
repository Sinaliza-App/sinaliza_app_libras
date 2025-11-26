import 'package:flutter_test/flutter_test.dart';
import 'package:sinaliza_app_libras/main.dart';

void main() {
  testWidgets('App inicializa corretamente', (WidgetTester tester) async {
    // Constrói o app principal
    await tester.pumpWidget(const sinaliza());

    // Verifica se o app carregou (sem crashar)
    expect(find.text('SINALIZA'), findsNothing);
  });
}
