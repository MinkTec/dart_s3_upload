import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'dart:io' show File;

abstract class UploadableContent {
  Future<int> get length;
  Future<http.MultipartFile> get filestream;

  String directory;
  String filename;
  String contentType;
  Map<String, String>? metadata;

  String get uploadKey => "$directory/$filename";

  UploadableContent(
      {this.contentType = 'binary/octet-stream',
      this.metadata,
      required this.directory,
      required this.filename});
}

class UploadableString extends UploadableContent {
  /// complex unicode is not supported
  final String _string;

  @override
  Future<http.MultipartFile> get filestream async {
    final stream = http.ByteStream(Stream.castFrom(
        Stream.fromIterable([_string.runes.map((e) => e.toInt()).toList()])));
    return http.MultipartFile('file', stream, await length);
  }

  @override
  Future<int> get length async => _string.length;

  UploadableString(this._string,
      {super.contentType,
      super.metadata,
      required super.directory,
      required super.filename});
}

class UploadableFile extends UploadableContent {
  final File _file;

  @override
  Future<http.MultipartFile> get filestream async {
    final stream = http.ByteStream(Stream.castFrom(_file.openRead()));

    return http.MultipartFile('file', stream, await length,
        filename: path.basename(_file.path));
  }

  @override
  Future<int> get length => _file.length();

  UploadableFile(this._file,
      {super.contentType,
      super.metadata,
      String? filename,
      required super.directory})
      : super(filename: filename ?? path.basename(_file.path));
}
