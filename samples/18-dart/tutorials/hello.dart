// Lesson 1: your first search. Self-contained, like the filmed Python hello.py:
// it needs DESKCITE_TOKEN_FILE and DESKCITE_CA, asks `similar` for the top
// three answers, and prints each answer with its source path.
import 'dart:io';

import 'package:deskcite/deskcite.dart';

Future<void> main() async {
  final token =
      File(Platform.environment['DESKCITE_TOKEN_FILE']!).readAsStringSync().trim();
  final trust = SecurityContext(withTrustedRoots: true)
    ..setTrustedCertificates(Platform.environment['DESKCITE_CA']!);
  final client = Client(Platform.environment['DESKCITE_URL']!, token,
      securityContext: trust);
  final result = await client
      .similar({'text': 'How do I upload a document in Deskcite?', 'n': 3});
  for (final row in result.body['rows']) {
    print(row['answer']);
    print('Source: ${row['path']}');
  }
}
