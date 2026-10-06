import 'dart:io';

Future<void> deleteTempFile(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // Melhor esforço: o diretório de cache do SO também é limpo pelo sistema.
  }
}
