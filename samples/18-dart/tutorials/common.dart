// Shared credential loader and atomic private store for the rotation lesson.
// Mirrors the Python common.py helper: load reads the bearer from a private
// file (or DESKCITE_TOKEN) and trusts an optional private CA; store writes the
// replacement to a mode-0600 temp file in the same directory, then renames it
// over the target. Unix, single-owner demonstration — not a production vault.
import 'dart:io';

import 'package:deskcite/deskcite.dart';

(Client, String) load() {
  final file = Platform.environment['DESKCITE_TOKEN_FILE'];
  final token = file != null
      ? File(file).readAsStringSync().trim()
      : Platform.environment['DESKCITE_TOKEN']!;
  final context = SecurityContext(withTrustedRoots: true);
  final ca = Platform.environment['DESKCITE_CA'];
  if (ca != null) context.setTrustedCertificates(ca);
  return (
    Client(Platform.environment['DESKCITE_URL']!, token,
        securityContext: context),
    token,
  );
}

Future<void> store(String token) async {
  final target = Platform.environment['DESKCITE_TOKEN_FILE']!;
  final directory = File(target).parent.path;
  final temp = File(
      '$directory/.rotate-$pid-${DateTime.now().microsecondsSinceEpoch}');
  await temp.create();
  // Restrict the file before the secret is written into it.
  final chmod = await Process.run('chmod', ['600', temp.path]);
  if (chmod.exitCode != 0) {
    await temp.delete();
    throw StateError('could not restrict credential file');
  }
  try {
    await temp.writeAsString('$token\n', flush: true);
    await temp.rename(target);
  } catch (error) {
    if (await temp.exists()) await temp.delete();
    rethrow;
  }
}
