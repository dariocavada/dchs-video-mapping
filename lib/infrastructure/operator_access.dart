import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class OperatorAccess {
  OperatorAccess._(this.root);
  final Directory root;
  String? _salt, _hash;
  int _failures = 0;
  DateTime? _blockedUntil;
  bool get isSet => _hash != null;
  static Future<OperatorAccess> load(Directory root) async {
    final a = OperatorAccess._(root), f = File('${root.path}/access.json');
    if (await f.exists()) {
      final j = jsonDecode(await f.readAsString()) as Map;
      if (j['schemaVersion'] != 1 ||
          base64Decode(j['salt'] as String).length != 16 ||
          base64Decode(j['hash'] as String).length != 32) {
        throw const FormatException(
          'Credenziali non valide; ripristinare dal personale tecnico.',
        );
      }
      a._salt = j['salt'] as String;
      a._hash = j['hash'] as String;
    }
    return a;
  }

  Future<List<int>> _derive(String pin, String salt) async =>
      await (await Pbkdf2(
            macAlgorithm: Hmac.sha256(),
            iterations: 120000,
            bits: 256,
          ).deriveKey(
            secretKey: SecretKey(utf8.encode(pin)),
            nonce: base64Decode(salt),
          ))
          .extractBytes();
  Future<void> setPin(String pin) async {
    if (!RegExp(r'^\d{6,12}$').hasMatch(pin)) {
      throw const FormatException('Usare da 6 a 12 cifre.');
    }
    final random = Random.secure(),
        salt = base64Encode(List.generate(16, (_) => random.nextInt(256))),
        hash = base64Encode(await _derive(pin, salt));
    await root.create(recursive: true);
    final f = File('${root.path}/access.tmp');
    await f.writeAsString(
      jsonEncode({'schemaVersion': 1, 'salt': salt, 'hash': hash}),
      flush: true,
    );
    await f.rename('${root.path}/access.json');
    _salt = salt;
    _hash = hash;
  }

  Future<bool> verify(String pin) async {
    if (!isSet || (_blockedUntil?.isAfter(DateTime.now()) ?? false)) {
      return false;
    }
    final actual = await _derive(pin, _salt!), expected = base64Decode(_hash!);
    var delta = actual.length ^ expected.length;
    for (var i = 0; i < actual.length && i < expected.length; i++) {
      delta |= actual[i] ^ expected[i];
    }
    if (delta == 0) {
      _failures = 0;
      return true;
    }
    if (++_failures >= 5) {
      _blockedUntil = DateTime.now().add(const Duration(seconds: 30));
      _failures = 0;
    }
    return false;
  }
}
