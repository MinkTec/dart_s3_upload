import 'dart:convert';

import 'package:dart_s3_upload/src/content.dart';
import 'package:http/http.dart';

class ClientResponse {
  final int statusCode;
  final String responseBody;
  final String? reasonPhrase;
  final UploadableContent content;

  ClientResponse(
      {required this.statusCode,
      required this.responseBody,
      required this.reasonPhrase,
      required this.content});

  static Future<ClientResponse> fromResponse(
          StreamedResponse response, UploadableContent content) async =>
      ClientResponse(
          statusCode: response.statusCode,
          responseBody: AsciiDecoder()
              .convert(await response.stream.expand((i) => i).toList()),
          reasonPhrase: response.reasonPhrase,
          content: content);

  bool get success => 200 <= statusCode && statusCode < 300;

  String get key => content.uploadKey;
}
