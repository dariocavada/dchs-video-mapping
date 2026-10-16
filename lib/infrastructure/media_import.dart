import 'dart:io';

class MediaImporter {
  MediaImporter(this.root);
  final Directory root;
  Future<String> import(
    Stream<List<int>> bytes,
    String extension, {
    required Future<void> Function(File) validate,
  }) async {
    if (!RegExp(r'^[a-zA-Z0-9]{1,8}$').hasMatch(extension)) {
      throw const FormatException('Invalid extension');
    }
    await Directory('${root.path}/media').create(recursive: true);
    final name = 'video-${DateTime.now().microsecondsSinceEpoch}';
    final temp = File('${root.path}/media/$name.tmp'),
        path = 'media/$name.${extension.toLowerCase()}';
    try {
      final sink = temp.openWrite();
      try {
        await sink.addStream(bytes);
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (await temp.length() == 0) {
        throw const FormatException('The video is empty.');
      }
      await validate(temp);
      await temp.rename('${root.path}/$path');
      return path;
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
  }
}
