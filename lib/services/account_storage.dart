import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

/// Immutable account scope: an in-flight operation never changes destination
/// when Firebase's current user changes. Legacy unowned files are left intact.
class AccountStorage {
  final String? userId;
  final Future<Directory> Function() _documentsDirectory;

  AccountStorage(this.userId,
      {Future<Directory> Function()? documentsDirectory})
      : _documentsDirectory =
            documentsDirectory ?? getApplicationDocumentsDirectory;

  Future<String> filePath(String name) async {
    if (userId == null) throw StateError('Account storage requires sign-in');
    if (!RegExp(r'^[a-z_]+\.json$').hasMatch(name)) {
      throw ArgumentError.value(name, 'name', 'Invalid account filename');
    }
    final root = await _documentsDirectory();
    final account = sha256.convert(utf8.encode(userId!)).toString();
    final directory = Directory('${root.path}/accounts/$account');
    await directory.create(recursive: true);
    return '${directory.path}/$name';
  }
}
