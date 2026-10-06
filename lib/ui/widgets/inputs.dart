import 'package:flutter/services.dart';

/// Só aceita dígitos, vírgula e ponto, com tamanho máximo. Primeira barreira;
/// a validação de verdade está em `core/validators.dart`.
List<TextInputFormatter> decimalInputFormatters() => <TextInputFormatter>[
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      LengthLimitingTextInputFormatter(8),
    ];

List<TextInputFormatter> integerInputFormatters() => <TextInputFormatter>[
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(3),
    ];
