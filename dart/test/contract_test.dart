// Dart contract test. Input validation runs always (like Go's TestInput); the
// live HTTPS/WSS contract runs only under the isolated fixture from
// tests/integration.mjs, which sets DS_TEST_URL/DS_TEST_CA. Mirrors the
// JavaScript and Python contract tests.
import 'dart:async';
import 'dart:io';

import 'package:deskcite/deskcite.dart';
import 'package:test/test.dart';

void main() {
  test('rejects non-HTTPS origins and unsafe document paths', () {
    for (final origin in [
      'http://example.test',
      'https://u@example.test',
      'https://example.test/path',
    ]) {
      expect(() => Client(origin, 'token'), throwsArgumentError);
    }
    final client = Client('https://example.test', 'token');
    for (final path in [
      'https://elsewhere.test/x',
      '/deskcite/documents/%2e%2e/x',
      '/deskcite/documents/a?x=1',
    ]) {
      expect(() => client.document(path), throwsArgumentError);
    }
  });

  final origin = Platform.environment['DS_TEST_URL'];
  test('HTTPS routes, bytes, errors, rotation, WSS', () async {
    final context = SecurityContext(withTrustedRoots: true)
      ..setTrustedCertificates(Platform.environment['DS_TEST_CA']!);
    final client = Client(origin!, 'test-bearer', securityContext: context);

    for (final entry in operations.entries) {
      if (['refresh', 'document', 'question'].contains(entry.key)) continue;
      final args = entry.value['kind'] == 'json'
          ? {'text': 'café & ?', 'q': 'test', 'action': 'calendar'}
          : <String, dynamic>{};
      final response = await client.call(entry.key, args);
      expect(response.body['ok'], isTrue, reason: entry.key);
    }

    final question = await client.question('id/ ?#');
    expect(question.body['path'], endsWith('id%2F%20%3F%23'));

    final document = await client.document('/deskcite/documents/a%20b.pdf');
    expect(document.body, equals([0, 255, 10]));

    for (final (text, status) in [('__error__', 503), ('__redirect__', 302)]) {
      try {
        await client.similar({'text': text});
        fail('expected DeskciteError for $text');
      } on DeskciteError catch (e) {
        expect(e.response.status, status);
        expect((e.response.body as List).isNotEmpty, isTrue);
      }
    }

    final renewed = await client.refresh();
    client.setToken(renewed.body['access_token'] as String);
    final rotated = await client.status();
    expect(rotated.body['credential'], 'rotated');

    final got = Completer<Map<String, dynamic>>();
    final connection = await client.events((message) {
      if (!got.isCompleted) got.complete(message);
    });
    try {
      await connection.recv();
      final event = await got.future.timeout(const Duration(seconds: 5));
      expect(event['type'], 'import.done');
    } finally {
      await connection.close();
    }
  },
      skip: origin == null
          ? 'set DS_TEST_URL (run tests/integration.mjs)'
          : false);
}
