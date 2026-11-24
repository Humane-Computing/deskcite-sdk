// Lesson 2: an echo agent over the mesgd bus. Both roles are WebSocket clients
// of the same broker. `to` routes a message; `type` selects a local callback.
// Run `bus server` in one terminal, wait for `ready: server`, then `bus client`
// in another. Plain JSON over verified TLS — no signing, durable delivery, or
// automatic reconnect.
import 'dart:convert';
import 'dart:io';

import 'package:mesgd/mesgd.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1 || !['server', 'client'].contains(args[0])) {
    stderr.writeln('usage: dart run bus.dart server|client');
    exit(1);
  }
  final role = args[0];
  final address = role == 'server' ? 'service' : 'client';
  final origin = Platform.environment['MESGD_WSS']!.replaceAll(RegExp(r'/+$'), '');
  final context = SecurityContext(withTrustedRoots: true);
  final ca = Platform.environment['MESGD_CA'];
  if (ca != null) context.setTrustedCertificates(ca);
  final connection = await Mesgd.connect('$origin/to=$address',
      token: Platform.environment['MESGD_TOKEN'], securityContext: context);
  var done = false;

  void receive(Map<String, dynamic> message) {
    if (role == 'server') {
      print('agent received: ${jsonEncode(message['body'])}');
      connection.send({
        'to': message['from'],
        'from': 'service',
        'type': 'echo.reply',
        'body': message['body'],
      });
    } else {
      print(jsonEncode(message['body']));
      done = true;
    }
  }

  connection.on(role == 'server' ? 'echo.request' : 'echo.reply', receive);
  print('ready: $role');
  try {
    if (role == 'client') {
      await connection.send({
        'to': 'service',
        'from': 'client',
        'type': 'echo.request',
        'body': {'text': 'hello'},
      });
    }
    while (!done) {
      await connection.recv();
    }
  } finally {
    await connection.close();
  }
}
