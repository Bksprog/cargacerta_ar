// Remove o arquivo temporário criado pela câmera nativa logo após a leitura,
// para que nenhuma foto da casa do usuário fique no armazenamento do app.
// Na web não há arquivo em disco (a foto vive só em memória), então vira no-op.
export 'secure_temp_stub.dart' if (dart.library.io) 'secure_temp_io.dart';
