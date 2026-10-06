import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'data/inventory_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Nenhum erro é enviado a servidores: o app não faz chamadas de rede.
  // Em produção o erro é contido (sem expor stack trace ao usuário).
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('Erro não tratado: $error\n$stack');
    }
    return true;
  };

  runApp(CargaCertaApp(repository: PrefsInventoryRepository()));
}
