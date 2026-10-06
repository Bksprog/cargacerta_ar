import 'package:cargacerta_ar/app.dart';
import 'package:cargacerta_ar/data/inventory_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// Mantém este arquivo: o `flutter create .` gera um widget_test.dart padrão
// (que referencia `MyApp`) e este aqui o substitui por um teste que funciona.
void main() {
  testWidgets('abre em Calibrar e navega para Mapear', (tester) async {
    await tester.pumpWidget(
      CargaCertaApp(repository: InMemoryInventoryRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Objeto de referência'), findsOneWidget);

    await tester.tap(find.text('Mapear').first);
    await tester.pumpAndSettle();

    expect(find.text('Mapear e selecionar'), findsOneWidget);
  });
}
