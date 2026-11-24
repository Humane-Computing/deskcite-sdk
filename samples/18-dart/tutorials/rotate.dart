// Lesson 3: refresh and replace a bearer. Refreshes exactly once, saves the
// replacement atomically, confirms it works, and requires HTTP 401 for the old
// bearer. Prints only verification text — never the credential.
import 'dart:io';

import 'package:deskcite/deskcite.dart';

import 'common.dart';

Future<void> main() async {
  Platform.environment['DESKCITE_TOKEN_FILE']!; // A private file is required.
  final (client, old) = load();
  final replacement =
      (await client.refresh()).body['access_token'] as String; // One attempt.
  await store(replacement); // Atomic replacement before resuming work.
  client.setToken(replacement);
  await client.status();
  client.setToken(old);
  try {
    await client.status();
    throw StateError('Old bearer was unexpectedly accepted');
  } on DeskciteError catch (error) {
    if (error.response.status != 401) rethrow;
  }
  client.setToken(replacement);
  print('Credential rotated and saved; replacement works; old bearer rejected.');
}
